require 'chatops_deployer/deploy_job'
require 'chatops_deployer/destroy_job'

module ChatopsDeployer
  WORKSPACE = ENV['DEPLOYER_WORKSPACE'] || '/var/www'
  DEPLOYER_HOST = ENV['DEPLOYER_HOST'] || '127.0.0.1.xip.io'
  NGINX_SITES_ENABLED_DIR = ENV['NGINX_SITES_ENABLED_DIR'] || '/etc/nginx/sites-enabled'
end
