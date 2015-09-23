require 'vault'

module ChatopsDeployer
  class Vault
    def read(secret, field)
      secret = ::Vault.logical.read(secret)
      secret ? secret.data[field.to_sym] : nil
    end
  end
end
