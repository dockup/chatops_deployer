require 'logger'
require 'open3'

module ChatopsDeployer
  class Command
    attr_reader :output

    def self.run(command: "", logger: ::Logger.new(STDOUT))
      new.run(command, logger)
    end

    def initialize
      @output = nil
      @status = nil
    end

    def run(command, logger)
      logger.info "Running command: #{command.inspect}"
      @out = []
      Open3.popen2e(*(Array(command))) do |_, out_err, thread|
        @output = out_err.read
        @status = thread.value
      end
      self
    end

    def success?
      @status && @status.success?
    end
  end
end
