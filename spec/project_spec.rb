require 'spec_helper'

describe MonkeyButler::Project do
  let!(:project_root) { clone_temp_sandbox }
  let(:project) { MonkeyButler::Project.load(project_root) }

  before(:each) do
    Dir.chdir(project_root)
  end

  describe '#git_url' do
  end

  describe '#git_latest_tag' do
    context "when there are no tags" do
      it "returns nil" do
        project.git_latest_tag.should be_nil
      end
    end

    context "when there is one tag" do
      before(:each) do
        tag_versions(%w{1.0.0})
      end

      it "returns that tag" do
        project.git_latest_tag.should == '1.0.0'
      end
    end

    context "when there are 4 tags" do
      before(:each) do
        tag_versions(%w{1.0.0 0.9.8 2.2.3 1.9.5})
      end

      it "returns the highest version number" do
        project.git_latest_tag.should == '2.2.3'
      end
    end
  end

  describe '#git_tag_for_version' do
    context "when there are no tags" do
      it "returns nil" do
        project.git_tag_for_version('v1.0.0').should be_nil
      end
    end

    context "when there is one tag" do
      before(:each) do
        tag_versions(%w{1.0.0})
      end

      it "returns that tag" do
        project.git_tag_for_version('1.0.0').should == '1.0.0'
      end

      context "but it doesn't match the query" do
        it "returns nil" do
          project.git_tag_for_version('0.9.6').should be_nil
        end
      end
    end

    context "when there are 4 tags" do
      before(:each) do
        tag_versions(%w{1.0.0 0.9.8 2.2.3 1.9.5})
      end

      it "returns the matching tag" do
        project.git_tag_for_version('0.9.8').should == '0.9.8'
      end

      context "but none match the query" do
        it "returns nil" do
          project.git_tag_for_version('0.5.12').should be_nil
        end
      end

      context "and there are point releases" do
        before(:each) do
          tag_versions(%w{0.9.8.1 0.9.8.5000 0.9.8.2 0.9.8.3})
        end

        it "returns the highest matching tag" do
          project.git_tag_for_version('0.9.8').should == '0.9.8.5000'
        end
      end
    end
  end

  def tag_versions(*versions)
    Dir.chdir(project_root) do
      versions.flatten.each do |version|
        filename = random_migration_name
        `echo '' > #{filename}`
        raise "Failed touching file" unless $?.exitstatus.zero?
        `git add #{filename} && git commit -m 'commiting #{random_migration_name}' .`
        raise "Failed commiting" unless $?.exitstatus.zero?
        `git tag #{version}`
        raise "Failed tagging version" unless $?.exitstatus.zero?
      end
    end
  end
end
