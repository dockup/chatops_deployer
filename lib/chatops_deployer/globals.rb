module ChatopsDeployer
  WORKSPACE = ENV['DEPLOYER_WORKSPACE'] || '/var/www'
  DEPLOYER_HOST = ENV['DEPLOYER_HOST'] || '127.0.0.1.xip.io'
  NGINX_SITES_ENABLED_DIR = ENV['NGINX_SITES_ENABLED_DIR'] || '/etc/nginx/sites-enabled'
  LOG_FILE = ENV['DEPLOYER_LOG_FILE'] || '/var/log/chatops_deployer.log'
  COPY_SOURCE_DIR = ENV['DEPLOYER_COPY_SOURCE_DIR'] || '/etc/chatops_deployer/copy'
  LOG_URL = ENV['DEPLOYER_LOG_URL']
end

