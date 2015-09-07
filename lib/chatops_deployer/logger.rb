require 'logger'

module ChatopsDeployer
  class MultiIO
    def initialize(*targets)
      @targets = targets
    end

    def write(*args)
      @targets.each{|t| t.write(*args); t.flush }
    end

    def close
      @targets.each(&:close)
    end
  end

  module Logger
    def self.included(base)
      class << base
        def logger
          @logger ||= ::Logger.new($stdout)
        end

        def logger=(logger)
          @logger = logger
        end
      end
    end

    def logger
      self.class.logger
    end

    def logger=(logger)
      self.class.logger = logger
    end
  end
end
