require_relative "server_benchmark_helper"
include ServerBenchmarkHelper

run_benchmark_with_threaded_server("Threaded") do |client|
  client.get("key")
end

run_benchmark_with_async_server("Async") do |client|
  client.get("key")
end
