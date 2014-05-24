require 'thor'
require "open3"
require 'monkey_butler/commands/init'
require 'monkey_butler/commands/generate'

class MonkeyButler::Config
  def self.load(path = Dir.pwd)
    config_path = File.join(path, '.monkey_butler.yml')
    raise "fatal: Not a monkey_butler repository: no .monkey_butler.yml" unless File.exists?(config_path)
    options = YAML.load(File.read(config_path))
    new(options)
  end

  attr_accessor :project_name

  def initialize(options = {})
    options.each { |k,v| send("#{k}=", v) }
  end

  def db_path
    "#{project_name}.db"
  end

  def schema_path
    "#{project_name}.sql"
  end
end

module MonkeyButler
  class CLI < Thor
    include Thor::Actions
    include MonkeyButler::Actions

    # TODO: class options: verbose, dry run, specify database to work on.

    register(MonkeyButler::Commands::Init, "init", "init PATH", "Initializes a Monkey Butler repository at PATH")

    desc "load", "Loads project schema into target database"
    def load
      config = MonkeyButler::Config.load
      unless File.size?(config.schema_path)
        raise Error, "Cannot load database: empty schema found at #{config.schema_path}. Maybe you need to `mb migrate`?"
      end
      File.truncate(config.db_path, 0)

      # NOTE: We load via sqlite3 CLI because its parsing is unforgiving of missing semicolons
      say_status :truncate, config.db_path, :yellow
      command = "sqlite3 #{config.db_path} < #{config.schema_path}"
      say_status :executing, command
      stdout_str, stderr_str, status = Open3.capture3(command)
      fail Error, "Failed loading schema: #{stderr_str}" unless stderr_str.empty?

      db = MonkeyButler::Database.new(config.db_path)
      say "Loaded schema at version #{db.current_version}"
    end

    desc "create NAME", "Creates a new migration"
    def create(name)

    end

    desc "status", "Displays current schema version and any unapplied migrations"
    def status

    end

    desc "migrate [VERSION]", "Applies pending migrations to the target database"
    def migrate(version = nil)

    end

    desc "generate", "Generates platform specific migration implementations"
    def generate

    end

    desc "validate", "Validates schema loads and all migrations are linearly applicable"
    def validate

    end

    desc "package VERSION", "Packages a release by validating, generating, and tagging a version"
    def package

    end

    desc "push VERSION", "Pushes a release to Git, CocoaPods, Maven, etc."
    def push

    end
  end
end
