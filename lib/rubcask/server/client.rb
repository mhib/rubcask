# frozen_string_literal: true

require "socket"

require_relative "../protocol"
require_relative "pipeline"

module Rubcask
  module Server
    class Client
      # @!macro [new] raises_invalid_response
      #   @raise [InvalidResponseError] If the response is invalid

      class InvalidResponseError < Error; end

      include Protocol

      # yields a new client to the block
      # closes the client after the block is terminated
      # @param host [String] hostname of the server
      # @param port [String] port of the server
      # @yieldparam [Client] the running client
      def self.with_client(host, port)
        client = new(host, port)
        begin
          yield client
        ensure
          client.close
        end
      end

      # @param host [String] hostname of the server
      # @param port [String] port of the server
      def initialize(host, port)
        @socket = TCPSocket.new(host, port)
      end

      # Get value associated with the key
      # @param [String] key
      # @return [String] Binary string representing the value
      # @return [Protocol::NIL] If no data associated with the key
      # @macro raises_invalid_response
      def get(key)
        call_method("get", key)
      end

      # Set value associated with the key
      # @param [String] key
      # @param [String] value
      # @return [Protocol::OK] If set succeeded
      # @return [Protocol::ERROR] If failed to set the value
      # @macro raises_invalid_response
      def set(key, value)
        call_method("set", key, value)
      end

      # Remove value associated with the key
      # @param [String] key
      # @return [Protocol::OK] If delete succeeded
      # @return [Protocol::NIL] Otherwise
      # @macro raises_invalid_response
      def del(key)
        call_method("del", key)
      end

      # Ping the server
      # Use this method to check if server is running and responding
      # @return [Protocol::PONG]
      # @macro raises_invalid_response
      def ping
        call_method("ping")
      end

      # Ping the server
      # Use this method to check if server is running and responding
      # @param [String] key
      # @param [String] value
      # @param [Integer, String] ttl
      # @return [String] Binary string representing the value
      # @return [Protocol::NIL] If no data associated with the key
      # @macro raises_invalid_response
      def setex(key, value, ttl)
        call_method("setex", key, value, ttl.to_s)
      end

      # Run the block in the pipeline
      # @note pipeline execution IS NOT atomic
      # @note instance_eval is used so you can call methods directly instead of using block argument
      # @yield_param [Pipeline] pipeline
      # @return [Array<String>] List of responses to the executed methods
      # @macro raises_invalid_response
      def pipelined(&block)
        pipeline = Pipeline.new
        pipeline.instance_eval(&block)
        call(pipeline.out)
        pipeline.count.times.map { get_response }
      end

      # Close the client
      def close
        @socket.close
      end

      private

      def call_method(method, *)
        call(create_call_message(method, *))
        get_response
      end

      def call(message)
        @socket.write(message)
      end

      def get_response
        length = @socket.gets(Protocol::SEPARATOR)

        if length.nil?
          raise InvalidResponseError, "no response"
        end
        length = length.to_i

        response = @socket.read(length)
        if response.bytesize < length
          raise InvalidResponseError, "response too short"
        end
        response
      end
    end
  end
end
