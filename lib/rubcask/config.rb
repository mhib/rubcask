# frozen_string_literal: true

require_relative "bytes"
module Rubcask
  # @!attribute max_file_size
  #   Maximum single file size.
  #
  #   New file is created after the current file is larger than this field
  #
  #   Default: Bytes::GIGABYTE * 2
  #   @return [Integer]
  # @!attribute io_strategy
  #   Guarantees; listed fastest first
  #
  #   :ruby is safe as long as you exit gracefully
  #
  #   :os is safe as long as no os or hardware failures occures
  #
  #   :os_sync is always safe
  #
  #   Default :ruby
  #   @return [:ruby, :os, :os_sync]
  # @!attribute threadsafe
  #   Set to true if you want to use Rubcask with many threads concurrently
  #
  #   Default: true
  #   @return [boolean]
  # @!attribute worker
  #   Type of worker used for async jobs
  #
  #   Currently it is only used for deleting files after merge
  #
  #   Default: :direct
  #   @return [:direct, :ractor, :thread]
  # Server runner config
  Config = Struct.new(:max_file_size, :io_strategy, :threadsafe, :worker) do
    # @yieldparam [self] config
    def initialize
      self.max_file_size = Bytes::GIGABYTE * 2
      self.io_strategy = :ruby
      self.threadsafe = true
      self.worker = :direct

      yield(self) if block_given?
    end

    def self.configure(&block)
      new(&block).freeze
    end
  end

  class Config
    DEFAULT_SERVER_CONFIG = configure { |c| c.io_strategy = :os }
  end
end
