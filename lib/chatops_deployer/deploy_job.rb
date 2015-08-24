require 'sucker_punch'
require 'fileutils'
require 'open3'
require 'httparty'
require 'chatops_deployer/project'
require 'chatops_deployer/nginx_config'
require 'chatops_deployer/container'

module ChatopsDeployer
  class DeployJob
    include SuckerPunch::Job

    def perform(repository:, branch:, callback_url:)
      project = Project.new(repository, branch)
      nginx_config = NginxConfig.new(project.sha1)
      container = Container.new(project.sha1)

      project.fetch_repo
      Dir.chdir(project.directory) do
        host = container.build
        if nginx_config.add(host)
          callback(callback_url, :deployment_success)
        else
          callback(callback_url, :deployment_failure)
        end
      end
    end

    private

    def callback(callback_url, status)
      body = {status: status, branch: @branch}
      if status == :deployment_success
        puts "Succesfully deployed #{@deployment_alias}.#{DEPLOYER_HOST}"
        body[:url] = "http://#{@deployment_alias}.#{DEPLOYER_HOST}"
      else
        puts "Failed deploying #{@deployment_alias}"
      end
      HTTParty.post(callback_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
