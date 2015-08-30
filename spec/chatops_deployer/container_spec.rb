require 'chatops_deployer/container'

describe ChatopsDeployer::Container do
  let(:container) { ChatopsDeployer::Container.new('fake_sha1') }
  let(:log_file) { '/var/log/chatops_deployer/fake_sha1' }
  describe '#build' do
    it 'creates a VM with docker machine' do
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine url fake_sha1', log_file: log_file)
        .and_return double(:command, success?: false)

      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine create --driver virtualbox fake_sha1', log_file: log_file)

      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine ip fake_sha1', log_file: log_file)
        .and_return double(:command, success?: true, output: '1.2.3.4')

      fake_env = <<-STR
      export KEY1="VALUE1"
      export KEY2="VALUE2"
      # some comment
      STR
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine env fake_sha1', log_file: log_file)
        .and_return double(:command, success?: true, output: fake_env)

      File.open('docker-compose.yml', 'w') do |f|
        f.puts <<-EOM
          db:
            image: postgres
          web:
            build: .
            command: bundle exec rails s -p 3000 -b '0.0.0.0'
            volumes:
              - .:/myapp
            ports:
              - "3000:3001"
            links:
              - db
        EOM
      end

      File.open('chatops_deployer.yml', 'w') do |f|
        f.puts <<-EOM
          expose:
            web: 3000
          after_build:
            web:
              - bundle exec rake db:create
        EOM
      end
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose build', log_file: log_file)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose run web bundle exec rake db:create', log_file: log_file)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose up -d', log_file: log_file)
        .and_return double(:command, success?: true)

      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose port web 3000', log_file: log_file)
        .and_return double(:command, success?: true, output: '0.0.0.0:3001')

      container.build

      expect(ENV['KEY1']).to eql 'VALUE1'
      expect(ENV['KEY2']).to eql 'VALUE2'
      expect(container.urls).to eql({'web' => '1.2.3.4:3001'})
    end
  end
end
