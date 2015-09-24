require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'chatops_deployer/globals'
require 'chatops_deployer/logger'
require 'yaml'

module ChatopsDeployer
  class Container
    include Logger
    class Error < ChatopsDeployer::Error; end

    attr_reader :urls
    def initialize(project)
      @sha1 = project.sha1
      @urls = {}
      @first_run = false
      @project = project
    end

    def build
      @config = @project.config
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
        logger.info "Creating VM #{@sha1}"
        mirror_config = REGISTRY_MIRROR ? " --engine-registry-mirror=#{REGISTRY_MIRROR}" : ""
        Command.run(command: "docker-machine create --driver virtualbox #{@sha1}#{mirror_config}", logger: logger)
        mount_cache_volume
        @first_run = true
      end
      get_ip = Command.run(command: "docker-machine ip #{@sha1}", logger: logger)
      unless get_ip.success?
        raise_error('Cannot create VM for running docker containers')
      end
      @ip = get_ip.output.chomp
    end

    def setup_docker_environment
      logger.info "Setting up docker environment for #{@sha1}"
      docker_env = Command.run(command: "docker-machine env #{@sha1}", logger: logger)
      raise_error('Cannot set docker environment variables') unless docker_env.success?

      matches = []
      docker_env.output.scan(/export (?<env_key>.*)="(?<env_value>.*)"\n/){ matches << $~ }
      matches.each do |match|
        ENV[match[:env_key]] = match[:env_value]
      end
    end

    def docker_compose_run_commands
      logger.info "Running commands on containers"
      if service_commands = @config['commands']
        service_commands.each do |service, commands_hash|
          commands = if @first_run
            commands_hash['first_run'] || []
          else
            commands_hash['next_runs'] || []
          end
          logger.info "Running commands on #{service} : #{commands.inspect}"
          commands.each do |command|
            docker_compose_run = Command.run(command: "docker-compose run #{service} #{command}", logger: logger)
            raise_error("docker-compose run #{service} #{command} failed") unless docker_compose_run.success?
          end
        end
      end
    end

    def docker_compose_up
      if @first_run
        logger.info "Running docker-compose up"
        docker_compose = Command.run(command: 'docker-compose up -d', logger: logger)
        raise_error('docker-compose up failed') unless docker_compose.success?
      else
        logger.info "Running docker-compose restart"
        docker_compose = Command.run(command: 'docker-compose restart', logger: logger)
        raise_error('docker-compose restart failed') unless docker_compose.success?
      end

      if expose = @config['expose']
        expose.each do |service, ports|
          @urls[service] = ports.collect do |port|
            get_url_on_vm(service, port)
          end
        end
      end
    end

    def vm_exists?
      Command.run(command: "docker-machine url #{@sha1}", logger: logger).success?
    end

    def destroy_vm
      logger.info "Destroying VM #{@sha1}"
      system("docker-machine stop #{@sha1}") &&
        system("docker-machine rm #{@sha1}")
    end

    def get_url_on_vm(service, port)
      docker_port = Command.run(command: "docker-compose port #{service} #{port}", logger: logger)
      raise_error("Cannot find exposed port for #{port} in service #{service}") unless docker_port.success?
      port = docker_port.output.chomp.split(':').last
      [@ip, port]
    end

    def mount_cache_volume
      Command.run(command: "docker-machine stop #{@sha1}", logger: logger)
      Command.run(command: "VBoxManage sharedfolder add #{@sha1} --name cache --hostpath #{CACHE_PATH} --automount", logger: logger)
      Command.run(command: "docker-machine start #{@sha1}", logger: logger)
      cache_mount_point = @config['cache_mount_point'] || '/cache'
      Command.run(command: "docker-machine ssh #{@sha1} 'sudo mkdir -p #{cache_mount_point}'", logger: logger)
      Command.run(command: "docker-machine ssh #{@sha1} 'sudo mount -t vboxsf -o defaults,uid=`id -u docker`,gid=`id -g docker` cache #{cache_mount_point}'", logger: logger)
    end

    def raise_error(message)
      raise Error, "Container error: #{message}"
    end
  end
end
