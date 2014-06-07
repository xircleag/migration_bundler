require 'spec_helper'
require 'monkey_butler/generators/java/java_generator'

describe MonkeyButler::Generators::JavaGenerator do
  let(:thor_class) { MonkeyButler::Generators::JavaGenerator }
  let!(:project_root) { clone_temp_sandbox }

  def get_version
    Dir.chdir(File.join(project_root, 'project')) do
      return `cat version.gradle | grep -oe "['][^']*[']"`.strip.delete "'"
    end    
  end

  def get_jar_path
    return File.join(project_root, 'project/build/libs/monkeybutler-' + get_version + '.jar')
  end

  describe '#generate' do
    before(:each) do
      puts "Working in directory: #{project_root}\n"
      invoke!(['generate'])
    end

    it "should have project/build.gradle and version.gradle files" do
      expect(File.directory?(File.join(project_root, 'project'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/build.gradle'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/version.gradle'))).to eq(true)
    end

    it "should have a schema file in resources/resources/schema" do
      expect(File.directory?(File.join(project_root, 'project/src/main/resources/resources/schema'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/src/main/resources/resources/schema/mb_schema.sql'))).to eq(true)
    end

    it "should have migration files in resources/resources/migrations" do
      expect(File.directory?(File.join(project_root, 'project/src/main/resources/resources/migrations'))).to eq(true)
      expect(Dir.entries(File.join(project_root, 'project/src/main/resources/resources/migrations')).size).not_to eq(2)
    end

    it "should have project/build/libs/monkeybutler-[version].jar files" do
      expect(File.file?(get_jar_path)).to eq(true)
    end

    it "should have a schema packaged in the JAR" do
      jar_schema = `jar tf #{get_jar_path} | grep -e resources/schema/.*[.]sql`.strip
      expect(jar_schema).to eq("resources/schema/mb_schema.sql")
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
      jar_migrations = `jar tf #{get_jar_path} | grep -e resources/migrations/.*[.]sql`
      jar_migration_array = jar_migrations.split(/\r?\n/)

      # Verify that the expected and actual have the same size
      expect(jar_migration_array.length).to eq(expected_migrations.length)

      # Verify that all JAR'd migrations were expected
      jar_migration_array.each { |jar_migration|
        length = jar_migration.length - "resources/migrations/".length
        migration = jar_migration[-length, length]
        expect(expected_migrations[migration]).to eq(true)
      }
    end
  end
end
