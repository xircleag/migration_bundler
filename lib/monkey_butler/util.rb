module MonkeyButler
  class Util
    class << self
      def migration_timestamp
        Time.now.strftime('%Y%m%d%M%S%3N').to_i
      end

      def migration_named(name)
        migration_name = [migration_timestamp, 'create', Thor::Util.snake_case(name) + '.sql'].join('_')
      end

      def strip_leading_whitespace(string)
        string.gsub(/^\s+/, '')
      end
    end
  end
end
