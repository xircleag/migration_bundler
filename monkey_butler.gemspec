# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'monkey_butler/version'

Gem::Specification.new do |s|
  s.name        = 'monkey_butler'
  s.version     = '0.0.1'
  s.date        = '2014-05-22'
  s.summary     = "Monkey Butler is a schema management system for SQLite"
  s.description = "A simple hello world gem"
  s.authors     = ["Blake Watters"]
  s.email       = 'blake@layer.com'
  s.homepage    = 'http://github.com/layerhq/monkey_butler'
  s.license     = 'Apache 2'

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency 'thor', '~> 0.19.1'
  s.add_dependency 'sqlite3', '~> 1.3.9'

  s.add_development_dependency "bundler", "~> 1.6"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.14.1"
  s.add_development_dependency "guard-rspec", "~> 4.2.9"
  s.add_development_dependency "simplecov", "~> 0.8.2"
  s.add_development_dependency "debugger", "~> 1.6.6"
end
