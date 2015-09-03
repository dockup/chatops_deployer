module ChatopsDeployer
  WORKSPACE = ENV['DEPLOYER_WORKSPACE'] || '/var/www'
  DEPLOYER_HOST = ENV['DEPLOYER_HOST'] || '127.0.0.1.xip.io'
  NGINX_SITES_ENABLED_DIR = ENV['NGINX_SITES_ENABLED_DIR'] || '/etc/nginx/sites-enabled'
  LOG_DIR = ENV['DEPLOYER_LOG_DIR'] || '/var/log/chatops_deployer'
  COPY_SOURCE_DIR = ENV['DEPLOYER_COPY_SOURCE_DIR'] || '/etc/chatops_deployer/copy'

  def log_file(sha1)
    File.join(LOG_DIR, sha1)
  end
end

