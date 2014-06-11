require 'monkey_butler/generators/base'

module MonkeyButler
  module Generators
    class JavaGenerator < MonkeyButler::Generators::Base
      def init
        unless project.config['java.maven.url']
          project.config['java.maven.url'] = ask("What is the URL of your Java Maven repo? ")
        end
        unless project.config['java.maven.username']
          project.config['java.maven.username'] = ask("What is the username for your Java Maven repo? ")
        end
        unless project.config['java.maven.password']
          project.config['java.maven.password'] = ask("What is the password for your Java Maven repo? ")
        end
      end

      def generate
        invoke :validate
        empty_directory "project"
        empty_directory "project/src"
        empty_directory "project/src/main"
        empty_directory "project/src/main/resources"
        empty_directory "project/src/main/resources/schema"

        copy_file "project/build.gradle", "project/build.gradle"
        FileUtils.cp_r project.schema_path, "project/src/main/resources/schema/schema.sql"
        FileUtils.cp_r project.migrations_path, "project/src/main/resources"

        run "cd project && gradle#{options['quiet'] && ' -q '} -Pversion=#{migrations.latest_version} clean jar"
      end

      def validate
        fail Error, "Invalid configuration: java.repo is not configured." if java_url.nil?
        fail Error, "Invalid configuration: java.username is not configured." if java_username.nil?
        fail Error, "Invalid configuration: java.password is not configured." if java_password.nil?
      end

      def push
        invoke :validate
        run "cd project && gradle#{options['quiet'] && ' -q'} -Pversion=#{migrations.latest_version} -Purl=#{java_url} -Pusername=#{java_username} -Ppassword=#{java_password} publish"
      end

      private

      def java_url
        project.config['java.maven.url']
      end

      def java_username
        project.config['java.maven.username']
      end

      def java_password
        project.config['java.maven.password']
      end
    end
  end
end
