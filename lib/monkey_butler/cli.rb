require 'thor'
require "open3"
require 'monkey_butler/commands/init'
require 'monkey_butler/config'
require 'monkey_butler/database'
require 'monkey_butler/migrations'

module MonkeyButler
  class CLI < Thor
    include Thor::Actions
    include MonkeyButler::Actions

    def self.source_root
      File.dirname(__FILE__)
    end

    # TODO: class options: verbose, dry run, specify database to work on.

    register(MonkeyButler::Commands::Init, "init", "init PATH", "Initializes a Monkey Butler repository at PATH")

    desc "load", "Loads project schema into target database"
    def load
      config = MonkeyButler::Config.load
      unless File.size?(config.schema_path)
        raise Error, "Cannot load database: empty schema found at #{config.schema_path}. Maybe you need to `mb migrate`?"
      end

      if File.size?(config.db_path)
        File.truncate(config.db_path, 0)
        say_status :truncate, config.db_path, :yellow
      end
      command = "sqlite3 #{config.db_path} < #{config.schema_path}"
      say_status :executing, command
      stdout_str, stderr_str, status = Open3.capture3(command)
      fail Error, "Failed loading schema: #{stderr_str}" unless stderr_str.empty?

      db = MonkeyButler::Database.new(config.db_path)
      say "Loaded schema at version #{db.current_version}"
    end

    desc "create NAME", "Creates a new migration"
    def create(name)
      migration_name = MonkeyButler::Util.migration_named(name)
      empty_directory('migrations')
      template('templates/migration.sql.erb', "migrations/#{migration_name}")
      git_add "migrations/#{migration_name}"
    end

    desc "status", "Displays current schema version and any unapplied migrations"
    def status
      config = MonkeyButler::Config.load
      db = MonkeyButler::Database.new(config.db_path)
      migrations = MonkeyButler::Migrations.new(config.migrations_path, db)

      if db.has_migrations_table?
        say "Current version: #{migrations.current_version}"
      else
        say "New database"
        say "The database at '#{config.db_path}' does not have a 'schema_migrations' table."
      end

      if migrations.up_to_date?
        say "Database is up to date."
        return
      end

      say
      say "Migrations to be applied"
      with_padding do
        say %q{(use "mb migrate" to apply)}
        with_padding do
          migrations.pending do |version, path|
            say "pending migration: #{path}", :green
          end
        end
      end
    end

    # TODO: The db path needs to be configurable...
    desc "migrate [VERSION]", "Applies pending migrations to the target database"
    def migrate(version = nil)
      config = MonkeyButler::Config.load
      db = MonkeyButler::Database.new(config.db_path)
      migrations = MonkeyButler::Migrations.new(config.migrations_path, db)

      if migrations.up_to_date?
        say "Database is up to date."
        return
      end

      target_version = version || migrations.latest_version
      if db.has_migrations_table?
        say "Migrating from #{db.current_version} to #{target_version}"
      else
        say "Migrating new database to #{target_version}"
      end
      say

      with_padding do
        say "Migrating database..."
        with_padding do
          migrations.pending do |version, path|
            say "applying migration: #{path}", :blue
            begin
              db.execute_migration(File.read(path))
            rescue SQLite3::Exception => exception
              fail Error, "Failed loading migration: #{exception}"
            end
            db.insert_version(version)
          end
        end
        say
      end
    end

    desc "validate", "Validates that schema loads and all migrations are linearly applicable"
    def validate
      config = MonkeyButler::Config.load

      say "Validating schema loads..."
      truncate_path(config.db_path)
      load
      say

      say "Validating migrations apply..."
      truncate_path(config.db_path)
      migrate

      say "Validation successful."
    end

    desc "generate", "Generates platform specific migration implementations"
    def generate
      # TODO: Figure this out
    end

    desc "package VERSION", "Packages a release by validating, generating, and tagging a version"
    def package
      # Run validation
      # Generate the Git, CocoaPods, etc.
      # Commit the revision (ask?)
      # Tag the version
    end

    desc "push VERSION", "Pushes a release to Git, CocoaPods, Maven, etc."
    def push
      # Verify that the tag exists
      # Push to Github, CocoaPods, Maven (ask?)
    end
  end
end
