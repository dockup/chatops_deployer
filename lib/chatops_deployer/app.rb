require 'sinatra'
require 'json'
require 'chatops_deployer/deploy_job'
require 'chatops_deployer/destroy_job'
require 'chatops_deployer/github_comment_callback'
require 'chatops_deployer/webhook_callback'
require 'fileutils'

module ChatopsDeployer
  class App < Sinatra::Base
    set :port, 8000
    set :bind, '0.0.0.0'

    configure do
      [WORKSPACE, COPY_SOURCE_DIR].each do |dir|
        FileUtils.mkdir_p dir unless Dir.exists?(dir)
      end
    end


    post '/deploy' do
      content_type :json
      json = JSON.parse(request.body.read)
      post_url = json['callback_url']

      DeployJob.new.async.perform(
        repository: json['repository'],
        branch: json['branch'],
        callbacks: [WebhookCallback.new(post_url)]
      )
      { log_url: LOG_URL }.to_json
    end

    post '/destroy' do
      content_type :json
      json = JSON.parse(request.body.read)
      post_url = json['callback_url']

      DestroyJob.new.async.perform(
        repository: json['repository'],
        branch: json['branch'],
        callbacks: [WebhookCallback.new(post_url)]
      )
    end

    post '/gh-webhook' do
      payload_body = request.body.read
      verify_signature(payload_body)
      payload = JSON.parse(payload_body)

      if payload['pull_request']
        comments_url = payload['pull_request']['comments_url']
        repository = payload['repository']['clone_url']
        branch = payload['pull_request']['head']['ref']

        case payload['action']
        when 'opened', 'synchronize', 'reopened'
          callbacks = [GithubCommentCallback.new(comments_url)]
          callbacks.push(WebhookCallback.new(DEFAULT_POST_URL)) if DEFAULT_POST_URL
          DeployJob.new.async.perform(
            repository: repository,
            branch: branch,
            callbacks: callbacks
          )
        when 'closed'
          callbacks = []
          callbacks.push(WebhookCallback.new(DEFAULT_POST_URL)) if DEFAULT_POST_URL
          DestroyJob.new.async.perform(repository: repository, branch: branch, callbacks: callbacks)
        end
      end
    end

    def verify_signature(payload_body)
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), GITHUB_WEBHOOK_SECRET, payload_body)
      return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
    end
  end
end

ChatopsDeployer::App.run!
