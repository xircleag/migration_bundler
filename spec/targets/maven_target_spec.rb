require 'spec_helper'
require 'migration_bundler/targets/base'
require 'migration_bundler/targets/maven/maven_target'

describe MigrationBundler::Targets::MavenTarget do
  let(:thor_class) { MigrationBundler::Targets::MavenTarget }
  let!(:project_root) { clone_temp_sandbox }

  describe "#init" do
    it "asks for Maven Java repository URL and credentials" do
      remove_maven_repo_from_config
      remove_maven_username_from_config
      remove_maven_password_from_config
      expect(Thor::LineEditor).to receive(:readline).with("What is the URL of your Java Maven repo?  ", {}).and_return(File.join(project_root, "maven"))
      expect(Thor::LineEditor).to receive(:readline).with("What is the username for your Java Maven repo?  ", {}).and_return("none")
      expect(Thor::LineEditor).to receive(:readline).with("What is the password for your Java Maven repo?  ", {}).and_return("none")
      invoke!(['init'])
    end
  end

  describe '#generate' do
    before(:all) do
      # Put config into the YAML
      yaml_path = File.join(project_root, '.migration_bundler.yml')
      project = YAML.load(File.read(yaml_path))
      project['config']['maven.url'] = 'maven'
      project['config']['maven.username'] = 'none'
      project['config']['maven.password'] = 'none'
      File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }

      invoke!(['generate', '--quiet'])
    end

    # Shadow the let! declarations so we can use before(:all)
    def thor_class
      MigrationBundler::Targets::MavenTarget
    end

    def project_root
      @project_root ||= clone_temp_sandbox
    end

    it "should have project/build.gradle" do
      expect(File.directory?(File.join(project_root, 'project'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/build.gradle'))).to eq(true)
    end

    it "should have a schema file in resources/schema" do
      expect(File.directory?(File.join(project_root, 'project/src/main/resources/schema'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/src/main/resources/schema/schema.sql'))).to eq(true)
    end

    it "should have migration files in resources/migrations" do
      expect(File.directory?(File.join(project_root, 'project/src/main/resources/migrations'))).to eq(true)
      expect(Dir.entries(File.join(project_root, 'project/src/main/resources/migrations')).size).not_to eq(2)
    end

    it "should have project/build/libs/MigrationBundler-[version].jar files" do
      expect(File.file?(built_jar_path)).to eq(true)
    end

    it "should have a schema packaged in the JAR" do
      jar_schema = `jar tf #{built_jar_path} | grep -e schema/.*[.]sql`.strip
      expect(jar_schema).to eq("schema/schema.sql")
    end

    it "should have all migrations packaged in the JAR" do
      # Create a hash of all expected migrations
      expected_migrations = Hash.new
      Dir.foreach(File.join(project_root, "migrations")) do |entry|
        if !entry.end_with? ".sql" then
          next
        end
        expected_migrations[entry] = true
      end

      # Create a array of all migrations packaged in the JAR
      jar_migrations = `jar tf #{built_jar_path} | grep -e migrations/.*[.]sql`
      jar_migration_array = jar_migrations.split(/\r?\n/)

      # Verify that the expected and actual have the same size
      expect(jar_migration_array.length).to eq(expected_migrations.length)

      # Verify that all JAR'd migrations were expected
      jar_migration_array.each { |jar_migration|
        length = jar_migration.length - "migrations/".length
        migration = jar_migration[-length, length]
        expect(expected_migrations[migration]).to eq(true)
      }
    end

    it "should clear java project between `generate` invocations" do
      # Create a random file in the project directory.
      yaml_path = File.join(project_root, '.migration_bundler.yml')
      project = YAML.load(File.read(yaml_path))
      File.open(File.join(project_root, 'project/deleteme.txt'), 'w') { |f| f << YAML.dump(project) }
      expect(File.file?(File.join(project_root, 'project/deleteme.txt'))).to eq(true)
      invoke!(['generate', '--quiet'])
      expect(File.file?(File.join(project_root, 'project/deleteme.txt'))).to eq(false)
    end
  end

  describe '#push' do
    before(:each) do
      set_config
      invoke!(%w{generate --quiet})
      invoke!(%w{push --quiet})
    end

    it "should have MigrationBundler-[version].jar file in the local Maven" do
      expect(File.file?(maven_jar_path)).to eq(true)
    end
  end

  private

  def remove_maven_repo_from_config
    yaml_path = File.join(project_root, '.migration_bundler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'maven.url'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def remove_maven_username_from_config
    yaml_path = File.join(project_root, '.migration_bundler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'maven.username'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def remove_maven_password_from_config
    yaml_path = File.join(project_root, '.migration_bundler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'maven.password'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def set_config
    remove_maven_repo_from_config
    remove_maven_username_from_config
    remove_maven_password_from_config
    expect(Thor::LineEditor).to receive(:readline).with("What is the URL of your Java Maven repo?  ", {}).and_return(File.join(project_root, "maven"))
    expect(Thor::LineEditor).to receive(:readline).with("What is the username for your Java Maven repo?  ", {}).and_return("none")
    expect(Thor::LineEditor).to receive(:readline).with("What is the password for your Java Maven repo?  ", {}).and_return("none")
    invoke!(['init'])
  end

  def maven_jar_path
    File.join(project_root, "maven/com/layer/MigrationBundler/20140523123443021/MigrationBundler-20140523123443021.jar")
  end

  def built_jar_path
    File.join(project_root, "project/build/libs/MigrationBundler-20140523123443021.jar")
  end

end
