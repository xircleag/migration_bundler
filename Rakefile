require 'bundler'
Bundler.setup
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Builds and installs the monkey_butler Gem'
task :install do
  lib = File.expand_path('../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'monkey_butler/version'
  
  system("gem build monkey_butler.gemspec && gem install monkey_butler-#{MonkeyButler::VERSION}.gem")
end

task :default => :spec
