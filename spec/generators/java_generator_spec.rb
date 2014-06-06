require 'spec_helper'
require 'monkey_butler/generators/java/java_generator'

describe MonkeyButler::Generators::JavaGenerator do
  let(:thor_class) { MonkeyButler::Generators::JavaGenerator }
  let!(:project_root) { clone_temp_sandbox }

  describe '#generate' do
    before(:each) do
      puts "Working in directory: #{project_root}"
      invoke!(['generate'])
    end

    it "should have a project/build.gradle file" do
      expect(File.directory?(File.join(project_root, 'project'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/build.gradle'))).to eq(true)
    end

    it "should have a schema file in resources/resources/schema" do
      expect(File.directory?(File.join(project_root, 'project/src/main/resources/resources/schema'))).to eq(true)
      expect(File.file?(File.join(project_root, 'project/src/main/resources/resources/schema/mb_schema.sql'))).to eq(true)
    end

    it "should have migration files in resources/resources/migrations" do
      expect(File.directory?(File.join(project_root, 'project/src/main/resources/resources/migrations'))).to eq(true)
      expect(Dir.entries(File.join(project_root, 'project/src/main/resources/resources/migrations')).size).not_to eq(2)
    end

    it "should have project/build/libs/monkeybutler.jar, monkeybutler-javadoc.jar files" do
      expect(File.file?(File.join(project_root, 'project/build/libs/monkeybutler-0.0.1.jar'))).to eq(true)
    end
  end

end
