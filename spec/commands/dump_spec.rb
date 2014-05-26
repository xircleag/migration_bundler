require 'spec_helper'
require 'monkey_butler/commands/dump'

describe MonkeyButler::Commands::Dump do
  let!(:project_root) { clone_temp_sandbox }
  let(:config) { MonkeyButler::Config.load(project_root) }
  let(:schema_path) { File.join(project_root, config.schema_path) }
  let(:db_path) { File.join(project_root, config.db_path) }

  before(:each) do
    db = MonkeyButler::Database.new(db_path)
    db.execute_migration MonkeyButler::Util.strip_leading_whitespace(
      <<-SQL
        #{MonkeyButler::Database.create_schema_migrations_sql}
        CREATE TABLE table1(version INTEGER UNIQUE NOT NULL, name STRING NOT NULL);
        CREATE TABLE table2(version INTEGER UNIQUE NOT NULL, name STRING NOT NULL);
        CREATE INDEX name1 ON table1(name);
        CREATE VIEW full_name AS SELECT table1.name || table2.name AS full_name FROM table1, table2;
        CREATE TRIGGER kill_overlapping_names AFTER DELETE ON table1
        BEGIN
          DELETE FROM table2 WHERE name = OLD.name;
        END;
        INSERT INTO schema_migrations(version) VALUES (201405233443021)
      SQL
    )
  end

  let(:dumped_schema) { File.read(schema_path) }

  it "dumps tables" do
    output = invoke!([])
    dumped_schema.should =~ /CREATE TABLE schema_migrations/
    output[:stdout].should =~ /wrote table: schema_migrations/
    dumped_schema.should =~ /CREATE TABLE table1\(version INTEGER UNIQUE NOT NULL, name STRING NOT NULL\);/
    output[:stdout].should =~ /wrote table: table1/
    dumped_schema.should =~ /CREATE TABLE table2\(version INTEGER UNIQUE NOT NULL, name STRING NOT NULL\);/
    output[:stdout].should =~ /wrote table: table2/
  end

  it "dumps indexes" do
    output = invoke!([])
    dumped_schema.should =~ /CREATE INDEX name1 ON table1\(name\);/
    output[:stdout].should =~ /wrote index: name1/
  end

  it "dumps triggers" do
    output = invoke!([])
    dumped_schema.should =~ /CREATE TRIGGER kill_overlapping_names AFTER DELETE ON table1/
    output[:stdout].should =~ /wrote trigger: kill_overlapping_names/
  end

  it "dumps views" do
    output = invoke!([])
    dumped_schema.should =~ /CREATE VIEW full_name AS SELECT table1.name || table2.name AS full_name FROM table1, table2;/
    output[:stdout].should =~ /wrote trigger: full_name/
  end

  it "dumps rows from schema_migrations" do
    output = invoke!([])
    dumped_schema.should =~ /INSERT INTO schema_migrations\(version\) VALUES \(201405233443021\);/
    output[:stdout].should =~ /wrote version: 201405233443021/
  end

  it "informs the user of completion" do
    output = invoke!([])
    output[:stdout].should =~ /Dump complete. Schema written to sandbox\.sql/
  end

  context "when given a database parameter" do
    it "dumps the specified database" do
      output = invoke!(%W{-d #{db_path}})
      output[:stdout].should =~ /Dumping schema from database '#{db_path}'/
    end

    context "that does not exist" do
      it "fails with error" do
        output = invoke!(%w{-d /tmp/invalid_path})
        output[:stderr].should =~ /Cannot dump database: no file at path '\/tmp\/invalid_path'/
      end
    end
  end
end
