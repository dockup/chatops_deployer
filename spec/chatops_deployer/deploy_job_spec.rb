require 'chatops_deployer/deploy_job'
require 'fileutils'
require 'webmock/rspec'

describe ChatopsDeployer::DeployJob do
  let(:deploy_job) { ChatopsDeployer::DeployJob.new }

  before do
    FileUtils.mkdir_p '/etc/nginx/sites-available'
  end

  describe '#perform' do
    let(:project) { instance_double('Project') }
    let(:nginx_config) { instance_double('NginxConfig') }
    let(:container) { instance_double('Container') }

    context 'happy flow - repo, branch and callback url are valid' do
      let(:repo) { 'fake_repo' }
      let(:branch) { 'branch' }
      let(:callback_url) { 'http://example.com/callback' }

      it 'should deploy the branch and trigger callback' do
        expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch)
          .and_return project
        expect(ChatopsDeployer::NginxConfig).to receive(:new).with('fake_sha1')
          .and_return nginx_config
        expect(ChatopsDeployer::Container).to receive(:new).with('fake_sha1')
          .and_return container
        expect(project).to receive(:sha1).at_least(:once).and_return 'fake_sha1'
        expect(project).to receive(:fetch_repo)
        expect(project).to receive(:directory).and_return('/tmp')
        expect(container).to receive(:build)
        expect(container).to receive(:host).at_least(:once).and_return 'fake_host'
        expect(nginx_config).to receive(:add).with('fake_host')
        expect(nginx_config).to receive(:url).at_least(:once).and_return('http://famous-five-17.example.com')

        stub_request(:post, callback_url)
          .with(
            body: {
              status: 'deployment_success',
              branch: branch,
              url: "http://famous-five-17.example.com"
            }.to_json,
            headers: {
              'Content-Type' => 'application/json'
            }
          ).to_return(status: 200)

        deploy_job.perform(repository: repo, branch: branch, callback_url: callback_url)
      end
    end

    context 'error scenario - when nginx config directory is non existent' do
      let(:repo) { 'fake_repo' }
      let(:branch) { 'branch' }
      let(:callback_url) { 'http://example.com/callback' }

      it 'trigger callback with failure status and reason' do
        expect(ChatopsDeployer::Project).to receive(:new).with(repo, branch)
          .and_return project
        expect(project).to receive(:sha1).at_least(:once).and_return 'fake_sha1'

        stub_request(:post, callback_url)
          .with(
            body: {
              status: 'deployment_failure',
              branch: branch,
              reason: "fake_sha1: Nginx error: Config directory /etc/nginx/sites-enabled does not exist"
            }.to_json,
            headers: {
              'Content-Type' => 'application/json'
            }
          ).to_return(status: 200)

        deploy_job.perform(repository: repo, branch: branch, callback_url: callback_url)
      end
    end
  end
end
