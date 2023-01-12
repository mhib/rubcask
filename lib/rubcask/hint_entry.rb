# frozen_string_literal: true

require_relative "expirable_entry"

module Rubcask
  HintEntry = Struct.new(:expire_timestamp, :key, :value_pos, :value_size) do
    include ExpirableEntry
  end
end
