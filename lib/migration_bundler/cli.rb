require 'thor'
require "open3"
require 'migration_bundler/project'
require 'migration_bundler/actions'
require 'migration_bundler/databases/abstract_database'
require 'migration_bundler/migrations'
require 'migration_bundler/util'
require 'migration_bundler/targets/base'

module MigrationBundler
  class CLI < Thor
    include Thor::Actions
    include MigrationBundler::Actions

    add_runtime_options!

    # Configures root path for resources (e.g. templates)
    def self.source_root
      File.dirname(__FILE__)
    end

    attr_reader :project

    desc 'init [PATH]', 'Initializes a new repository into PATH'
    method_option :name, type: :string, aliases: '-n', desc: "Specify project name"
    method_option :database, type: :string, aliases: '-d', desc: "Specify database path or URL."
    method_option :targets, type: :array, aliases: '-g', default: [], desc: "Specify default code targets."
    method_option :bundler, type: :boolean, aliases: '-b', default: false, desc: "Use Bundler to import MigrationBundler into project."
    method_option :config, type: :hash, aliases: '-c', default: {}, desc: "Specify config variables."
    def init(path)
      if File.exists?(path)
        raise Error, "Cannot create repository: regular file exists at path '#{path}'" unless File.directory?(path)
        raise Error, "Cannot create repository into non-empty path '#{path}'" if File.directory?(path) && Dir.entries(path) != %w{. ..}
      end
      self.destination_root = File.expand_path(path)
      empty_directory('.')
      inside(destination_root) { git init: '-q' }

      # hydrate the project
      project_name = options['name'] || File.basename(path)
      sanitized_options = options.reject { |k,v| %w{bundler pretend database}.include?(k) }
      sanitized_options[:name] = project_name
      sanitized_options[:database_url] = options[:database] || "sqlite:#{project_name}.sqlite"
      @project = MigrationBundler::Project.set(sanitized_options)

      # generate_gitignore
      template('templates/gitignore.erb', ".gitignore")
      git_add '.gitignore'

      # generate_config
      create_file '.migration_bundler.yml', YAML.dump(sanitized_options)
      git_add '.migration_bundler.yml'

      # generate_gemfile
      if options['bundler']
        template('templates/Gemfile.erb', "Gemfile")
      end

      # init_targets
      project = MigrationBundler::Project.set(sanitized_options)
      target_options = options.merge('name' => project_name)
      MigrationBundler::Util.target_classes_named(options[:targets]) do |target_class|
        say "Initializing target '#{target_class.name}'..."
        invoke(target_class, :init, [], target_options)
      end
      project.config['db.dump_tables'] = %w{schema_migrations}
      project.save!(destination_root) unless options['pretend']
      git_add '.migration_bundler.yml'

      # Run after targets in case they modify the Gemfile
      # run_bundler
      if options['bundler']
        git_add "Gemfile"
        bundle
        git_add "Gemfile.lock"
      end

      # touch_database
      create_file(project.schema_path)
      git_add project.schema_path

      # init_database_adapter
      empty_directory('migrations')
      inside do
        invoke(project.database_target_class, :init, [], target_options)
      end
    end

    desc "dump", "Dump project schema from a database"
    def dump
      @project = MigrationBundler::Project.load
      invoke(project.database_target_class, :dump, [], options)
    end

    desc "load", "Load project schema into a database"
    def load
      @project = MigrationBundler::Project.load
      invoke(project.database_target_class, :load, [], options)
    end

    desc "drop", "Drop the schema currently loaded into a database"
    def drop
      @project = MigrationBundler::Project.load
      invoke(project.database_target_class, :drop, [], options)
    end

    desc "new NAME", "Create a new migration"
    def new(name)
      @project = MigrationBundler::Project.load
      empty_directory('migrations')
      invoke(project.database_target_class, :new, [name], options)
    end

    desc "status", "Display current schema version and any pending migrations"
    method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE"
    def status
      project = MigrationBundler::Project.load
      migrations = MigrationBundler::Migrations.new(project.migrations_path, database)

      if database.migrations_table?
        say "Current version: #{migrations.current_version}"
        pending_count = migrations.pending.size
        version = (pending_count == 1) ? "version" : "versions"
        say "The database at '#{database}' is #{pending_count} #{version} behind #{migrations.latest_version}" unless migrations.up_to_date?
      else
        say "New database"
        say "The database at '#{database}' does not have a 'schema_migrations' table."
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
      project = MigrationBundler::Project.load

      if migrations.up_to_date?
        say "Database is up to date."
        return
      end

      target_version = version || migrations.latest_version
      if database.migrations_table?
        say "Migrating from #{database.current_version} to #{target_version}"
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
              database.execute_migration(File.read(path))
              database.insert_version(version)
            rescue project.database_class.exception_class => exception
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
      project = MigrationBundler::Project.load

      say "Validating project configuration..."
      say_status :git, "configuration", (project.git_url.empty? ? :red : :green)
      if project.git_url.empty?
        fail Error, "Invalid configuration: git does not have a remote named 'origin'."
      end
      say

      invoke(project.database_target_class, :validate, [], options)

      say "Validating schema loads..."
      truncate_database
      load
      say

      say "Validating migrations apply..."
      truncate_database
      migrate
      say

      say "Validating targets..."
      target_names = options['targets'] || project.targets
      MigrationBundler::Util.target_classes_named(target_names) do |target_class|
        with_padding do
          say_status :validate, target_class.name
          invoke_with_padding(target_class, :validate, [], options)
        end
      end
      say

      say "Validation successful."
    end

    desc "generate", "Generate platform specific migration implementations"
    method_option :targets, type: :array, aliases: '-t', desc: "Generate only the specified targets."
    def generate
      project = MigrationBundler::Project.load
      invoke(project.database_target_class, :generate, [], options)
      target_names = options['targets'] || project.targets
      MigrationBundler::Util.target_classes_named(target_names) do |target_class|
        say "Invoking target '#{target_class.name}'..."
        invoke(target_class, :generate, [], options)
      end
    end

    desc "package", "Package a release by validating, generating, and tagging a version."
    method_option :diff, type: :boolean, desc: "Show Git diff after packaging"
    method_option :commit, type: :boolean, desc: "Commit package artifacts after build."
    def package
      validate
      say
      generate
      say

      git_add '.'
      git :status unless options['quiet']

      show_diff = options['diff'] != false && (options['diff'] || ask("Review package diff?", limited_to: %w{y n}) == 'y')
      git diff: '--cached' if show_diff

      commit = options['commit'] != false && (options['commit'] || ask("Commit package artifacts?", limited_to: %w{y n}) == 'y')
      if commit
        tag = unique_tag_for_version(migrations.latest_version)
        git commit: "#{options['quiet'] && '-q '}-m 'Packaging release #{tag}' ."
        git tag: "#{tag}"
      else
        say "Package artifacts were built but not committed. Re-run `mb package` when ready to complete build."
      end
    end

    desc "push", "Push a release to Git, CocoaPods, Maven, etc."
    def push
      # Verify that the tag exists
      git tag: "-l #{migrations.latest_version}"
      unless $?.exitstatus.zero?
        fail Error, "Could not find tag #{migrations.latest_version}. Did you forget to run `mb package`?"
      end
      push_options = []
      push_options << '--force' if options['force']
      branch_name = project.git_current_branch
      run "git config branch.`git symbolic-ref --short HEAD`.merge", verbose: false
      unless $?.exitstatus.zero?
        say_status :git, "no merge branch detected: setting upstream during push", :yellow
        push_options << "--set-upstream origin #{branch_name}"
      end
      push_options << "origin #{branch_name}"
      push_options << "--tags"

      git push: push_options.join(' ')
      unless $?.exitstatus.zero?
        fail Error, "git push failed."
      end

      # Give the targets a chance to push
      target_names = options['targets'] || project.targets
      MigrationBundler::Util.target_classes_named(target_names) do |target_class|
        say "Invoking target '#{target_class.name}'..."
        invoke(target_class, :push, [], options)
      end
    end

    desc "config", "Get and set configuration options."
    def config(key = nil, value = nil)
      if key && value
        project.config[key] = value
        project.save!(Dir.pwd)
      elsif key
        value = project.config[key]
        if value
          say "#{key}=#{value}"
        else
          say "No value for key '#{key}'"
        end
      else
        project.config.each { |key, value| say "#{key}=#{value}" }
      end
    end

    # Hook into the command execution for dynamic task configuration
    def self.start(given_args = ARGV, config = {})
      if File.exists?(Dir.pwd + '/.migration_bundler.yml')
        project = MigrationBundler::Project.load
        project.database_target_class.register_with_cli(self)
      end
      super
    end

    private
    def unique_tag_for_version(version)
      return version if options['pretend']

      revision = nil
      tag = nil
      begin
        tag = [version, revision].compact.join('.')
        existing_tag = run "git tag -l #{tag}", capture: true
        break if existing_tag == ""
        revision = revision.to_i + 1
      end while true
      tag
    end

    private
    def bundle
      inside(destination_root) { run "bundle" }
    end

    def project
      @project ||= MigrationBundler::Project.load
    end

    def database
      @database ||= project.database_class.new((options[:database] && URI(options[:database])) || project.database_url)
    end

    def migrations
      @migrations ||= MigrationBundler::Migrations.new(project.migrations_path, database)
    end
  end
end
