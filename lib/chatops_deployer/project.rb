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
    class ConfigNotFoundError < Error; end

    attr_reader :sha1, :branch_directory, :config, :org, :repo
    attr_accessor :env
    def initialize(repository, branch, config_file="chatops_deployer.yml")
      @repository = repository
      @branch = branch
      @config_file = config_file
      @env = {}

      matchdata = @repository.match(/.*github.com\/(.*)\/(.*).git/)
      raise_error("Bad github repository: #{@repository}") if matchdata.nil?
      @org, @repo = matchdata.captures
      @sha1 = Digest::SHA1.hexdigest(@org + @repo + branch)
      @branch_directory = File.join(WORKSPACE, @org, @repo, 'repositories', @branch)
      @project_directory = File.join(WORKSPACE, @org, @repo)
      @common_cache_dir = File.join(@project_directory, 'cache')
    end

    def fetch_repo
      logger.info "Cloning branch #{@repository}:#{@branch}"
      git_clone = Command.run(command: ['git', 'clone', "--branch=#{@branch}", '--depth=1', @repository, '.'], logger: logger)
      unless git_clone.success?
        raise_error("Cannot clone git repository: #{@repository}, branch: #{@branch}")
      end
    end

    def delete_repo
      logger.info "Deleting #{@repository}:#{@branch}"
      FileUtils.rm_rf @branch_directory
    end

    def cloned?
      Dir.entries('.').size > 2
    end

    def delete_repo_contents
      logger.info "Deleting contents of #{@branch_directory}"
      raise_error("Need to be in #{@branch_directory} before deleting contents") unless Dir.pwd == @branch_directory
      FileUtils.rm_rf '.'
    end

    def read_config
      raise ConfigNotFoundError, "Cannot find #{@config_file}." unless validate_configs
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
      cache_directory_list = @config['cache'].to_h
      cache_directory_list.each do |directory, _|
        cache_dir = File.join(@common_cache_dir, directory)
        target_cache_dir = File.join(@branch_directory, directory)
        FileUtils.mkdir_p cache_dir
        FileUtils.mkdir_p target_cache_dir
        FileUtils.rm_rf target_cache_dir
        FileUtils.cp_r(cache_dir, target_cache_dir)
      end
    end

    def update_cache
      cache_directory_list = @config['cache'].to_h
      cache_directory_list.each do |directory, service_paths|
        service_paths.each do |service, path|
          ps = Command.run(command: ["docker-compose", "ps", "-q", service], logger: logger)
          container = ps.output.chomp
          next if container.empty?
          cache_dir = File.join(@common_cache_dir, directory)
          tmp_dir = File.join(@project_directory, 'tmp_cache')
          copy_from_container = Command.run(command: ["docker", "cp", "#{container}:#{path}", tmp_dir], logger: logger)
          raise_error("Cannot copy '#{path}' from container '#{container}' of service '#{service}'") unless copy_from_container.success?
          FileUtils.rm_rf(cache_dir)
          FileUtils.mv(tmp_dir, cache_dir)
          FileUtils.rm_rf(tmp_dir)
        end
      end
    end

    def setup_directory
      FileUtils.mkdir_p @branch_directory
      FileUtils.mkdir_p @common_cache_dir
    end

    private

    def validate_configs
      unless File.exists?(@config_file)
        logger.info "#{@config_file} not found in branch #{@branch} of #{@repository}"
        false
      else
        true
      end
    end

    def raise_error(message)
      raise Error, "Project error: #{message}"
    end
  end
end
