module MonkeyButler
  module Generators
    class Base < Thor
      include Thor::Actions
      include MonkeyButler::Actions
      add_runtime_options!

      class << self
        def source_root
          File.join File.dirname(__FILE__), name
        end

        def name
          "#{self}".split('::').last.gsub(/Generator$/, '').downcase
        end
      end

      desc "init", "Initializes the generator."
      def init
        # Default implementation does nothing
      end

      desc "generate", "Generates a platform specific package."
      def generate
        raise "Generators must provide an implementation of :generate"
      end

      desc "push", "Pushes a built package."
      def push
        # Default implementation does nothing
      end

      protected
      def project
        @project ||= MonkeyButler::Project.load(destination_root)
      end

      def database
        @db ||= MonkeyButler::Database.new(options[:database] || project.db_path)
      end

      def migrations
        @migrations ||= MonkeyButler::Migrations.new(project.migrations_path, database)
      end

      def git_user_email
        `git config user.email`.chomp
      end

      def git_user_name
        `git config user.name`.chomp
      end
    end
  end
end
