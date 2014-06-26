require 'spec_helper'
require 'monkey_butler/databases/sqlite_database'

describe MonkeyButler::Databases::SqliteDatabase do
  it "has a SQL file extension" do
    MonkeyButler::Databases::SqliteDatabase.migration_ext.should == '.sql'
  end

  it "initializes with a URL" do
    path = Dir.mktmpdir + '/sandbox.sqlite'
    database = MonkeyButler::Databases::SqliteDatabase.new(URI("sqlite://#{path}"))
    database.path.should == path
  end

  it "stores url" do
    url = URI("sqlite://#{Dir.mktmpdir}/sandbox.sqlite")
    database = MonkeyButler::Databases::SqliteDatabase.new(url)
    database.url.should == url
  end

  it "uses path for to_s" do
    url = URI("sqlite://#{Dir.mktmpdir}/sandbox.sqlite")
    database = MonkeyButler::Databases::SqliteDatabase.new(url)
    database.to_s.should == url.path
  end

  context "when initialized with a relative path" do
    it "loads the relative path" do
      path = Dir.mktmpdir
      Dir.chdir(path) do
        database = MonkeyButler::Databases::SqliteDatabase.new(URI("sqlite:test.sqlite"))
        database.path.should == 'test.sqlite'
      end
    end
  end

  let(:db_path) { Tempfile.new('monkey_butler').path }
  let(:db) { MonkeyButler::Databases::SqliteDatabase.create(URI(db_path)) }

  describe '#origin_version' do
    context "when the schema_migrations table is empty" do
      it "returns nil" do
        db.origin_version.should be_nil
      end
    end

    context "when the schema_migrations table has a single row" do
      before(:each) do
        @version = MonkeyButler::Util.migration_timestamp
        db.insert_version(@version)
      end

      it "returns the value of the version column" do
        db.origin_version.should == @version
      end
    end

    context "when the schema_migrations table has many rows" do
      before(:each) do
        # Inject to guarantee mutation of the timestamp
        @versions = (1..5).inject([]) do |versions, i|
          version = MonkeyButler::Util.migration_timestamp + i
          db.insert_version(version)
          versions << version
        end
      end

      it "returns the lowest value" do
        db.origin_version.should == @versions.first
      end
    end
  end

  describe '#current_version' do
    context "when the schema_migrations table is empty" do
      it "returns nil" do
        db.current_version.should be_nil
      end
    end

    context "when the schema_migrations table has a single row" do
      before(:each) do
        @version = MonkeyButler::Util.migration_timestamp
        db.insert_version(@version)
      end

      it "returns the value of the version column" do
        db.current_version.should == @version
      end
    end

    context "when the schema_migrations table has many rows" do
      before(:each) do
        # Inject to guarantee mutation of the timestamp
        @versions = (1..5).inject([]) do |versions, i|
          version = MonkeyButler::Util.migration_timestamp + i
          db.insert_version(version)
          versions << version
        end
      end

      it "returns the highest value" do
        db.current_version.should == @versions.last
      end
    end
  end

  describe '#all_versions' do
    context "when the database is empty" do
      it "raises a SQL exception" do
        db = MonkeyButler::Databases::SqliteDatabase.new(URI(db_path))
        expect { db.all_versions }.to raise_error(SQLite3::SQLException)
      end
    end

    context "when the schema_migrations table is empty" do
      it "returns an empty array" do
        db.all_versions.should == []
      end
    end

    context "when the schema_migrations table has a single row" do
      before(:each) do
        @version = MonkeyButler::Util.migration_timestamp
        db.insert_version(@version)
      end

      it "returns the only value" do
        db.all_versions.should == [@version]
      end
    end

    context "when the schema_migrations table has many rows" do
      before(:each) do
        # Inject to guarantee mutation of the timestamp
        @versions = (1..5).inject([]) do |versions, i|
          version = MonkeyButler::Util.migration_timestamp + i
          db.insert_version(version)
          versions << version
        end
      end

      it "returns all values in ascending order" do
        db.all_versions.should == @versions
      end
    end
  end

  describe '#execute_migration' do
    context "when given valid SQL" do
      it "executes without error" do
        expect { db.execute_migration("CREATE TABLE new_table(version INTEGER UNIQUE NOT NULL)") }.not_to raise_error
      end
    end

    context "when given invalid SQL" do
      it "raises an error" do
        expect do
          db.execute_migration MonkeyButler::Util.strip_leading_whitespace(
          <<-SQL
            CREATE TABLE new_table(version INTEGER UNIQUE NOT NULL);
            DELETE FROM invalid_table;
          SQL
          )
        end.to raise_error(SQLite3::SQLException)
      end

      it "rolls back transaction" do
        db.execute_migration("CREATE TABLE new_table(version INTEGER UNIQUE NOT NULL)")
        db.execute_migration MonkeyButler::Util.strip_leading_whitespace(
        <<-SQL
          DROP TABLE new_table;
          DELETE FROM invalid_table;
        SQL
        ) rescue nil
        expect(db.db.get_first_value('SELECT MIN(version) FROM new_table')).to be_nil
      end
    end
  end

  describe "#dump_rows" do
    before(:each) do
      1.upto(5) { |version| db.insert_version(version) }
    end

    it "dumps the rows to SQL" do
      statements = db.dump_rows('schema_migrations')
      expected_statements = [
        "INSERT INTO schema_migrations (version) VALUES (1);",
        "INSERT INTO schema_migrations (version) VALUES (2);",
        "INSERT INTO schema_migrations (version) VALUES (3);",
        "INSERT INTO schema_migrations (version) VALUES (4);",
        "INSERT INTO schema_migrations (version) VALUES (5);"
      ]
      expect(statements).to eq(expected_statements)
    end
  end
end
