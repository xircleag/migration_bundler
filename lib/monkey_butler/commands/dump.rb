require 'monkey_butler/commands/base'
require 'monkey_butler/project'
require 'monkey_butler/database'
require 'monkey_butler/util'

module MonkeyButler
  module Commands
    class Dump < Base
      class_option :database, type: :string, aliases: '-d', desc: "Set target DATABASE"

      def validate_database
        fail Error, "Cannot dump database: no file at path '#{database_path}'." unless File.exists?(database_path)
        fail Error, "Cannot dump database: the database at path '#{database_path}' does not have a `schema_migrations` table." unless database.migrations_table?      
        say "Dumping schema from database '#{database_path}'"
      end

      def truncate_schema
        File.truncate(project.schema_path, 0)
      end

      def dump_tables
        say "Dumping tables..."
        dump_to_schema(:table) do |name|
          say "wrote table: #{name}", :green
        end
        say
      end

      def dump_indexes
        say "Dumping indexes..."
        dump_to_schema(:index) do |name|
          say "wrote index: #{name}", :green
        end
        say
      end

      def dump_triggers
        say "Dumping triggers..."
        dump_to_schema(:trigger) do |name|
          say "wrote trigger: #{name}", :green
        end
        say
      end

      def dump_views
        say "Dumping views..."
        dump_to_schema(:view) do |name|
          say "wrote trigger: #{name}", :green
        end
        say
      end

      def dump_rows_from_schema_migrations
        say "Dumping rows from 'schema_migrations'..."
        with_padding do
          File.open(project.schema_path, 'a') do |f|
            database.all_versions.each do |version|
              f.puts "INSERT INTO schema_migrations(version) VALUES (#{version});"
              say "wrote version: #{version}", :green
            end
          end
        end
        say
      end

      def inform_user_of_completion
        say "Dump complete. Schema written to #{schema_path}."
      end

      private
      def project
        @project ||= MonkeyButler::Project.load
      end

      def schema_path
        project.schema_path
      end

      def database_path
        options[:database] || project.db_path
      end

      def database
        @database ||= MonkeyButler::Database.new(database_path)
      end

      def dump_to_schema(type)
        sql = MonkeyButler::Util.strip_leading_whitespace <<-SQL
          SELECT name, sql
          FROM sqlite_master
          WHERE sql NOT NULL AND type = '#{type}'
          ORDER BY name ASC
        SQL
        with_padding do
          File.open(schema_path, 'a') do |f|
            database.db.execute(sql) do |row|
              name, sql = row
              next if name =~ /^sqlite/
              f << "#{sql};\n"
              yield name if block_given?
            end
            f.puts
          end
        end
      end
    end
  end
end
