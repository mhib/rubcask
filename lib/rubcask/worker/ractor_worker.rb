# frozen_string_literal: true

require "logger"
require "forwardable"

module Rubcask
  module Worker
    # Worker implementation that delegates work to a dedicated ractor
    class RactorWorker
      extend Forwardable

      def_delegator :@ractor, :send, :push

      def initialize
        @ractor = new_ractor
        @logger = Logger.new($stdout)
      end

      def close
        push(nil)
        @ractor.take
      end

      private

      def new_ractor
        Ractor.new(@logger) do |logger|
          while (value = Ractor.receive)
            begin
              value.call
            rescue => e
              logger.warn("Error while executing task " + e)
            end
            Ractor.yield(nil)
          end
        end
      end
    end
  end
end
