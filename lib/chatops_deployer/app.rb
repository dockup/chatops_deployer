require 'sinatra'
require 'net/http'
require 'json'
require 'chatops_deployer/deploy_job'
require 'fileutils'

module ChatopsDeployer
  class App < Sinatra::Base
    set :port, 8000
    set :bind, '0.0.0.0'

    configure do
      [WORKSPACE, COPY_SOURCE_DIR, CACHE_PATH].each do |dir|
        FileUtils.mkdir_p dir unless Dir.exists?(dir)
      end
    end

    post '/deploy' do
      content_type :json
      json = JSON.parse(request.body.read)

      DeployJob.new.async.perform(repository: json['repository'], branch: json['branch'], callback_url: json['callback_url'])
      { log_url: LOG_URL }.to_json
    end

    post '/destroy' do
      content_type :json
      json = JSON.parse(request.body.read)

      DestroyJob.new.async.perform(repository: json['repository'], branch: json['branch'], callback_url: json['callback_url'])
    end
  end
end

ChatopsDeployer::App.run!
