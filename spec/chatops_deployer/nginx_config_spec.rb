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
            'Nginx error: Config directory /etc/nginx/sites-enabled does not exist'
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
    context 'when exposed urls are not loaded' do
      it 'raises error' do
        expect { nginx_config.add_urls({"web" => ['1.2.3.4', '3000']}) }
          .to raise_error ChatopsDeployer::NginxConfig::Error,
            'Nginx error: Cannot add nginx config because exposed ports could not be read from chatops_deployer.yml'
      end
    end

    context 'when exported urls are loaded' do
      let(:fake_env) { {} }
      before do
        allow(project).to receive(:env).and_return(fake_env)
        expect(nginx_config).to receive(:service_ports_from_config).and_return({ 'web' => [3000, 3001], 'admin' => [8080]})
        expect(Haikunator).to receive(:haikunate).and_return('shy-surf-3571')
        expect(Haikunator).to receive(:haikunate).and_return('long-flower-2811')
        expect(Haikunator).to receive(:haikunate).and_return('crimson-meadow-2')
        nginx_config.prepare_urls

        expect(nginx_config.urls).to eql({
          "web" => {
            "3000" => "shy-surf-3571.127.0.0.1.xip.io",
            "3001" => "long-flower-2811.127.0.0.1.xip.io"
          },
          "admin" => {
            "8080" => "crimson-meadow-2.127.0.0.1.xip.io"
          }
        })

        expect(fake_env).to eql({
          "urls" => {
            "web" => {
              "3000" => "http://shy-surf-3571.127.0.0.1.xip.io",
              "3001" => "http://long-flower-2811.127.0.0.1.xip.io"
            },
            "admin" => {
              "8080" => "http://crimson-meadow-2.127.0.0.1.xip.io"
            }
          }
        })
      end
      it 'creates an nginx config' do
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'service nginx reload', logger: nginx_config.logger)
          .and_return(double(:command, success?: true))

        nginx_config.add_urls({"web" => [['fake_host', '3000'], ['fake_host', '3001']], "admin" => [['fake_host2','8080']]})

        expect(File.read('/etc/nginx/sites-enabled/fake_sha1')).to eql <<-EOM
        server{
            listen 80;
            server_name shy-surf-3571.127.0.0.1.xip.io;

            # host error and access log
            access_log /var/log/nginx/shy-surf-3571.127.0.0.1.xip.io.access.log;
            error_log /var/log/nginx/shy-surf-3571.127.0.0.1.xip.io.error.log;

            location / {
                proxy_pass http://fake_host:3000;
                proxy_set_header Host $host;
            }
        }
        server{
            listen 80;
            server_name long-flower-2811.127.0.0.1.xip.io;

            # host error and access log
            access_log /var/log/nginx/long-flower-2811.127.0.0.1.xip.io.access.log;
            error_log /var/log/nginx/long-flower-2811.127.0.0.1.xip.io.error.log;

            location / {
                proxy_pass http://fake_host:3001;
                proxy_set_header Host $host;
            }
        }
        server{
            listen 80;
            server_name crimson-meadow-2.127.0.0.1.xip.io;

            # host error and access log
            access_log /var/log/nginx/crimson-meadow-2.127.0.0.1.xip.io.access.log;
            error_log /var/log/nginx/crimson-meadow-2.127.0.0.1.xip.io.error.log;

            location / {
                proxy_pass http://fake_host2:8080;
                proxy_set_header Host $host;
            }
        }
      EOM
      end
    end
  end
end
