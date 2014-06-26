require 'spec_helper'
require 'monkey_butler/targets/sqlite/sqlite_target'
require 'monkey_butler/databases/sqlite_database'

describe MonkeyButler::Targets::SqliteTarget do
  let(:thor_class) { MonkeyButler::CLI }
  let!(:project_root) { clone_temp_sandbox }
  let(:project) { MonkeyButler::Project.load(project_root) }
  let(:schema_path) { File.join(project_root, project.schema_path) }
  let(:db_path) { File.join(project_root, 'sandbox.sqlite') }

  describe "#new" do
    it "generates a new migration with the given name" do
      invoke!(%w{new add_column_to_table})
      migration = Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /add_column_to_table\.sql/ }
      migration.should_not be_nil
    end
  end

  describe '#dump' do
    before(:each) do
      db = MonkeyButler::Databases::SqliteDatabase.new(URI(db_path))
      db.drop
      db.execute_migration MonkeyButler::Util.strip_leading_whitespace(
        <<-SQL
          #{MonkeyButler::Databases::SqliteDatabase.create_schema_migrations_sql}
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
      output = invoke!(%w{dump})
      dumped_schema.should =~ /CREATE TABLE schema_migrations/
      output[:stdout].should =~ /wrote table: schema_migrations/
      dumped_schema.should =~ /CREATE TABLE table1\(version INTEGER UNIQUE NOT NULL, name STRING NOT NULL\);/
      output[:stdout].should =~ /wrote table: table1/
      dumped_schema.should =~ /CREATE TABLE table2\(version INTEGER UNIQUE NOT NULL, name STRING NOT NULL\);/
      output[:stdout].should =~ /wrote table: table2/
    end

    it "dumps indexes" do
      output = invoke!(%w{dump})
      dumped_schema.should =~ /CREATE INDEX name1 ON table1\(name\);/
      output[:stdout].should =~ /wrote index: name1/
    end

    it "dumps triggers" do
      output = invoke!(%w{dump})
      dumped_schema.should =~ /CREATE TRIGGER kill_overlapping_names AFTER DELETE ON table1/
      output[:stdout].should =~ /wrote trigger: kill_overlapping_names/
    end

    it "dumps views" do
      output = invoke!(%w{dump})
      dumped_schema.should =~ /CREATE VIEW full_name AS SELECT table1.name || table2.name AS full_name FROM table1, table2;/
      output[:stdout].should =~ /wrote view: full_name/
    end

    it "dumps rows from schema_migrations" do
      output = invoke!(%w{dump})
      dumped_schema.should =~ /INSERT INTO schema_migrations \(version\) VALUES \(201405233443021\);/
      output[:stdout].should =~ /wrote 1 rows./
    end

    it "informs the user of completion" do
      output = invoke!(%w{dump})
      output[:stdout].should =~ /Dump complete. Schema written to sandbox\.sql/
    end

    context "when given a database parameter" do
      it "dumps the specified database" do
        output = invoke!(%W{dump -d #{db_path}})
        output[:stdout].should =~ /Dumping schema from database '#{db_path}'/
      end

      context "that does not exist" do
        it "fails with error" do
          output = invoke!(%w{dump -d /tmp/invalid_path})
          output[:stderr].should =~ /Cannot dump database: no file at path '\/tmp\/invalid_path'/
        end
      end
    end
  end

  describe "#drop" do
    it "truncates the database file" do
      File.open(db_path, 'w+') { |f| f << "test" }
      output = invoke!(%w{drop})
      File.size(db_path).should == 0
    end
  end
end
