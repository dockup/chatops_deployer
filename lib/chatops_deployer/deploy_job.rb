require 'sucker_punch'
require 'fileutils'
require 'chatops_deployer/globals'
require 'chatops_deployer/project'
require 'chatops_deployer/nginx_config'
require 'chatops_deployer/container'
require 'chatops_deployer/logger'

module ChatopsDeployer
  class DeployJob
    include SuckerPunch::Job

    def perform(repository:, branch: 'master', host: 'github.com' , config_file: 'chatops_deployer.yml', callbacks: [], clean: true)
      @project = Project.new(repository, branch, host, config_file)
      log_file = File.open(LOG_FILE, 'a')
      logger = ::Logger.new(MultiIO.new($stdout, log_file)).tap do |l|
        l.progname = project.sha1
      end

      nginx_config = NginxConfig.new(project)
      container = Container.new(project)
      [project, nginx_config, container].each do |obj|
        obj.logger = logger
      end

      project.setup_directory
      Dir.chdir(project.branch_directory) do
        if project.cloned?
          container.destroy
          if clean
            project.delete_repo_contents
            project.fetch_repo
          end
        else
          project.fetch_repo
        end
        project.read_config
        nginx_config.prepare_urls
        project.copy_files_from_deployer
        project.setup_cache_directories
        container.build
        project.update_cache
      end
      nginx_config.add_urls(container.urls)

      logger.info "Succesfully deployed #{branch}"
      callbacks.each{|c| c.deployment_success(branch, nginx_config.exposed_urls)}
    rescue ChatopsDeployer::Error => e
      reason = e.message
      logger.info "Failed deploying #{branch}. Reason: #{reason}"
      callbacks.each{|c| c.deployment_failure(branch, e)}
    end
  end
end
