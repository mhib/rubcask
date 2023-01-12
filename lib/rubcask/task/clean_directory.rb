# frozen_string_literal: true

module Rubcask
  module Task
    # Removes all files marked as executable in the directory
    class CleanDirectory
      def initialize(directory)
        @directory = directory
      end

      def call
        Dir.glob(["*.data", "*.hint"].map! { |ext| File.join(@directory, ext) }).each do |file|
          next unless File.executable?(file)
          File.delete(file)
        end
      end
    end
  end
end
