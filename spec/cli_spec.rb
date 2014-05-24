require 'spec_helper'

describe MonkeyButler::CLI do
  let!(:project_root) { clone_temp_sandbox }
  let(:config) { MonkeyButler::Config.load(project_root) }

  def invoke!(args, options = {:capture => true})
    output = nil
    Dir.chdir(project_root) do
      if options[:capture]
        output = capture_output(proc { MonkeyButler::CLI.start(args) })
      else
        MonkeyButler::CLI.start(args)
      end
    end
  end

  describe '#load' do
    let(:schema_path) { File.join(project_root, config.schema_path) }

    context "when the schema is empty" do
      before(:each) do
        File.truncate(schema_path, 0)
      end

      it "fails with an error" do
        output = invoke!(%w{load})
        output[:stderr].should =~ /Cannot load database: empty schema found at/
      end
    end

    context "when the schema contains invalid SQL" do
      before(:each) do
        @timestamp = MonkeyButler::Util.migration_timestamp
        sql = <<-SQL
        CREATE TABLE this_is_invalid;
        SQL
        File.open(schema_path, 'w+') do |f|
          f << MonkeyButler::Util.strip_leading_whitespace(sql)
        end
      end

      it "fails with an error" do
        output = invoke!(%w{load})
        output[:stderr].should =~ /Failed loading schema: Error: near line 1: near ";": syntax error/
      end
    end

    context "when the schema is populated" do
      before(:each) do
        @timestamp = MonkeyButler::Util.migration_timestamp
        sql = <<-SQL
        #{MonkeyButler::Database.create_schema_migrations_sql}
        INSERT INTO schema_migrations(version) VALUES ('#{@timestamp}');
        SQL
        File.open(schema_path, 'w+') do |f|
          f << MonkeyButler::Util.strip_leading_whitespace(sql)
        end
      end

      it "loads without error" do
        output = invoke!(%w{load})
        output[:stdout].should =~ /executing  sqlite3 sandbox.db < sandbox.sql/
        output[:stderr].should be_empty
      end

      it "reports the current version of the database" do
        output = invoke!(%w{load})
        output[:stdout].should =~ /Loaded schema at version #{@timestamp}/
      end
    end
  end
end
