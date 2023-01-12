require "benchmark/ips"
require "securerandom"

require_relative "../lib/rubcask"

@values = Array.new(10_000) { SecureRandom.hex(128) }

Dir.mktmpdir do |path|
  # This does not reflect raw performance well as there is dir creation overhead but works good enough for comparison
  Benchmark.ips do |x|
    x.warmup = 15
    x.time = 30

    x.stats = :bootstrap
    x.confidence = 95

    x.report("put_get_os") do
      Dir.mktmpdir do |path|
        dir = Rubcask::Directory.new(path, config: Rubcask::Config.configure { |x| x.io_strategy = :os })

        (0...10_000).each do |idx|
          dir[idx.to_s] = @values[idx]
        end
      end
    end

    x.report("put_get_ruby") do
      Dir.mktmpdir do |path|
        dir = Rubcask::Directory.new(path, config: Rubcask::Config.new)

        (0...10_000).each do |idx|
          dir[idx.to_s] = @values[idx]
        end
      end
    end

    x.report("put_get_os_sync") do
      Dir.mktmpdir do |path|
        dir = Rubcask::Directory.new(path, config: Rubcask::Config.configure { |x| x.io_strategy = :os_sync })

        (0...10_000).each do |idx|
          dir[idx.to_s] = @values[idx]
        end
      end
    end

    x.compare!
  end
end