# frozen_string_literal: true

require "singleton"

module Rubcask
  module Worker
    # Worker implementation that executes the job in the current thread
    class DirectWorker
      def initialize
        @logger = Logger.new($stdout)
      end

      def push(task)
        task.call
      rescue => e
        @logger.warn("Error while executing task #{e}")
      end

      def close
      end
    end
  end
end
