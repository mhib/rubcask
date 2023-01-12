# frozen_string_literal: true

module Rubcask
  module Server
    class Runner
      # @!attribute merge_interval
      #   How frequent in seconds should merge operation by run.
      #
      #   Default: 3600
      #   @return [Integer, null]
      # @!attribute server_type
      #   Which type of server should be run.
      #
      #   Use threaded if you are not on MRI. If you are on mri and can install `async-io` use :async.
      #
      #   Default: :threaded
      #   @return [:threaded, :async]
      # @!attribute directory_path
      #   Path of the directory in which the data is stored.
      #
      #   Default: no default value, user has to set it manually.
      #   @return [String]
      # Server runner config
      Config = Struct.new(:merge_interval, :server_type, :directory_path) do
        # Overide fields with the block
        # @yieldparam [self] config
        def initialize
          self.server_type = :threaded
          self.merge_interval = 3_600
          self.directory_path = nil

          yield(self) if block_given?
        end

        # Calls new and freezes the config
        # @see .initialize
        def self.configure(&block)
          new(&block).freeze
        end
      end
    end
  end
end
