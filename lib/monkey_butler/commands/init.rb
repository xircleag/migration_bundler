require 'monkey_butler/commands/base'
require 'monkey_butler/util'

module MonkeyButler
  module Commands
    class Init < Base
      argument :path, type: :string, desc: 'Location to initialize the repository into', required: true
      class_option :name, type: :string, aliases: '-n', desc: "Specify project name"
      class_option :generators, type: :array, aliases: '-g', default: [], desc: "Specify default code generators."
      class_option :config, type: :hash, aliases: '-c', default: {}, :required => true
      class_option :bundler, type: :boolean, aliases: '-b', default: false, desc: "Use Bundler to import MonkeyButler into project."
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
        create_file '.monkey_butler.yml', YAML.dump(sanitized_options)
        git_add '.monkey_butler.yml'
      end

      def generate_gemfile
        if options[:bundler]
          template('templates/Gemfile.erb', "Gemfile")
          git_add "Gemfile"
        end
      end

      def touch_database
        create_file("#{project_name}.sqlite")
        create_file("#{project_name}.sql")
      end

      def generate_initial_migration
        migration_name = MonkeyButler::Util.migration_named(project_name)
        empty_directory('migrations')
        template('templates/create_monkey_butler_tables.sql.erb', "migrations/#{migration_name}")
        git_add "migrations/#{migration_name}"
      end

      protected
      def project_name
        options[:name] || File.basename(path)
      end

      def sanitized_options
        ignored_keys = %w{bundler}
        options.reject { |k,v| ignored_keys.include?(k) }
      end
    end
  end
end
