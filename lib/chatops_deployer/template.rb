require 'chatops_deployer/vault'

module ChatopsDeployer
  class Template
    attr_reader :env, :vault

    def initialize(input_file_path)
      @erb = ERB.new(File.read(input_file_path))
      @env = {}
      @vault = ChatopsDeployer::Vault.new
    end

    def inject(env)
      @env = env
      self
    end

    def write(output_file_path)
      File.open(output_file_path, 'w') do |f|
        f.write(@erb.result(binding))
      end
    end
  end
end
