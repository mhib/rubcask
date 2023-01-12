require "benchmark/ips"
require "securerandom"

require_relative "../lib/rubcask"

Benchmark.ips do |x|
  x.time = 30

  x.report("1 milion writes") do
    Dir.mktmpdir do |path|
      dir = Rubcask::Directory.new(path, config: Rubcask::Config.new)

      1_000_000.times do |idx|
        dir[idx.to_s] = SecureRandom.hex(128)
      end
    end
  end

  x.report("1 milion writes gets") do
    Dir.mktmpdir do |path|
      dir = Rubcask::Directory.new(path, config: Rubcask::Config.new)

      1_000_000.times do |idx|
        dir[idx.to_s] = SecureRandom.hex(128)
      end

      1_000_000.times do |idx|
        dir[idx.to_s]
      end
    end
  end
end
