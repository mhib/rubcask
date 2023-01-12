require "test_helper"

class TestThreadWorker < Minitest::Test
  def setup
    @worker = Rubcask::Worker::ThreadWorker.new
  end

  def teardown
    @worker.close
  end

  def test_it_executes
    q = Thread::Queue.new
    @worker.push(lambda { q << 1 })
    assert_equal(1, q.pop)
  end
end
