require 'open3'

module ChatopsDeployer
  class Command
    def self.run(command: "", log_file: nil)
      new.run(command, log_file)
    end

    def run(command, log_file)
      puts "Running command: #{command.inspect}"
      @out = []
      Open3.popen2e(*(Array(command))) do |_, out_err, thread|
        f = log_file.nil? ? nil : File.open(log_file, 'a')
        out_err.each_line do |line|
          puts line
          @out << line
          f && f.write(line) && f.flush
        end
        @status = thread.value
        f.close
      end
      self
    end

    def output
      @out.join("\n")
    end

    def success?
      @status.success?
    end
  end
end
