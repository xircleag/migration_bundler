module MigrationBundler
  class Migrations
    attr_reader :path, :database

    def initialize(path, database)
      @path = path
      @database = database
      migration_paths = Dir.glob(File.join(path, "*#{database.class.migration_ext}"))
      @paths_by_version = MigrationBundler::Util.migrations_by_version(migration_paths)
    end

    def current_version
      database.migrations_table? ? database.current_version : nil
    end

    def all_versions
      @paths_by_version.keys
    end

    def latest_version
      all_versions.max
    end

    def applied_versions
      database.migrations_table? ? database.all_versions : []
    end

    def pending_versions
      (all_versions - applied_versions).sort
    end

    def pending(&block)
      pending_versions.inject({}) { |hash, v| hash[v] = self[v]; hash }.tap do |hash|
        hash.each(&block) if block_given?
      end
    end

    def all(&block)
      all_versions.inject({}) { |hash, v| hash[v] = self[v]; hash }.tap do |hash|
        hash.each(&block) if block_given?
      end
    end

    def up_to_date?
      pending_versions.empty?
    end

    def [](version)
      @paths_by_version[version]
    end
  end
end
