# frozen_string_literal: true

require "stringio"

require_relative "../bytes"
require_relative "../protocol"
require_relative "config"

module Rubcask
  module Server
    class AbstractServer
      BLOCK_SIZE = Rubcask::Bytes::KILOBYTE * 64
      MAX_READ_SIZE = BLOCK_SIZE * 128

      include Protocol

      attr_reader :dir

      private

      def read_command_args(conn)
        length = conn.gets(Protocol::SEPARATOR)

        return nil unless length
        length = length.to_i

        command_body = read_command_body(conn, length)

        return nil unless command_body
        return nil if command_body.bytesize != length

        reader = StringIO.new(command_body)

        command = reader.gets(SEPARATOR)
        command&.chomp!(SEPARATOR)

        args = parse_args(reader)
        [command, args]
      end

      def client_loop(conn)
        while running?
          length = conn.gets(Protocol::SEPARATOR)

          break unless length
          length = length.to_i

          command_body = read_command_body(conn, length)

          break unless command_body
          break if command_body.bytesize != length

          reader = StringIO.new(command_body)

          command = reader.gets(SEPARATOR)
          command&.chomp!(SEPARATOR)

          args = parse_args(reader)

          conn.write(execute_command!(command, args))
        end
      end

      def execute_command!(command, args)
        begin
          if command == "ping"
            return pong_message
          end

          if command == "get"
            return error_message if args.size != 1
            val = @dir[args[0]]
            return val ? encode_message(val) : nil_message
          end

          if command == "set"
            return error_message if args.size != 2

            @dir[args[0]] = args[1]

            return ok_message
          end

          if command == "setex"
            return error_message if args.size != 3
            ttl = args[2].to_i
            return error_message if ttl.negative?
            @dir.set_with_ttl(args[0], args[1], ttl)
            return ok_message
          end

          if command == "del"
            return error_message if args.size != 1

            return @dir.delete(args[0]) ? ok_message : nil_message
          end
        rescue => e
          logger.warn("Error " + e.to_s)
        end

        error_message
      end

      def parse_word(reader)
        length = reader.gets(SEPARATOR).to_i
        return nil if length.zero?
        reader.read(length)
      end

      def read_command_body(conn, length)
        command_body = (+"").b
        size = 0

        while size < length
          val = conn.read([MAX_READ_SIZE, length - size].min)
          return nil if val.nil?
          size += val.bytesize
          command_body << val
        end

        command_body
      end

      def parse_args(reader)
        args = []

        while (word = parse_word(reader))
          args << word
        end

        args
      end
    end
  end
end
