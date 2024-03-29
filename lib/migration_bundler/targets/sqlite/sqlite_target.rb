require 'migration_bundler/databases/sqlite_database'

module MigrationBundler
  module Targets
    class SqliteTarget < Base
      # TODO: Need a way to do this for self elegantly...
      def self.register_with_cli(cli)
        cli.method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE", for: :dump
        cli.method_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE", for: :load
      end

      def init
        migration_name = MigrationBundler::Util.migration_named('create_' + options['name'])
        template('create_migration_bundler_tables.sql.erb', "migrations/#{migration_name}.sql")
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
        migration_name = MigrationBundler::Util.migration_named(name) + migration_ext
        template('migration.sql.erb', "migrations/#{migration_name}")
        git_add "migrations/#{migration_name}"
      end

      def dump
        database_url = (options[:database] && URI(options[:database])) || project.database_url
        database_path = database_url.path || database_url.opaque
        fail Error, "Cannot dump database: no file at path '#{database_path}'." unless File.exists?(database_path)

        @database = MigrationBundler::Databases::SqliteDatabase.new(database_url)
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

        File.open(project.schema_path, 'a') do |f|
          project.config['db.dump_tables'].each do |table_name|
            say "Dumping rows from '#{table_name}'..."
            with_padding do
              row_statements = database.dump_rows(table_name)
              f.puts row_statements.join("\n\n")
              say "wrote #{row_statements.size} rows.", :green
            end
          end
          say
        end

        say "Dump complete. Schema written to #{project.schema_path}."
      end

      def load
        project = MigrationBundler::Project.load
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
