# ChatopsDeployer

A lightweight Sinatra app that deploys staging apps of git branches
in docker containers.

Features:

* Disposable environments using docker and friends
* Simple API to deploy apps in github repos
* Hubot ready
* Works with Github webhooks
* Supports multi-container environments
* Support for secret management using Vault

## Requirements

**All commands need to be run as the root user**
So it's best if you can run this on a dedicated disposable server.

1. docker-compose - For running multi-container apps
2. nginx - For setting up a subdomain for each deployment

TODO: setup script to install requirements on Ubuntu 14.04

## Installation

    $ gem install chatops_deployer

## Usage

Set the following ENV vars:

```bash
export DEPLOYER_HOST=<hostname where nginx listens>
export DEPLOYER_WORKSPACE=<path where you want your projects to be git-cloned> # default: '/var/www'
export NGINX_SITES_ENABLED_DIR=<path to sites-enabled directory in nginx conf> # default: '/etc/nginx/sites-enabled'
export DEPLOYER_COPY_SOURCE_DIR = <path to directory containing source files to be copied over to projects> # default: '/etc/chatops_deployer/copy'
export DEPLOYER_LOG_URL = <optional URL to tail logs(if you are using something like frontail)>
export GITHUB_WEBHOOK_SECRET = <Secret used to configure github webhook (if using github webhooks to deploy)>
export GITHUB_OAUTH_TOKEN = <OAuth token which will be used to post comments on PRs (if using github webhooks)>
export DEPLOYER_DEFAULT_POST_URL = <Additional HTTP endpoint where deployment success/faulure messages are posted (optional)>

# Optional to use Vault for managing and distributing secrets
export VAULT_ADDR= <address where vault server is listening>
export VAULT_TOKEN= <token which can read keys stored under path secret/*>
export VAULT_CACERT= <CA certificate file to verify vault server SSL certificate>
```
And run the server as the root user:

    $ chatops_deployer

### Configuration

To configure an app for deployment using chatops_deployer API, you need to follow the following steps:

#### 1. Dockerize the app

Add a `docker-compose.yml` file inside the root of the app that can run the app
and the dependent services as docker containers using the command `docker-compose up`.
Refer [the docker compose docs](https://docs.docker.com/compose/) to learn how
to prepare this file for your app.

#### 2. Add chatops_deployer.yml

Add a `chatops_deployer.yml` file inside the root of the app.
This file will tell `chatops_deployer` about ports to expose as haikunated
subdomains, commands to run after cloning the repository and also if any files
need to be copied into the project after cloning it for any runtime configuration.

Here's an example `chatops_deployer.yml` :

```yaml
# `expose` is a hash in the format <service>:<array of ports>
# <service> : Service name as specified in docker-compose.yml
# <array of ports> : Ports on the container which should be exposed as subdomains
expose:
  web: [3000]

# `commands` is a list of commands that should be run inside a service container
# before all systems are go.
# Commands are run in the same order as they appear in the list.
commands:
  - [db, "./setup_script_in_container"]
  - [web, "bundle exec rake db:create"]
  - [web, "bundle exec rake db:schema:load"]

# `copy` is an array of strings in the format "<source>:<destination>"
# If source begins with './' , the source file is searched from the root of the cloned
# repo, else it is assumed to be a path to a file relative to
# /etc/chatops_deployer/copy in the deployer server.
# destination is the path relative to chatops_deployer.yml to which the source file
# should be copied. Copying of files happen soon after the repository is cloned
# and before any docker containers are created.
# If the source file ends with .erb, it's treated as an ERB template and gets
# processed. You have access to the following objects inside the ERB templates:
# "env", "vault"
#
# "env" holds the exposed urls. For example:
# "<%= env['urls']['web']['3000'] %>" will be replaced with "http://crimson-cloud-12.example.com"
#
# "vault" can be used to access secrets managed using Vault if you have set it up
# "<%= vault.read('secret/app-name/AWS_SECRET_KEY', 'value') %>" will be replaced with the secret key fetched from Vault
# using the command `vault read -field=value secret/app-name/AWS_SECRET_KEY`
copy:
  - "./config.dev.env.erb:config.env"

# `cache` is a hash in the format <directory_in_code>: {<service>: <directory_in_service>}
# <directory_in_code> is a directory under the root of the cloned repo
# where a cached directory is created.
# <service> is the name of a service which will have the cached directory in its container.
# <directory_in_service> is the absolute path of the cached directory inside the running service.
# The `cache` option allows you to share data among deployments (for faster deployments).
# Before every deployment, each cache directory is mounted under the cloned repo.
# These directories can then be used during docker build. Once the app is deployed,
# the cache directories are updated with their latest content from the running
# containers, which will be used for subsequent deployments.
cache:
  - tmp/bundler
  - node_modules
```

### Deployment

#### Using HTTP API endpoint

To deploy an app using `chatops_deployer`, send a POST request to `chatops_deployer`
like so :

```
curl -XPOST  -d '{"repository":"https://github.com/user/app.git","branch":"master","callback_url":"example.com/deployment_status"}' -H "Content-Type: application/json" localhost:8000/deploy
```

You can see that the request accepts a `callback_url`. chatops_deployer will
POST to this callback_url with the following data:

1. Success callback

Example:
```ruby
{
  "status": "deployment_success",
  "branch": "master",
  "urls": { "web" => { "3000" => "misty-meadows-123.deployer-host.com"} }
}
```

2. Failure callback

Example:
```json
{
  "status": "deployment_failure",
  "branch": "master",
  "reason": "Nginx error: Config directory /etc/nginx/sites-enabled does not exist"
}
```

#### Using Github Webhook

1. Create a Github webhook

Follow these instructions : https://developer.github.com/webhooks/creating/ .
Use `<host>:<port>/gh-webhook` as the payload URL, where `host:port` is where
chatops_deployer is running. Don't forget to set a secret when configuring the
webhook and set it in the environment variable `GITHUB_WEBHOOK_SECRET` before
starting chatops_deployer.

2. Make sure chatops_deployer can clone the repository

Create a github user solely for deploying your apps, or from your personal
account, create a Personal Access Token. Make sure this user is added to the
repository and can clone the repo and leave comments. Set this token in the
environment variable `GITHUB_OAUTH_TOKEN` before starting chatops_deployer.

Now whenever a Pull Request is opened, updated or closed, a new deployment will be triggered
and chatops_deployer will leave a comment on the PR with the URLs to access
the services deployed for the newly staged environment. This environment will
be destroyed when the PR is closed.

If you also want to get a message posted to a callback url, you can set a default
HTTP endpoint where the status will be updated, in the environment variable:
DEPLOYER_DEFAULT_POST_URL.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/code-mancers/chatops_deployer.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

