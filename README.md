# Rubcask
Rubcask is a Bitcask-like log-structured Key/Value storage library.

It ships with a TCP server and client implementing a custom protocol.

It has design very similar to bitcask including merge operation, moving to a next file after reaching a configurable limit; timestamp however is used for expiration only.

## Documentation
https://rubydoc.info/github/mhib/rubcask/master

## Disclaimer
This library is not production-ready.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rubcask'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rubcask

## Usage
Rubcask's main methods are very similar to ruby's hash.

```ruby
dir = Rubcask::Directory.new("path_to_directory")
dir["key"] = "value"
dir["key"] # => "value"
dir.delete("key") # => true
dir.close
```

You can also set value with a ttl.

```ruby
dir = Rubcask::Directory.new("path_to_directory")
dir.set_with_ttl("key", "value", 10)
dir["key"] # => "value"
sleep(11)
dir["key"] # => nil
dir.close
```

Rubcask does not store encoding information and stores keys as bytes, so using utf-8 strings is the same as using ASCII strings.
The same goes with values.

```ruby
dir = Rubcask::Directory.new("path_to_directory")
dir["jeż"] = "3"
dir["jeż".b] # => 3
dir.close
```

Rubcask can be used both as a library and as a server.

See `examples/server_runner.rb` for example configuration with a TCP server and a merge worker.

See `lib/rubcask/server/client.rb` for server client

## Thread safety
By default `Rubcask::Directory` is thread safe.

Consider installing `concurrent-ruby-ext` for some performance gains.

If you do not want to pay performance penalty for synchronization, it is possible to disable thread synchronization in config.

```ruby
config = Rubcask::Config.configure { |c| c.threadsafe = false }
dir = Rubcask::Directory.new("path_to_directory", config: config)
```

It is only safe to do that when using Rubcask as a library; server implementations assumes that Directory is run with `threadsafe = true`.

## Server implementations
Projects is shipped with threaded server that does not require any dependencies, and with async server that requires `async-io`.

They implement the same custom protocol.

Generally async server is faster especially for pipelines as it buffers reads.

Note that async server might not work on JRuby.

## Supported Ruby implementations
Tested against supported versions of CRuby and JRuby. TruffleRuby currently does not work due to some `IO` incompatibilities.

## Todo
* A script in `bin/` for running server runner easily.
* (maybe) Nice drb support
* (maybe) Using trie instead of key-dir with ordered iteration support

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mhib/rubcask.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
