require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class CocoapodsGenerator < MonkeyButler::Generators::Base
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
