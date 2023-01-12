# frozen_string_literal: true

module Rubcask
  # HintFile stores only keys, and information on where the value of the key is located
  class HintFile
    extend Forwardable
    def_delegators :@file, :seek, :close, :flush

    HEADER_FORMAT = "Q>nNQ>"

    # @param [File] file An already opened file
    def initialize(file)
      @file = file
    end

    # Yields each hint entry from the file
    # @yieldparam [HintEntry] hint_entry
    # @return [Enumerator] if no block given
    def each
      return to_enum(__method__) unless block_given?

      seek(0)

      loop do
        val = read
        break unless val
        yield val
      end
    end

    # Reads hint entry at the current offset
    # @return [HintEntry]
    # @return [nil] If at the end of file
    # @raise LoadError if unable to read from the file
    def read
      header = @file.read(22)

      return nil unless header

      expire_timestamp, key_size, value_size, value_pos = header.unpack(HEADER_FORMAT)
      key = @file.read(key_size)

      HintEntry.new(expire_timestamp, key, value_pos, value_size)
    end

    # Appends an entry to the file
    # @param [HintEntry] entry
    # @return [Integer] Number of bytes written
    def append(entry)
      @file.write(
        [entry.expire_timestamp, entry.key.bytesize, entry.value_size, entry.value_pos].pack(HEADER_FORMAT),
        entry.key
      )
    end
  end
end
