# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wrenchmode'

Gem::Specification.new do |spec|
  spec.name          = "wrenchmode-rack"
  spec.version       = Wrenchmode::Rack::VERSION
  spec.authors       = ["Micah Wedemeyer"]
  spec.email         = ["me@micahwedemeyer.com"]

  spec.summary       = "Rack middleware for using maintenance mode with Wrenchmode.com"
  #spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "http://github.com/micahwedemeyer/wrenchmode-rack"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 1.0"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.10.3"
end
