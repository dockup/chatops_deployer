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
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: git_command, logger: project.logger) do
          double(:command, success?: true)
        end
        Dir.chdir project.directory
        project.fetch_repo
      end
    end

    context 'when directory is not empty' do
      it 'pulls changes from remote branch' do
        dummy_file = File.join project.directory, 'dummy'
        File.open(dummy_file, 'w')

        Dir.chdir project.directory
        git_command = ["git", "pull", "origin", "branch"]
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: git_command, logger: project.logger) do
          double(:command, success?: true)
        end
        project.fetch_repo
      end
    end

    context 'when config_file is present' do
      before do
        Dir.chdir project.directory
        File.open('chatops_deployer.yml', 'w') do |f|
          f.puts <<-EOM
            key: value
          EOM
        end
      end
      it 'loads the YML file into config' do
        git_command = ["git", "pull", "origin", "branch"]
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: git_command, logger: project.logger) do
          double(:command, success?: true)
        end
        project.fetch_repo
        expect(project.config).to eql({"key" => "value"})
      end
    end

    context 'when config_file is not present' do
      it 'config is an empty hash' do
        git_command = ["git", "clone", "--branch=branch", "--depth=1", "repo", "."]
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: git_command, logger: project.logger) do
          double(:command, success?: true)
        end
        Dir.chdir project.directory
        project.fetch_repo
        expect(project.config).to eql({})
      end
    end
  end

  describe '#copy_files_from_deployer' do
    let(:source_directory) { File.join(ChatopsDeployer::COPY_SOURCE_DIR, 'app_name', 'staging') }
    let(:source_path) { File.join(source_directory, 'sample.txt') }
    let(:source_content) { "sample" }
    before do
      FileUtils.mkdir_p source_directory
      File.open(source_path, 'w') do |f|
        f.puts source_content
      end

      Dir.chdir project.directory
      File.open('chatops_deployer.yml', 'w') do |f|
        f.puts config
      end
      git_command = ["git", "pull", "origin", "branch"]
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: git_command, logger: project.logger) do
        double(:command, success?: true)
      end
      project.fetch_repo
    end

    context 'when destination path is not provided explicitly' do
      let(:config) do
        <<-EOM
          copy:
            - "app_name/staging/sample.txt"
        EOM
      end

      it 'uses the source filename as the destination' do
        project.copy_files_from_deployer
        expect(File.read('sample.txt')).to eql File.read(source_path)
      end
    end

    context 'when destination path is provided explicitly' do
      let(:config) do
        <<-EOM
          copy:
            - "app_name/staging/sample.txt:sample1.txt"
        EOM
      end

      it 'uses the source filename as the destination' do
        project.copy_files_from_deployer
        expect(File.read('sample1.txt')).to eql File.read(source_path)
      end
    end

    context 'when source is an .erb file' do
      let(:source_path) { File.join(source_directory, 'sample.txt.erb') }
      let(:source_content) { "Hello <%= env['name'] %>" }

      let(:config) do
        <<-EOM
          copy:
            - "app_name/staging/sample.txt.erb"
        EOM
      end
      it 'compiles the ERB tags' do
        project.env = {'name' => 'Rosemary'}
        project.copy_files_from_deployer
        expect(File.read('sample.txt')).to eql "Hello Rosemary\n"
      end
    end
  end
end
