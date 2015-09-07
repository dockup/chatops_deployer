require 'sucker_punch'
require 'fileutils'
require 'httparty'
require 'chatops_deployer/globals'
require 'chatops_deployer/project'
require 'chatops_deployer/nginx_config'
require 'chatops_deployer/container'
require 'chatops_deployer/logger'

module ChatopsDeployer
  class DeployJob
    include SuckerPunch::Job

    def perform(repository:, branch: 'master', config_file: 'chatops_deployer.yml', callback_url:)
      @branch = branch
      @project = Project.new(repository, branch, config_file)
      log_file = File.open(LOG_FILE, 'a')
      @logger = ::Logger.new(MultiIO.new($stdout, log_file)).tap do |l|
        l.progname = @project.sha1
      end

      @nginx_config = NginxConfig.new(@project)
      @container = Container.new(@project)
      [@project, @nginx_config, @container].each do |obj|
        obj.logger = @logger
      end

      Dir.chdir(@project.directory) do
        @project.fetch_repo
        @nginx_config.prepare_urls
        @project.copy_files_from_deployer
        @container.build
      end
      @nginx_config.add_urls(@container.urls)
      callback(callback_url, :deployment_success)
    rescue ChatopsDeployer::Error => e
      @logger.error(e.message)
      callback(callback_url, :deployment_failure, e.message)
    end

    private

    def callback(callback_url, status, reason=nil)
      body = {status: status, branch: @branch}
      if status == :deployment_success
        body[:urls] = @nginx_config.readable_urls
        @logger.info "Succesfully deployed #{@branch}"
      else
        body[:reason] = reason
        @logger.info "Failed deploying #{@branch}. Reason: #{reason}"
      end
      HTTParty.post(callback_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
