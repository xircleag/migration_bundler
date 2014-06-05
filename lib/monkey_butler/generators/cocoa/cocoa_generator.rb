require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class CocoapodsGenerator < MonkeyButler::Generators::Base
      def generate_podspec
        template('podspec.erb', "#{project.name}.podspec")
      end
    end
  end
end
