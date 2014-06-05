require 'spec_helper'
require 'monkey_butler/generators/cocoapods/cocoapods_generator'

module Pod
  class Spec
    attr_accessor :name, :version, :summary, :homepage, :author, :source, :license, :resource_bundles

    def initialize(hash = {})
      yield self if block_given?
    end
  end
end

describe MonkeyButler::Generators::CocoapodsGenerator do
  let(:thor_class) { MonkeyButler::Generators::CocoapodsGenerator }
  let!(:project_root) { clone_temp_sandbox }

  before(:each) do
    Dir.chdir(project_root) do
      system("git config user.email developer@layer.com")
      system("git config user.name 'Layer Developer'")
    end
  end

  describe "#init" do
    it "asks for the name of the cocoapods repository" do
      remove_cocoapods_repo_from_config
      expect(Thor::LineEditor).to receive(:readline).with("What is the name of your Cocoapods specs repo?  ", {}).and_return("layerhq")
      invoke!(['init'])
    end
  end

  describe '#generate' do
    let!(:podspec) do
      invoke!(['generate'])
      eval(File.read(File.join(project_root, 'sandbox.podspec')))
    end

    it "has name" do
      expect(podspec.name).to eq('sandbox')
    end

    it "has version" do
      expect(podspec.version).to eq('201405233443021')
    end

    it "has summary" do
      expect(podspec.summary).to eq('Packages the database schema and migrations for sandbox')
    end

    it "has homepage" do
      expect(podspec.homepage).to eq('')
    end

    it "has author" do
      expect(podspec.author).to eq({"Layer Developer"=>"developer@layer.com"})
    end

    it "has source" do
      expect(podspec.source).to eq({:git=>"git@github.com:layerhq/monkey_butler_sandbox.git", :tag=>"201405233443021"})
    end

    it "has license" do
      expect(podspec.license).to eq('Commercial')
    end

    it "has resource_bundles" do
      expect(podspec.resource_bundles).to eq({"MonkeyButler"=>["migrations/*", "sandbox.sql"]})
    end
  end

  describe "#push" do
    context "when cocoapods.repo is not configured" do
      it "fails with an error" do
        remove_cocoapods_repo_from_config
        output = invoke!(['push'])
        output[:stderr].should =~ /Cannot push to CocoaPods: cocoapods.repo is not configured./
      end
    end

    context "when cocoapods.repo is configured" do
      it "invokes pod push" do
        output = invoke!(['push', '--pretend'])
        output[:stdout].should =~ /run  pod repo push example_specs_repo sandbox.podspec/
      end
    end
  end

  def remove_cocoapods_repo_from_config
    yaml_path = File.join(project_root, '.monkey_butler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'cocoapods.repo'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end
end
