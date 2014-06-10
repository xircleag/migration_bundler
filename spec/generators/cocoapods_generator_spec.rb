require 'spec_helper'
require 'monkey_butler/generators/cocoapods/cocoapods_generator'

module Pod
  class Spec
    attr_accessor :name, :version, :summary, :homepage, :author, :source, :license, :resource_bundles, :requires_arc

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
      expect(podspec.homepage).to eq('http://github.com/layerhq')
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
      expect(podspec.resource_bundles).to eq({"sandbox"=>["migrations/*", "sandbox.sql"]})
    end
  end

  describe "#push" do
    context "when cocoapods.repo is not configured" do
      it "fails with an error" do
        remove_cocoapods_repo_from_config
        output = invoke!(['push'])
        output[:stderr].should =~ /Invalid configuration: cocoapods.repo is not configured./
      end
    end

    context "when cocoapods.repo is configured" do
      it "invokes pod push" do
        output = invoke!(['push', '--pretend'])
        output[:stdout].should =~ /run\s+pod repo push --allow-warnings example_specs_repo sandbox.podspec/
      end
    end
  end

  describe "#validate" do
    context "when the cocoapods repo is not configured" do
      before(:each) do
        remove_cocoapods_repo_from_config
      end

      it "fails with error" do
        output = invoke!(['validate'])
        output[:stderr].should =~ /Invalid configuration: cocoapods.repo is not configured./
      end
    end
  end

  describe "#push" do
    context "when there is no repo configured" do
      before(:each) do
        remove_cocoapods_repo_from_config
      end

      it "fails validation" do
        output = invoke!(['push'])
        output[:stderr].should =~ /Invalid configuration: cocoapods.repo is not configured./
      end
    end

    context "when there is a repo configured" do
      def with_temporary_cocoapods_repo
        path = Dir.mktmpdir
        temp_specs_repo_at_path(File.join(path, 'master'))
        temp_specs_repo_at_path(File.join(path, 'example_specs_repo'))

        ENV['CP_REPOS_DIR'] = path
        yield path
        ENV.delete('CP_REPOS_DIR')
      end

      it "pushes to cocoapods" do
        git_repo_path = path_for_temp_bare_git_repo
        Dir.chdir(project_root) do
          `git remote set-url origin file://#{git_repo_path}`
        end

        # Generate the podspec
        invoke!(['generate'])

        Dir.chdir(project_root) do
          `git remote set-url origin file://#{git_repo_path}`
          `git add .`
          `git commit --no-status -m 'Adding files' .`
          `git tag 201405233443021`
          `git push -q origin master --tags`
        end

        with_temporary_cocoapods_repo do |repo_path|
          output = invoke!(%w{push --quiet})

          Dir.chdir(repo_path) do
            pushed_podspec_path = File.join(repo_path, 'example_specs_repo', 'sandbox', '201405233443021', 'sandbox.podspec')
            File.exists?(pushed_podspec_path).should be_true
            content = File.read(pushed_podspec_path)
            content.should =~ /201405233443021/
            content.should =~ /resource_bundles/
          end
        end
      end
    end
  end

  def remove_cocoapods_repo_from_config
    yaml_path = File.join(project_root, '.monkey_butler.yml')
    project = YAML.load(File.read(yaml_path))
    project['config'].delete 'cocoapods.repo'
    File.open(yaml_path, 'w') { |f| f << YAML.dump(project) }
  end

  def path_for_temp_bare_git_repo
    git_repo_path = Dir.mktmpdir
    Dir.chdir(git_repo_path) do
      `git init --bare`
    end
    git_repo_path
  end

  def temp_specs_repo_at_path(path)
    FileUtils.mkdir_p path
    Dir.chdir(path) do
      run("git init -q .")
      raise "Failed to init git repo" unless $?.exitstatus.zero?
      run("echo '' > README.md")
      run("git add README.md")
      run("git commit --no-status -m 'Add README.md' .")
      raise "Failed to touch README.md" unless $?.exitstatus.zero?
      remote_url = "file://#{path_for_temp_bare_git_repo}"
      run("git remote add origin #{remote_url}")
      raise "Failed to set origin remote url" unless $?.exitstatus.zero?
      run("git push -q -u origin master")
      raise "Failed to push to temp repo" unless $?.exitstatus.zero?
    end
  end

  def run(command, echo = false)
    if echo
      puts "Executing `#{command}`"
      system(command)
    else
      `#{command}`
    end
  end
end
