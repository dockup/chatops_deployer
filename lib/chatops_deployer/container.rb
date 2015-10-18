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
      @project = project
    end

    def build
      @config = @project.config
      #create_docker_machine
      #setup_docker_environment
      docker_compose_run_commands
      docker_compose_up
    end

    def destroy
      #raise_error("Cannot destroy VM because it doesn't exist") unless vm_exists?
      #destroy_vm
      docker_compose_stop
    end

    private

    #def create_docker_machine
      #if vm_exists?
        #logger.info "VM for the branch already exists. Destroying it."
        #Command.run(command: "docker-machine rm #{@sha1}", logger: logger)
      #end
      #logger.info "Creating VM #{@sha1}"
      #mirror_config = REGISTRY_MIRROR ? " --engine-registry-mirror=#{REGISTRY_MIRROR}" : ""
      #Command.run(command: "docker-machine create --driver virtualbox #{@sha1}#{mirror_config}", logger: logger)
      #get_ip = Command.run(command: "docker-machine ip #{@sha1}", logger: logger)
      #unless get_ip.success?
        #raise_error('Cannot create VM for running docker containers')
      #end
      #@ip = get_ip.output.chomp
    #end

    #def setup_docker_environment
      #logger.info "Setting up docker environment for #{@sha1}"
      #docker_env = Command.run(command: "docker-machine env #{@sha1}", logger: logger)
      #raise_error('Cannot set docker environment variables') unless docker_env.success?

      #matches = []
      #docker_env.output.scan(/export (?<env_key>.*)="(?<env_value>.*)"\n/){ matches << $~ }
      #matches.each do |match|
        #ENV[match[:env_key]] = match[:env_value]
      #end
    #end

    def docker_compose_run_commands
      logger.info "Running commands on containers"
      commands = @config['commands']
      commands.each do |service_commands|
        service = service_commands[0]
        command = service_commands[1]
        docker_compose_run = Command.run(command: "docker-compose -p #{@sha1} run #{service} #{command}", logger: logger)
        raise_error("docker-compose -p #{@sha1} run #{service} #{command} failed") unless docker_compose_run.success?
      end
    end

    def docker_compose_up
      logger.info "Running docker-compose up"
      docker_compose = Command.run(command: "docker-compose -p #{@sha1} up -d", logger: logger)
      raise_error('docker-compose up failed') unless docker_compose.success?

      if expose = @config['expose']
        expose.each do |service, ports|
          @urls[service] = ports.collect do |port|
            #get_url_on_vm(service, port)
            #retry_on_exception(exception: Error) do
            [get_ip_of_service(service), port]
            #end
          end
        end
      end
    end

    #def vm_exists?
      #Command.run(command: "docker-machine url #{@sha1}", logger: logger).success?
    #end

    #def destroy_vm
      #logger.info "Destroying VM #{@sha1}"
      #system("docker-machine stop #{@sha1}") &&
        #system("docker-machine rm #{@sha1}")
    #end

    def docker_compose_stop
      logger.info "Stopping docker containers for project-name #{@sha1}"
      Command.run(command: "docker-compose -p #{@sha1} stop")
    end

    #def get_url_on_vm(service, port)
      #docker_port = Command.run(command: "docker-compose port #{service} #{port}", logger: logger)
      #raise_error("Cannot find exposed port for #{port} in service #{service}") unless docker_port.success?
      #port = docker_port.output.chomp.split(':').last
      #[@ip, port]
    #end

    def get_ip_of_service(service)
      container_id_command = Command.run(command: "docker-compose -p #{@sha1} ps -q #{service}", logger: logger)
      ip_command = Command.run(command: "docker inspect --format='{{.NetworkSettings.IPAddress}}' #{container_id_command.output}")
      raise_error("Cannot find ip of service #{service}") unless ip_command.success?
      ip_command.output
    end

    def raise_error(message)
      raise Error, "Container error: #{message}"
    end
  end
end
