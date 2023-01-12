# frozen_string_literal: true

module Rubcask
  module ExpirableEntry
    def expired?
      expire_timestamp != Rubcask::NO_EXPIRE_TIMESTAMP && expire_timestamp < Time.now.to_i
    end
  end
end
