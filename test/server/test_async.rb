# frozen_string_literal: true

require "socket"

require "test_helper"
require "rubcask/server/client"

has_async = false
begin
  require "rubcask/server/async"
  has_async = true
rescue LoadError
end

if has_async
  class TestAsyncServer < Minitest::Test
    def setup
      @dir = Dir.mktmpdir
    end

    def test_read_write
      server_config = Rubcask::Server::Config.new
      server = Rubcask::Server::Async.new(
        Rubcask::Directory.new(@dir, config: Rubcask::Config::DEFAULT_SERVER_CONFIG),
        config: server_config
      )

      from_thread_q = Thread::Queue.new
      to_thread_q = Thread::Queue.new

      server_thread = Thread.new(server) do |server|
        Sync do
          start_condition = Async::Condition.new
          Async do
            start_condition.wait
            from_thread_q << nil
          end

          server.start(start_condition)
          to_thread_q.pop
          server.shutdown
        end
      end
      from_thread_q.pop
      client = Rubcask::Server::Client.new(server_config.hostname, server_config.port)
      begin
        client.set("lorem", "ipsum")
        assert_equal("ipsum".b, client.get("lorem"))
        assert_equal(Rubcask::Protocol::OK, client.del("lorem"))
        assert_equal(Rubcask::Protocol::NIL, client.del("lorem"))
        assert_equal(Rubcask::Protocol::PONG, client.ping)
      ensure
        to_thread_q << nil
        client.close
        server_thread.join
      end
    end

    def test_pipelined
      server_config = Rubcask::Server::Config.new
      server = Rubcask::Server::Async.new(
        Rubcask::Directory.new(@dir, config: Rubcask::Config::DEFAULT_SERVER_CONFIG),
        config: server_config
      )

      from_thread_q = Thread::Queue.new
      to_thread_q = Thread::Queue.new

      server_thread = Thread.new(server) do |server|
        Sync do
          start_condition = Async::Condition.new
          Async do
            start_condition.wait
            from_thread_q << nil
          end

          server.start(start_condition)
          to_thread_q.pop
          server.shutdown
        end
      end
      from_thread_q.pop
      client = Rubcask::Server::Client.new(server_config.hostname, server_config.port)

      begin
        assert_equal(
          [Rubcask::Protocol::OK, "ipsum".b, Rubcask::Protocol::OK, Rubcask::Protocol::NIL],
          client.pipelined do
            set("lorem", "ipsum")
            get("lorem")
            del("lorem")
            del("lorem")
          end
        )
      ensure
        to_thread_q << nil
        client.close
        server_thread.join
      end
    end

    def teardown
      FileUtils.remove_entry @dir
    end
  end
end
