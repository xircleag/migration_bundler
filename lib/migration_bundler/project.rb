require 'yaml'
require 'uri'

module MigrationBundler
  class Project
    class << self
      def load(path = Dir.pwd)
        @project ||= proc do
          project_path = File.join(path, '.migration_bundler.yml')
          raise "fatal: Not a migration_bundler repository: no .migration_bundler.yml" unless File.exists?(project_path)
          options = YAML.load(File.read(project_path))
          new(options)
        end.call
      end

      def set(options)
        @project = new(options)
      end

      def clear
        @project = nil
      end
    end

    attr_accessor :name, :config, :database_url, :targets

    def initialize(options = {})
      options.each { |k,v| send("#{k}=", v) }
    end

    def database_url=(database_url)
      @database_url = database_url ? URI(database_url) : nil
    end

    def database
      database_url.scheme || 'sqlite'
    end

    def schema_path
      "#{name}" + database_class.migration_ext
    end

    def migrations_path
      "migrations"
    end

    def git_url
      `git config remote.origin.url`.chomp
    end

    def git_latest_tag
      git_tag_for_version(nil)
    end
    
    def git_current_branch
      `git symbolic-ref --short HEAD`.chomp
    end

    def git_tag_for_version(version)
      pattern = version && "#{version}*"
      tag = `git tag -l --sort=-v:refname #{pattern} | head -n 1`.chomp
      tag.empty? ? nil : tag
    end

    def git_user_email
      `git config user.email`.chomp
    end

    def git_user_name
      `git config user.name`.chomp
    end

    def save!(path)
      project_path = File.join(path, '.migration_bundler.yml')
      File.open(project_path, 'w') { |f| f << YAML.dump(self.to_hash) }
    end

    def database_class
      MigrationBundler::Util.database_named(database)
    end

    def database_target_class
      MigrationBundler::Util.target_classes_named(database)[0]
    end

    def to_hash
      { "name" => name, "config" => config, "database_url" => database_url.to_s, "targets" => targets }
    end
  end
end
