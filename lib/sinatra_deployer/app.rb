require 'sinatra'
require 'net/http'
require 'json'

module SinatraDeployer
  class App < Sinatra::Base
    set :port, 8000
    set :bind, '0.0.0.0'

    post '/deploy' do
      content_type :json
      puts request.body.read.inspect

      #asynchronously fetch repo and deploy
      {key: 'value'}.to_json
    end
  end
end

SinatraDeployer::App.run!
