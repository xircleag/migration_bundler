require 'spec_helper'

describe MonkeyButler::CLI do
  let!(:project_root) { clone_temp_sandbox }
  let(:config) { MonkeyButler::Config.load(project_root) }
  let(:schema_path) { File.join(project_root, config.schema_path) }

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

  def add_migration(sql)
    path = File.join(project_root, 'migrations', random_migration_name)
    File.open(path, 'w+') do |f|
      f << sql
    end
    File.basename(path)
  end

  def create_sandbox_migration_path
    Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /create_sandbox\.sql/ }
  end

  describe '#load' do
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

  describe "#migrate" do
    before(:each) do
      @migration_paths = [
        create_sandbox_migration_path,
        add_migration('CREATE TABLE table1 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);'),
        add_migration('CREATE TABLE table2 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);'),
        add_migration('CREATE TABLE table3 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
      ]
    end

    context "when the database is empty" do
      it "applies all migrations" do
        output = invoke!(%w{migrate})

        db = MonkeyButler::Database.new(project_root + '/sandbox.db')
        expected_versions = MonkeyButler::Util.migrations_by_version(@migration_paths).keys.sort
        target_version = expected_versions.max
        expect(db.current_version).to eql(target_version)
        expect(db.all_versions).to eql(expected_versions)
      end

      it "informs the user of target version" do
        output = invoke!(%w{migrate})
        expected_versions = MonkeyButler::Util.migrations_by_version(@migration_paths).keys.sort
        target_version = expected_versions.max
        output[:stdout].should =~ %r{Migrating new database to #{target_version}}
      end

      it "informs the user of all migrations applied" do
        output = invoke!(%w{migrate}, capture: true)
        output[:stdout].should =~ /Migrating database.../
        @migration_paths.each do |path|
          output[:stdout].should =~ %r{applying migration:\s+migrations\/#{path}}
        end
      end

      pending "dumps the schema and schema_migrations rows"
      pending "adds the schema file to the Git staging area"
    end

    context "when the database is up to date" do
      before(:each) do
        versions = MonkeyButler::Util.migration_versions_from_paths(@migration_paths)
        database = MonkeyButler::Database.create(project_root + '/sandbox.db')
        versions.each { |version| database.insert_version(version) }
      end

      it "informs the user the database is up to date" do
        output = invoke!(%w{migrate})
        output[:stdout].should =~ /Database is up to date./
      end
    end

    context "when some migrations have been applied" do
      before(:each) do
        versions = MonkeyButler::Util.migration_versions_from_paths(@migration_paths)
        database = MonkeyButler::Database.create(project_root + '/sandbox.db')
        @current_version = versions.first
        database.insert_version(@current_version)
      end

      it "displays the current version of the database" do
        output = invoke!(%w{migrate})
        expected_versions = MonkeyButler::Util.migrations_by_version(@migration_paths).keys.sort
        target_version = expected_versions.max
        output[:stdout].should =~ %r{Migrating from #{@current_version} to #{target_version}}
      end

      it "displays the migrations to be applied" do
        output = invoke!(%w{migrate})
        output[:stdout].should =~ /Migrating database/
        @migration_paths[1,3].each do |path|
          output[:stdout].should =~ %r{applying migration:\s+migrations\/#{path}}
        end
      end
    end
  end

  describe '#status' do
    before(:each) do
      @migration_paths = [
        create_sandbox_migration_path,
        add_migration('CREATE TABLE table1 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);'),
        add_migration('CREATE TABLE table2 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);'),
        add_migration('CREATE TABLE table3 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
      ]
    end

    context "when the database is up to date" do
      before(:each) do
        versions = MonkeyButler::Util.migration_versions_from_paths(@migration_paths)
        database = MonkeyButler::Database.create(project_root + '/sandbox.db')
        versions.each { |version| database.insert_version(version) }
      end

      it "displays the current version" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /Current version\:/
      end

      it "displays up to date status" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /Database is up to date./
      end
    end

    context "when the database is empty" do
      it "informs the user the database is missing the schema migrations table" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /New database/
        output[:stdout].should =~ /The database at 'sandbox.db' does not have a 'schema_migrations' table./
      end

      it "displays the migrations to be applied" do
        output = invoke!(%w{status}, capture: true)
        output[:stdout].should =~ /Migrations to be applied/
        output[:stdout].should =~ /\(use "mb migrate" to apply\)/
        @migration_paths.each do |path|
          output[:stdout].should =~ %r{pending migration:\s+migrations\/#{path}}
        end
      end
    end

    context "when there are unapplied migrations" do
      before(:each) do
        versions = MonkeyButler::Util.migration_versions_from_paths(@migration_paths)
        database = MonkeyButler::Database.create(project_root + '/sandbox.db')
        @current_version = versions.first
        database.insert_version(@current_version)
      end

      it "displays the current version of the database" do
        output = invoke!(%w{status})
        output[:stdout].should =~ %r{Current version: #{@current_version}}
      end

      it "displays the migrations to be applied" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /Migrations to be applied/
        output[:stdout].should =~ /\(use "mb migrate" to apply\)/
        @migration_paths[1,3].each do |path|
          output[:stdout].should =~ %r{pending migration:\s+migrations\/#{path}}
        end
      end
    end
  end

  describe '#validate' do
    before(:each) do
      sql = MonkeyButler::Util.strip_leading_whitespace <<-SQL
        #{MonkeyButler::Database.create_schema_migrations_sql}
        INSERT INTO schema_migrations(version) VALUES ('#{MonkeyButler::Util.migration_timestamp}');
      SQL
      File.open(schema_path, 'w+') { |f| f << sql }
      add_migration('CREATE TABLE table1 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
      add_migration('CREATE TABLE table2 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
    end

    context "when there is a schema to and migrations to apply" do
      it "informs the user validation was successful" do
        output = invoke!(%w{validate})
        output[:stdout].should =~ /Validation successful./
      end
    end
  end

  describe '#create' do
    it "generates a new migration with the given name" do
      invoke!(%w{create add_column_to_table})
      migration = Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /add_column_to_table\.sql/ }
      migration.should_not be_nil
    end
  end
end
