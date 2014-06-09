module MonkeyButler
  class Project
    class << self
      def load(path = Dir.pwd)
        @project ||= proc do
          project_path = File.join(path, '.monkey_butler.yml')
          raise "fatal: Not a monkey_butler repository: no .monkey_butler.yml" unless File.exists?(project_path)
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

    attr_accessor :name, :config, :generators

    def initialize(options = {})
      options.each { |k,v| send("#{k}=", v) }
    end

    def db_path
      "#{name}.sqlite"
    end

    def schema_path
      "#{name}.sql"
    end

    def migrations_path
      "migrations"
    end

    def git_url
      @git_url ||= `git config remote.origin.url`.chomp
    end

    def git_latest_tag
      git_tag_for_version(nil)
    end

    def git_tag_for_version(version)
      pattern = version && "#{version}*"
      tag = `git tag -l --sort=-v:refname #{pattern} | head -n 1`.chomp
      tag.empty? ? nil : tag
    end

    def save!(path)
      project_path = File.join(path, '.monkey_butler.yml')
      File.open(project_path, 'w') { |f| f << YAML.dump(self.to_hash) }
    end

    def to_hash
      { "name" => name, "config" => config, "generators" => generators }
    end
  end
end
