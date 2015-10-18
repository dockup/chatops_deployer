require 'sucker_punch'
require 'fileutils'
require 'httparty'

module ChatopsDeployer
  class DestroyJob
    include SuckerPunch::Job

    def perform(repository:, branch:, callback_url:)
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
        @container.destroy
      end
      @nginx_config.remove
      @project.delete_repo
      callback(callback_url, :destroy_success)
    rescue ChatopsDeployer::Error => e
      @logger.error(e.message)
      callback(callback_url, :destroy_failure, e.message)
    end

    private

    def callback(callback_url, status, reason=nil)
      body = {status: status, branch: @branch}
      if status == :destroy_success
        @logger.info "Succesfully destroyed #{@branch}"
      else
        body[:reason] = reason
        @logger.info "Failed destroying #{@branch}. Reason: #{reason}"
      end
      HTTParty.post(callback_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
