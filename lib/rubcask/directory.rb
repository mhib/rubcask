# frozen_string_literal: true

require "concurrent/atomic/atomic_fixnum"
require "concurrent/atomic/reentrant_read_write_lock"

require "fiber" # rubocop:disable Lint/RedundantRequireStatement It is needed for `Fiber.current`(used by concurrent) in some rubies
require "forwardable"
require "logger"
require "monitor"
require "tmpdir"

require_relative "concurrency/fake_lock"
require_relative "concurrency/fake_atomic_fixnum"
require_relative "concurrency/fake_monitor_mixin"

require_relative "task/clean_directory"

require_relative "worker/factory"

require_relative "config"
require_relative "data_entry"
require_relative "data_file"
require_relative "hint_entry"
require_relative "hint_file"
require_relative "hinted_file"
require_relative "keydir_entry"
require_relative "merge_directory"
require_relative "tombstone"

module Rubcask
  class Directory
    extend Forwardable

    # yields directory to the block and closes it after the block is terminated
    # @see #initialize
    # @yieldparam [Directory] directory
    # @return [void]
    def self.with_directory(dir, config: Config.new)
      directory = new(dir, config: config)
      begin
        yield directory
      ensure
        directory.close
      end
    end

    # @!macro [new] key_is_bytearray
    #   @note key is always treated as byte array, encoding is ignored

    # @!macro [new] deleted_keys
    #   @note It might include deleted keys

    # @!macro [new] lock_block_for_iteration
    #   @note This method blocks writes for the entire iteration

    # @!macro [new] key_any_order
    #   @note Keys might be in any order

    # @param [String] dir Path to the directory where data is stored
    # @param [Config] config Config of the directory
    def initialize(dir, config: Config.new)
      @dir = dir
      @config = check_config(config)

      max_id = 0
      files = dir_data_files
      @files = files.each_with_object({}) do |file, hash|
        next if File.executable?(file)
        if file.equal?(files.last) && File.size(file) < config.max_file_size
          hinted_file = open_write_file(file)
          @active = hinted_file
        else
          hinted_file = open_read_only_file(file)
        end

        id = hinted_file.id

        hash[id] = hinted_file
        max_id = id # dir_data_files returns an already sorted collection
      end
      @max_id = (config.threadsafe ? Concurrent::AtomicFixnum : Concurrency::FakeAtomicFixnum).new(max_id)
      @lock = config.threadsafe ? Concurrent::ReentrantReadWriteLock.new : Concurrency::FakeLock.new
      @worker = Worker::Factory.new_worker(@config.worker)

      @logger = Logger.new($stdin)
      @logger.level = Logger::INFO

      @merge_mutex = Thread::Mutex.new

      load_keydir!
      create_new_file! unless @active
    end

    # Set value associated with given key.
    # @macro key_is_bytearray
    # @param [String] key
    # @param [String] value
    # @return [String] the value provided by the user
    def []=(key, value)
      put(key, value, NO_EXPIRE_TIMESTAMP)
      value # rubocop:disable Lint/Void
    end

    # Set value associated with given key with given ttl
    # @macro key_is_bytearray
    # @param [String] key
    # @param [String] value
    # @param [Integer] ttl Time to live
    # @return [String] the value provided by the user
    # @return [String] the value provided by the user
    # @raise [ArgumentError] if ttl is negative
    def set_with_ttl(key, value, ttl)
      raise ArgumentError, "Negative ttl" if ttl.negative?
      put(key, value, Time.now.to_i + ttl)
      value # rubocop:disable Lint/Void
    end

    # Gets value associated with the key
    # @macro key_is_bytearray
    # @param [String] key
    # @return [String] value associatiod with the key
    # @return [nil] If no value associated with the key
    def [](key)
      key = normalize_key(key)
      @lock.with_read_lock do
        entry = @keydir[key]
        return nil unless entry

        if entry.expired?
          return nil
        end

        data_file = @files[entry.file_id]

        # We are using pread so there's no need to synchronize the read
        value = data_file.pread(entry.value_pos, entry.value_size).value
        return nil if Tombstone.is_tombstone?(value)
        return value
      end
    end

    # Remove entry associated with the key.
    # @param [String] key
    # @macro key_is_bytearray
    # @return false if the existing value does not exist
    # @return true if the delete was succesfull
    def delete(key)
      key = normalize_key(key)
      @lock.with_write_lock do
        prev_val = @keydir[key]
        if prev_val.nil?
          return false
        end
        if prev_val.expired?
          @keydir.delete(key)
          return false
        end
        do_delete(key, prev_val.file_id)
        true
      end
    end

    # Starts the merge operation.
    # @raise [MergeAlreadyInProgress] if another merge operation is in progress
    def merge
      unless @merge_mutex.try_lock
        raise MergeAlreadyInProgressError, "Merge is already in progress"
      end
      begin
        non_synced_merge
      rescue => ex
        logger.error("Error while merging #{ex}")
      ensure
        @merge_mutex.unlock
      end
    end

    # Closes all the files and the worker
    def close
      @lock.with_write_lock do
        @files.each_value(&:close)
        if active.write_pos == 0
          File.delete(active.path)
        end
      end
      worker.close
    end

    # @yieldparam [String] key
    # @yieldparam [String] value
    # @macro lock_block_for_iteration
    # @macro key_any_order
    # @return [Enumerator<Array(String, String)>] if no block given
    def each
      return to_enum(__method__) unless block_given?

      @lock.with_read_lock do
        @keydir.each do |key, entry|
          file = @files[entry.file_id]
          value = file[entry.value_pos, entry.value_size].value
          next if Tombstone.is_tombstone?(value)
          yield [key, value]
        end
      end
    end

    # @yieldparam [String] key
    # @macro deleted_keys
    # @macro key_any_order
    # @macro lock_block_for_iteration
    # @return [Enumerator<String>] if no block given
    def each_key(&block)
      return to_enum(__method__) unless block

      @lock.with_read_lock do
        @keydir.each_key(&block)
      end
    end

    # Generate hint files for data files that do not have hint files
    def generate_missing_hint_files!
      @lock.with_read_lock do
        @files.each_value do |data_file|
          next if data_file.has_hint_file? && !data_file.dirty?
          data_file.synchronize do
            data_file.save_hint_file
          end
        end
      end
    end

    # Generate hint files for all the data files
    def regenerate_hint_files!
      @lock.with_read_lock do
        @files.each_value do |data_file|
          data_file.synchronize do
            data_file.save_hint_file
          end
        end
      end
    end

    # Removes files that are not needed after the merge
    def clear_files
      worker.push(Rubcask::Task::CleanDirectory.new(@dir))
    end

    # Returns number of keys in the store
    # @note It might count some deleted keys
    # @return [Integer]
    def key_count
      @lock.with_read_lock do
        @keydir.size
      end
    end

    # Returns array of keys in store
    # @macro deleted_keys
    # @macro key_any_order
    # @return [Array<String>]
    def keys
      @lock.with_read_lock do
        @keydir.keys
      end
    end

    private

    attr_reader :config, :active, :worker, :logger

    def put(key, value, expire_timestamp)
      key = normalize_key(key)
      @lock.with_write_lock do
        @keydir[key] = active.append(
          DataEntry.new(expire_timestamp, key, value)
        )
        if active.write_pos >= @config.max_file_size
          create_new_file!
        end
      end
      value # rubocop:disable Lint/Void
    end

    # @note This method assumes write lock and normalized key
    def do_delete(key, prev_file_id)
      active.append(
        DataEntry.new(NO_EXPIRE_TIMESTAMP, key, Tombstone.new_tombstone(active.id, prev_file_id))
      )
      @keydir.delete(key)
      if active.write_pos >= @config.max_file_size
        create_new_file!
      end
    end

    # This methods does not provide synchronization and should be run with write lock
    def close_not_active
      @files.each_value do |file|
        next if file == active
        file.close
      end
    end

    def synchronize_hinted_file!(file)
      file.extend(
        @config.threadsafe ? MonitorMixin : Concurrency::FakeMonitorMixin
      )
    end

    def non_synced_merge
      merging_paths = nil
      @lock.with_write_lock do
        merging_paths = @files.sort_by(&:first).map! { |k, v| [k, v.path] }
        create_new_file!
      end

      Dir.mktmpdir do |tmpdir|
        out = MergeDirectory.new(tmpdir, config: @config, max_id_ref: @max_id)

        merging_paths.each do |id, path|
          merge_single_file(out, id, path)
        end

        out.close

        Dir.each_child(tmpdir) do |child|
          FileUtils.mv(File.join(tmpdir, child), @dir)
        end
      end

      @lock.with_write_lock do
        close_not_active
        merging_paths.each { |_id, path| FileUtils.chmod("+x", path) }
        reload!
      end
      clear_files
    end

    def merge_single_file(out, id, path)
      File.open(path, "rb") do |io|
        pos = 0
        file = DataFile.new(io, 0)
        file.each do |entry|
          start_pos = pos
          pos = file.pos

          next if entry.expired?
          next if Tombstone.is_tombstone?(entry.value)

          @lock.acquire_read_lock
          begin
            keydir_entry = @keydir[entry.key]
            next unless keydir_entry

            # Ignore records overwritten in a new file
            next if keydir_entry.file_id > id
            # Ignore records overwritten in the data file
            next if keydir_entry.file_id == id && keydir_entry.value_pos > start_pos
          ensure
            @lock.release_read_lock
          end
          out.append(entry)
        end
      end
    end

    def reload!
      @files = dir_data_files.each_with_object({}) do |file, hash|
        next if File.executable?(file) || file == @active.path
        hinted_file = open_read_only_file(file)

        id = hinted_file.id

        hash[id] = hinted_file
      end
      @files[@active.id] = @active
      load_keydir!
    end

    def load_keydir!
      @keydir = {}

      # Note that file iteration is oldest to newest
      @files.each_value do |file|
        file.each_keydir_entry do |key, entry|
          if entry.expired?
            @keydir.delete(key)
          else
            @keydir[key] = entry
          end
        end
      end
    end

    def open_write_file(file)
      HintedFile.new(
        file,
        os_sync: config.io_strategy == :os_sync,
        read_only: false,
        ruby_sync: config.io_strategy != :ruby
      ).tap { |f| synchronize_hinted_file!(f) }
    end

    def open_read_only_file(file)
      HintedFile.new(
        file,
        read_only: true
      ).tap { |f| synchronize_hinted_file!(f) }
    end

    def create_new_file!
      id = @max_id.increment
      file = open_write_file(File.join(@dir, "#{id}.data"))
      @active = file
      @files[id] = file
    end

    def dir_data_files
      Dir.glob(File.join(@dir, "*.data")).sort_by! { |el| File.basename(el).to_i }
    end

    def check_config(config)
      config
    end

    def normalize_key(key)
      key = key.to_s
      return key if key.encoding.equal?(Encoding::ASCII_8BIT)

      key.b
    end
  end
end
