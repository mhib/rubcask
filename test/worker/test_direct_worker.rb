require "test_helper"

class TestDirectWorker < Minitest::Test
  def setup
    @worker = Rubcask::Worker::DirectWorker.new
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
