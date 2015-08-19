require 'sinatra'
require 'net/http'
require 'json'
require 'sinatra_deployer/deploy_job'

module SinatraDeployer
  class App < Sinatra::Base
    set :port, 8000
    set :bind, '0.0.0.0'

    post '/deploy' do
      content_type :json
      json = JSON.parse(request.body.read)

      DeployJob.new.async.perform(repository: json['repository'], branch: json['branch'], callback_url: json['callback_url'])
    end
  end
end

SinatraDeployer::App.run!
