# frozen_string_literal: true

module Rubcask
  module Concurrency
    # Fake of Concurrent::ReentrantReadWriteLock
    # It does not do any synchronization
    class FakeLock
      def acquire_read_lock
        true
      end

      def acquire_write_lock
        true
      end

      def release_read_lock
        false
      end

      def release_write_lock
        false
      end

      def has_waiters?
        false
      end

      def with_write_lock
        yield
      end

      def with_read_lock
        yield
      end

      def write_locked?
        false
      end
    end
  end
end
