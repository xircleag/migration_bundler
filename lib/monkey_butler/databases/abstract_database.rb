module MonkeyButler
  module Databases
    class AbstractDatabase
      class << self
        def migration_ext
          raise NotImplementedError, "Required method not implemented."
        end
      end

      def migrations_table?
        raise NotImplementedError, "Required method not implemented."
      end

      def origin_version
        raise NotImplementedError, "Required method not implemented."
      end

      def current_version
        raise NotImplementedError, "Required method not implemented."
      end

      def all_versions
        raise NotImplementedError, "Required method not implemented."
      end

      def insert_version(version)
        raise NotImplementedError, "Required method not implemented."
      end

      def execute_migration(content)
        raise NotImplementedError, "Required method not implemented."
      end

      def truncate
        raise NotImplementedError, "Required method not implemented."
      end

      attr_reader :url

      def initialize(url)
        @url = url
      end

      def to_s
        url.to_s
      end
    end
  end
end
