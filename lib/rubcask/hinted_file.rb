# frozen_string_literal: true

require "forwardable"
require "tempfile"
require "fileutils"

module Rubcask
  # HintedFile represents DataFile with the associated hint file
  # it delegated all read/write responsibility to the @data_file
  class HintedFile
    extend Forwardable

    ID_REGEX = /(\d+)\.data$/
    HINT_EXTENSION_REGEX = /\.data$/

    def_delegators :@data_file, :seek, :[], :pread, :close, :flush, :each, :pos, :write_pos

    # @return [String] path of the file
    attr_reader :path

    # @return [Integer] id of the file
    attr_reader :id

    # @return [String] Path of the hint file associated with the data file
    attr_reader :hint_path

    # @param [String] file_path Path of the data_file
    # @param [Boolean] os_sync Should O_SYNC flag be used on the data file?
    # @param [Boolean] read_only Should the data file be opened read-only?
    # @param [Boolean] ruby_sync Should ruby I/O buffers by bupassed?
    def initialize(file_path, os_sync: false, read_only: false, ruby_sync: false)
      @id = file_path.scan(ID_REGEX)[0][0].to_i
      @hint_path = file_path.sub(HINT_EXTENSION_REGEX, ".hint")
      @path = file_path
      @read_only = read_only

      io = nil
      size = nil
      flags = (os_sync && ruby_sync) ? File::SYNC : 0
      if File.exist?(file_path)
        size = File.size(file_path)
        @dirty = false
        io = File.open(file_path, "#{read_only ? "r" : "a+"}b", flags: flags)
      else # If file does not exist we ignore read_only as it does not make sense
        size = 0
        @dirty = true
        io = File.open(file_path, "a+b", flags: flags)
      end
      @data_file = DataFile.new(io, size)

      if ruby_sync
        @data_file.sync = true
      end
    end

    # yields every KeydirEntry in the file
    # @yield [keydir_entry]
    # @yieldparam [KeydirEntry] keydirEntry
    # @return [Enumerator] if no block given
    def each_keydir_entry(&block)
      return to_enum(__method__) unless block
      if has_hint_file?
        return each_hint_file_keydir_entry(&block)
      end
      each_data_file_keydir_entry(&block)
    end

    # Appends the entry to the end of the file
    # @param [DataEntry] entry entry to append
    # @return [KeydirEntry]
    def append(entry)
      if !dirty?
        FileUtils.rm_f(hint_path)
        @dirty = true
      end
      write_entry = @data_file.append(entry)
      KeydirEntry.new(id, write_entry.value_size, write_entry.value_pos, entry.expire_timestamp)
    end

    # Creates a new hint file
    def save_hint_file
      tempfile = Tempfile.new("hint")
      current_pos = 0
      map = {}
      data_file.each do |entry|
        new_pos = data_file.pos
        new_entry = HintEntry.new(entry.expire_timestamp, entry.key, current_pos, new_pos - current_pos)
        current_pos = new_pos
        map[entry.key] = new_entry
      end

      begin
        hint_file = HintFile.new(tempfile)
        map.each_value do |entry|
          hint_file.append(entry)
        end
        hint_file.close
        FileUtils.mv(tempfile.path, hint_path)
        @dirty = false
      ensure
        tempfile.close(true)
      end
    end

    # @return true if hint path exists
    def has_hint_file?
      File.exist?(hint_path)
    end

    # @return true if there were any appends to the data file
    def dirty?
      @dirty
    end

    private

    attr_reader :data_file

    def each_data_file_keydir_entry
      current_pos = 0
      @data_file.each do |entry|
        new_pos = @data_file.pos
        value_size = new_pos - current_pos
        value_pos = current_pos
        current_pos = new_pos
        yield [
          entry.key,
          KeydirEntry.new(
            id, value_size, value_pos, entry.expire_timestamp
          )
        ]
      end
    end

    def each_hint_file_keydir_entry
      File.open(hint_path, "rb") do |file|
        HintFile.new(file).each do |entry|
          yield [
            entry.key,
            KeydirEntry.new(
              id, entry.value_size, entry.value_pos, entry.expire_timestamp
            )
          ]
        end
      end
    end
  end
end
