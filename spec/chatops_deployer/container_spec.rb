require 'chatops_deployer/container'

describe ChatopsDeployer::Container do
  let(:project) do
    config = YAML.load_file 'chatops_deployer.yml'
    instance_double('Project', sha1: 'fake_sha1', config: config)
  end
  let(:container) { ChatopsDeployer::Container.new(project) }
  let(:log_file) { '/var/log/chatops_deployer/fake_sha1' }
  describe '#build' do
    before do


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

      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose port web 3000', log_file: log_file)
        .and_return double(:command, success?: true, output: '0.0.0.0:3001')
    end
    it 'creates a VM with docker machine' do
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine url fake_sha1', log_file: log_file)
        .and_return double(:command, success?: false)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-machine create --driver virtualbox fake_sha1', log_file: log_file)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose run web bundle exec rake db:create', log_file: log_file)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose run web bundle exec rake db:schema:load', log_file: log_file)
        .and_return double(:command, success?: true)
      expect(ChatopsDeployer::Command).to receive(:run)
        .with(command: 'docker-compose up -d', log_file: log_file)
        .and_return double(:command, success?: true)

      container.build

      expect(ENV['KEY1']).to eql 'VALUE1'
      expect(ENV['KEY2']).to eql 'VALUE2'
      expect(container.urls).to eql({'web' => ['1.2.3.4:3001']})
    end

    context 'next runs' do
      it 'runs the next_runs commands' do
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'docker-machine url fake_sha1', log_file: log_file)
          .and_return double(:command, success?: true)
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'docker-compose run web bundle exec rake db:migrate', log_file: log_file)
          .and_return double(:command, success?: true)
        expect(ChatopsDeployer::Command).to receive(:run)
          .with(command: 'docker-compose restart', log_file: log_file)
          .and_return double(:command, success?: true)

        container.build

        expect(ENV['KEY1']).to eql 'VALUE1'
        expect(ENV['KEY2']).to eql 'VALUE2'
        expect(container.urls).to eql({'web' => ['1.2.3.4:3001']})
      end
    end
  end
end
