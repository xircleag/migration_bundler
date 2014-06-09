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

    class_option :pretend, type: :boolean, aliases: "-p", group: :runtime, desc: "Run but do not make any changes"

    # Configures root path for resources (e.g. templates)
    def self.source_root
      File.dirname(__FILE__)
    end

    register(MonkeyButler::Commands::Init, "init", "init PATH", "Initialize a Monkey Butler project at PATH")
    register(MonkeyButler::Commands::Dump, "dump", "dump", "Dump project schema from a database")

    # Workaround bug in Thor option registration
    tasks["init"].options = MonkeyButler::Commands::Init.class_options
    tasks["dump"].options = MonkeyButler::Commands::Dump.class_options

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

    desc "new NAME", "Create a new migration"
    def new(name)
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
        pending_count = migrations.pending.size
        version = (pending_count == 1) ? "version" : "versions"
        say "The database at '#{project.db_path}' is #{pending_count} #{version} behind #{migrations.latest_version}" unless migrations.up_to_date?
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
        say
        with_padding do
          migrations.pending do |version, path|
            say "pending migration: #{path}", :green
          end
        end
        say
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
        say
        with_padding do
          migrations.pending do |version, path|
            say "applying migration: #{path}", :green
            begin
              db.execute_migration(File.read(path))
              db.insert_version(version)
            rescue SQLite3::Exception => exception
              fail Error, "Failed loading migration: #{exception}"
            end
          end
        end
        say
      end

      say "Migration to version #{target_version} complete."

      if options['dump']
        say
        invoke :dump, [], options
      end
    end

    desc "validate", "Validate that schema loads and all migrations are linearly applicable"
    def validate
      project = MonkeyButler::Project.load

      say "Validating project configuration..."
      say_status :git, "configuration", (project.git_url.empty? ? :red : :green)
      if project.git_url.empty?
        fail Error, "Invalid configuration: git does not have a remote named 'origin'."
      end
      say

      say "Validating schema loads..."
      truncate_path(project.db_path)
      load
      say

      say "Validating migrations apply..."
      truncate_path(project.db_path)
      migrate
      say

      say "Validating generators..."
      generator_names = options[:generators] || project.generators
      MonkeyButler::Util.generator_classes_named(generator_names) do |generator_class|
        with_padding do
          say_status :validate, generator_class.name
          invoke_with_padding(generator_class, :validate, [], options)
        end
      end
      say

      say "Validation successful."
    end

    desc "generate", "Generate platform specific migration implementations"
    method_option :generators, type: :array, aliases: '-g', desc: "Run a specific set of generators."
    def generate
      project = MonkeyButler::Project.load
      generator_names = options[:generators] || project.generators
      MonkeyButler::Util.generator_classes_named(generator_names) do |generator_class|
        say "Invoking generator '#{generator_class.name}'..."
        invoke(generator_class, :generate, [], options)
      end
    end

    desc "package", "Package a release by validating, generating, and tagging a version."
    method_option :commit, type: :boolean, aliases: '-c', desc: "Commit package artifacts after build."
    method_option :diff, type: :boolean, default: true, desc: "Show Git diff after generation"
    def package
      project = MonkeyButler::Project.load
      db = MonkeyButler::Database.new(project.db_path)
      migrations = MonkeyButler::Migrations.new(project.migrations_path, db)

      validate
      generate

      git_add '.'
      # git :status
      git diff: '--cached' if options[:diff]

      if options['commit'] || ask("Commit package artifacts?", limited_to: %w{y n}) == 'y'
        git commit: "-m 'Packaging release #{migrations.latest_version}' ."
        # TODO: Handle overwriting existing tag OR create unique tag by appending digits?
        git tag: "#{migrations.latest_version}"
      else
        say "Package artifacts were built but not committed. Re-run `mb package` when ready to complete build."
      end
    end

    desc "push", "Push a release to Git, CocoaPods, Maven, etc."
    method_option :force, type: :boolean, aliases: '-f', desc: "Force the Git push."
    def push
      project = MonkeyButler::Project.load
      db = MonkeyButler::Database.new(project.db_path)
      migrations = MonkeyButler::Migrations.new(project.migrations_path, db)

      # Verify that the tag exists
      git tag: "-l #{migrations.latest_version}"
      unless $?.exitstatus.zero?
        fail Error, "Could not find tag #{migrations.latest_version}. Did you forget to run `mb package`?"
      end
      push_options = %w{--tags}
      push_options << '--force' if options['force']
      branch_name = run "git symbolic-ref --short HEAD", capture: true, verbose: false
      run "git config branch.`git symbolic-ref --short HEAD`.merge", verbose: false
      unless $?.exitstatus.zero?
        say_status :git, "no merge branch detected: setting upstream during push", :yellow
        push_options << "--set-upstream origin #{branch_name}"
      end
      git push: push_options.join(' ')
      unless $?.exitstatus.zero?
        fail Error, "git push failed."
      end

      # Give the generators a chance to push
      generator_names = options[:generators] || project.generators
      MonkeyButler::Util.generator_classes_named(generator_names) do |generator_class|
        say "Invoking generator '#{generator_class.name}'..."
        invoke(generator_class, :push, [], options)
      end
    end
  end
end
