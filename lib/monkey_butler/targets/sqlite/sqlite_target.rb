require 'monkey_butler/databases/sqlite_database'

module MonkeyButler
  module Targets
    class SqliteTarget < Base
      # TODO: Need a way to do this for self elegantly...
      def self.register_with_cli(cli)
        cli.method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE", for: :dump
        cli.method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE", for: :load
      end

      def init
        migration_name = MonkeyButler::Util.migration_named(options['name'])
        template('create_monkey_butler_tables.sql.erb', "migrations/#{migration_name}.sql")
        git_add "migrations/#{migration_name}.sql"
        create_file(database_path)
        append_to_file '.gitignore', database_path
      end

      no_commands do
        # NOTE: Used instead of database.url to avoid creation of the database in pretend mode
        def database_path
          database_url.path || database_url.opaque
        end
      end

      def new(name)
        migration_ext = project.database_class.migration_ext
        migration_name = MonkeyButler::Util.migration_named(name) + migration_ext
        template('migration.sql.erb', "migrations/#{migration_name}")
        git_add "migrations/#{migration_name}"
      end

      def dump
        database_url = (options[:database] && URI(options[:database])) || project.database_url
        database_path = database_url.path || database_url.opaque
        fail Error, "Cannot dump database: no file at path '#{database_path}'." unless File.exists?(database_path)

        @database = MonkeyButler::Databases::SqliteDatabase.new(database_url)
        fail Error, "Cannot dump database: the database at path '#{database_path}' does not have a `schema_migrations` table." unless database.migrations_table?
        say "Dumping schema from database '#{database_path}'"

        File.truncate(project.schema_path, 0)

        types = { table: 'tables', index: 'indexes', trigger: 'triggers', view: 'views'}
        types.each do |type, name|
          say "Dumping #{name}..."
          with_padding do
            database.dump_to_schema(type, project.schema_path) do |name|
              say "wrote #{type}: #{name}", :green
            end
          end
          say
        end

        say "Dumping rows from 'schema_migrations'..."
        with_padding do
          File.open(project.schema_path, 'a') do |f|
            database.all_versions.each do |version|
              f.puts "INSERT INTO schema_migrations(version) VALUES (#{version});\n\n"
              say "wrote version: #{version}", :green
            end
          end
        end
        say

        say "Dump complete. Schema written to #{project.schema_path}."
      end

      def load
        project = MonkeyButler::Project.load
        unless File.size?(project.schema_path)
          raise Error, "Cannot load database: empty schema found at #{project.schema_path}. Maybe you need to `mb migrate`?"
        end

        drop
        command = "sqlite3 #{database.path} < #{project.schema_path}"
        say_status :executing, command
        stdout_str, stderr_str, status = Open3.capture3(command)
        fail Error, "Failed loading schema: #{stderr_str}" unless stderr_str.empty?

        say "Loaded schema at version #{database.current_version}"
      end
      
      def drop
        say_status :truncate, database.path, :yellow
        database.drop
      end
    end
  end
end
