module MonkeyButler
  class Util
    class << self
      def migration_timestamp
        Time.now.strftime('%Y%m%d%M%S%3N').to_i
      end

      def migration_named(name, timestamp = migration_timestamp)
        migration_name = [timestamp, 'create', Thor::Util.snake_case(name)].join('_')
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

      def camelize(term, uppercase_first_letter = true)
        string = term.to_s
        string = string.sub(/^[a-z\d]*/) { $&.capitalize }
        string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
        string.gsub!('/', '::')
        string
      end

      def database_named(name)
        raise ArgumentError, "Database name cannot be nil." if name.nil?
        require "monkey_butler/databases/#{name}_database"
        klass_name = "MonkeyButler::Databases::#{Util.camelize(name)}Database"
        Object.const_get(klass_name)
      end

      def target_classes_named(*names)
        raise ArgumentError, "Database name cannot be nil." if names.nil?
        names.flatten.map do |name|
          require "monkey_butler/targets/#{name}/#{name}_target"
          klass_name = "MonkeyButler::Targets::#{Util.camelize(name)}Target"
          Object.const_get(klass_name).tap do |klass|
            yield klass if block_given?
          end
        end
      end
    end
  end
end
