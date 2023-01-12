require "test_helper"

# Disabled because:
# 1. Not supported by jruby
# 2. It messes up code coverage report for CRuby for some reason

# class TestRactorWorker < Minitest::Test
#   def setup
#     @worker = Rubcask::Worker::RactorWorker.new
#   end

#   def teardown
#     @worker.close
#   end

#   def test_it_executes
#     @worker.push(Task.new(Ractor.current))
#     assert_equal(1, Ractor.receive)
#   end

#   class Task
#     def initialize(ractor)
#       @ractor = ractor
#     end

#     def call
#       @ractor.send(1)
#     end
#   end
#   private_constant :Task
# end
