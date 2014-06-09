require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class JavaGenerator < MonkeyButler::Generators::Base
      def copy_project
        # Copy Android project
        FileUtils.mkdir_p "project"
        FileUtils.cp_r File.join(File.dirname(__FILE__), "project"), "."
      end

      def copy_sql
        # Clear, Create and Populate schema and migrations directories
        FileUtils.rm_rf "project/src/main/resources/resources/schema"
        FileUtils.rm_rf "project/src/main/resources/resources/migrations"
        FileUtils.mkdir_p "project/src/main/resources/resources/schema/"
        FileUtils.mkdir_p "project/src/main/resources/resources/migrations/"
        FileUtils.cp_r project.schema_path, "project/src/main/resources/resources/schema/mb_schema.sql"
        FileUtils.cp_r project.migrations_path, "project/src/main/resources/resources/"
      end

      def build_project
        # Build
        Dir.chdir("project") do
          `gradle clean build jar`
        end        
      end

      def generate
        copy_project()
        copy_sql()
        build_project()
      end

      def push
        # Build
        Dir.chdir("project") do
          `gradle -Pusername=admin -Ppassword=admin123 clean bumpVersion build jar publish`
        end        
      end
    end
  end
end
