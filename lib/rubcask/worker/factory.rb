# frozen_string_literal: true

require_relative "direct_worker"
require_relative "ractor_worker"
require_relative "thread_worker"

module Rubcask
  module Worker
    module Factory
      extend self

      # Returns a new worker of provided type
      # @param [:direct, :thread, :reactor] type Type of worker to create
      # @return [Worker]
      # @raise [ArgumentError] if unknown type
      def new_worker(type)
        case type
        when :direct
          DirectWorker.new
        when :thread
          ThreadWorker.new
        when :ractor
          RactorWorker.new
        else
          raise ArgumentError, "#{type} is not a known worker type"
        end
      end

      # Class for documentation purposes
      class Worker
        # @param [#call] arg job to execute
        # @return [void]
        def push(arg)
        end

        # @return [void]
        def close
        end
      end
    end
  end
end
