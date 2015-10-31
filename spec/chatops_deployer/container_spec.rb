require 'chatops_deployer/container'

describe ChatopsDeployer::Container do
  before do
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
            - "3000"
          links:
            - db
      EOM
    end

    File.open('chatops_deployer.yml', 'w') do |f|
      f.puts <<-EOM
        expose:
          web: [3000]
        commands:
          - [web, "bundle exec rake db:create"]
          - [web, "bundle exec rake db:schema:load"]
      EOM
    end
  end

  let(:project) do
    config = YAML.load_file 'chatops_deployer.yml'
    instance_double('Project', sha1: 'fake_sha1', config: config)
  end
  let(:container) { ChatopsDeployer::Container.new(project) }

  describe '#build' do
    it 'uses docker-compose create the environment' do
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: ['docker-compose', '-p', 'fake_sha1', 'build'], logger: container.logger)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: ['docker-compose', '-p', 'fake_sha1', 'run', 'web', 'bundle', 'exec', 'rake', 'db:create'], logger: container.logger)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: ["docker-compose", "-p", "fake_sha1", "run", "web", 'bundle', 'exec', 'rake', 'db:schema:load'], logger: container.logger)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: ['docker-compose', '-p', 'fake_sha1', 'up', '-d'], logger: container.logger)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: ['docker-compose', '-p', 'fake_sha1', 'ps', '-q', 'web'], logger: container.logger)
        .and_return double(:command, success?: true, output: 'fake_container_id')
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: ["docker", "inspect", "--format='{{.NetworkSettings.IPAddress}}'", "fake_container_id"], logger: container.logger)
        .and_return double(:command, success?: true, output: 'docker_ip')

      container.build

      expect(container.urls).to eql({'web' => [['docker_ip','3000']]})
    end
  end
end
