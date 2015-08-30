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
    end

    def build
      create_docker_machine
      setup_docker_environment
      docker_compose_build
      docker_compose_after_build
      docker_compose_up
      docker_compose_after_run
    end

    def destroy
      raise_error("Cannot destroy VM because it doesn't exist") unless vm_exists?
      destroy_vm
    end

    private

    def create_docker_machine
      raise_error("Cannot create VM because it already exists") if vm_exists?
      puts "Creating VM #{@sha1}"
      Command.run(command: "docker-machine create --driver virtualbox #{@sha1}", log_file: File.join(LOG_DIR,@sha1))
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

    def docker_compose_build
      raise_error('Cannot run docker-compose because docker-compose.yml is missing') unless File.exists?('docker-compose.yml')
      @chatops_config = File.exists?('chatops_deployer.yml') ? YAML.load_file('chatops_deployer.yml') : {}
      puts "Running docker-compose build"
      docker_compose = Command.run(command: 'docker-compose build', log_file: File.join(LOG_DIR,@sha1))
      raise_error('docker-compose build failed') unless docker_compose.success?
    end

    def docker_compose_after_build
      if after_build = @chatops_config['after_build']
        puts after_build.inspect
        after_build.each do |service, command|
          docker_compose_run = Command.run(command: "docker-compose run #{service} #{command}", log_file: File.join(LOG_DIR,@sha1))
          raise_error("docker-compose run #{service} #{command} failed") unless docker_compose_run.success?
        end
      end
    end

    def docker_compose_up
      puts "Running docker-compose up"
      docker_compose = Command.run(command: 'docker-compose up -d', log_file: File.join(LOG_DIR,@sha1))
      raise_error('docker-compose up failed') unless docker_compose.success?
    end

    def docker_compose_after_run
      puts @chatops_config.inspect
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
