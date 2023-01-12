# frozen_string_literal: true

module Rubcask
  module Concurrency
    # Fake of MonitorMixin module that implements
    # a subset of methods
    # It does not do any synchronization
    module FakeMonitorMixin
      def mon_synchronize
        yield
      end
      alias_method :synchronize, :mon_synchronize

      def mon_enter
      end

      def mon_exit
      end
    end
  end
end
