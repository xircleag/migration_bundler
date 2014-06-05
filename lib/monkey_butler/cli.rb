require 'thor'
require "open3"
require 'monkey_butler/project'
require 'monkey_butler/database'
require 'monkey_butler/migrations'
require 'monkey_butler/commands/init'
require 'monkey_butler/commands/dump'
require 'monkey_butler/generators/base'

module MonkeyButler
  class CLI < Thor
    include Thor::Actions
    include MonkeyButler::Actions

    # Configures root path for resources (e.g. templates)
    def self.source_root
      File.dirname(__FILE__)
    end

    register(MonkeyButler::Commands::Init, "init", "init PATH", "Initializes a Monkey Butler repository at PATH")
    register(MonkeyButler::Commands::Dump, "dump", "dump", "Dump project schema from a database")

    desc "load", "Load project schema into a database"
    method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE"
    def load
      project = MonkeyButler::Project.load
      unless File.size?(project.schema_path)
        raise Error, "Cannot load database: empty schema found at #{project.schema_path}. Maybe you need to `mb migrate`?"
      end

      db_path = options[:database] || project.db_path
      if File.size?(db_path)
        File.truncate(db_path, 0)
        say_status :truncate, db_path, :yellow
      end
      command = "sqlite3 #{db_path} < #{project.schema_path}"
      say_status :executing, command
      stdout_str, stderr_str, status = Open3.capture3(command)
      fail Error, "Failed loading schema: #{stderr_str}" unless stderr_str.empty?

      db = MonkeyButler::Database.new(db_path)
      say "Loaded schema at version #{db.current_version}"
    end

    desc "create NAME", "Create a new migration"
    def create(name)
      migration_name = MonkeyButler::Util.migration_named(name)
      empty_directory('migrations')
      template('templates/migration.sql.erb', "migrations/#{migration_name}")
      git_add "migrations/#{migration_name}"
    end

    desc "status", "Display current schema version and any pending migrations"
    def status
      project = MonkeyButler::Project.load
      db = MonkeyButler::Database.new(project.db_path)
      migrations = MonkeyButler::Migrations.new(project.migrations_path, db)

      if db.migrations_table?
        say "Current version: #{migrations.current_version}"
      else
        say "New database"
        say "The database at '#{project.db_path}' does not have a 'schema_migrations' table."
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

    desc "migrate [VERSION]", "Apply pending migrations to a database"
    method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE"
    method_option :dump, type: :boolean, aliases: '-D', desc: "Dump schema after migrate"
    def migrate(version = nil)
      project = MonkeyButler::Project.load
      db_path = options[:database] || project.db_path
      db = MonkeyButler::Database.new(db_path)
      migrations = MonkeyButler::Migrations.new(project.migrations_path, db)

      if migrations.up_to_date?
        say "Database is up to date."
        return
      end

      target_version = version || migrations.latest_version
      if db.migrations_table?
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
              db.insert_version(version)
            rescue SQLite3::DatabaseException => exception
              fail Error, "Failed loading migration: #{exception}"
            end
          end
        end
        say
      end

      invoke :dump if options[:dump]
    end

    desc "validate", "Validate that schema loads and all migrations are linearly applicable"
    def validate
      project = MonkeyButler::Project.load

      say "Validating schema loads..."
      truncate_path(project.db_path)
      load
      say

      say "Validating migrations apply..."
      truncate_path(project.db_path)
      migrate

      say "Validation successful."
    end

    desc "generate", "Generate platform specific migration implementations"
    method_option :generators, type: :array, aliases: '-g', desc: "Run a specific set of generators."
    def generate
      project = MonkeyButler::Project.load
      generator_names = options[:generators] || project.generators
      generator_names.each do |name|
        require "monkey_butler/generators/#{name}/#{name}_generator"
        klass_name = "MonkeyButler::Generators::#{Util.camelize(name)}Generator"
        klass = Object.const_get(klass_name)
        say "Invoking generator '#{name}'..."
        invoke(klass)
      end
    end

    desc "package VERSION", "Package a release by validating, generating, and tagging a version"
    def package
      # Run validation
      # Generate the Git, CocoaPods, etc.
      # Commit the revision (ask?)
      # Tag the version
    end

    desc "push VERSION", "Push a release to Git, CocoaPods, Maven, etc."
    def push
      # Verify that the tag exists
      # Push to Github, CocoaPods, Maven (ask?)
    end
  end
end
