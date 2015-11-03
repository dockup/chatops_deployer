require 'chatops_deployer/project'

describe ChatopsDeployer::Project do
  let(:repo) { 'https://github.com/code-mancers/app.git' }
  let(:project) { ChatopsDeployer::Project.new(repo, 'branch') }
  before { project.setup_directory }

  describe "setup_directory" do
    it 'creates the project and branch directories' do
      branch_dir = File.join(ChatopsDeployer::WORKSPACE, 'code-mancers/app/repositories/branch')
      project_dir = File.join(ChatopsDeployer::WORKSPACE, 'code-mancers/app')
      expect(project.branch_directory).to eql branch_dir
      expect(File.exists?(branch_dir)).to be_truthy
      expect(File.exists?(project_dir)).to be_truthy
    end

    it 'creates a cache directory inside the project directory' do
      cache_dir = File.join(ChatopsDeployer::WORKSPACE, 'code-mancers/app/cache')
      project
      expect(File.exists?(cache_dir)).to be_truthy
    end

    it 'does not throw any error if project directory exists' do
      FileUtils.mkdir_p File.join(ChatopsDeployer::WORKSPACE, 'code-mancers/app/repositories/branch')
      expect{ project }.not_to raise_error
    end
  end

  describe '#fetch_repo' do
    context 'when directory is empty' do
      it 'clones the git repo' do
        git_command = ["git", "clone", "--branch=branch", "--depth=1", repo, "."]
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: git_command, logger: project.logger) do
          double(:command, success?: true)
        end
        Dir.chdir project.branch_directory
        project.fetch_repo
      end
    end
  end

  describe '#delete_repo' do
    it 'deletes the branch directory' do
      expect(Dir.exists?(project.branch_directory)).to be_truthy
      project.delete_repo
      expect(Dir.exists?(project.branch_directory)).to be_falsey
    end
  end

  describe '#read_config' do
    context 'when config_file is present' do
      before do
        Dir.chdir project.branch_directory
        File.open('chatops_deployer.yml', 'w') do |f|
          f.puts <<-EOM
            key: value
          EOM
        end
      end
      it 'loads the YML file into config' do
        project.read_config
        expect(project.config).to eql({"key" => "value"})
      end
    end

    context 'when config_file is not present' do
      it 'config is an empty hash' do
        Dir.chdir project.branch_directory
        expect { project.read_config }.to raise_error ChatopsDeployer::Project::ConfigNotFoundError
      end
    end

    context 'when config_file is empty' do
      before do
        Dir.chdir project.branch_directory
        File.open('chatops_deployer.yml', 'w')
      end
      it 'config is an empty hash' do
        project.read_config
        expect(project.config).to eql({})
      end
    end

    context 'when config_file cannot be read' do
      before do
        Dir.chdir project.branch_directory
        File.open('chatops_deployer.yml', 'w') do |f|
          f.puts <<-EOM
            : -
          EOM
        end
      end
      it 'throws an error' do
        expect{ project.read_config }.to raise_error ChatopsDeployer::Project::Error,
          "Project error: Cannot parse YAML content in chatops_deployer.yml"
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

      Dir.chdir project.branch_directory
      File.open('chatops_deployer.yml', 'w') do |f|
        f.puts config
      end
      project.read_config
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

      let(:config) do
        <<-EOM
          copy:
            - "app_name/staging/sample.txt.erb"
        EOM
      end

      context 'when env hash is used in ERB' do
        let(:source_content) { "Hello <%= env['name'] %>" }
        it 'compiles the ERB tags with env values' do
          project.env = {'name' => 'Rosemary'}
          project.copy_files_from_deployer
          expect(File.read('sample.txt')).to eql "Hello Rosemary\n"
        end
      end

      context 'when vault object is used in ERB' do
        let(:source_content) { "Secret: <%= vault.read('secret', 'value') %>" }
        before do
          fake_vault = double('Vault')
          expect(fake_vault).to receive(:read)
            .with('secret', 'value')
            .and_return('this-is-a-secret')
          expect(ChatopsDeployer::Vault).to receive(:new)
            .and_return fake_vault
        end
        it 'compiles the ERB tags' do
          project.env = {'name' => 'Rosemary'}
          project.copy_files_from_deployer
          expect(File.read('sample.txt')).to eql "Secret: this-is-a-secret\n"
        end
      end
    end

    context 'when source starts with ./' do
      let(:source_path) { File.join(project.branch_directory, 'sample.txt') }
      let(:source_content) { "I'm inside the project" }

      let(:config) do
        <<-EOM
          copy:
            - "./sample.txt:sample1.txt"
        EOM
      end
      it 'copies the file from project directory to destination' do
        project.copy_files_from_deployer
        expect(File.read('sample1.txt')).to eql "I'm inside the project\n"
      end
    end
  end

  describe '#setup_cache_directories' do
    let(:project_dir) { File.join(ChatopsDeployer::WORKSPACE, 'code-mancers/app') }
    let(:branch_dir) { File.join(project_dir, 'repositories', 'branch') }
    let(:common_cache_dir) { File.join(project_dir, 'cache') }

    before do
      Dir.chdir project.branch_directory
      File.open('chatops_deployer.yml', 'w') do |f|
        f.puts config
      end
      project.read_config
    end

    context 'when cache is not specified in the config' do
      let(:config) { "" }
      it 'does not throw any error' do
        expect{ project.setup_cache_directories }.not_to raise_error
      end
    end

    context 'when cache is empty' do
      let(:config) do
        <<-EOM
          cache:
        EOM
      end
      it 'does not throw any error' do
        expect{ project.setup_cache_directories }.not_to raise_error
      end
    end

    context 'when cache directories are specified' do
      let(:config) do
        <<-EOM
          cache:
            tmp/bundler:
              api: /app/tmp/bundler
            tmp/node_modules:
              frontend: /web/tmp/node_modules
        EOM
      end

      it 'creates the cache directories in project cache' do
        project.setup_cache_directories
        expect(File.exists?(File.join(branch_dir, 'tmp/bundler'))).to be_truthy
        expect(File.exists?(File.join(branch_dir, 'tmp/node_modules'))).to be_truthy
      end
    end
  end

  describe '#update_cache' do
    let(:project_dir) { File.join(ChatopsDeployer::WORKSPACE, 'code-mancers/app') }
    let(:branch_dir) { File.join(project_dir, 'repositories', 'branch') }
    let(:common_cache_dir) { File.join(project_dir, 'cache') }
    let(:tmp_cache_dir) { File.join(project_dir, 'tmp_cache') }

    before do
      FileUtils.mkdir_p File.join(common_cache_dir, 'tmp/bundler')
      Dir.chdir project.branch_directory
      File.open('chatops_deployer.yml', 'w') do |f|
        f.puts config
      end
      project.read_config
    end

    context 'when cache is specified' do
      let(:config) do
        <<-EOM
          cache:
            tmp/bundler:
              api: /app/tmp/bundler
        EOM
      end
      it 'copies the directory from the container to host' do
        ps_command = ["docker-compose", "ps", "-q", "api"]
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: ps_command, logger: project.logger) do
          double(:command, success?: true, output: 'fake_container_id')
        end

        cp_command = ["docker", "cp", "fake_container_id:/app/tmp/bundler", tmp_cache_dir]
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: cp_command, logger: project.logger) do
          double(:command, success?: true)
        end
        FileUtils.mkdir_p tmp_cache_dir

        project.update_cache
        expect(File.exists?(tmp_cache_dir)).to be_falsey
      end
    end
  end
end
