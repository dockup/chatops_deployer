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

    attr_reader :sha1, :branch_directory, :config
    attr_accessor :env
    def initialize(repository, branch, config_file="chatops_deployer.yml")
      @sha1 = Digest::SHA1.hexdigest(repository + branch)
      @repository = repository
      @branch = branch
      @config_file = config_file
      @env = {}
      setup_project_directory
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
    end

    def read_config
      @config = if File.exists?(@config_file)
        begin
          YAML.load_file(@config_file) || {}
        rescue StandardError => e
          raise_error("Cannot parse YAML content in #{@config_file}")
        end
      else
        {}
      end
    end

    def copy_files_from_deployer
      copy_list = @config['copy'].to_a
      return if copy_list.empty?
      logger.info "Copying files from deployer to project"
      copy_list.each do |copy_string|
        source, destination = copy_string.split(':')
        # source is from COPY_SOURCE_DIR if source doesn't start with ./
        source = File.join(COPY_SOURCE_DIR, source) unless source.match(/^\.\//)
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

    def setup_cache_directories
      cache_directory_list = @config['cache'].to_a
      return if cache_directory_list.empty?
      cache_directory_list.each do |directory|
        cache_dir = File.join(@project_directory, 'cache', directory)
        target_cache_dir = File.join(@branch_directory, directory)
        FileUtils.mkdir_p cache_dir
        FileUtils.mkdir_p target_cache_dir
        Dir.rmdir target_cache_dir
        File.symlink(cache_dir, target_cache_dir)
      end
    end

    private

    def setup_project_directory
      matchdata = @repository.match(/.*github.com\/(.*)\/(.*).git/)
      raise_error("Bad github repository: #{@repository}") if matchdata.nil?
      org, repo = matchdata.captures
      @branch_directory = File.join(WORKSPACE, org, repo, @branch)
      @project_directory = File.join(WORKSPACE, org, repo)
      FileUtils.mkdir_p @branch_directory
      FileUtils.mkdir_p File.join(@project_directory, 'cache')
    end

    def project_directory(repository, branch)
      matchdata = repository.match(/.*github.com\/(.*)\/(.*).git/)
      raise_error("Bad github repository: #{repository}") if matchdata.nil?
      org, repo = matchdata.captures
      File.join(org, repo, branch)
    end

    def raise_error(message)
      raise Error, "Project error: #{message}"
    end
  end
end
