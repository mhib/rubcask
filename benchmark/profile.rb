require "tempfile"
require "securerandom"
require "stackprof"

require_relative "../lib/rubcask"

StackProf.run(out: "tmp/stackprof-cpu-myapp.dump", raw: true) do
  Dir.mktmpdir do |path|
    dir = Rubcask::Directory.new(path, config: Rubcask::Config.new)

    1_000_000.times do |idx|
      dir[idx.to_s] = SecureRandom.hex(128)
    end
  end
end
