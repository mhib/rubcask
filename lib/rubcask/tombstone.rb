# frozen_string_literal: true

module Rubcask
  # Tombstone represents deleted value

  # The prev_file_id is
  # stored to support merge of subset of directory files, that is currently not implemented
  module Tombstone
    extend self

    PREFIX = "TOMBSTONE".b
    PREFIX_SIZE = PREFIX.bytesize
    FILE_ID_FORMAT = "N"
    FULL_BYTE_SIZE = PREFIX_SIZE + 4

    # @param [String] value value to check
    # @return true if value is a tombstone
    # @return false otherwise
    def is_tombstone?(value)
      value.bytesize <= FULL_BYTE_SIZE && value.start_with?(PREFIX)
    end

    # Creates a new tombstone value
    # @param [Integer] current_file_id Id of the active file
    # @param [Integer] prev_file_id Id of the file where the record is currently located
    # @return [String]
    def new_tombstone(current_file_id, prev_file_id)
      return PREFIX if prev_file_id == current_file_id
      PREFIX.b << [prev_file_id].pack(FILE_ID_FORMAT)
    end

    # Gets file id from tombstone value
    # @param [String] value Tombstone value
    # @return [Integer, nil]
    def tombstone_file_id(value)
      return nil if value.bytesize < FULL_BYTE_SIZE
      value.byteslice(PREFIX_SIZE, 4).unpack1(FILE_ID_FORMAT)
    end
  end
end
