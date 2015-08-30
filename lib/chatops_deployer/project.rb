require 'chatops_deployer/globals'
require 'chatops_deployer/error'
require 'chatops_deployer/command'
require 'digest/sha1'
require 'fileutils'

module ChatopsDeployer
  class Project
    class Error < ChatopsDeployer::Error; end

    attr_reader :sha1, :directory
    def initialize(repository, branch)
      @sha1 = Digest::SHA1.hexdigest(repository + branch)
      @directory = "#{WORKSPACE}/#{@sha1}"
      @repository = repository
      @branch = branch
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
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Project error: #{message}"
    end
  end
end
