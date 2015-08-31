require 'chatops_deployer/globals'
require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'haikunator'
require 'fileutils'

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

    def add_urls(urls)
      return if urls.nil?
      remove if exists?

      urls.each do |service, url|
        add(url)
      end
      puts "Reloading nginx"
      Command.run(command: 'service nginx reload', log_file: File.join(LOG_DIR, @sha1))
    end

    def remove
      puts "Removing nginx config"
      FileUtils.rm @config_path
      system('service nginx reload')
    end

    private

    def check_sites_enabled_dir_exists!
      unless Dir.exist? NGINX_SITES_ENABLED_DIR
        raise_error("Config directory #{NGINX_SITES_ENABLED_DIR} does not exist")
      end
    end

    def add(host)
      raise_error("Cannot add nginx config because host is nil") if host.nil?
      @haiku = Haikunator.haikunate
      contents = <<-EOM
        server{
            listen 80;
            server_name #{@haiku}.#{DEPLOYER_HOST};

            # host error and access log
            access_log /var/log/nginx/#{@haiku}.access.log;
            error_log /var/log/nginx/#{@haiku}.error.log;

            location / {
                proxy_pass http://#{host};
            }
        }
      EOM
      puts "Adding nginx config at #{NGINX_SITES_ENABLED_DIR}/#{@sha1}"
      File.open(@config_path, 'a') do |file|
        file << contents
      end
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Nginx error: #{message}"
    end
  end
end
