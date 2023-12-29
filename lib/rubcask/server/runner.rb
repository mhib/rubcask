# frozen_string_literal: true

require "concurrent/timer_task"

require_relative "config"
require_relative "runner/config"
require_relative "../config"

module Rubcask
  module Server
    # ServerRunner runs a server alongside merge worker
    # It supports graceful shutdown with Ctrl-c
    class Runner
      def initialize(
        server_config: Rubcask::Server::Config.new,
        dir_config: Rubcask::Config::DEFAULT_SERVER_CONFIG,
        runner_config: Rubcask::Server::Runner::Config.new
      )
        @dir = Rubcask::Directory.new(
          runner_config.directory_path,
          config: dir_config
        )
        @server = new_server(runner_config.server_type, server_config)
        @merge_worker = if runner_config.merge_interval && runner_config.merge_interval > 0
          Concurrent::TimerTask.new(
            execution_interval: runner_config.merge_interval
          ) do
            merge_dir
          end
        end
      end

      # Starts the runner.
      # @note It blocks the current thread
      def start
        install_trap!
        @merge_worker.execute
        @server.start
      end

      # Stops the server
      def close
        close_server
        mutex_close
      end

      private

      def close_server
        puts "Shutting down server!"
        begin
          @server.shutdown
        rescue
        end
      end

      def mutex_close
        if @merge_worker
          puts "Stoping merge worker"
          @merge_worker.shutdown
          if @merge_worker.wait_for_termination(60)
            puts "Closed merge worker"
          else
            puts "Failed to close worker"
          end
        end

        puts "Closing Dir!"
        begin
          @dir.close
        rescue
        end
        puts "Closed dir"
      end

      def install_trap!
        Signal.trap("INT") do
          puts ""
          # Close server in the same thread
          close_server

          # Other things might needs mutex so a new thread is needed
          Thread.new do
            mutex_close
          end.join
        end
      end

      def new_server(type, config)
        if type == :threaded
          require_relative "threaded"
          Rubcask::Server::Threaded.new(@dir, config: config)
        elsif type == :async
          require_relative "async"
          Rubcask::Server::Async.new(@dir, config: config)
        else
          raise ArgumentError, "Unknown server typ #{type}"
        end
      end

      def merge_dir
        @server.dir.merge
      rescue => e
        puts e
      end
    end
  end
end
