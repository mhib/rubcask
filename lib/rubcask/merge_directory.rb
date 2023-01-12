# frozen_string_literal: true

require_relative "hinted_file"

module Rubcask
  # A temporary directory that is used during the merge operation.
  # You probably should not use this class outside of this context.
  # @see Rubcask::Directory
  class MergeDirectory
    def initialize(dir, max_id_ref:, config: Config.new)
      @dir = dir
      @config = config
      @max_id = max_id_ref

      @data_files = []

      create_new_file!
    end

    def append(entry)
      value_pos = active.write_pos
      active.append(entry)
      value_size = active.write_pos
      @active_hints[entry.key] = HintEntry.new(entry.expire_timestamp, entry.key, value_pos, value_size)

      if active.write_pos >= config.max_file_size
        prepare_old_file!
        create_new_file!
      end
    end

    def close
      if active.write_pos == 0
        File.delete(active.path)
      else
        prepare_old_file!
      end
    end

    private

    attr_reader :config

    def prepare_old_file!
      active.close
      save_active_hint_file!
    end

    def save_active_hint_file!
      File.open(active.hint_path, "ab") do |io|
        hint_file = HintFile.new(io)
        @active_hints.each_value do |entry|
          hint_file.append(entry)
        end
      end
    end

    def active
      @data_files.last
    end

    def create_new_file!
      @active_hints = {}

      id = @max_id.increment
      file = HintedFile.new(
        File.join(@dir, "#{id}.data"),
        os_sync: false,
        read_only: false,
        ruby_sync: config.io_strategy != :ruby
      )
      @data_files << file
    end
  end
end
