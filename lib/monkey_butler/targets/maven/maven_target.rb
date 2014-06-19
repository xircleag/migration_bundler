require 'monkey_butler/targets/base'

module MonkeyButler
  module Targets
    class MavenTarget < MonkeyButler::Targets::Base
      def init
        unless project.config['maven.url']
          project.config['maven.url'] = ask("What is the URL of your Java Maven repo? ")
        end
        unless project.config['maven.username']
          project.config['maven.username'] = ask("What is the username for your Java Maven repo? ")
        end
        unless project.config['maven.password']
          project.config['maven.password'] = ask("What is the password for your Java Maven repo? ")
        end
      end

      def generate
        invoke :validate
        remove_file "project"
        empty_directory "project"
        empty_directory "project/src"
        empty_directory "project/src/main"
        empty_directory "project/src/main/resources"
        empty_directory "project/src/main/resources/schema"

        copy_file "project/build.gradle", "project/build.gradle"
        FileUtils.cp_r project.schema_path, "project/src/main/resources/schema/schema.sql"
        FileUtils.cp_r project.migrations_path, "project/src/main/resources"

        version = unique_tag_for_version(migrations.latest_version)
        run "cd project && gradle#{options['quiet'] && ' -q '} -Pversion=#{version} clean jar"
      end

      def validate
        fail Error, "Invalid configuration: maven.repo is not configured." unless maven_url
        fail Error, "Invalid configuration: maven.username is not configured." unless maven_username
        fail Error, "Invalid configuration: maven.password is not configured." unless maven_password
      end

      def push
        invoke :validate
        version = project.git_latest_tag
        run "cd project && gradle#{options['quiet'] && ' -q'} -Pversion=#{version} -Purl=#{maven_url} -Pusername=#{maven_username} -Ppassword=#{maven_password} publish"
      end

      private

      def maven_url
        project.config['maven.url']
      end

      def maven_username
        project.config['maven.username']
      end

      def maven_password
        project.config['maven.password']
      end
    end
  end
end
