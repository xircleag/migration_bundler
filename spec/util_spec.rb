require 'spec_helper'

describe MonkeyButler::Util do
  describe '#migrations_by_version' do
    it "returns a Hash keyed by version" do
      paths = %w{migrations/20140523123443021_create_sandbox.sql migrations/20140523123845031_add_comments_table.sql}
      hash = MonkeyButler::Util.migrations_by_version(paths)
      hash.size.should == 2
      hash[20140523123443021].should == 'migrations/20140523123443021_create_sandbox.sql'
      hash[20140523123845031].should == 'migrations/20140523123845031_add_comments_table.sql'
    end
  end
end
