require 'uri'
require 'cql'

module MigrationBundler
  module Databases
    class CassandraDatabase < AbstractDatabase
      attr_reader :client, :keyspace

      class << self
        def migration_ext
          ".cql"
        end

        def exception_class
          Cql::CqlError
        end
      end

      def initialize(url)
        super(url)
        options = { host: url.host, port: (url.port || 9042) }
        @client = Cql::Client.connect(options)
        @keyspace = url.path[1..-1] # Drop leading slash
      end

      def migrations_table?
        client.use('system')
        rows = client.execute "SELECT columnfamily_name FROM schema_columnfamilies WHERE keyspace_name='#{keyspace}' AND columnfamily_name='schema_migrations'"
        !rows.empty?
      end

      def origin_version
        client.use(keyspace)
        rows = client.execute("SELECT version FROM schema_migrations WHERE partition_key = 0 ORDER BY version ASC LIMIT 1")
        rows.empty? ? nil : rows.each.first['version']
      end

      def current_version
        client.use(keyspace)
        rows = client.execute("SELECT version FROM schema_migrations WHERE partition_key = 0 ORDER BY version DESC LIMIT 1")
        rows.empty? ? nil : rows.each.first['version']
      end

      def all_versions
        client.use(keyspace)
        rows = client.execute("SELECT version FROM schema_migrations WHERE partition_key = 0 ORDER BY version ASC")
        rows.each.map { |row| row['version'] }
      end

      def insert_version(version)
        client.use(keyspace)
        client.execute "INSERT INTO schema_migrations (partition_key, version) VALUES (0, ?)", version
      end

      def execute_migration(cql)
        cql.split(';').each { |statement| client.execute(statement) unless statement.strip.empty? }
      end

      def drop(keyspaces = [keyspace])
        keyspaces.each { |keyspace| client.execute "DROP KEYSPACE IF EXISTS #{keyspace}" }
      end

      def create_migrations_table
        client.execute "CREATE KEYSPACE IF NOT EXISTS #{keyspace} WITH replication = {'class' : 'SimpleStrategy', 'replication_factor' : 1};"
        client.execute "CREATE TABLE IF NOT EXISTS #{keyspace}.schema_migrations (partition_key INT, version VARINT, PRIMARY KEY (partition_key, version));"
      end

      def dump_rows(table_name)
        client.use(keyspace)
        rows = client.execute "SELECT * FROM #{table_name}"
        columns = Array.new.tap do |columns|
          rows.metadata.each do |column_metadata|
            columns << column_metadata.column_name
          end
        end
        Array.new.tap do |statements|
          rows.each do |row|
            values = columns.map do |column|
              value = row[column]
              value.is_a?(String) ? "\"#{value}\"" : value
            end
            statements << "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES (#{values.join(', ')});"
          end
        end
      end
    end
  end
end
