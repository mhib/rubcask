# frozen_string_literal: true

require "forwardable"

module Rubcask
  module Worker
    # Worker implementation that delegates work to a dedicated thread
    class ThreadWorker
      extend Forwardable

      def_delegator :@queue, :push

      def initialize
        @queue = Queue.new
        @logger = Logger.new($stdout)
        @thread = new_thread
      end

      def close
        @queue.close
        @thread.join
        nil
      end

      private

      def new_thread
        Thread.new(@queue) do |queue|
          while (el = queue.pop)
            begin
              el.call
            rescue => e
              @logger.warn(e)
            end
          end
        end
      end
    end
  end
end
