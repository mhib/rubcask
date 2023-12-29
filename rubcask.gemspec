# frozen_string_literal: true

require_relative "lib/rubcask/version"

Gem::Specification.new do |spec|
  spec.name = "rubcask"
  spec.version = Rubcask::VERSION
  spec.authors = ["Marcin Henryk Bartkowiak"]
  spec.email = ["mhbartkowiak@gmail.com"]

  spec.summary = "Key/Value storage library"
  spec.description = "Bitcask-like Key/Value storege library with a TCP server included"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"
  spec.homepage = "https://github.com/mhib/rubcask"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", "~> 1.1"

  spec.add_dependency "stringio", "~> 3.1"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
