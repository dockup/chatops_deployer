require 'chatops_deployer/project'

describe ChatopsDeployer::Project do
  let(:project) { ChatopsDeployer::Project.new('repo', 'branch') }

  describe "initialize" do
    it 'creates the project directory' do
      project_dir = File.join(ChatopsDeployer::WORKSPACE, project.sha1)
      expect(project.directory).to eql project_dir
      expect(File.exists?(project_dir)).to be_truthy
    end

    it 'does not throw any error if project directory exists' do
      expect(Digest::SHA1).to receive(:hexdigest).with('repobranch')
        .and_return('fakse_sha1')
      FileUtils.mkdir_p File.join(ChatopsDeployer::WORKSPACE, 'fake_sha1')
      expect{ project }.not_to raise_error
    end
  end

  describe '#fetch_repo' do
    context 'when directory is empty' do
      it 'clones the git repo' do
        git_command = ["git", "clone", "--branch=branch", "--depth=1", "repo", "."]
        expect(ChatopsDeployer::Command).to receive(:run).with(*git_command) do
          double(:command, success?: true)
        end
        Dir.chdir project.directory
        project.fetch_repo
      end
    end

    context 'when directory is not empty' do
      it 'clones the git repo' do
        dummy_file = File.join project.directory, 'dummy'
        File.open(dummy_file, 'w')

        Dir.chdir project.directory
        git_command = ["git", "pull", "origin", "branch"]
        expect(ChatopsDeployer::Command).to receive(:run).with(*git_command) do
          double(:command, success?: true)
        end
        project.fetch_repo
      end
    end
  end
end
