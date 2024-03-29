require 'sqlite3'
require 'uri'

module MigrationBundler
  module Databases
    class SqliteDatabase < AbstractDatabase
      attr_reader :db, :path

      class << self
        def create_schema_migrations_sql
          MigrationBundler::Util.strip_leading_whitespace <<-SQL
            CREATE TABLE schema_migrations(
                version INTEGER UNIQUE NOT NULL
            );
          SQL
        end

        def create(url)
          new(url) do |database|
            database.db.execute(create_schema_migrations_sql)
          end
        end

        def migration_ext
          ".sql"
        end

        def exception_class
          SQLite3::Exception
        end
      end

      def initialize(url)
        super(url)
        raise ArgumentError, "Must initialize with a URI" unless url.kind_of?(URI)
        raise ArgumentError, "Must initialize with a sqlite URI" unless url.scheme.nil? || url.scheme == 'sqlite'
        path = url.path || url.opaque
        raise ArgumentError, "Must initialize with a sqlite URI that has a path component" unless path
        @path = path
        @db = SQLite3::Database.new(path)
        yield self if block_given?
      end

      def migrations_table?
        has_table?('schema_migrations')
      end

      def origin_version
        db.get_first_value('SELECT MIN(version) FROM schema_migrations')
      end

      def current_version
        db.get_first_value('SELECT MAX(version) FROM schema_migrations')
      end

      def all_versions
        db.execute('SELECT version FROM schema_migrations ORDER BY version ASC').map { |row| row[0] }
      end

      def insert_version(version)
        db.execute("INSERT INTO schema_migrations(version) VALUES (?)", version)
      end

      def execute_migration(sql)
        db.transaction do |db|
          db.execute_batch(sql)
        end
      end

      def drop
        File.truncate(path, 0) if File.size?(path)
      end

      def to_s
        path
      end

      def dump_rows(table_name)
        statement = db.prepare("SELECT * FROM #{table_name}")
        result_set = statement.execute
        Array.new.tap do |statements|
          result_set.each do |row|
            values = row.map { |v| v.is_a?(String) ? SQLite3::Database.quote(v) : v }
            statements << "INSERT INTO #{table_name} (#{result_set.columns.join(', ')}) VALUES (#{values.join(', ')});"
          end
        end
      end

      ####
      # Outside of abstract interface...

      def dump_to_schema(type, schema_path)
        sql = MigrationBundler::Util.strip_leading_whitespace <<-SQL
          SELECT name, sql
          FROM sqlite_master
          WHERE sql NOT NULL AND type = '#{type}'
          ORDER BY name ASC
        SQL
        File.open(schema_path, 'a') do |f|
          db.execute(sql) do |row|
            name, sql = row
            next if name =~ /^sqlite/
            f << "#{sql};\n\n"
            yield name if block_given?
          end
          f.puts
        end
      end

      private
      def has_table?(table)
        db.get_first_value("SELECT name FROM sqlite_master WHERE type='table' AND name=?", table)
      end
    end
  end
end
