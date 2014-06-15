module MonkeyButler
  module Targets
    class Base < Thor
      include Thor::Actions
      include MonkeyButler::Actions
      add_runtime_options!

      class << self
        def source_root
          File.join File.dirname(__FILE__), name
        end

        def name
          "#{self}".split('::').last.gsub(/Target$/, '').downcase
        end

        def register_with_cli(cli)
          # Allows targets a chance to configure the CLI
          # This is an ideal place to register any options, tweak description, etc.
        end
      end

      attr_reader :project, :database, :migrations

      # Target Command

      desc "init", "Initializes the target."
      def init
        # Default implementation does nothing
      end

      desc "new NAME", "Create a new migration"
      def new(path)
        # Default implementation does nothing
      end

      desc "generate", "Generates a platform specific package."
      def generate
        # Default implementation does nothing
      end

      desc "push", "Pushes a built package."
      def push
        # Default implementation does nothing
      end

      desc "push", "Validates the environment."
      def validate
        # Default implementation does nothing
      end

      desc "dump", "Dumps the schema"
      def dump
        # Default implementation does nothing
      end

      desc "load", "Loads the schema"
      def load
        # Default implementation does nothing
      end
      
      desc "drop", "Drops all tables and records"
      def drop
        # Default implementation does nothing
      end

      protected
      def project
        @project ||= MonkeyButler::Project.load(destination_root)
      end

      def database
        @database ||= project.database_class.new(database_url)
      end

      def database_url
        (options[:database] && URI(options[:database])) || project.database_url
      end

      def migrations
        @migrations ||= MonkeyButler::Migrations.new(project.migrations_path, database)
      end
    end
  end
end
