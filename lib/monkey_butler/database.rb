require 'sqlite3'

module MonkeyButler
  class Database
    attr_reader :db

    class << self
      def create_schema_migrations_sql
        MonkeyButler::Util.strip_leading_whitespace <<-SQL
          CREATE TABLE schema_migrations(
              version INTEGER UNIQUE NOT NULL
          );
        SQL
      end

      def create(path)
        new(path) do |database|
          database.db.execute(create_schema_migrations_sql)
        end
      end
    end

    def initialize(path)
      @db = SQLite3::Database.new(path)
      yield self if block_given?
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
  end
end
