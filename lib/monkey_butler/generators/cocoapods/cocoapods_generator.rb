require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class CocoapodsGenerator < MonkeyButler::Generators::Base
      def generate
        template('podspec.erb', "#{project.name}.podspec")
      end

      def push

      end
    end
  end
end
