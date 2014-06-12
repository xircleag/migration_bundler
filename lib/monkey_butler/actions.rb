module MonkeyButler
  module Actions
    # Run a command in git.
    #
    #   git :init
    #   git add: "this.file that.rb"
    #   git add: "onefile.rb", rm: "badfile.cxx"
    def git(commands={})
      if commands.is_a?(Symbol)
        run "git #{commands}"
      else
        commands.each do |cmd, options|
          run "git #{cmd} #{options}"
        end
      end
    end

    def git_add(*paths)
      inside(destination_root) do
        git add: paths.flatten.join(' ')
      end
    end

    def truncate_database
      say_status :truncate, database.to_s, :yellow
      database.truncate
    end

    def bundle
      inside(destination_root) { run "bundle" }
    end
  end
end
