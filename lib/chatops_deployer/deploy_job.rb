require 'sucker_punch'
require 'fileutils'
require 'httparty'
require 'chatops_deployer/project'
require 'chatops_deployer/nginx_config'
require 'chatops_deployer/container'

module ChatopsDeployer
  class DeployJob
    include SuckerPunch::Job

    def perform(repository:, branch: 'master', config_file: 'chatops_deployer.yml', callback_url:)
      @branch = branch
      @project = Project.new(repository, branch, config_file)
      @nginx_config = NginxConfig.new(@project)
      @container = Container.new(@project)

      Dir.chdir(@project.directory) do
        @project.fetch_repo
        @nginx_config.prepare_urls
        @project.copy_files_from_deployer
        @container.build
      end
      @nginx_config.add_urls(@container.urls)
      callback(callback_url, :deployment_success)
    rescue ChatopsDeployer::Error => e
      callback(callback_url, :deployment_failure, e.message)
    end

    private

    def callback(callback_url, status, reason=nil)
      body = {status: status, branch: @branch}
      if status == :deployment_success
        body[:urls] = @nginx_config.readable_urls
        puts "Succesfully deployed #{@branch}"
      else
        body[:reason] = reason
        puts "Failed deploying #{@branch}. Reason: #{reason}"
      end
      HTTParty.post(callback_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
