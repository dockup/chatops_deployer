require 'chatops_deployer/globals'
require 'httparty'

module ChatopsDeployer
  class WebhookCallback
    def initialize(post_url)
      @post_url = post_url
    end

    def deployment_success(branch, urls)
      body = {
        urls: urls.to_json,
        status: :deployment_success,
        branch: branch
      }
      HTTParty.post(@post_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end

    def deployment_failure(branch, reason)
      body = {
        reason: reason,
        status: :deployment_failure,
        branch: branch
      }
      HTTParty.post(@post_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end

    def destroy_success(branch)
      body = {
        status: :destroy_success,
        branch: branch
      }
      HTTParty.post(@post_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end

    def destroy_failure(branch, reason)
      body = {
        reason: reason,
        status: :destroy_failure,
        branch: branch
      }
      HTTParty.post(@post_url, body: body.to_json, headers: {'Content-Type' => 'application/json'})
    end
  end
end
