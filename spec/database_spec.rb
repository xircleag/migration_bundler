require 'spec_helper'

describe MonkeyButler::Database do
  let(:db_path) { Tempfile.new('monkey_butler').path }
  let(:db) { MonkeyButler::Database.create(db_path) }

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
        db = MonkeyButler::Database.new(db_path)
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
end
