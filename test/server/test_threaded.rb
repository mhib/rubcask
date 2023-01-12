# frozen_string_literal: true

require "socket"

require "test_helper"
require "rubcask/server/threaded"
require "rubcask/server/client"

class TestThreadedServer < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @port = get_random_port
  end

  def test_read_write
    server_config = Rubcask::Server::Config.new { |s| s.port = get_random_port }
    server = Rubcask::Server::Threaded.new(
      Rubcask::Directory.new(@dir, config: Rubcask::Config::DEFAULT_SERVER_CONFIG),
      config: server_config
    ).setup_shutdown_pipe.connect

    server_thread = Thread.new(server, &:start)

    client = Rubcask::Server::Client.new(server_config.hostname, server_config.port)
    begin
      client.set("lorem", "ipsum")
      assert_equal("ipsum".b, client.get("lorem"))
      assert_equal(Rubcask::Protocol::OK, client.del("lorem"))
      assert_equal(Rubcask::Protocol::NIL, client.del("lorem"))
      assert_equal(Rubcask::Protocol::PONG, client.ping)
    ensure
      server.shutdown
      server_thread.join
      client.close
    end
  end

  def test_pipeline
    server_config = Rubcask::Server::Config.new { |s| s.port = get_random_port }
    server = Rubcask::Server::Threaded.new(
      Rubcask::Directory.new(@dir, config: Rubcask::Config::DEFAULT_SERVER_CONFIG),
      config: server_config
    ).setup_shutdown_pipe.connect

    server_thread = Thread.new(server, &:start)
    Rubcask::Server::Client.with_client(server_config.hostname, server_config.port) do |client|
      assert_equal(
        [Rubcask::Protocol::OK, "ipsum".b, Rubcask::Protocol::OK, Rubcask::Protocol::NIL, Rubcask::Protocol::PONG],
        client.pipelined do
          set("lorem", "ipsum")
          get("lorem")
          del("lorem")
          del("lorem")
          ping
        end
      )
    ensure
      server.shutdown
      server_thread.join
    end
  end

  def test_set_with_expire
    server_config = Rubcask::Server::Config.new { |s| s.port = get_random_port }
    server = Rubcask::Server::Threaded.new(
      Rubcask::Directory.new(@dir, config: Rubcask::Config::DEFAULT_SERVER_CONFIG),
      config: server_config
    ).setup_shutdown_pipe.connect

    server_thread = Thread.new(server, &:start)
    client = Rubcask::Server::Client.new(server_config.hostname, server_config.port)

    begin
      now = Time.now
      client.setex("key", "value", 300)
      assert_equal("value", client.get("key"))
      Timecop.freeze(now + 150)
      assert_equal("value", client.get("key"))
      Timecop.freeze(now + 301)
      assert_equal(Rubcask::Protocol::NIL, client.get("key"))
    ensure
      Timecop.return
      server.shutdown
      server_thread.join
      client.close
    end
  end

  def get_random_port
    server = TCPServer.new("127.0.0.1", 0)
    begin
      server.addr[1]
    ensure
      server.close
    end
  end

  def teardown
    FileUtils.remove_entry @dir
  end
end
