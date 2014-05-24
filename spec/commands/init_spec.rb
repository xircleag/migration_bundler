require 'spec_helper'
require 'monkey_butler/commands/init'

describe MonkeyButler::Commands::Init do
  context 'when no PATH is given' do
    it "prints an argument error to stderr" do
      content = capture(:stderr) { MonkeyButler::Commands::Init.start }
      content.should =~ /No value provided for required arguments 'path'/
    end
  end

  context 'when the PATH given already exists' do
    context "and contains existing content" do
      it "aborts with an error" do
        Dir.mktmpdir do |path|
          File.open(File.join(path, 'sdasdasd'), 'w+')
          output = capture_output(proc { MonkeyButler::Commands::Init.start([path]) })
          output[:stderr].should =~ /Cannot create repository into non-empty path/
        end
      end
    end

    context "and is a regular file" do
      it "aborts with an error" do
        path = Tempfile.new('monkey_butler').path
        output = capture_output(proc { MonkeyButler::Commands::Init.start([path]) })
        output[:stderr].should =~ /Cannot create repository: regular file exists at path/
      end
    end

    context "and is empty" do
      it "reports the path already exists" do
        Dir.mktmpdir do |path|
          output = capture_output(proc { MonkeyButler::Commands::Init.start([path]) })
          output[:stderr].should be_empty
          output[:stdout].should =~ /exist\s+$/
        end
      end
    end
  end

  context 'when the PATH given does not exist' do
    before(:each) do
      @path = Dir.mktmpdir
      FileUtils.remove_entry @path
    end

    def invoke!(args = [@path])
      capture_output(proc { MonkeyButler::Commands::Init.start(args) })
    end

    it "creates the path" do
      output = invoke!
      output[:stderr].should be_empty
      output[:stdout].should =~ /create\s+$/
      File.exists?(@path).should be_true
      File.directory?(@path).should be_true
    end

    it "populates .gitignore" do
      invoke!([@path, '--project-name=MonkeyButler'])
      path = File.join(@path, '.gitignore')
      expect(File.exists?(@path)).to be_true
      content = File.read(path)
      content.should include('.DS_Store')
      content.should =~ /^MonkeyButler.db$/
    end

    describe '.monkey_butler.yml' do
      before(:each) do
        invoke!([@path, '--project-name=MonkeyButler'])
        @yaml_path = File.join(@path, '.monkey_butler.yml')
      end

      it "is created" do
        expect(File.exists?(@yaml_path)).to be_true
      end

      it "is valid YAML" do
        expect { YAML.load(File.read(@yaml_path)) }.not_to raise_error
      end

      it "configures the project name" do
        config = YAML.load(File.read(@yaml_path))
        config['project_name'].should == 'MonkeyButler'
      end
    end

    it "creates an empty database" do
      invoke!([@path, '--project-name=MonkeyButler'])
      path = File.join(@path, 'MonkeyButler.db')
      expect(File.exists?(@path)).to be_true
    end

    it "creates an empty schema" do
      invoke!([@path, '--project-name=MonkeyButler'])
      path = File.join(@path, 'MonkeyButler.sql')
      expect(File.exists?(@path)).to be_true
    end

    it "generates an initial migration" do
      invoke!([@path, '--project-name=MonkeyButler'])
      filename = Dir.entries(File.join(@path, 'migrations')).detect { |f| f =~ /create_monkey_butler.sql$/ }
      expect(filename).not_to be_nil
      path = File.join(@path, 'migrations', filename)
      expect(File.exists?(path)).to be_true
    end

    pending "initializes a Git repository at the destination path" do
      # puts invoke!.inspect
      # repo = Rugged::Repository.new(@path)
      # expect(repo.empty?).to be_true
      # repo.index.entries.should_not == %w{}
    end
  end
end
