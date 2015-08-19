require 'sucker_punch'
require 'fileutils'
require 'open3'

module SinatraDeployer
  class DeployJob
    include SuckerPunch::Job

    WORKSPACE = ENV['DEPLOYER_WORKSPACE'] || '/var/www'
    DEPLOYER_HOST = ENV['DEPLOYER_HOST'] || '127.0.0.1.xip.io'
    NGINX_SITES_ENABLED_DIR = ENV['NGINX_SITES_ENABLED_DIR'] || '/etc/nginx/sites-enabled'

    def perform(repository:, branch:, callback_url:)
      puts "RUNNING ASYNC === #{repository} == #{branch} == #{callback_url}"
      git_basename = repository.split('/').last
      project = File.basename(git_basename,File.extname(git_basename))
      @deployment_alias = "#{project}-#{branch}"
      @project_dir = "#{WORKSPACE}/#{project}/#{branch}"
      puts "Creating #{@project_dir} if it doesn't exist already"
      FileUtils.mkdir_p @project_dir
      Dir.chdir @project_dir

      #TODO: No error conditions are handled in the following methods.
      if fetch_repository(repository, branch) && dockerup && add_nginx_config
        #callback(callback_url, :success)
      else
        #callback(callback_url, :failure)
      end
    end

    private

    def fetch_repository(repository, branch)
      puts "Cloning #{repository}:#{branch}"
      if Dir['*'].empty?
        system("git clone --branch=#{branch} --depth=1 #{repository} .")
      else
        system("git pull origin #{branch}")
      end
    end

    def dockerup
      puts "Running docker container #{@deployment_alias}"
      system("docker build -t #{@deployment_alias} .") &&
        system("docker run -d -P --name=#{@deployment_alias} #{@deployment_alias}")
    end

    def add_nginx_config
      puts "Adding nginx config at #{NGINX_SITES_ENABLED_DIR}/#{@deployment_alias}"
      Dir.chdir(NGINX_SITES_ENABLED_DIR) do
        return false if File.exists?(@deployment_alias)

        contents <<-EOM
          server{
              listen 80;
              server_name #{@deployment_alias}.#{DEPLOYER_HOST};

              # host error and access log
              access_log /var/log/nginx/#{@deployment_alias}.access.log;
              error_log /var/log/nginx/#{@deployment_alias}.error.log;

              location / {
                  proxy_pass http://#{get_docker_host};
              }
          }
        EOM
        File.open(@deployment_alias, 'w') do |file|
          file << contents
        end
      end
    end

    def get_docker_host
      host = ""
      Open3.popen3("docker inspect --format '{{ .NetworkSettings.IPAddress }}' #{@deployment_alias}") do |i, o|
        output = o.read
        host = output.chomp
      end
      Open3.popen3("docker port #{@deployment_alias}") do |i, o|
        output = o.read
        port = output.split(':').last.chomp
        host += ":#{port}"
      end
      host
    end
  end
end
