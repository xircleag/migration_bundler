require 'spec_helper'
require 'monkey_butler/targets/cassandra/cassandra_target'
require 'monkey_butler/databases/cassandra_database'

describe MonkeyButler::Targets::CassandraTarget do
  let(:thor_class) { MonkeyButler::CLI }
  let!(:project_root) { clone_temp_sandbox(:cassandra) }
  let(:project) { MonkeyButler::Project.load(project_root) }
  let(:database) { MonkeyButler::Databases::CassandraDatabase.new(project.database_url) }

  before(:each) do
    database.truncate
  end

  describe "#init" do
    let(:path) do
      Dir.mktmpdir.tap { |path| FileUtils.remove_entry(path) }
    end

    it "generates a new migration with the given name" do
      invoke!(["init", "-d", "cassandra://localhost:9170/sandbox", path])
      migration = Dir.entries(File.join(path, 'migrations')).detect { |f| f =~ /\d{15}_create_.+\.cql/ }
      migration.should_not be_nil
    end
  end

  describe "#new" do
    it "generates a new migration with the given name" do
      invoke!(%w{new add_column_to_table})
      migration = Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /add_column_to_table\.cql/ }
      migration.should_not be_nil
    end
  end

  describe "#dump" do
    before(:each) do
      database = MonkeyButler::Databases::CassandraDatabase.new(project.database_url)
      database.create_migrations_table
      database.insert_version(123)
    end

    it "dumps the database" do
      invoke!(%w{dump})
      content = File.read(File.join(project_root, project.schema_path))
      content.should =~ /CREATE KEYSPACE sandbox/
    end

    it "dumps the schema_migrations rows" do
      invoke!(%w{dump})
      content = File.read(File.join(project_root, project.schema_path))
      content.should =~ /INSERT INTO schema_migrations\(partition_key, version\) VALUES \(0, 123\);/
    end
  end

  describe "#load" do
    before(:each) do
      @database = MonkeyButler::Databases::CassandraDatabase.new(project.database_url)
      @database.create_migrations_table
      invoke!(%w{dump})
      @database.truncate
    end

    it "loads the database" do
      expect(@database.migrations_table?).to be_false
      invoke!(%w{load})
      expect(@database.migrations_table?).to be_true
    end
  end

  describe "#status" do
    context "when the database is empty" do
      before(:each) do
        database.truncate
      end

      it "shows status" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /New database/
        output[:stdout].should =~ /The database at 'cassandra:\/\/localhost:9042\/sandbox' does not have a 'schema_migrations' table./
      end
    end

    context "when the database is up to date" do
      before(:each) do
        database.create_migrations_table
        database.insert_version(12345)
      end

      it "tells the user the database is up to date" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /Current version: 12345/
        output[:stdout].should =~ /Database is up to date./
      end
    end

    context "when there are migrations to apply" do
      before(:each) do
        File.open(File.join(project_root, 'migrations/201405233443021_add_another_table.cql'), 'w') do |f|
          f << "CREATE TABLE IF NOT EXISTS sandbox.another_table (some_column VARINT, PRIMARY KEY (some_column));"
        end
        database.create_migrations_table
        database.insert_version(12345)
      end

      it "tells the user there is a migration to apply" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /The database at 'cassandra:\/\/localhost:9042\/sandbox' is 1 version behind 201405233443021/
        output[:stdout].should =~ /pending migration: migrations\/201405233443021_add_another_table.cql/
      end
    end
  end

  describe "#migrate" do
    context "when the database is empty" do
      before(:each) do
        database.truncate
      end

      it "shows migrate" do
        output = invoke!(%w{migrate})
        output[:stdout].should =~ /Database is up to date./
      end
    end

    context "when the database is up to date" do
      before(:each) do
        database.create_migrations_table
        database.insert_version(12345)
      end

      it "tells the user the database is up to date" do
        output = invoke!(%w{migrate})
        output[:stdout].should =~ /Database is up to date./
      end
    end

    context "when there are migrations to apply" do
      before(:each) do
        File.open(File.join(project_root, 'migrations/201405233443021_add_another_table.cql'), 'w') do |f|
          f << "CREATE TABLE IF NOT EXISTS sandbox.another_table (some_column VARINT, PRIMARY KEY (some_column));"
        end
        database.create_migrations_table
        database.insert_version(12345)
      end

      it "tells the user there is a migration to apply" do
        output = invoke!(%w{migrate})
        output[:stdout].should =~ /applying migration: migrations\/201405233443021_add_another_table.cql/
        output[:stdout].should =~ /Migration to version 201405233443021 complete./
      end
    end
  end
end
