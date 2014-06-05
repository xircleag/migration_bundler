require 'spec_helper'
require 'monkey_butler/generators/java/java_generator'

describe MonkeyButler::Generators::JavaGenerator do
  let(:thor_class) { MonkeyButler::Generators::JavaGenerator }
  let!(:project_root) { clone_temp_sandbox }

  describe '#generate' do
    it "should have a schema file in assets/schema" do
      invoke!(['generate'])
      expect(File.file?(File.join(project_root, 'project/monkeybutler/src/main/assets/schema/schema_create2.sql'))).to eq(true)
    end
  end

end
