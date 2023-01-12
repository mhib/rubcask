# frozen_string_literal: true

require_relative "rubcask/version"
require_relative "rubcask/directory"
require_relative "rubcask/bytes"

module Rubcask
  class Error < StandardError; end

  class LoadError < Error; end

  class ChecksumError < LoadError; end

  class MergeAlreadyInProgressError < Error; end

  class ConfigValidationError < Error; end

  NO_EXPIRE_TIMESTAMP = 0
end
