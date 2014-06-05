module MonkeyButler
  class Project
    def self.load(path = Dir.pwd)
      config_path = File.join(path, '.monkey_butler.yml')
      raise "fatal: Not a monkey_butler repository: no .monkey_butler.yml" unless File.exists?(config_path)
      options = YAML.load(File.read(config_path))
      new(options)
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
  end
end
