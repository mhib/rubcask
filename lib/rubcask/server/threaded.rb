# frozen_string_literal: true

require "logger"
require "socket"
require "io/wait"
require "stringio"

require_relative "../bytes"
require_relative "../protocol"
require_relative "config"
require_relative "abstract_server"

module Rubcask
  module Server
    # Thread-based server supporting Rubcask protocol
    # If you are running on CRuby you should consider using Server::Async as it is generally more performant
    class Threaded < AbstractServer
      include Protocol

      def initialize(dir, config: Server::Config.new)
        @dir = dir
        @config = config
        @hostname = config.hostname
        @port = config.port
        @logger = Logger.new($stdout)
        @logger.level = Logger::INFO
        @threads = ThreadGroup.new
        @connected = false
        @status = :stopped
        @listeners = []
      end

      # Creates sockets
      # @return [self]
      def connect
        return if @connected
        @connected = true
        @listeners = Socket.tcp_server_sockets(@hostname, @port)
        if @config.keepalive
          @listeners.each do |s|
            s.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
          end
        end
        @listeners.each do |s|
          address = s.connect_address
          logger.info "Listening on #{address.ip_address}:#{address.ip_port}"
        end
        self
      end

      # Starts the server
      # @note It blocks the current thread
      def start
        connect

        setup_shutdown_pipe

        @status = :running

        Thread.handle_interrupt(Exception => :never) do
          Thread.handle_interrupt(Exception => :immediate) do
            accept_loop
          end
        ensure
          cleanup_shutdown_pipe
          @status = :shutdown
          cleanup_listeners
          @threads.list.each(&:kill)
          @status = :stopped
          @connected = false
          logger.info "Closed server"
        end
      end

      # Shuts down the server
      # @note You probably want to use it in a signal trap
      def shutdown
        if @status == :running
          @status = :shutdown
        end
        @shutdown_pipe[1].write_nonblock("\0")
        @shutdown_pipe[1].close
      end

      # Prepares an IO pipe that is used in shutdown process
      # Call if you need to shutdown the server from a different thread
      # @return [self]
      def setup_shutdown_pipe
        @shutdown_pipe ||= IO.pipe
        self
      end

      private

      attr_reader :logger

      def cleanup_listeners
        @listeners.each do |listener|
          listener.shutdown
        rescue Errno::ENOTCONN
          listener.close
        else
          listener.close
        end
        @listeners.clear
      end

      def cleanup_shutdown_pipe
        pipe = @shutdown_pipe
        pipe&.each(&:close)
        @shutdown_pipe = nil
      end

      def accept_loop
        shutdown_read = @shutdown_pipe[0]
        while @status == :running
          begin
            fds = IO.select([shutdown_read, *@listeners])[0]
            if fds.include?(shutdown_read)
              consume_pipe(shutdown_read)
              break
            end
            fds.each do |listener|
              client = accept_client(listener)
              next unless client
              @threads.add(
                Thread.start(client) { |conn| client_block(conn) }
              )
            end
          rescue Errno::EBADF, Errno::ENOTSOCK, IOError
            # Possible if socket was manually shut down
          end
        end
      end

      def accept_client(listener)
        sock = listener.accept_nonblock(exception: false)
        return nil if sock == :wait_readable
        sock[0]
      rescue
        nil
      end

      def consume_pipe(pipe)
        buf = +""
        while String === pipe.read_nonblock([pipe.nread, 8].max, buf, exception: false)
        end
      end

      def client_block(conn)
        conn.binmode
        with_interrupt_handle(conn) do |io|
          client_loop(io)
        end
      end

      def with_interrupt_handle(conn)
        Thread.handle_interrupt(Exception => :never) do
          Thread.handle_interrupt(Exception => :immediate) do
            yield conn
          end
        ensure
          begin
            conn.close
          rescue # It sometimes failes on jruby
          end
        end
      end
    end
  end
end
