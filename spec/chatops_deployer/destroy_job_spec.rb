require 'chatops_deployer/destroy_job'
require 'fileutils'
require 'webmock/rspec'

describe ChatopsDeployer::DestroyJob do
  let(:destroy_job) { ChatopsDeployer::DestroyJob.new }

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
      let(:host) { 'http://fake_host.example.com' }

      it 'should deploy the branch and trigger callback' do
        expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch, host)
          .and_return project
        expect(ChatopsDeployer::NginxConfig).to receive(:new).with(project)
          .and_return nginx_config
        expect(ChatopsDeployer::Container).to receive(:new).with(project)
          .and_return container
        expect(project).to receive(:logger=)
        expect(project).to receive(:sha1).and_return 'fake_sha1'
        expect(project).to receive(:branch_directory).and_return('/tmp')
        expect(project).to receive(:delete_repo).and_return('/tmp')
        expect(container).to receive(:logger=)
        expect(container).to receive(:destroy)
        expect(nginx_config).to receive(:logger=)
        expect(nginx_config).to receive(:remove)


        fake_callback = double
        expect(fake_callback).to receive(:destroy_success)
          .with("branch")
        destroy_job.perform(repository: repo, branch: branch, host: host, callbacks: [fake_callback])
      end
    end
  end
end

