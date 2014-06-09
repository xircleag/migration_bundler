require 'spec_helper'
require 'monkey_butler/generators/base'
require 'monkey_butler/generators/java/java_generator'

describe MonkeyButler::Generators::JavaGenerator do
  let(:thor_class) { MonkeyButler::Generators::JavaGenerator }
  let!(:project_root) { clone_temp_sandbox }

  describe "#init" do
    it "asks for Maven Java repository URL and credentials" do
      puts "Working in directory: #{project_root}\n"
      set_config
    end
  end

  describe '#generate' do
    before(:each) do
      puts "Working in directory: #{project_root}\n"
      set_config
      invoke!(['generate'])
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

    it "should have project/build/libs/monkeybutler-[version].jar files" do
      expect(File.file?(jar_path)).to eq(true)
    end

    it "should have a schema packaged in the JAR" do
      jar_schema = `jar tf #{jar_path} | grep -e schema/.*[.]sql`.strip
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
      jar_migrations = `jar tf #{jar_path} | grep -e migrations/.*[.]sql`
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
  end

  def remove_java_repo_from_config
    yaml_path = File.join(project_root, '.monkey_butler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'java.maven.url'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def remove_java_username_from_config
    yaml_path = File.join(project_root, '.monkey_butler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'java.maven.username'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def remove_java_password_from_config
    yaml_path = File.join(project_root, '.monkey_butler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'java.maven.password'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def set_config
    remove_java_repo_from_config
    remove_java_username_from_config
    remove_java_password_from_config
    expect(Thor::LineEditor).to receive(:readline).with("What is the URL of your Java Maven repo?  ", {}).and_return("maven")
    expect(Thor::LineEditor).to receive(:readline).with("What is the username for your Java Maven repo?  ", {}).and_return("none")
    expect(Thor::LineEditor).to receive(:readline).with("What is the password for your Java Maven repo?  ", {}).and_return("none")
    invoke!(['init'])
  end

  def jar_path
    return File.join(project_root, "project/build/libs/monkeybutler-201405233443021.jar")
  end

end
