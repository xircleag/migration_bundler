require 'monkey_butler/databases/cassandra_database'

module MonkeyButler
  module Targets
    class CassandraTarget < Base
      def init
        migration_path = "migrations/" + MonkeyButler::Util.migration_named('create_' + options[:name]) + '.cql'
        template('create_schema_migrations.cql.erb', migration_path)
        git_add migration_path
      end

      def new(name)
        migration_path = "migrations/" + MonkeyButler::Util.migration_named(name) + '.cql'
        template('migration.cql.erb', migration_path)
        git_add migration_path
      end

      def dump
        database_url = (options[:database] && URI(options[:database])) || project.database_url
        @database = MonkeyButler::Databases::CassandraDatabase.new(database_url)
        fail Error, "Cannot dump database: the database at '#{database_url}' does not have a `schema_migrations` table." unless database.migrations_table?
        say "Dumping schema from database '#{database_url}'"

        say "Dumping keyspaces '#{keyspaces.join(', ')}'..."
        describe_statements = keyspaces.map { |keyspace| "describe keyspace #{keyspace};" }
        run "cqlsh -e '#{describe_statements.join(' ')}' #{database_url.host} > #{project.schema_path}"

        say "Dumping rows from 'schema_migrations'..."
        with_padding do
          File.open(project.schema_path, 'a') do |f|
            f.puts "USE #{keyspace};"
            database.all_versions.each do |version|
              f.puts "INSERT INTO schema_migrations(partition_key, version) VALUES (0, #{version});"
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

        @database = MonkeyButler::Databases::CassandraDatabase.new(database_url)
        drop
        run "cqlsh #{database_url.host} -f #{project.schema_path}"

        say "Loaded schema at version #{database.current_version}"
      end

      def drop
        say_status :drop, database_url, :yellow
        database.drop(keyspaces)
      end

      private
      def keyspace
        database_url.path[1..-1]
      end

      def keyspaces
        keyspaces = (project.config['cassandra.keyspaces'] || []).dup
        keyspaces.unshift(keyspace)
      end
    end
  end
end
