# frozen_string_literal: true

require_relative "expirable_entry"

module Rubcask
  DataEntry = Struct.new(:expire_timestamp, :key, :value, :deleted?) do
    include ExpirableEntry
  end
end
