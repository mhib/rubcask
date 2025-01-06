# frozen_string_literal: true

require "async/io"
require "async/queue"
require "async/io/stream"

require_relative "abstract_server"

module Rubcask
  module Server
    # Async-based server supporting Rubcask protocol
    # It requires "async-io" gem.
    class Async < AbstractServer
      def initialize(dir, config: Server::Config.new)
        @dir = dir
        @config = config
        @hostname = config.hostname
        @port = config.port
        @logger = Logger.new($stdout)
        @endpoint = ::Async::IO::Endpoint.tcp(@hostname, @port)
        @running = false
      end

      # Shuts down the server
      # @note You might want to use it inside signal trap
      def shutdown
        return unless @task
        Sync do
          @running = false
          @shutdown_condition.signal
          @task.wait
        end
      end

      # Starts the server
      # @param [::Async::Condition, nil] on_start_condition The condition will be signalled after a successful bind
      def start(on_start_condition = nil)
        Sync do
          @shutdown_condition = ::Async::Condition.new

          _, @task = @endpoint.bind do |server, task|
            if @config.keepalive
              server.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
            end

            define_close_routine(server, task)

            Console.logger.info(server) { "Accepting connections on #{server.local_address.inspect}" }

            server.listen(Socket::SOMAXCONN)
            on_start_condition&.signal
            @running = true

            server.accept_each do |conn|
              conn.binmode
              client_loop(::Async::IO::Stream.new(conn))
            ensure
              ::Async::Task.current.stop
            end
          end
        end
      end

      private

      def running?
        @running
      end

      def client_loop(conn)
        q = ::Async::Queue.new
        Async do
          @shutdown_condition.wait
          q << nil
        end
        while running?
          Async { q << read_command_args(conn) }
          command_args = q.dequeue
          return unless command_args

          conn.write(execute_command!(*command_args))
        end
      rescue => x
        Console::Event::Failure.for(error).emit(server, "Error while handling connection")
      end

      def define_close_routine(server, task)
        task.async do |subtask|
          @shutdown_condition.wait

          Console.logger.info(server) { "Shutting down connections on #{server.local_address.inspect}" }

          server.close

          subtask.with_timeout(30) do
            task.children.each { |t| t.wait unless t == subtask }
          rescue ::Async::TimeoutError
            Console.logger.warn("Could not terminate child connections...")
          end

          task.stop
        end
      end

      def read_command_body(conn, length)
        conn.read(length)
      end
    end
  end
end
