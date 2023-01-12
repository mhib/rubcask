$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "tempfile"

require "rubcask"
require "rubcask/server/runner"

Dir.mktmpdir do |tmpdir|
  runner_config = Rubcask::Server::Runner::Config.configure do |c|
    c.directory_path = tmpdir
  end

  runner = Rubcask::Server::Runner.new(runner_config: runner_config)
  runner.start
end
