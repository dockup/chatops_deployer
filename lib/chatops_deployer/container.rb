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
      docker_compose_build
      docker_compose_run_commands
      docker_compose_up
    end

    def destroy
      docker_compose_stop
      docker_compose_rm
    end

    private

    def docker_compose_build
      logger.info "Building images"
      build_command = Command.run(command: ["docker-compose", "-p", @sha1, "build"], logger: logger)
      raise_error("docker-compose -p #{@sha1} build failed") unless build_command.success?
    end

    def docker_compose_run_commands
      logger.info "Running commands on containers"
      commands = @config['commands']
      unless commands
        logger.info "No commands to run"
        return
      end
      commands.each do |service_commands|
        service = service_commands[0]
        command = service_commands[1]
        docker_compose_run = Command.run(command: ["docker-compose", "-p", @sha1, "run", service] + command.split(' '), logger: logger)
        raise_error("docker-compose -p #{@sha1} run #{service} #{command} failed") unless docker_compose_run.success?
      end
    end

    def docker_compose_up
      logger.info "Running docker-compose up"
      docker_compose = Command.run(command: ["docker-compose", "-p", @sha1, "up", "-d"], logger: logger)
      raise_error('docker-compose up failed') unless docker_compose.success?

      if expose = @config['expose']
        expose.each do |service, ports|
          @urls[service] = ports.collect do |port|
            [get_ip_of_service(service), port.to_s]
          end
        end
      end
    end

    def docker_compose_stop
      logger.info "Stopping docker containers for project-name #{@sha1}"
      Command.run(command: ["docker-compose", "-p", @sha1, "stop"], logger: logger)
    end

    def docker_compose_rm
      logger.info "Removing docker containers for project-name #{@sha1}"
      Command.run(command: ["docker-compose", "-p", @sha1, "rm", "-f", "-v"], logger: logger)
    end

    def get_ip_of_service(service)
      container_id_command = Command.run(command: ["docker-compose", "-p", @sha1, "ps", "-q", service], logger: logger)
      ip_command = Command.run(command: ["docker", "inspect", "--format='{{.NetworkSettings.IPAddress}}'", container_id_command.output.chomp], logger: logger)
      raise_error("Cannot find ip of service #{service}") unless ip_command.success?
      ip_command.output.chomp
    end

    def raise_error(message)
      raise Error, "Container error: #{message}"
    end
  end
end
