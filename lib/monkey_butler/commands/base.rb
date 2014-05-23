require 'thor'
require 'monkey_butler/actions'

module MonkeyButler
  module Commands
    class Error < Thor::Error # :nodoc:
    end

    class Base < Thor::Group
      include Thor::Actions
      include MonkeyButler::Actions

      def self.source_root
        File.join File.dirname(__FILE__), '..'
      end
    end
  end
end
