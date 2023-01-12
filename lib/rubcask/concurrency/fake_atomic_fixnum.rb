# frozen_string_literal: true

module Rubcask
  module Concurrency
    # A fake class that implements interface of Concurrent::AtomicFixnum
    # without actually doing any synchronization
    class FakeAtomicFixnum
      attr_accessor :value
      def initialize(initial = 0)
        @value = initial
      end

      def compare_and_set(expected, update)
        @value = update if @value == expected
        @value
      end

      def decrement(delta = 1)
        @value -= delta
        @value
      end

      def increment(delta = 1)
        @value += delta
        @value
      end

      def update
        @value = yield(@value)
        @value
      end
    end
  end
end
