require 'open3'

module ChatopsDeployer
  class Command
    attr_reader :stdout, :stderr, :status
    def self.run(*args)
      new.run(*args)
    end

    def run(*args)
      puts "Running command: #{args.inspect}"
      @stdout, @stderr, @status = Open3.capture3(*args)
      self
    end

    def success?
      @status.success?
    end
  end
end
