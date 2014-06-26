require 'bundler'
Bundler.setup
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Builds and installs the migration_bundler Gem'
task :install do
  lib = File.expand_path('../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'migration_bundler/version'
  
  system("gem build migration_bundler.gemspec && gem install migration_bundler-#{MigrationBundler::VERSION}.gem")
end

task :default => :spec
