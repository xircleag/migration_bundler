module MonkeyButler
  class Util
    class << self
      def migration_timestamp
        Time.now.strftime('%Y%m%d%M%S%3N').to_i
      end

      def migration_named(name, timestamp = migration_timestamp)
        migration_name = [timestamp, 'create', Thor::Util.snake_case(name) + '.sql'].join('_')
      end

      def strip_leading_whitespace(string)
        string.gsub(/^\s+/, '')
      end

      def migration_version_from_path(path)
        path.match(/(\d{15})_/)[1].to_i
      end

      def migration_versions_from_paths(paths)
        paths.map { |path| migration_version_from_path(path) }
      end

      def migrations_by_version(paths)
        paths.inject({}) do |hash, path|
          version = migration_version_from_path(path)
          hash[version] = path
          hash
        end
      end
    end
  end
end
