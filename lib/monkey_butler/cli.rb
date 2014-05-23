require 'thor'
require 'monkey_butler/commands/init'
require 'monkey_butler/commands/generate'

module MonkeyButler
  class CLI < Thor
    # TODO: class options: verbose, dry run, specify database to work on.
    
    register(MonkeyButler::Commands::Init, "init", "init PATH", "Initializes a Monkey Butler repository at PATH")
    
    desc "load", "Loads project schema into target database"
    def load
      
    end
    
    desc "create NAME", "Creates a new migration"
    def create(name)
      
    end
    
    desc "status", "Displays current schema version and any unapplied migrations"
    def status
      
    end
    
    desc "migrate [VERSION]", "Applies pending migrations to the target database"
    def migrate(version = nil)
      
    end
    
    desc "generate", "Generates platform specific migration implementations"
    def generate
      
    end
    
    desc "validate", "Validates schema loads and all migrations are linearly applicable"
    def validate
      
    end
    
    desc "package VERSION", "Packages a release by validating, generating, and tagging a version"
    def package
      
    end
    
    desc "push VERSION", "Pushes a release to Git, CocoaPods, Maven, etc."
    def push
      
    end
  end  
end
