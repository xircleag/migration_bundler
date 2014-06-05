require 'spec_helper'
require 'monkey_butler/generators/java/java_generator'

describe MonkeyButler::Generators::JavaGenerator do
  let(:thor_class) { MonkeyButler::Generators::JavaGenerator }
  let!(:project_root) { clone_temp_sandbox }

  describe '#generate' do
    it "should have a `generate` method" do
      # Mostly here for project_root
      puts "Working in directory: #{project_root}"
      invoke!(['generate'])
    end

    it "should have a project/build.gradle file" do
      invoke!(['generate'])
      expect(File.directory?(File.join(project_root, 'project'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/build.gradle'))).to eq(true)
    end

    it "should have a schema file in assets/schema" do
      invoke!(['generate'])
      expect(File.directory?(File.join(project_root, 'project/monkeybutler/src/main/assets/schema'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/monkeybutler/src/main/assets/schema/schema_create.sql'))).to eq(true)
    end

    it "should have migration files in assets/migrations" do
      invoke!(['generate'])
      expect(File.directory?(File.join(project_root, 'project/monkeybutler/src/main/assets/migrations'))).to eq(true)
      expect(Dir.entries(File.join(project_root, 'project/monkeybutler/src/main/assets/migrations')).size).not_to eq(2)
    end
  end

end
