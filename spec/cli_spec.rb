require 'spec_helper'
require 'monkey_butler/databases/sqlite_database'

describe MonkeyButler::CLI, "#init" do
  describe "#init" do
    let(:thor_class) { MonkeyButler::CLI }
    let!(:project_root) { Dir.mktmpdir }

    context 'when no PATH is given' do
      it "prints an argument error to stderr" do
        output = invoke!([:init])
        output[:stderr].should =~ /ERROR: "\w+ init" was called with no arguments/
      end
    end

    context 'when the PATH given already exists' do
      context "and contains existing content" do
        it "aborts with an error" do
          Dir.mktmpdir do |path|
            File.open(File.join(path, 'sdasdasd'), 'w+')
            output = invoke!([:init, path])
            output[:stderr].should =~ /Cannot create repository into non-empty path/
          end
        end
      end

      context "and is a regular file" do
        it "aborts with an error" do
          path = Tempfile.new('monkey_butler').path
          output = invoke!([:init, path])
          output[:stderr].should =~ /Cannot create repository: regular file exists at path/
        end
      end

      context "and is empty" do
        it "reports the path already exists" do
          Dir.mktmpdir do |path|
            output = invoke!([:init, path])
            output[:stderr].should be_empty
            output[:stdout].should =~ /exist\s+$/
          end
        end
      end
    end

    context 'when the PATH given does not exist' do
      before(:each) do
        FileUtils.remove_entry project_root
      end

      it "creates the path" do
        output = invoke!([:init, project_root])
        output[:stderr].should be_empty
        output[:stdout].should =~ /create\s+$/
        File.exists?(project_root).should be_true
        File.directory?(project_root).should be_true
      end

      it "populates .gitignore" do
        invoke!([:init, project_root, '--name=MonkeyButler'])
        path = File.join(project_root, '.gitignore')
        expect(File.exists?(project_root)).to be_true
        content = File.read(path)
        content.should include('.DS_Store')
        content.should =~ /^MonkeyButler.sqlite$/
      end

      describe '.monkey_butler.yml' do
        let(:args) { [:init, project_root, '--name=MonkeyButler'] }
        before(:each) do
          invoke!(args)
          @yaml_path = File.join(project_root, '.monkey_butler.yml')
        end

        it "is created" do
          expect(File.exists?(@yaml_path)).to be_true
        end

        it "is valid YAML" do
          expect { YAML.load(File.read(@yaml_path)) }.not_to raise_error
        end

        it "configures the project name" do
          config = YAML.load(File.read(@yaml_path))
          config['name'].should == 'MonkeyButler'
        end

        it "includes a nested config dictionary" do
          config = YAML.load(File.read(@yaml_path))
          config['config'].should == {}
        end

        it "configures default adapters" do
          config = YAML.load(File.read(@yaml_path))
          config['config'].should == {}
        end

        context "when config option is specified" do
          let(:args) { [:init, project_root, '--name=MonkeyButler', '--config', 'foo:bar'] }

          it "parses the arguments as a hash of config vars" do
            config = YAML.load(File.read(@yaml_path))
            config['config'].should == {"foo" => "bar"}
          end
        end
      end

      it "creates an empty database" do
        invoke!([:init, project_root, '--name=MonkeyButler'])
        path = File.join(project_root, 'MonkeyButler.db')
        expect(File.exists?(project_root)).to be_true
      end

      it "creates an empty schema" do
        invoke!([:init, project_root, '--name=MonkeyButler'])
        path = File.join(project_root, 'MonkeyButler.sql')
        expect(File.exists?(project_root)).to be_true
      end

      it "generates an initial migration" do
        invoke!([:init, project_root, '--name=MonkeyButler'])
        filename = Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /create_monkey_butler.sql$/ }
        expect(filename).not_to be_nil
        path = File.join(project_root, 'migrations', filename)
        expect(File.exists?(path)).to be_true
      end

      it "initializes a Git repository at the destination path" do
        invoke!([:init, project_root, '--name=MonkeyButler'])
        path = File.join(project_root, '.git')
        expect(File.exists?(path)).to be_true
      end

      def stub_bundler
        MonkeyButler::CLI.any_instance.stub(:bundle) do
          File.open(File.join(project_root, 'Gemfile.lock'), 'w')
        end
      end

      context "when --bundler option is given" do
        before(:each) do
          stub_bundler
        end

        it "creates a Gemfile" do
          invoke!([:init, project_root, '--bundler'])
          path = File.join(project_root, 'Gemfile')
          expect(File.exists?(path)).to be_true
        end

        it "omits the option from the YAML" do
          invoke!([:init, project_root, '--bundler'])
          project = YAML.load File.read(File.join(project_root, '.monkey_butler.yml'))
          expect(project['bundler']).to be_nil
        end
      end

      context "when --targets option is given" do
        context "when cocoapods is specified" do
          it "informs the user that the targets are being initialized" do
            output = invoke!([:init, project_root, "--config", 'cocoapods.repo:whatever', '--pretend', '--targets', 'cocoapods'])
            output[:stdout].should =~ /Initializing target 'cocoapods'.../
          end

          it "writes any changes written to the config back to the file" do
            expect(Thor::LineEditor).to receive(:readline).with("What is the name of your Cocoapods specs repo?  ", {}).and_return("layerhq")
            invoke!([:init, project_root, '--targets', 'cocoapods'])
            project = YAML.load File.read(File.join(project_root, '.monkey_butler.yml'))
            expect(project['config']['cocoapods.repo']).to eql('layerhq')
          end

          context "when --bundler is given" do
            it "appends CocoaPods to the Gemfile" do
              stub_bundler
              invoke!([:init, project_root, "--config", 'cocoapods.repo:whatever', '--bundler', '--targets', 'cocoapods'])
              gemfile_content = File.read(File.join(project_root, 'Gemfile'))
              gemfile_content.should =~ /gem 'cocoapods'/
            end
          end
        end
      end
    end
  end
end

describe MonkeyButler::CLI do
  let!(:project_root) { clone_temp_sandbox }
  let(:project) { MonkeyButler::Project.load(project_root) }
  let(:schema_path) { File.join(project_root, project.schema_path) }

  def add_migration(sql, ext = '.sql')
    path = File.join(project_root, 'migrations', random_migration_name + ext)
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
        #{MonkeyButler::Databases::SqliteDatabase.create_schema_migrations_sql}
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

  def sqlite_url_for_path(path)
    URI("sqlite://#{path}")
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

          db = MonkeyButler::Databases::SqliteDatabase.new(sqlite_url_for_path(db_path))
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

        db = MonkeyButler::Databases::SqliteDatabase.new(sqlite_url_for_path(project_root + '/sandbox.sqlite'))
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
        database = MonkeyButler::Databases::SqliteDatabase.create(sqlite_url_for_path(project_root + '/sandbox.sqlite'))
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
        database = MonkeyButler::Databases::SqliteDatabase.create(sqlite_url_for_path(project_root + '/sandbox.sqlite'))
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
        path = project_root + '/sandbox.sqlite'
        uri = URI("sqlite://#{path}")
        database = MonkeyButler::Databases::SqliteDatabase.create(uri)
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
        output = invoke!(%w{status})
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
        path = project_root + '/sandbox.sqlite'
        uri = URI("sqlite://#{path}")
        database = MonkeyButler::Databases::SqliteDatabase.create(uri)
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
        #{MonkeyButler::Databases::SqliteDatabase.create_schema_migrations_sql}
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
    # TODO: The only test here should be that a dummy database adapter was invoked....
    context "when using a SQLite database" do
      it "generates a new migration with the given name" do
        invoke!(%w{new add_column_to_table})
        migration = Dir.entries(File.join(project_root, 'migrations')).detect { |f| f =~ /add_column_to_table\.sql/ }
        migration.should_not be_nil
      end
    end

    context "when using a Cassandra database" do
      it "generates a migration"
    end
  end

  describe '#generate' do
    before(:each) do
      sql = MonkeyButler::Util.strip_leading_whitespace <<-SQL
        #{MonkeyButler::Databases::SqliteDatabase.create_schema_migrations_sql}
        INSERT INTO schema_migrations(version) VALUES ('#{MonkeyButler::Util.migration_timestamp}');
      SQL
      File.open(schema_path, 'w+') { |f| f << sql }
      add_migration('CREATE TABLE table1 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
      add_migration('CREATE TABLE table2 (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);')
    end

    context "when no target option is not given" do
      it "invokes the default targets for the project" do
        output = invoke!(%w{generate})
        output[:stdout].should =~ /Invoking target 'cocoapods'/
        output[:stdout].should_not =~ /Invoking target 'java'/
        output[:stderr].should == ""
      end
    end

    context "when target option is given" do
      it "invokes the specified targets" do
        output = invoke!(%w{generate -t maven})
        output[:stdout].should =~ /Invoking target 'maven'/
        output[:stdout].should_not =~ /Invoking target 'cocoapods'/
      end
    end
  end

  describe '#package' do
    before(:each) do
      sql = MonkeyButler::Util.strip_leading_whitespace <<-SQL
        #{MonkeyButler::Databases::SqliteDatabase.create_schema_migrations_sql}
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
      output[:stdout].should =~ /Invoking target 'cocoapods'/
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
        db = MonkeyButler::Databases::SqliteDatabase.new(sqlite_url_for_path(project_root + '/sandbox.sqlite'))
        migrations = MonkeyButler::Migrations.new(project_root + '/migrations', db)

        stub_questions
        output = invoke!(%w{package --pretend --commit})
        output[:stdout].should =~ /git tag #{migrations.latest_version}/
      end

      context "when a tag for the version already exists" do
        it "tags a point release" do
          db = MonkeyButler::Databases::SqliteDatabase.new(URI(project_root + '/sandbox.sqlite'))
          migrations = MonkeyButler::Migrations.new(project_root + '/migrations', db)
          Dir.chdir(project_root) do
            `echo '' > foo`
            `git add foo && git commit -m 'fake commit' .`
            `git tag #{migrations.latest_version}`
          end
          point_release = "#{migrations.latest_version}.1"

          stub_questions
          output = invoke!(%w{package --commit --quiet})
          Dir.chdir(project_root) do
            project.git_latest_tag.should == point_release
          end
        end
      end
    end
  end

  describe '#push' do
    it "pushes to git" do
      output = invoke!(%w{push --pretend})
      output[:stdout].should =~ /git push origin master --tags/
    end
  end
  
  describe "#config" do
    before(:each) do
      project = MonkeyButler::Project.load(project_root)
      project.config['this'] = 'that'
      project.config['option'] = 'value'
    end
    
    context "when called with no arguments" do
      it "enumerates all config variables" do        
        output = invoke!(%w{config})
        output[:stdout].should =~ /this=that/
        output[:stdout].should =~ /option=value/
      end
    end
    
    context "when called with one argument" do
      it "reads the value for that option" do
        output = invoke!(%w{config this})
        output[:stdout].should =~ /this=that/
        output[:stdout].should_not =~ /option=value/
      end
    end
    
    context "when called with two arguments" do
      it "sets the value for the specified option" do
        invoke!(%w{config this value})
        yaml = YAML.load(File.read(File.join(project_root, '.monkey_butler.yml')))
        yaml['config']['this'].should == 'value'
      end
    end
  end
end

describe MonkeyButler::CLI, "#target integration" do
  let!(:project_root) { clone_temp_sandbox }

  context "when the current directory has a monkey_butler.yml file" do
    it "allows the database target to register options" do
      output = invoke!(%w{help dump})
      output[:stdout].should =~ /#{Regexp.escape "-d, [--database=DATABASE]  # Set target DATABASE"}/
    end
  end
end
