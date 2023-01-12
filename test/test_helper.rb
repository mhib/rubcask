# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch

  add_filter %r{^/test/}

  has_async = false
  begin
    require "rubcask/server/async"
    has_async = true
  rescue LoadError
  end

  unless has_async
    add_filter { |file| file.filename.end_with?("rubcask/server/async.rb") }
  end
end
require "rubcask"
require "fileutils"
require "timecop"

require "minitest/autorun"
