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

      Dir.chdir(@project.branch_directory) do
        if @project.exists?
          @container.destroy
          @project.delete_repo
        end
        @project.fetch_repo
        @project.read_config
        @nginx_config.prepare_urls
        @project.copy_files_from_deployer
        @project.setup_cache_directories
        @container.build
        @project.update_cache
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
