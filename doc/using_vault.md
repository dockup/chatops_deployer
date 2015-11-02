Using Vault for secrets management
==================================

[Vault](https://vaultproject.io/) is an awesome tool to securely store and
distribute secrets among your apps. The flow that we'll use for our deployer
is as follows:

## 1. Set up Vault server

The admin who sets up chatops_deployer will need to set up Vault and run the
Vault server.
Follow the [Vault deployment guide](https://vaultproject.io/intro/getting-started/deploy.html).

You'll have to generate a TLS key and cert first.

```
openssl genrsa 1024 > vault.key
chmod 400 vault.key
openssl req -new -x509 -nodes -sha1 -days 365 -key vault.key > vault.crt
```
Pass the `vault.crt` file to the person who'll be writing secrets.

Then use the following config file when starting the server :

```
backend "file" {
  path = "secret"
}

listener "tcp" {
 address = "0.0.0.0:8200"
 tls_cert_file = "vault.crt"
 tls_key_file = "vault.key"
}
```

Follow rest of the guide to complete the deployment. Please make sure you
note down the "Initial Root Token" which you get after `vault init` step.

Export the following ENV vars and start chatops_deployer
```
export VAULT_ADDR= <address where vault server is listening>
export VAULT_TOKEN= <token which can read keys stored under path secret/*>
export VAULT_CACERT= <CA certificate file to verify vault server SSL certificate>
```
## 2. Setup for each environment

### 1. Generate an access policy

Use the following template to create an ACL

Contents of `myapp-staging.hcl`
```
path "secret/myapp-staging/*" {
  policy = "write"
}
```

Use the above policy file to create a policy :

```
vault policy-write myapp-staging myapp-staging.hcl
```

### 2. Generate a token using policy

```
vault token-create -display-name="myapp-staging" -policy="myapp-staging"
```

Pass this token to the person who'll be setting the secrets.

## 3. Write secrets

The developer or the person who's to set the secrets will need to install
Vault first. Then set the following ENV vars :

export VAULT_ADDR=https://<vault server url>
export VAULT_CACERT=vault.crt
export VAULT_TOKEN=<token generated in step 2>

Now you shoud be able to set secrets for `myapp-staging`:

Create a file with secrets in JSON format:

```javascript
// secrets.json
{
  "SECRET_KEY_1": "SECRET_VALUE_1",
  "SECRET_KEY_2": "SECRET_VALUE_2"
}
```

Now write the secrets to Vault:

```bash
vault write secret/myapp-staging @secrets.json
```

Note: The `@` before the JSON filename is required.

## 4. Use secrets in `copy` files

In `chatops_deployer.yml`, use `copy` option to write a config file using the
secret. For example:

```
# chatops_deployer.yml
copy:
  - "./config/secrets.staging.yml.erb:config/secrets.yml"
```

```
# config/secrets.staging.yml.erb
staging:
  SECRET_KEY_1: <%= vault.read('secret/myapp-staging', 'SECRET_KEY_1') %>
```

chatops_deployer will expand the ERB tag by reading the secret from Vault and
write the file to the specified destination, ie, `config/secrets.yml`
