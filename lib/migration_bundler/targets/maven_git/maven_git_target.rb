require 'migration_bundler/targets/base'

module MigrationBundler
  module Targets
    class MavenGitTarget < MigrationBundler::Targets::Base
      def self.name
        'maven_git'
      end

      def init
        unless project.config['maven_git.repo.name']
          project.config['maven_git.repo.name'] = ask("What is the name of your Maven Github repo? ")
        end
        unless project.config['maven_git.org.name']
          project.config['maven_git.org.name'] = ask("What is the name of your Github Organization? ")
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
        run "cd project && gradle#{options['quiet'] && ' -q '} -Pversion=#{version} -PgitRepoHome='' -Prepo=#{maven_git_repo_name} -Porg=#{maven_git_org_name} clean jar"
      end

      def validate
        fail Error, "Invalid configuration: maven_git.repo.name is not configured." unless maven_git_repo_name
        fail Error, "Invalid configuration: maven_git.org.name is not configured." unless maven_git_org_name
      end

      def push
        invoke :validate
        version = project.git_latest_tag
        Dir.mktmpdir do |temp_dir_path|
          run "cd project && gradle#{options['quiet'] && ' -q'} -Pversion=#{version} -PgitRepoHome=#{temp_dir_path} -Prepo=#{maven_git_repo_name} -Porg=#{maven_git_org_name} publishToGithub"
        end
      end

      private

      def maven_git_repo_name
        project.config['maven_git.repo.name']
      end

      def maven_git_org_name
        project.config['maven_git.org.name']
      end
    end
  end
end
