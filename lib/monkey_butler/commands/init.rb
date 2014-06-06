require 'monkey_butler/commands/base'
require 'monkey_butler/util'
require 'yaml'

module MonkeyButler
  module Commands
    class Init < Base
      argument :path, type: :string, desc: 'Location to initialize the repository into', required: true
      class_option :name, type: :string, aliases: '-n', desc: "Specify project name"
      class_option :generators, type: :array, aliases: '-g', default: [], desc: "Specify default code generators."
      class_option :bundler, type: :boolean, aliases: '-b', default: false, desc: "Use Bundler to import MonkeyButler into project."
      class_option :config, type: :hash, aliases: '-c', default: {}, desc: "Specify config variables."
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

      def init_generators
        MonkeyButler::Util.generator_classes_named(options[:generators]) do |generator_class|
          say "Initializing generator '#{generator_class.name}'..."
          invoke(generator_class, %w{init})
        end
        project.save!(destination_root) unless options['pretend']
        git_add '.monkey_butler.yml'
      end

      def generate_gemfile
        if options[:bundler]
          template('templates/Gemfile.erb', "Gemfile")
          git_add "Gemfile"
          bundle
          git_add "Gemfile.lock"
        end
      end

      def touch_database
        create_file(project.db_path)
        create_file(project.schema_path)
        git_add project.schema_path
      end

      def generate_initial_migration
        migration_name = MonkeyButler::Util.migration_named(project_name)
        empty_directory('migrations')
        template('templates/create_monkey_butler_tables.sql.erb', "migrations/#{migration_name}")
        git_add "migrations/#{migration_name}"
      end

      protected
      def bundle
        run "bundle"
      end

      def project_name
        options[:name] || File.basename(path)
      end

      def project
        @project ||= MonkeyButler::Project.new(sanitized_options)
      end

      def sanitized_options
        ignored_keys = %w{bundler pretend}
        options.reject { |k,v| ignored_keys.include?(k) }.merge('name' => project_name)
      end
    end
  end
end
