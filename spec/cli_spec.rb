require 'spec_helper'

describe MonkeyButler::CLI do
  let!(:project_root) { clone_temp_sandbox }
  let(:project) { MonkeyButler::Project.load(project_root) }
  let(:schema_path) { File.join(project_root, project.schema_path) }

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
        output[:stdout].should =~ /executing  sqlite3 sandbox.sqlite < sandbox.sql/
        output[:stderr].should be_empty
      end

      it "reports the current version of the database" do
        output = invoke!(%w{load})
        output[:stdout].should =~ /Loaded schema at version #{@timestamp}/
      end

      context "when a database argument is given" do
        it "loads into the specified database" do
          db_path = Tempfile.new('specific.db').path
          output = invoke!(%W{load -d #{db_path}})
          output[:stdout].should_not =~ /truncate sandbox.sqlite/
          output[:stdout].should =~ /executing  sqlite3 #{db_path} < sandbox.sql/
          output[:stdout].should =~ /Loaded schema at version #{@timestamp}/
          output[:stderr].should be_empty
        end
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
      context "when a database argument is given" do
        it "applies all migrations to the specified database" do
          db_path = Tempfile.new('specific.db').path
          output = invoke!(%W{migrate -d #{db_path}})

          db = MonkeyButler::Database.new(db_path)
          expected_versions = MonkeyButler::Util.migrations_by_version(@migration_paths).keys.sort
          target_version = expected_versions.max
          expect(db.current_version).to eql(target_version)
          expect(db.all_versions).to eql(expected_versions)
        end

        context "when the dump option is given" do
          it "dumps the database after migrations" do
            db_path = Tempfile.new('specific.db').path
            File.truncate(schema_path, 0)
            output = invoke!(%W{migrate -d #{db_path} --dump})
            output[:stdout].should =~ /Dumping schema from database/
            File.size(schema_path).should_not == 0
          end
        end
      end

      it "applies all migrations" do
        output = invoke!(%w{migrate})

        db = MonkeyButler::Database.new(project_root + '/sandbox.sqlite')
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
        output = invoke!(%w{migrate})
        output[:stdout].should =~ /Migrating database.../
        @migration_paths.each do |path|
          output[:stdout].should =~ %r{applying migration:\s+migrations\/#{path}}
        end
      end

      it "displays migraiton complete message" do
        output = invoke!(%w{migrate})
        expected_versions = MonkeyButler::Util.migrations_by_version(@migration_paths).keys.sort
        target_version = expected_versions.max
        output[:stdout].should =~ /Migration to version #{target_version} complete./
      end

      pending "dumps the schema and schema_migrations rows"
      pending "adds the schema file to the Git staging area"
    end

    context "when the database is up to date" do
      before(:each) do
        versions = MonkeyButler::Util.migration_versions_from_paths(@migration_paths)
        database = MonkeyButler::Database.create(project_root + '/sandbox.sqlite')
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
        database = MonkeyButler::Database.create(project_root + '/sandbox.sqlite')
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
        database = MonkeyButler::Database.create(project_root + '/sandbox.sqlite')
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
        output[:stdout].should =~ /The database at 'sandbox.sqlite' does not have a 'schema_migrations' table./
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
        database = MonkeyButler::Database.create(project_root + '/sandbox.sqlite')
        @current_version = versions.first
        database.insert_version(@current_version)
      end

      it "displays the current version of the database" do
        output = invoke!(%w{status})
        output[:stdout].should =~ %r{Current version: #{@current_version}}
      end

      it "displays the migrations to be applied" do
        output = invoke!(%w{status})
        output[:stdout].should =~ /The database at 'sandbox.sqlite' is 3 versions behind /
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

    context "when the git url is not configured" do
      before(:each) do
        Dir.chdir(project_root) do
          system("git remote remove origin")
        end
      end

      it "fails with error" do
        output = invoke!(['validate'])
        output[:stderr].should =~ /Invalid configuration: git does not have a remote named 'origin'./
      end
    end
  end

  describe '#new' do
    it "generates a new migration with the given name" do
      invoke!(%w{new add_column_to_table})
      migration = Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /add_column_to_table\.sql/ }
      migration.should_not be_nil
    end
  end

  describe '#generate' do
    before(:each) do
      sql = MonkeyButler::Util.strip_leading_whitespace <<-SQL
        #{MonkeyButler::Database.create_schema_migrations_sql}
        INSERT INTO schema_migrations(version) VALUES ('#{MonkeyButler::Util.migration_timestamp}');
      SQL
      File.open(schema_path, 'w+') { |f| f << sql }
      add_migration('CREATE TABLE table1 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
      add_migration('CREATE TABLE table2 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
    end

    context "when no generator option is not given" do
      it "invokes the default generators for the project" do
        output = invoke!(%w{generate})
        output[:stdout].should =~ /Invoking generator 'cocoapods'/
        output[:stdout].should_not =~ /Invoking generator 'java'/
        output[:stderr].should == ""
      end
    end

    context "when generator option is given" do
      it "invokes the specified generators" do
        output = invoke!(%w{generate -g java})
        output[:stdout].should =~ /Invoking generator 'java'/
        output[:stdout].should_not =~ /Invoking generator 'cocoapods'/
      end
    end
  end

  describe '#package' do
    before(:each) do
      sql = MonkeyButler::Util.strip_leading_whitespace <<-SQL
        #{MonkeyButler::Database.create_schema_migrations_sql}
        INSERT INTO schema_migrations(version) VALUES ('#{MonkeyButler::Util.migration_timestamp}');
      SQL
      File.open(schema_path, 'w+') { |f| f << sql }
      add_migration('CREATE TABLE table1 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
      add_migration('CREATE TABLE table2 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
    end

    def stub_questions
      Thor::LineEditor.stub(:readline).and_return("n")
    end

    it "invokes validation" do
      stub_questions
      output = invoke!(%w{package --pretend})
      output[:stdout].should =~ /Validation successful/
    end

    it "invokes generation" do
      stub_questions
      output = invoke!(%w{package --pretend})
      output[:stdout].should =~ /Invoking generator 'cocoapods'/
    end

    it "adds the project to git" do
      stub_questions
      output = invoke!(%w{package --pretend})
      output[:stdout].should =~ /git add . from "."/
    end

    it "runs git status" do
      stub_questions
      output = invoke!(%w{package --pretend})
      output[:stdout].should =~ /git status from "."/
    end

    describe "diff" do
      context "when no diff option is given" do
        it "asks if you want to see the diff" do
          expect(Thor::LineEditor).to receive(:readline).with("Review package diff? [y, n] ", {:limited_to=>["y", "n"]}).and_return("n")
          stub_questions
          output = invoke!(%w{package --pretend})
        end
      end

      context "when --diff is specified" do
        it "shows the diff" do
          stub_questions
          output = invoke!(%w{package --pretend --diff})
          output[:stdout].should =~ /git diff --cached from "."/
        end
      end

      context "when --no-diff is specified" do
        it "should not ask to review the diff" do
          expect(Thor::LineEditor).not_to receive(:readline).with("Review package diff? [y, n] ", {:limited_to=>["y", "n"]})
          stub_questions
          output = invoke!(%w{package --pretend --no-diff})
        end
      end
    end

    describe "commit" do
      context "when no commit option is given" do
        it "asks if you want to commit" do
          expect(Thor::LineEditor).to receive(:readline).with("Commit package artifacts? [y, n] ", {:limited_to=>["y", "n"]}).and_return("n")
          stub_questions
          output = invoke!(%w{package --pretend})
        end
      end

      context "when --commit is specified" do
        it "commits the changes" do
          stub_questions
          output = invoke!(%w{package --pretend --commit})
          output[:stdout].should =~ /git commit -m 'Packaging release/
        end
      end

      context "when --no-commit is specified" do
        it "commits the changes" do
          expect(Thor::LineEditor).not_to receive(:readline).with("Commit package artifacts? [y, n] ", {:limited_to=>["y", "n"]})
          stub_questions
          output = invoke!(%w{package --pretend --no-commit})
          output[:stdout].should_not =~ /git commit -m 'Packaging release/
        end
      end

      it "tags a release for the latest version" do
        db = MonkeyButler::Database.new(project_root + '/sandbox.sqlite')
        migrations = MonkeyButler::Migrations.new(project_root + '/migrations', db)

        stub_questions
        output = invoke!(%w{package --pretend --commit})
        output[:stdout].should =~ /git tag #{migrations.latest_version}/
      end

      context "when a tag for the version already exists" do
        it "tags a point release" do
          db = MonkeyButler::Database.new(project_root + '/sandbox.sqlite')
          migrations = MonkeyButler::Migrations.new(project_root + '/migrations', db)
          Dir.chdir(project_root) do
            `echo '' > foo`
            `git add foo && git commit -m 'fake commit' .`
            `git tag #{migrations.latest_version}`
          end
          point_release = "#{migrations.latest_version}.1"

          stub_questions
          output = invoke!(%w{package --commit})
          output[:stdout].should =~ /git tag #{point_release}/
        end
      end
    end
  end

  describe '#push' do
  end
end
