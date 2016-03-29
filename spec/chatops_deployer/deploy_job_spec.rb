require 'chatops_deployer/deploy_job'
require 'fileutils'
require 'webmock/rspec'

describe ChatopsDeployer::DeployJob do
  let(:deploy_job) { ChatopsDeployer::DeployJob.new }

  before do
    FileUtils.mkdir_p '/etc/nginx/sites-available'
    FileUtils.mkdir_p '/var/log'
  end

  describe '#perform' do
    let(:project) { instance_double('Project') }
    let(:nginx_config) { instance_double('NginxConfig') }
    let(:container) { instance_double('Container') }

    context 'happy flow - repo, branch and callback url are valid' do
      let(:repo) { 'fake_repo' }
      let(:branch) { 'branch' }
      let(:callback_url) { 'http://example.com/callback' }
      let(:host) { 'http://fake_host.example.com/' }

      it 'should deploy the branch and trigger callback' do
        expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch, host, 'chatops_deployer.yml')
          .and_return project
        expect(ChatopsDeployer::NginxConfig).to receive(:new).with(project)
          .and_return nginx_config
        expect(ChatopsDeployer::Container).to receive(:new).with(project)
          .and_return container
        expect(project).to receive(:logger=)
        expect(project).to receive(:sha1).and_return 'fake_sha1'
        expect(project).to receive(:cloned?).and_return false
        expect(project).to receive(:setup_directory)
        expect(project).to receive(:fetch_repo)
        expect(project).to receive(:read_config)
        expect(project).to receive(:copy_files_from_deployer)
        expect(project).to receive(:setup_cache_directories)
        expect(project).to receive(:update_cache)
        expect(project).to receive(:branch_directory).and_return('/tmp')
        expect(container).to receive(:build)
        urls = {'web' => ['192.168.0.1:3000']}
        exposed_urls = {'web' => ['http://famous-five-17.example.com']}
        expect(container).to receive(:logger=)
        expect(container).to receive(:urls).at_least(:once).and_return(urls)
        expect(nginx_config).to receive(:logger=)
        expect(nginx_config).to receive(:prepare_urls)
        expect(nginx_config).to receive(:exposed_urls).and_return(exposed_urls)
        expect(nginx_config).to receive(:add_urls).with urls

        fake_callback = double
        expect(fake_callback).to receive(:deployment_success).with("branch", exposed_urls)
        deploy_job.perform(repository: repo, branch: branch, host: host, callbacks: [fake_callback])
      end

      context 'when project is already cloned' do
        before { expect(project).to receive(:cloned?).and_return true }
        it 'deletes the directory and clones again when "clean" is not specified' do
          expect(container).to receive(:destroy)
          expect(project).to receive(:delete_repo_contents)

          expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch, host, 'chatops_deployer.yml')
            .and_return project
          expect(ChatopsDeployer::NginxConfig).to receive(:new).with(project)
            .and_return nginx_config
          expect(ChatopsDeployer::Container).to receive(:new).with(project)
            .and_return container
          expect(project).to receive(:logger=)
          expect(project).to receive(:sha1).and_return 'fake_sha1'
          expect(project).to receive(:setup_directory)
          expect(project).to receive(:fetch_repo)
          expect(project).to receive(:read_config)
          expect(project).to receive(:copy_files_from_deployer)
          expect(project).to receive(:setup_cache_directories)
          expect(project).to receive(:update_cache)
          expect(project).to receive(:branch_directory).and_return('/tmp')
          expect(container).to receive(:build)
          urls = {'web' => ['192.168.0.1:3000']}
          exposed_urls = {'web' => ['http://famous-five-17.example.com']}
          expect(container).to receive(:logger=)
          expect(container).to receive(:urls).at_least(:once).and_return(urls)
          expect(nginx_config).to receive(:logger=)
          expect(nginx_config).to receive(:prepare_urls)
          expect(nginx_config).to receive(:exposed_urls).and_return(exposed_urls)
          expect(nginx_config).to receive(:add_urls).with urls

          fake_callback = double
          expect(fake_callback).to receive(:deployment_success).with("branch", exposed_urls)
          deploy_job.perform(repository: repo, branch: branch, host: host, callbacks: [fake_callback])
        end

        it 'keeps the directory and does not clone again when "clean" is false' do
          expect(container).to receive(:destroy)
          expect(project).not_to receive(:delete_repo_contents)
          expect(project).not_to receive(:fetch_repo)

          expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch, host, 'chatops_deployer.yml')
            .and_return project
          expect(ChatopsDeployer::NginxConfig).to receive(:new).with(project)
            .and_return nginx_config
          expect(ChatopsDeployer::Container).to receive(:new).with(project)
            .and_return container
          expect(project).to receive(:logger=)
          expect(project).to receive(:sha1).and_return 'fake_sha1'
          expect(project).to receive(:setup_directory)
          expect(project).to receive(:read_config)
          expect(project).to receive(:copy_files_from_deployer)
          expect(project).to receive(:setup_cache_directories)
          expect(project).to receive(:update_cache)
          expect(project).to receive(:branch_directory).and_return('/tmp')
          expect(container).to receive(:build)
          urls = {'web' => ['192.168.0.1:3000']}
          exposed_urls = {'web' => ['http://famous-five-17.example.com']}
          expect(container).to receive(:logger=)
          expect(container).to receive(:urls).at_least(:once).and_return(urls)
          expect(nginx_config).to receive(:logger=)
          expect(nginx_config).to receive(:prepare_urls)
          expect(nginx_config).to receive(:exposed_urls).and_return(exposed_urls)
          expect(nginx_config).to receive(:add_urls).with urls

          fake_callback = double
          expect(fake_callback).to receive(:deployment_success).with("branch", exposed_urls)
          deploy_job.perform(repository: repo, branch: branch, host: host, callbacks: [fake_callback], clean: false)
        end
      end
    end

    context 'when an error occurs' do
      let(:repo) { 'fake_repo' }
      let(:branch) { 'branch' }
      let(:callback_url) { 'http://example.com/callback' }
      let(:host) { 'http://fake_host.example.com/' }

      it 'trigger callback with failure status and reason' do
        expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch, host, 'chatops_deployer.yml')
          .and_return project
        expect(project).to receive(:sha1).at_least(:once).and_return 'fake_sha1'
        fake_error = ChatopsDeployer::Error.new('failed!')
        expect(ChatopsDeployer::NginxConfig).to receive(:new).and_raise fake_error

        fake_callback = double
        expect(fake_callback).to receive(:deployment_failure)
          .with("branch", fake_error)
        deploy_job.perform(repository: repo, branch: branch, host: host, callbacks: [fake_callback])
      end
    end
  end
end
