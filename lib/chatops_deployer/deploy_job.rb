require 'sucker_punch'
require 'fileutils'
require 'httparty'
require 'chatops_deployer/project'
require 'chatops_deployer/nginx_config'
require 'chatops_deployer/container'

module ChatopsDeployer
  class DeployJob
    include SuckerPunch::Job

    def perform(repository:, branch:, callback_url:)
      @branch = branch
      @project = Project.new(repository, branch)
      @nginx_config = NginxConfig.new(@project.sha1)
      @container = Container.new(@project.sha1)

      Dir.chdir(@project.directory) do
        @project.fetch_repo
        @container.build
      end
      @nginx_config.add(@container.host)
      callback(callback_url, :deployment_success)
    rescue ChatopsDeployer::Error => e
      callback(callback_url, :deployment_failure, e.message)
    end

    private

    def callback(callback_url, status, reason=nil)
      body = {status: status, branch: @branch}
      if status == :deployment_success
        body[:url] = @nginx_config.url
        puts "Succesfully deployed #{@branch} at #{@nginx_config.url}"
      else
        body[:reason] = reason
        puts "Failed deploying #{@branch}. Reason: #{reason}"
      end
      HTTParty.post(callback_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
