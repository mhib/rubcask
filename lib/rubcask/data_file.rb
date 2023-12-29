# frozen_string_literal: true

require "forwardable"
require "stringio"
require "zlib"

module Rubcask
  # DataFile is a file where the key and values are actually stored
  class DataFile
    extend Forwardable
    def_delegators :@file, :seek, :pos, :close, :sync=, :flush

    attr_reader :write_pos

    HEADER_SIZE = 4 + 8 + 2 + 4

    HEADER_WITHOUT_CRC_FORMAT = "Q>nN"
    HEADER_FORMAT = "N#{HEADER_WITHOUT_CRC_FORMAT}"

    EXPIRE_MASK = ~(1 << 63)
    DELETED_MASK = (1 << 63)
    MAX_EXPIRE_VALUE = DELETED_MASK - 1

    # @param [File] file File with the data
    # @param [Integer] file_size Current size of `file` in bytes
    def initialize(file, file_size)
      @file = file
      @write_pos = file_size
    end

    # @!macro [new] might_change_pos
    #   @note Calling this method might change `pos` of the `file`

    # @!macro [new] no_change_pos
    #   @note Calling this method will not change `pos` of the `file`

    # @!macro [new] read_result_return
    #   @return [DataEntry]
    #   @return [nil] if at the end of file
    #   @raise [ChecksumError] if the entry has an incorrect checksum

    # Fetch entry at given offset.
    # With optional size parameter we can do less I/O operations.
    # @macro might_change_pos
    # @param [Integer] offset File offset in bytes
    # @param [Integer, nil] size Entry size in bytes
    # @macro read_result_return
    def [](offset, size = nil)
      if size.nil?
        seek(offset)
        return read
      end
      pread(offset, size)
    end

    # yields each entry in the file
    # @macro might_change_pos
    # @return [Enumerator] if no block given
    # @yieldparam [DataEntry] data_entry Entry from the file
    def each
      return to_enum(__method__) unless block_given?

      seek(0)

      loop do
        val = read
        break unless val
        yield val
      end
    end

    # Read an entry at the current file position
    # @macro might_change_pos
    # @param [Integer, nil] size Entry size in bytes
    # @macro read_result_return
    def read(size = nil)
      read_from_io(
        size ? StringIO.new(@file.read(size)) : @file
      )
    end

    # Fetch an entry at given offset and with provided size
    # @macro no_change_pos
    # @param [Integer] offset File offset in bytes
    # @param [Integer] size Entry size in bytes
    # @macro read_result_return
    def pread(offset, size)
      read_from_io(StringIO.new(@file.pread(size, offset)))
    end

    AppendResult = Struct.new(:value_pos, :value_size)
    # Append an entry at the end of the file
    # @macro no_change_pos
    # @param [DataEntry] entry Entry to write to the file
    # @return [AppendResult] struct containing position and size of the entry
    def append(entry)
      current_pos = @write_pos

      key_size = entry.key.bytesize
      value_size = entry.value.bytesize
      timestamp_with_deleted = entry.expire_timestamp
      timestamp_with_deleted |= DELETED_MASK if entry.deleted?
      crc = Zlib.crc32([
        timestamp_with_deleted,
        key_size,
        value_size
      ].pack(HEADER_WITHOUT_CRC_FORMAT) + entry.key + entry.value)
      @write_pos += @file.write(
        [crc, timestamp_with_deleted, key_size, value_size].pack(HEADER_FORMAT),
        entry.key,
        entry.value
      )
      @file.flush
      AppendResult.new(current_pos, @write_pos - current_pos)
    end

    private

    def read_from_io(io)
      header = io.read(HEADER_SIZE)

      return nil unless header

      crc, expire_timestamp_with_deleted, key_size, value_size = header.unpack(HEADER_FORMAT)
      key = io.read(key_size)
      value = io.read(value_size)
      expire_timestamp = (expire_timestamp_with_deleted & EXPIRE_MASK)
      deleted = (expire_timestamp_with_deleted & DELETED_MASK) != 0

      raise ChecksumError, "Checksums do not match" if crc != Zlib.crc32(header[4..] + key + value)
      DataEntry.new(expire_timestamp, key, value, deleted)
    end
  end
end
