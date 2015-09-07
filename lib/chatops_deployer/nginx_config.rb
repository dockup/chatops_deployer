require 'chatops_deployer/globals'
require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'haikunator'
require 'fileutils'
require 'chatops_deployer/logger'

module ChatopsDeployer
  class NginxConfig
    include Logger
    attr_reader :urls

    class Error < ChatopsDeployer::Error; end

    def initialize(project)
      @sha1 = project.sha1
      @project = project
      check_sites_enabled_dir_exists!
      @config_path = File.join NGINX_SITES_ENABLED_DIR, @sha1
      @urls = {}
    end

    def exists?
      File.exists? @config_path
    end

    # service_urls is an array in the format:
    # {"web" => [["10.1.1.2", "3000"],["10.1.1.2", "4000"]] }
    def add_urls(service_urls)
      return if service_urls.nil?
      remove if exists?

      service_urls.each do |service, internal_urls|
        Array(internal_urls).each do |internal_url|
          expose(service, internal_url)
        end
      end
      logger.info "Reloading nginx"
      nginx_reload = Command.run(command: 'service nginx reload', logger: logger)
      unless nginx_reload.success?
        raise_error("Cannot reload nginx after adding config. Check #{NGINX_SITES_ENABLED_DIR}/#{@sha1} for errors")
      end
    end

    def remove
      logger.info "Removing nginx config"
      FileUtils.rm @config_path
      system('service nginx reload')
    end

    def readable_urls
      urls = {}
      @urls.each do |service, port_exposed_urls|
        urls[service] = port_exposed_urls.collect do |port, exposed_url|
          exposed_url
        end
      end
      urls.to_json
    end

    def prepare_urls
      service_ports_from_config.each do |service, ports|
        @urls[service] = {}
        ports.each do |port|
          @urls[service][port.to_s] = generate_haikunated_url
        end
      end
      @project.env['urls'] = @urls
    end

    private

    def check_sites_enabled_dir_exists!
      unless Dir.exist? NGINX_SITES_ENABLED_DIR
        raise_error("Config directory #{NGINX_SITES_ENABLED_DIR} does not exist")
      end
    end

    def service_ports_from_config
      @project.config['expose'] || {}
    end

    def generate_haikunated_url
      haiku = Haikunator.haikunate
      "#{haiku}.#{DEPLOYER_HOST}"
    end

    # service => name of service , example: "web"
    # internal_url => a pair of ip and port, example: ["10.1.1.2", "3000"]
    def expose(service, internal_url)
      raise_error("Cannot add nginx config because host is nil") if internal_url.nil? || internal_url.empty?
      ip = internal_url[0]
      port = internal_url[1]
      begin
        exposed_url = @urls[service][port]
      rescue
        raise_error("Cannot add nginx config because exposed ports could not be read from chatops_deployer.yml")
      end
      contents = <<-EOM
        server{
            listen 80;
            server_name #{exposed_url};

            # host error and access log
            access_log /var/log/nginx/#{exposed_url}.access.log;
            error_log /var/log/nginx/#{exposed_url}.error.log;

            location / {
                proxy_pass http://#{ip}:#{port};
            }
        }
      EOM
      logger.info "Adding nginx config at #{NGINX_SITES_ENABLED_DIR}/#{@sha1}"
      File.open(@config_path, 'a') do |file|
        file << contents
      end
    end

    def raise_error(message)
      raise Error, "Nginx error: #{message}"
    end
  end
end
