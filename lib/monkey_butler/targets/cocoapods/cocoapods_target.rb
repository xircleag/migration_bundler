require 'monkey_butler/targets/base'

module MonkeyButler
  module Targets
    class CocoapodsTarget < MonkeyButler::Targets::Base
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
        fail Error, "Invalid configuration: cocoapods.repo is not configured." if cocoapods_repo.nil?
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
    end
  end
end
