require 'vault'

module ChatopsDeployer
  class Vault
    def read(secret, field)
      secret = ::Vault.logical.read(secret)
      secret ? secret.data[field] : nil
    end
  end
end
