require "concurrent"
require "descriptive_statistics/safe"

require "tempfile"

require_relative "../lib/rubcask"
require_relative "../lib/rubcask/server/client"

require_relative "../lib/rubcask/server/threaded"
require_relative "../lib/rubcask/server/async"

module ServerBenchmarkHelper
  NUMBER_OF_THREADS = 128
  VALUE = ("8  bytes" * Rubcask::Bytes::KILOBYTE).freeze

  def run_benchmark(seconds, threads, hostname, port)
    res = Concurrent::Array.new

    threads.times.map do
      Thread.new do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        client = Rubcask::Server::Client.new(hostname, port)
        array = []
        while (task_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)) - start < seconds
          task_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          yield(client)
          array << Process.clock_gettime(Process::CLOCK_MONOTONIC) - task_start
        end
        res.concat(array)
        client.close
      end
    end.map(&:join)

    res.extend(DescriptiveStatistics)
    {
      "count" => res.size,
      "median" => res.median,
      "mean" => res.mean,
      "standard deviation" => res.standard_deviation,
      "95 percentile" => res.percentile(95),
      "99 percentile" => res.percentile(99),
      "99.99 percentile" => res.percentile(99.99),
      "max" => res.max
    }
  end

  def run_benchmark_with_async_server(label, &block)
    Dir.mktmpdir do |path|
      dir = Rubcask::Directory.new(path, config: Rubcask::Config::DEFAULT_SERVER_CONFIG)
      dir["key"] = VALUE

      config = Rubcask::Server::Config.new { |c| c.port = get_free_port }
      server = Rubcask::Server::Async.new(dir, config: config)
      from_thread_q = Thread::Queue.new
      to_thread_q = Thread::Queue.new
      server_thread = Thread.new(server) do |s|
        Sync do
          condition = Async::Condition.new
          Async do
            condition.wait
            from_thread_q << nil
          end

          s.start(condition)

          to_thread_q.pop
          server.shutdown
        end
      end
      from_thread_q.pop
      begin
        run_benchmark(10, 10, config.hostname, config.port, &block) # warmup

        rd, wr = IO.pipe

        Process.fork do
          val = run_benchmark(10, NUMBER_OF_THREADS, config.hostname, config.port, &block)
          rd.close
          wr.write(val.to_s)
          wr.close
        end

        wr.close
        puts "#{label}: #{rd.read}"
        rd.close
      ensure
        to_thread_q << nil
        server_thread.join
        dir.close
      end
    end
  end

  def run_benchmark_with_threaded_server(label, &block)
    Dir.mktmpdir do |path|
      dir = Rubcask::Directory.new(path, config: Rubcask::Config::DEFAULT_SERVER_CONFIG)
      dir["key"] = VALUE

      config = Rubcask::Server::Config.new { |c| c.port = get_free_port }
      server = Rubcask::Server::Threaded.new(dir, config: config)
      server.setup_shutdown_pipe
      begin
        server.connect
      rescue Errno::EADDRINUSE
        retry
      end
      server_thread = Thread.new(server, &:start)
      begin
        run_benchmark(10, 10, config.hostname, config.port, &block) # warmup
        rd, wr = IO.pipe

        Process.fork do
          rd.close
          val = run_benchmark(10, NUMBER_OF_THREADS, config.hostname, config.port, &block)
          wr.write(val.to_s)
          wr.close
        end

        wr.close
        puts "#{label}: #{rd.read}"
        rd.close
      ensure
        server.shutdown
        server_thread.join
        dir.close
      end
    end
  end

  def get_free_port
    server = TCPServer.new("127.0.0.1", 0)
    begin
      server.addr[1]
    ensure
      server.close
    end
  end
end
