module MonkeyButler
  class Config
    def self.load(path = Dir.pwd)
      config_path = File.join(path, '.monkey_butler.yml')
      raise "fatal: Not a monkey_butler repository: no .monkey_butler.yml" unless File.exists?(config_path)
      options = YAML.load(File.read(config_path))
      new(options)
    end

    attr_accessor :project_name

    def initialize(options = {})
      options.each { |k,v| send("#{k}=", v) }
    end

    def db_path
      "#{project_name}.db"
    end

    def schema_path
      "#{project_name}.sql"
    end

    def migrations_path
      "migrations"
    end
  end
end
