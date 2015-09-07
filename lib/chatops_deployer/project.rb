require 'chatops_deployer/globals'
require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'chatops_deployer/template'
require 'chatops_deployer/logger'
require 'digest/sha1'
require 'fileutils'
require 'yaml'

module ChatopsDeployer
  class Project
    include Logger
    class Error < ChatopsDeployer::Error; end

    attr_reader :sha1, :directory, :config
    attr_accessor :env
    def initialize(repository, branch, config_file="chatops_deployer.yml")
      @sha1 = Digest::SHA1.hexdigest(repository + branch)
      @directory = "#{WORKSPACE}/#{@sha1}"
      @repository = repository
      @branch = branch
      @config_file = config_file
      @env = {}
      FileUtils.mkdir_p @directory
    end

    def fetch_repo
      logger.info "Fetching #{@repository}:#{@branch}"
      if Dir.entries('.').size == 2
        logger.info "Directory not found. Cloning"
        git_clone = Command.run(command: ['git', 'clone', "--branch=#{@branch}", '--depth=1', @repository, '.'], logger: logger)
        unless git_clone.success?
          raise_error("Cannot clone git repository: #{@repository}, branch: #{@branch}")
        end
      else
        logger.info "Directory exists. Fetching"
        git_pull = Command.run(command: ['git', 'pull', 'origin', @branch], logger: logger)
        unless git_pull.success?
          raise_error("Cannot pull git repository: #{@repository}, branch: #{@branch}")
        end
      end
      @config = File.exists?(@config_file) ? YAML.load_file(@config_file) : {}
    end

    def copy_files_from_deployer
      if copy_list = @config['copy']
        logger.info "Copying files from deployer to project"
        copy_list.each do |copy_string|
          source, destination = copy_string.split(':')
          source = File.join(COPY_SOURCE_DIR, source)
          if File.extname(source) == '.erb'
            destination ||= File.basename(source, '.erb')
            logger.info "Processing ERB template #{source} into #{destination}"
            Template.new(source).inject(@env).write(destination)
          else
            destination ||= File.basename source
            logger.info "Copying #{source} into #{destination}"
            FileUtils.cp source, destination
          end
        end
      end
    end

    def raise_error(message)
      raise Error, "Project error: #{message}"
    end
  end
end
