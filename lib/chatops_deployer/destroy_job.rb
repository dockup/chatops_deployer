require 'sucker_punch'
require 'fileutils'
require 'chatops_deployer/globals'
require 'chatops_deployer/project'
require 'chatops_deployer/nginx_config'
require 'chatops_deployer/container'
require 'chatops_deployer/logger'

module ChatopsDeployer
  class DestroyJob
    include SuckerPunch::Job

    def perform(repository:, branch:, host:, callbacks:[])
      @branch = branch
      @project = Project.new(repository, branch, host)
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
        @container.destroy
      end
      @nginx_config.remove
      @project.delete_repo

      @logger.info "Succesfully destroyed #{@branch}"
      callbacks.each{|c| c.destroy_success(@branch)}
    rescue ChatopsDeployer::Error => e
      reason = e.message
      @logger.info "Failed destroying #{@branch}. Reason: #{reason}"
      callbacks.each{|c| c.destroy_failure(@branch, reason)}
    end
  end
end
