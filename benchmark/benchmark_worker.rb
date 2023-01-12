require "benchmark/ips"

require "fileutils"
require "securerandom"
require "tmpdir"

require_relative "../lib/rubcask/worker/factory"
require_relative "../lib/rubcask/task/clean_directory"

class SimulateIOTask
  def call
    10_000.times { IO.read("/dev/null") }
    sleep(0.01)
  end
end

@benchmark_procedure = lambda do |type, times|
  times.times do
    worker = Rubcask::Worker::Factory.new_worker(type)
    10.times { worker.push(SimulateIOTask.new) }
    100_000.times { IO.read("/dev/null") } # Simulate some IO
    worker.close
  end
end

Benchmark.ips do |x|
  x.warmup = 15
  x.time = 30

  x.stats = :bootstrap
  x.confidence = 95

  x.report("thread") do |times|
    @benchmark_procedure[:thread, times]
  end

  x.report("ractor") do |times|
    @benchmark_procedure[:ractor, times]
  end

  x.report("direct") do |times|
    @benchmark_procedure[:direct, times]
  end

  x.compare!
end
