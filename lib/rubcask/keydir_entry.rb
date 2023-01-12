# frozen_string_literal: true

require_relative "expirable_entry"

module Rubcask
  KeydirEntry = Struct.new(:file_id, :value_size, :value_pos, :expire_timestamp) do
    include ExpirableEntry
  end
end
