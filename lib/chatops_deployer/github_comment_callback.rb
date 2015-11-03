require 'chatops_deployer/project'
require 'chatops_deployer/globals'
require 'chatops_deployer/webhook_callback'
require 'json'
require 'httparty'

module ChatopsDeployer
  class GithubCommentCallback
    def initialize(comments_url)
      @comments_url = comments_url
    end

    def deployment_success(branch, urls)
      WebhookCallback.new(DEFAULT_POST_URL).deployment_success(branch, urls)

      links = urls.collect do |service, urls|
        urls.collect do |port, url|
          "[#{service} (port: #{port})](#{url})"
        end.join(', ')
      end.join(', ')
      body = "Deployed branch #{branch} at url: #{links}"
      HTTParty.post(@comments_url, body: {body: body}.to_json, headers: {
        'Authorization' => "token #{GITHUB_OAUTH_TOKEN}",
        'User-Agent' => 'chatops_deployer' #Mandatory field, just passing random value
      })
    end

    def deployment_failure(branch, error)
      return if error.is_a? Project::ConfigNotFoundError

      WebhookCallback.new(DEFAULT_POST_URL).deployment_failure(branch, error)
      body = "Could not deploy branch: #{branch}. Reason: #{error.message}."
      HTTParty.post(@comments_url, body: {body: body}.to_json, headers: {
        'Authorization' => "token #{GITHUB_OAUTH_TOKEN}",
        'User-Agent' => 'chatops_deployer' #Mandatory field, just passing random value
      })
    end

    def destroy_success(branch)
      # NOOP
    end

    def destroy_failure(branch, error)
      # NOOP
    end
  end
end
