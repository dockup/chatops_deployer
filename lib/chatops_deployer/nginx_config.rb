require 'chatops_deployer/globals'
require 'chatops_deployer/error'
require 'chatops_deployer/command'

module ChatopsDeployer
  class NginxConfig
    class Error < ChatopsDeployer::Error; end

    def initialize(sha1)
      @sha1 = sha1
      check_sites_enabled_dir_exists!
      @config_path = File.join NGINX_SITES_ENABLED_DIR, sha1
    end

    def exists?
      File.exists? @config_path
    end

    def add(host)
      return if exists?
      raise_error("Cannot add nginx config because host is nil") if host.nil?
      contents = <<-EOM
        server{
            listen 80;
            server_name #{@sha1}.#{DEPLOYER_HOST};

            # host error and access log
            access_log /var/log/nginx/#{@sha1}.access.log;
            error_log /var/log/nginx/#{@sha1}.error.log;

            location / {
                proxy_pass http://#{host};
            }
        }
      EOM
      puts "Adding nginx config at #{NGINX_SITES_ENABLED_DIR}/#{@sha1}"
      File.open(@config_path, 'w') do |file|
        file << contents
      end
      puts "Reloading nginx"
      Command.run('service nginx reload')
    end

    def remove
      puts "Removing nginx config"
      File.rm @config_path
      system('service nginx reload')
    end

    private

    def check_sites_enabled_dir_exists!
      unless Dir.exist? NGINX_SITES_ENABLED_DIR
        raise_error("Config directory #{NGINX_SITES_ENABLED_DIR} does not exist")
      end
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Nginx error: #{message}"
    end
  end
end
