require 'monkey_butler/commands/base'

module MonkeyButler
  module Commands
    class Init < Base
      argument :path, type: :string, desc: 'Location to initialize the repository into', required: true
      class_option :project_name, type: :string, desc: "Specify project name"
      desc 'Initializes a new repository into PATH'

      def create_repository
        if File.exists?(path)
          raise Error, "Cannot create repository: regular file exists at path '#{path}'" unless File.directory?(path)
          raise Error, "Cannot create repository into non-empty path '#{path}'" if File.directory?(path) && Dir.entries(path) != %w{. ..}
        end
        self.destination_root = File.expand_path(path)
        empty_directory('.')
        inside(destination_root) { git init: '-q' }
      end

      def generate_gitignore
        template('templates/gitignore.erb', ".gitignore")
        git_add '.gitignore'
      end

      def generate_config
        template('templates/monkey_butler.yml.erb', '.monkey_butler.yml')
        git_add '.monkey_butler.yml'
      end

      def touch_database
        database_file = "#{project_name}.sqlite"
        create_file(database_file)
      end

      def generate_initial_migration
        migration_timestamp = Time.now.strftime('%Y%m%d%M%S%3N')
        migration_name = [migration_timestamp, 'create', Thor::Util.snake_case(project_name) + '.sql'].join('_')
        empty_directory('migrations')
        template('templates/migration.sql.erb', "migrations/#{migration_name}")
        git_add "migrations/#{migration_name}"
      end

      protected
      def project_name
        options[:project_name] || File.basename(path)
      end
    end
  end
end
