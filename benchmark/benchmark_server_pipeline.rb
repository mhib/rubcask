require_relative "./server_benchmark_helper"

include ServerBenchmarkHelper

pipeline_block = proc do |client|
  client.pipelined do |pipe|
    pipe.get("key")
    pipe.get("unknown_key")
    pipe.ping
    pipe.get("key")
  end
end

without_pipeline_block = proc do |client|
  client.get("key")
  client.get("unknown_key")
  client.ping
  client.get("key")
end

run_benchmark_with_async_server("Asyc pipelined", &pipeline_block)
run_benchmark_with_async_server("Async without pipeline", &without_pipeline_block)
run_benchmark_with_threaded_server("Threaded pipelined", &pipeline_block)
run_benchmark_with_threaded_server("Threaded without pipeline", &without_pipeline_block)
