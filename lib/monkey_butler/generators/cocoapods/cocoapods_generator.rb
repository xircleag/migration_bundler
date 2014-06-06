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
        template('podspec.erb', podspec_name)
      end

      def push
        cocoapods_repo = project.config['cocoapods.repo']
        fail Error, "Cannot push to CocoaPods: cocoapods.repo is not configured." if cocoapods_repo.nil?
        run "pod repo push #{cocoapods_repo} #{podspec_name}"
      end

      private
      def podspec_name
        "#{project.name}.podspec"
      end
    end
  end
end
