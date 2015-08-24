require 'open3'

module ChatopsDeployer
  class Container
    class Error < StandardError;end
    def initialize(sha1)
      @sha1
    end

    def build
      create_docker_machine
      setup_docker_environment
      host = docker_compose
      host
    end

    def destroy
      raise_error("Cannot destroy VM because it doesn't exist") unless vm_exists?
      destroy_vm
    end

    private

    def create_docker_machine
      raise_error("Cannot create VM because it already exists") if vm_exists?
      puts "Creating VM #{@sha1}"
      system "docker-machine create --driver virtualbox #{@sha1}"
      Open3.popen3("docker-machine ip #{@sha1}") do |i, o, err, thread|
        raise_error('Cannot create VM for running docker containers') unless thread.value.success?
        @ip = o.read.chomp
      end
    end

    def setup_docker_environment
      puts "Setting up docker environment for #{@sha1}"
      Open3.popen3("docker-machine env #{@sha1}") do |i, o, err, thread|
        raise_error('Cannot set docker environment variables') unless thread.value.success?
        output = o.read
        matches = []
        output.scan(/export (?<env_key>.*)="(?<env_value>.*)"\n/){ matches << $~ }
        matches.each do |match|
          ENV[match[:env_key]] = match[:env_value]
        end
      end
    end

    def docker_compose
      raise_error('Cannot run docker-compose because docker-compose.yml is missing') unless File.exists?('docker-compose.yml')
      puts "Running docker-compose up"
      if system("docker-compose up -d")
        "#{@ip}:#{get_port}"
      else
        raise_error('docker-compose failed')
      end
    end

    def vm_exists?
      system("docker-machine url #{@sha1}")
    end

    def destroy_vm
      puts "Destroying VM #{@sha1}"
      system("docker-machine stop #{@sha1}") &&
        system("docker-machine rm #{@sha1}")
    end

    def get_port
      services_with_ports = YAML.load_file('docker-compose.yml').select{|k,v| v.has_key?('ports')}
      raise_error("docker-compose.yml does not expose any port") if services_with_ports.empty?
      #TODO: We're now picking the first port we find in docker-compose as the
      # primary web service port. There should be a way to specify which port
      # of which service should be used as the http port
      service, config = services_with_ports.first
      first_port = config['ports']
        .first # "3000:3000" or "3000"
        .split(':') # ["3000",...]
        .first # "3000"
      Open3.popen3("docker-compose port #{service} #{first_port}") do |i, o|
        begin
          port = o.read.chomp.split(':').last
          return port
        rescue
          raise_error("Cannot find exposed port for #{first_port} in service #{service}")
        end
      end
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Container error: #{message}"
    end
  end
end
