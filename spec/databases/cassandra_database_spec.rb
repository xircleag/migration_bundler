require 'spec_helper'
require 'monkey_butler/databases/cassandra_database'

describe MonkeyButler::Databases::CassandraDatabase do
  let(:db) { MonkeyButler::Databases::CassandraDatabase.new(cassandra_url) }
  let(:cassandra_url) { URI("cassandra://localhost:9042/monkey_butler") }

  before(:each) do
    db.drop
  end

  describe ".migration_ext" do
    MonkeyButler::Databases::CassandraDatabase.migration_ext.should == '.cql'
  end

  describe '#keyspace' do
    it "extracts keyspace from path" do
      db.keyspace.should == 'monkey_butler'
    end
  end

  describe "#migrations_table?" do
    context "when the migrations table exists" do
      before(:each) do
        db.create_migrations_table
      end

      it "is true" do
        expect(db.migrations_table?).to be_true
      end
    end

    context "when the migrations table does not exist" do
      before(:each) do
        db.drop
      end

      it "is true" do
        expect(db.migrations_table?).to be_false
      end
    end
  end

  describe "#origin_version" do
    context "when the schema_migrations table does not exist" do
      before(:each) do
        db.drop
      end

      it "raises an error" do
        expect { db.origin_version }.to raise_error(Cql::QueryError, "Keyspace 'monkey_butler' does not exist")
      end
    end

    context "when the schema_migrations table is empty" do
      before(:each) do
        db.create_migrations_table
      end

      it "returns nil" do
        db.origin_version.should be_nil
      end
    end

    context "when the database has one version row" do
      before(:each) do
        db.create_migrations_table
        db.insert_version(20140101023213)
      end

      it "returns that row" do
        db.origin_version.should == 20140101023213
      end
    end

    context "when the database has three version rows" do
      before(:each) do
        db.create_migrations_table
        db.insert_version(1)
        db.insert_version(2)
        db.insert_version(3)
      end

      it "returns the lowest value" do
        db.origin_version.should == 1
      end
    end
  end

  describe "#current_version" do
    context "when the schema_migrations table does not exist" do
      before(:each) do
        db.drop
      end

      it "raises an error" do
        expect { db.current_version }.to raise_error(Cql::QueryError, "Keyspace 'monkey_butler' does not exist")
      end
    end

    context "when the schema_migrations table is empty" do
      before(:each) do
        db.create_migrations_table
      end

      it "returns nil" do
        db.current_version.should be_nil
      end
    end

    context "when the database has one version row" do
      before(:each) do
        db.create_migrations_table
        db.insert_version(20140101023213)
      end

      it "returns that row" do
        db.current_version.should == 20140101023213
      end
    end

    context "when the database has three version rows" do
      before(:each) do
        db.create_migrations_table
        db.insert_version(1)
        db.insert_version(2)
        db.insert_version(3)
      end

      it "returns the highest value" do
        db.current_version.should == 3
      end
    end
  end

  describe "#all_versions" do
    context "when the schema_migrations table does not exist" do
      before(:each) do
        db.drop
      end

      it "raises an error" do
        expect { db.current_version }.to raise_error(Cql::QueryError, "Keyspace 'monkey_butler' does not exist")
      end
    end

    context "when the schema_migrations table is empty" do
      before(:each) do
        db.create_migrations_table
      end

      it "returns an empty array" do
        db.all_versions.should be_empty
      end
    end

    context "when the database has one version row" do
      before(:each) do
        db.create_migrations_table
        db.insert_version(20140101023213)
      end

      it "returns that row" do
        db.all_versions.should == [20140101023213]
      end
    end

    context "when the database has three version rows" do
      before(:each) do
        db.create_migrations_table
        db.insert_version(1)
        db.insert_version(2)
        db.insert_version(3)
      end

      it "returns the highest value" do
        db.all_versions.should == [1,2,3]
      end
    end
  end

  describe "#insert_version" do
    context "when the schema_migrations table does not exist" do
      before(:each) do
        db.drop
      end

      it "raises an error" do
        expect { db.insert_version(1234) }.to raise_error(Cql::QueryError, "Keyspace 'monkey_butler' does not exist")
      end
    end

    context "when the schema_migrations table exists" do
      before(:each) do
        db.create_migrations_table
      end

      it "inserts successfully" do
        db.insert_version(1234)
        db.all_versions.should == [1234]
      end
    end
  end

  describe "#execute_migration" do
    context "when the schema_migrations table does not exist" do
      before(:each) do
        db.drop
      end

      it "raises an error" do
        expect { db.insert_version(1234) }.to raise_error(Cql::QueryError, "Keyspace 'monkey_butler' does not exist")
      end
    end

    context "when the schema_migrations table exists" do
      before(:each) do
        db.create_migrations_table
      end

      it "inserts successfully" do
        db.insert_version(1234)
        db.all_versions.should == [1234]
      end
    end
  end

  describe "#truncate" do
    context "when the keyspace has tables" do
      before(:each) do
        db.create_migrations_table
      end

      it "destroys the tables" do
        expect(db.migrations_table?).to be_true
        db.drop
        expect(db.migrations_table?).to be_false
      end
    end
  end

  describe "#dump_rows" do
    before(:each) do
      db.create_migrations_table
      1.upto(5) { |version| db.insert_version(version) }
    end

    it "dumps the rows as statements" do
      statements = db.dump_rows('schema_migrations')
      expected_statements = [
        "INSERT INTO schema_migrations (partition_key, version) VALUES (0, 1);",
        "INSERT INTO schema_migrations (partition_key, version) VALUES (0, 2);",
        "INSERT INTO schema_migrations (partition_key, version) VALUES (0, 3);",
        "INSERT INTO schema_migrations (partition_key, version) VALUES (0, 4);",
        "INSERT INTO schema_migrations (partition_key, version) VALUES (0, 5);"
      ]
      expect(statements).to eq(expected_statements)
    end
  end
end
