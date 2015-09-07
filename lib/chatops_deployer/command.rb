require 'logger'
require 'open3'

module ChatopsDeployer
  class Command
    attr_reader :output

    def self.run(command: "", logger: ::Logger.new(STDOUT))
      new.run(command, logger)
    end

    def initialize
      @output = ""
      @status = nil
    end

    def run(command, logger)
      logger.info "Running command: #{command.inspect}"
      Open3.popen2e(*(Array(command))) do |_, out_err, thread|
        out_err.each_line do |line|
          logger.info line
          @output << line
        end
        @status = thread.value
      end
      self
    end

    def success?
      @status && @status.success?
    end
  end
end
