require 'bundler/setup'
Bundler.setup

require 'monkey_butler'

require 'tempfile'
require 'debugger'
Debugger.start

RSpec.configure do |config|
  config.before do
    ARGV.replace []
  end

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

  def source_root
    File.join(File.dirname(__FILE__), "fixtures")
  end

  def destination_root
    File.join(File.dirname(__FILE__), "sandbox")
  end

  def clone_temp_sandbox
    path = Dir.mktmpdir
    FileUtils.cp_r Dir.glob(destination_root + '/.'), path
    path
  end
end
