require 'digest/sha1'
require 'fileutils'

module ChatopsDeployer
  class Project
    class Error < StandardError; end

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
      if Dir['*'].empty?
        puts "Directory not found. Cloning"
        unless system('git', 'clone', "--branch=#{@branch}", '--depth=1', @repository, '.')
          raise_error("Cannot clone git repository: #{@repository}, branch: #{@branch}")
        end
      else
        puts "Directory exists. Fetching"
        unless system('git', 'pull', 'origin', branch)
          raise_error("Cannot pull git repository: #{@repository}, branch: #{@branch}")
        end
      end
    end

    def raise_error(message)
      raise Error, "#{@sha1}: Project error: #{message}"
    end
  end
end
