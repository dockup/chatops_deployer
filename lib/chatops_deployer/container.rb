require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'chatops_deployer/globals'
require 'yaml'

module ChatopsDeployer
  class Container
    class Error < ChatopsDeployer::Error; end

    attr_reader :urls
    def initialize(sha1)
      @sha1 = sha1
      @urls = {}
      @first_run = false
    end

    def build
      create_docker_machine
      setup_docker_environment
      docker_compose_run_commands
      docker_compose_up
    end

    def destroy
      raise_error("Cannot destroy VM because it doesn't exist") unless vm_exists?
      destroy_vm
    end

    private

    def create_docker_machine
      unless vm_exists?
        puts "Creating VM #{@sha1}"
        Command.run(command: "docker-machine create --driver virtualbox #{@sha1}", log_file: File.join(LOG_DIR,@sha1))
        @first_run = true
      end
      get_ip = Command.run(command: "docker-machine ip #{@sha1}", log_file: File.join(LOG_DIR,@sha1))
      unless get_ip.success?
        raise_error('Cannot create VM for running docker containers')
      end
      @ip = get_ip.output.chomp
    end

    def setup_docker_environment
      puts "Setting up docker environment for #{@sha1}"
      docker_env = Command.run(command: "docker-machine env #{@sha1}", log_file: File.join(LOG_DIR,@sha1))
      raise_error('Cannot set docker environment variables') unless docker_env.success?

      matches = []
      docker_env.output.scan(/export (?<env_key>.*)="(?<env_value>.*)"\n/){ matches << $~ }
      matches.each do |match|
        ENV[match[:env_key]] = match[:env_value]
      end
    end

    def docker_compose_run_commands
      @chatops_config = File.exists?('chatops_deployer.yml') ? YAML.load_file('chatops_deployer.yml') : {}
      if service_commands = @chatops_config['commands']
        service_commands.each do |service, commands_hash|
          if @first_run
            commands = commands_hash['first_run']
          else
            commands = commands_hash['next_runs']
          end
          commands ||= []
          commands.each do |command|
            docker_compose_run = Command.run(command: "docker-compose run #{service} #{command}", log_file: File.join(LOG_DIR,@sha1))
            raise_error("docker-compose run #{service} #{command} failed") unless docker_compose_run.success?
          end
        end
      end
    end

    def docker_compose_up
      if @first_run
        puts "Running docker-compose up"
        docker_compose = Command.run(command: 'docker-compose up -d', log_file: File.join(LOG_DIR,@sha1))
        raise_error('docker-compose up failed') unless docker_compose.success?
      else
        puts "Running docker-compose restart"
        docker_compose = Command.run(command: 'docker-compose restart', log_file: File.join(LOG_DIR,@sha1))
        raise_error('docker-compose restart failed') unless docker_compose.success?
      end

      if expose = @chatops_config['expose']
        expose.each do |service, port|
          @urls[service] = get_url_on_vm(service, port)
        end
      end
    end

    def vm_exists?
      Command.run(command: "docker-machine url #{@sha1}", log_file: File.join(LOG_DIR,@sha1)).success?
    end

    def destroy_vm
      puts "Destroying VM #{@sha1}"
      system("docker-machine stop #{@sha1}") &&
        system("docker-machine rm #{@sha1}")
    end

    def get_url_on_vm(service, port)
      docker_port = Command.run(command: "docker-compose port #{service} #{port}", log_file: File.join(LOG_DIR,@sha1))
      raise_error("Cannot find exposed port for #{port} in service #{service}") unless docker_port.success?
      port = docker_port.output.chomp.split(':').last
      "#{@ip}:#{port}"
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Container error: #{message}"
    end
  end
end
