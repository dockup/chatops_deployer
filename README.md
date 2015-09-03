# ChatopsDeployer

A lightweight Sinatra app that deploys staging apps of git branches
in docker containers. Meant to be used with hubot.

## Requirements

**All commands need to be run as the root user**
So it's best if you can run this on a dedicated disposable server.

1. virtualbox - For creating isolated VMs for each project
3. docker-machine - For starting docker daemons on VMs
2. docker-compose - For running multi-container apps using docker daemons on VMs
4. nginx - For setting up a subdomain for each deployment

TODO: setup script to install requirements on Ubuntu 14.04

## Installation

    $ gem install chatops_deployer

## Usage

Set the following ENV vars:

```bash
export DEPLOYER_HOST=<hostname where nginx listens>
export WORKSPACE=<path where you want your projects to be git-cloned> # default: '/var/www'
export NGINX_SITES_ENABLED_DIR=<path to sites-enabled directory in nginx conf> # default: '/etc/nginx/sites-enabled'
export COPY_SOURCE_DIR = <path to directory containing source files to be copied over to projects> # default: '/etc/chatops_deployer/copy'
```
And run the server as the root user:

    $ chatops_deployer

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/code-mancers/chatops_deployer.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

