require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class CocoapodsGenerator < MonkeyButler::Generators::Base
      def init
        unless project.config['cocoapods.repo']
          project.config['cocoapods.repo'] = ask("What is the name of your Cocoapods specs repo? ")
        end
        if options['bundler']
          append_to_file 'Gemfile', "gem 'cocoapods'\n"
        end
      end

      def generate
        invoke :validate
        template('podspec.erb', podspec_name)
      end

      def validate
        fail Error, "Invalid configuration: cocoapods.repo is not configured." unless cocoapods_repo
      end

      def push
        invoke :validate
        run "pod repo push #{options['quiet'] && '--silent '}--allow-warnings #{cocoapods_repo} #{podspec_name}"
      end

      private
      def cocoapods_repo
        project.config['cocoapods.repo']
      end

      def podspec_name
        "#{project.name}.podspec"
      end

      def pod_version
        unique_tag_for_version(migrations.latest_version)
      end
    end
  end
end
