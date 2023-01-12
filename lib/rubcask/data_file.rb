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

    HEADER_FORMAT = "NQ>nN"
    HEADER_WITHOUT_CRC_FORMAT = "Q>nN"

    # @param [File] file File with the data
    # @param [Integer] file_size Current size of `file` in bytes
    def initialize(file, file_size)
      @file = file
      @write_pos = file_size
    end

    # Fetch entry at given offset.
    # Optional size parameter is size of the record. With it we make one less I/O
    # @param [Integer] offset File offset in bytes
    # @param [Integer, nil] size Record size in bytes
    def [](offset, size = nil)
      seek(offset)
      read(size)
    end

    # yields each record in the file
    # @return [Enumerator] if no block given
    # @yieldparam [DataEntry]
    def each
      return to_enum(__method__) unless block_given?

      seek(0)

      loop do
        val = read
        break unless val
        yield val
      end
    end

    # Read entry at the current file position
    # @return [DataEntry]
    # @return [nil] if at the end of file
    # @raise [ChecksumError] if the entry has an incorrect checksum
    def read(size = nil)
      io = size ? StringIO.new(@file.read(size)) : @file
      header = io.read(18)

      return nil unless header

      crc, expire_timestamp, key_size, value_size = header.unpack(HEADER_FORMAT)
      key = io.read(key_size)
      value = io.read(value_size)

      raise ChecksumError, "Checksums do not match" if crc != Zlib.crc32(header[4..] + key + value)
      DataEntry.new(expire_timestamp, key, value)
    end

    AppendResult = Struct.new(:value_pos, :value_size)
    # Append a record at the end of the file
    # @param [DataEntry] entry Entry to write to the file
    # @return [AppendResult] struct containing position and size of the record
    def append(entry)
      current_pos = @write_pos

      key_size = entry.key.bytesize
      value_size = entry.value.bytesize

      crc = Zlib.crc32([
        entry.expire_timestamp,
        key_size,
        value_size
      ].pack(HEADER_WITHOUT_CRC_FORMAT) + entry.key + entry.value)
      @write_pos += @file.write(
        [crc, entry.expire_timestamp, key_size, value_size].pack(HEADER_FORMAT),
        entry.key,
        entry.value
      )
      @file.flush
      AppendResult.new(current_pos, @write_pos - current_pos)
    end
  end
end
