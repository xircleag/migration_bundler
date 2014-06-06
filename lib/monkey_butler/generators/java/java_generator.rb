require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class JavaGenerator < MonkeyButler::Generators::Base
      def clean
        Dir.chdir(File.join(File.dirname(__FILE__), "project")) do
          `gradle clean`
        end
      end

      def generate
        # Copy Android project
        FileUtils.mkdir_p "project"
        FileUtils.cp_r File.join(File.dirname(__FILE__), "project"), "."

        # Clear, Create and Populate schema and migrations directories
        FileUtils.rm_rf "project/monkeybutler/src/main/assets/schema"
        FileUtils.rm_rf "project/monkeybutler/src/main/assets/migrations"
        FileUtils.mkdir_p "project/monkeybutler/src/main/assets/schema/"
        FileUtils.mkdir_p "project/monkeybutler/src/main/assets/migrations/"
        FileUtils.cp_r project.schema_path, "project/monkeybutler/src/main/assets/schema/schema_create.sql"
        FileUtils.cp_r project.migrations_path, "project/monkeybutler/src/main/assets/"

        # Build
        Dir.chdir("project") do
          `gradle javadocRelease jarRelease`
        end
      end

      def push
      end
    end
  end
end
