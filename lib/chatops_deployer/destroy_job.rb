require 'sucker_punch'
require 'fileutils'
require 'httparty'

module ChatopsDeployer
  class DestroyJob
    include SuckerPunch::Job

    def perform(repository:, branch:, callback_url:)
      git_basename = repository.split('/').last
      project = File.basename(git_basename,File.extname(git_basename))
      @branch = branch
      @deployment_alias = "#{project}-#{branch}"
      project_dir = "#{WORKSPACE}/#{project}/#{branch}"
      puts "Removing #{project_dir}"
      FileUtils.rm_rf project_dir

      #TODO: No error conditions are handled in the following methods.
      if remove_nginx_config && dockerdown
        callback(callback_url, :destroy_success)
      else
        callback(callback_url, :destroy_failure)
      end
    end

    private

    def dockerdown
      puts "Removing docker container #{@deployment_alias}"
      system('docker', 'stop', @deployment_alias) &&
        system('docker', 'rm', @deployment_alias)
    end

    def remove_nginx_config
      nginx_config = File.join(NGINX_SITES_ENABLED_DIR, @deployment_alias)
      return false if !File.exists?(nginx_config)

      puts "Removing nginx config at #{nginx_config}"
      File.delete(nginx_config)
      system('service nginx reload')
    end

    def callback(callback_url, status)
      body = {status: status, branch: @branch}
      if status == :destroy_success
        puts "Succesfully destroyed staging env of #{@branch}"
      else
        puts "Failed destroying staging env of #{@branch}"
      end
      HTTParty.post(callback_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
