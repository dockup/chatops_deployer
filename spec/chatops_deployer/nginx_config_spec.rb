require 'chatops_deployer/nginx_config'
require 'fileutils'

describe ChatopsDeployer::NginxConfig do
  let(:sha1) { 'fake_sha1' }
  let(:project) { instance_double('Project', sha1: 'fake_sha1') }
  let(:nginx_config) { ChatopsDeployer::NginxConfig.new(project) }

  before do
    FileUtils.mkdir_p ChatopsDeployer::NGINX_SITES_ENABLED_DIR
  end

  describe 'initialize' do
    subject{ nginx_config }
    context 'when sites-enabled dir does not exist' do
      before do
        FileUtils.rm_rf ChatopsDeployer::NGINX_SITES_ENABLED_DIR
      end
      it "raises error" do
        expect{ subject }
          .to raise_error ChatopsDeployer::NginxConfig::Error,
            'fake_sha1: Nginx error: Config directory /etc/nginx/sites-enabled does not exist'
      end
    end

    context 'when sites-enabled dir exists' do
      it "raises error" do
        expect{ subject }.not_to raise_error
      end
    end
  end

  describe '#exists?' do
    subject { nginx_config.exists? }
    context 'when the nginx config exists' do
      before do
        File.open(File.join(ChatopsDeployer::NGINX_SITES_ENABLED_DIR, sha1), 'w')
      end
      it { is_expected.to be_truthy }
    end

    context 'when the nginx config does not exist' do
      it { is_expected.to be_falsey }
    end
  end

  describe '#add_urls' do
    context 'when host is nil' do
      it 'raises error' do
        expect { nginx_config.add_urls({web: [nil]}) }
          .to raise_error ChatopsDeployer::NginxConfig::Error,
            'fake_sha1: Nginx error: Cannot add nginx config because host is nil'
      end
    end

    context 'when host is present' do
      it 'creates an nginx config' do
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'service nginx reload', log_file: '/var/log/chatops_deployer/fake_sha1')
        expect(Haikunator).to receive(:haikunate).and_return('shy-surf-3571')
        expect(Haikunator).to receive(:haikunate).and_return('long-flower-2811')

        nginx_config.add_urls({web: ['fake_host'], admin: ['fake_host2']})

        expect(File.read('/etc/nginx/sites-enabled/fake_sha1')).to eql <<-EOM
        server{
            listen 80;
            server_name shy-surf-3571.127.0.0.1.xip.io;

            # host error and access log
            access_log /var/log/nginx/shy-surf-3571.access.log;
            error_log /var/log/nginx/shy-surf-3571.error.log;

            location / {
                proxy_pass http://fake_host;
            }
        }
        server{
            listen 80;
            server_name long-flower-2811.127.0.0.1.xip.io;

            # host error and access log
            access_log /var/log/nginx/long-flower-2811.access.log;
            error_log /var/log/nginx/long-flower-2811.error.log;

            location / {
                proxy_pass http://fake_host2;
            }
        }
      EOM
      end
    end
  end
end
