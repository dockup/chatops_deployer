require 'chatops_deployer/container'

describe ChatopsDeployer::Container do
  let(:container) { ChatopsDeployer::Container.new('fake_sha1') }
  describe '#build' do
    it 'creates a VM with docker machine' do
      expect(ChatopsDeployer::Command).to receive(:run)
        .with('docker-machine url fake_sha1')
        .and_return double(:command, success?: false)

      expect(ChatopsDeployer::Command).to receive(:run)
        .with('docker-machine create --driver virtualbox fake_sha1')

      expect(ChatopsDeployer::Command).to receive(:run)
        .with('docker-machine ip fake_sha1')
        .and_return double(:command, success?: true, stdout: '1.2.3.4')

      fake_env = <<-STR
      export KEY1="VALUE1"
      export KEY2="VALUE2"
      # some comment
      STR
      expect(ChatopsDeployer::Command).to receive(:run)
        .with('docker-machine env fake_sha1')
        .and_return double(:command, success?: true, stdout: fake_env)

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
      expect(ChatopsDeployer::Command).to receive(:run)
        .with('docker-compose up -d')
        .and_return double(:command, success?: true)

      expect(ChatopsDeployer::Command).to receive(:run)
        .with('docker-compose port web 3000')
        .and_return double(:command, success?: true, stdout: '0.0.0.0:3001')

      container.build

      expect(ENV['KEY1']).to eql 'VALUE1'
      expect(ENV['KEY2']).to eql 'VALUE2'
      expect(container.host).to eql('1.2.3.4:3001')
    end
  end
end
