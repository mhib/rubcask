require "forwardable"
require_relative "directory"

module Rubcask
  class MarshaledDirectory
    def initialize(directory)
      @directory = directory
    end

    # Set value associated with given key.
    # @param [Object] key
    # @param [Object] value
    # @return [Object] the value provided by the user
    def []=(key, value)
      @directory[Marshal.dump(key)] = Marshal.dump(value)
      value # rubocop:disable Lint/Void
    end

    # Set value associated with given key with given ttl
    # @param [Object] key
    # @param [Object] value
    # @param [Integer] ttl Time to live
    # @return [Object] the value provided by the user
    # @raise [ArgumentError] if ttl is negative
    def set_with_ttl(key, value, ttl)
      @directory.set_with_ttl(
        Marshal.dump(key),
        Marshal.dump(value),
        ttl
      )
      value
    end

    # Gets value associated with the key
    # @param [Object] key
    # @return [Object] value associatiod with the key
    # @return [nil] If no value associated with the key
    def [](key)
      value = @directory[Marshal.dump(key)]
      if value.nil?
        value
      else
        Marshal.load(value)
      end
    end

    # Remove entry associated with the key.
    # @param [Object] key
    # @return false if the existing value does not exist
    # @return true if the delete was succesfull
    def delete(key)
      @directory.delete(Marshal.dump(key))
    end

    extend Forwardable
    def_delegators :@directory, *(Directory.public_instance_methods(false) - MarshaledDirectory.public_instance_methods(false))
  end
end
