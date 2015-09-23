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
            - "3000:3001"
          links:
            - db
      EOM
    end

    File.open('chatops_deployer.yml', 'w') do |f|
      f.puts <<-EOM
        expose:
          web: [3000]
        commands:
          web:
            first_run:
              - bundle exec rake db:create
              - bundle exec rake db:schema:load
            next_runs:
              - bundle exec rake db:migrate
      EOM
    end
  end

  let(:project) do
    config = YAML.load_file 'chatops_deployer.yml'
    instance_double('Project', sha1: 'fake_sha1', config: config)
  end
  let(:container) { ChatopsDeployer::Container.new(project) }

  describe '#build' do
    before do
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine ip fake_sha1', logger: container.logger)
        .and_return double(:command, success?: true, output: '1.2.3.4')

      fake_env = <<-STR
      export KEY1="VALUE1"
      export KEY2="VALUE2"
      # some comment
      STR
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine env fake_sha1', logger: container.logger)
        .and_return double(:command, success?: true, output: fake_env)


      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose port web 3000', logger: container.logger)
        .and_return double(:command, success?: true, output: '0.0.0.0:3001')
      ChatopsDeployer::REGISTRY_MIRROR = "http://mirror"
    end
    it 'creates a VM with docker machine' do
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine url fake_sha1', logger: container.logger)
        .and_return double(:command, success?: false)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine create --driver virtualbox fake_sha1 --engine-registry-mirror=http://mirror', logger: container.logger)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine stop fake_sha1', logger: container.logger)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'VBoxManage sharedfolder add fake_sha1 --name cache --hostpath /etc/chatops_deployer/cache --automount', logger: container.logger)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine start fake_sha1', logger: container.logger)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: "docker-machine ssh fake_sha1 'sudo mount -t vboxsf -o uid=$UID cache /cache'", logger: container.logger)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose run web bundle exec rake db:create', logger: container.logger)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose run web bundle exec rake db:schema:load', logger: container.logger)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose up -d', logger: container.logger)
        .and_return double(:command, success?: true)

      container.build

      expect(ENV['KEY1']).to eql 'VALUE1'
      expect(ENV['KEY2']).to eql 'VALUE2'
      expect(container.urls).to eql({'web' => [['1.2.3.4','3001']]})
    end

    context 'next runs' do
      it 'runs the next_runs commands' do
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'docker-machine url fake_sha1', logger: container.logger)
          .and_return double(:command, success?: true)
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'docker-compose run web bundle exec rake db:migrate', logger: container.logger)
          .and_return double(:command, success?: true)
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'docker-compose restart', logger: container.logger)
          .and_return double(:command, success?: true)

        container.build

        expect(ENV['KEY1']).to eql 'VALUE1'
        expect(ENV['KEY2']).to eql 'VALUE2'
        expect(container.urls).to eql({'web' => [['1.2.3.4','3001']]})
      end
    end
  end
end
