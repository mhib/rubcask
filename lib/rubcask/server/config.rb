# frozen_string_literal: true

module Rubcask
  module Server
    # @!attribute hostname
    #   @return [String] Hostname of the server
    # @!attribute port
    #   @return [Integer] Port of the server
    # @!attribute timeout
    #   Timeut of the server
    #
    #   If the client does not send any messages for provided number of seconds the connection with it s closed
    #   @return [Integer]
    # @!attribute keepalive
    #    @return [boolean] Flag whether to set TCP's keepalive
    Config = Struct.new(:hostname, :port, :timeout, :keepalive) do
      def initialize
        self.hostname = "localhost"
        self.timeout = nil
        self.keepalive = true
        self.port = 8080

        yield(self) if block_given?
      end

      def self.configure(&block)
        new(&block).freeze
      end
    end
  end
end
