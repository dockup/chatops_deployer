require 'chatops_deployer/globals'
require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'chatops_deployer/template'
require 'digest/sha1'
require 'fileutils'
require 'yaml'

module ChatopsDeployer
  class Project
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
      puts "Fetching #{@repository}:#{@branch}"
      if Dir.entries('.').size == 2
        puts "Directory not found. Cloning"
        git_clone = Command.run(command: ['git', 'clone', "--branch=#{@branch}", '--depth=1', @repository, '.'], log_file: File.join(LOG_DIR, @sha1))
        unless git_clone.success?
          raise_error("Cannot clone git repository: #{@repository}, branch: #{@branch}")
        end
      else
        puts "Directory exists. Fetching"
        git_pull = Command.run(command: ['git', 'pull', 'origin', @branch], log_file: File.join(LOG_DIR, @sha1))
        unless git_pull.success?
          raise_error("Cannot pull git repository: #{@repository}, branch: #{@branch}")
        end
      end
      @config = File.exists?(@config_file) ? YAML.load_file(@config_file) : {}
    end

    def copy_files_from_deployer
      if copy_list = @config['copy']
        copy_list.each do |copy_string|
          source, destination = copy_string.split(':')
          source = File.join(COPY_SOURCE_DIR, source)
          if File.extname(source) == '.erb'
            destination ||= File.basename(source, '.erb')
            Template.new(source).inject(@env).write(destination)
          else
            destination ||= File.basename source
            FileUtils.cp source, destination
            File.read(destination)
          end
        end
      end
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Project error: #{message}"
    end
  end
end
