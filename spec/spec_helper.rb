require 'bundler/setup'
Bundler.setup

require 'migration_bundler'

require 'rspec/core/shared_context'
require 'tempfile'
require 'digest'
require 'byebug'

module GlobalContext
  extend RSpec::Core::SharedContext

  # Assume that most specs will describe a Thor subclass
  let(:thor_class) { subject.class }
end

RSpec.configure do |config|
  config.before do
    ARGV.replace []
    MigrationBundler::Project.clear
  end

  config.include GlobalContext

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  def capture_output(proc, &block)
    error = nil
    content = capture(:stdout) do
      error = capture(:stderr) do
        proc.call
      end
    end
    yield content, error if block_given?
    { stdout: content, stderr: error }
  end

  # def source_root
  #   File.join(File.dirname(__FILE__), "fixtures")
  # end

  def sandbox_root
    Pathname.new File.join(File.dirname(__FILE__), "sandbox")
  end

  def clone_temp_sandbox(database = :sqlite)
    Dir.mktmpdir.tap do |path|
      FileUtils.cp_r Dir.glob(sandbox_root + "#{database}/."), path
      Dir.chdir(path) do
        system("git init -q .")
        system("git remote add origin git@github.com:layerhq/migration_bundler_sandbox.git")
      end
    end
  end

  def random_migration_name
    timestamp = MigrationBundler::Util.migration_timestamp + rand(1..1000)
    MigrationBundler::Util.migration_named(Digest::SHA256.hexdigest(Time.now.to_s), timestamp)
  end

  # Requires `thor_class` and `project_root`
  def invoke!(args = [], options = {:capture => true})
    output = nil
    # Some commands work with a directory that doesn't yet exist
    dir = File.exists?(project_root) ? project_root : '.'
    Dir.chdir(dir) do
      if options[:capture]
        output = capture_output(proc { thor_class.start(args) })
      else
        thor_class.start(args)
      end
    end
  end

  def invoke_target!(command, options = {})
    output = nil
    # Some commands work with a directory that doesn't yet exist
    dir = File.exists?(project_root) ? project_root : '.'
    Dir.chdir(dir) do
      if options.delete(:capture)
        output = capture_output proc do
          target = thor_class.new([], options)
          target.invoke(command)
        end
      else
        target = thor_class.new([], options)
        target.invoke(command)
      end
    end
  end
end
