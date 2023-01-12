# frozen_string_literal: true

module Rubcask
  module Server
    # @!macro [new] see_client
    #   @see Client#$0

    # Pipeline represents a sequence of commands.
    # @note Pipeline execution IS NOT atomic.
    # @see Client
    class Pipeline
      include Protocol

      attr_reader :out, :count

      def initialize
        @out = (+"").b
        @count = 0
      end

      # @macro see_client
      def get(key)
        @out << create_call_message("get", key)
      end

      # @macro see_client
      def set(key, value)
        @out << create_call_message("set", key, value)
      end

      # @macro see_client
      def del(key)
        @out << create_call_message("del", key)
      end

      # @macro see_client
      def ping
        @out << create_call_message("ping")
      end

      private

      def create_call_message(method, *args)
        @count += 1
        super
      end
    end
  end
end
