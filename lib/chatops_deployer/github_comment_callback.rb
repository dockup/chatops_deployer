require 'chatops_deployer/globals'
require 'json'
require 'httparty'

module ChatopsDeployer
  class GithubCommentCallback
    def initialize(comments_url)
      @comments_url = comments_url
    end

    def deployment_success(branch, urls)
      links = urls.collect do |service, urls|
        urls.collect do |port, url|
          "[#{service} (port: #{port})](#{url})"
        end.join(', ')
      end.join(', ')
      body = "Staged branch #{branch} at url: #{links}"
      HTTParty.post(@comments_url, body: {body: body}.to_json, headers: {
        'Authorization' => "token #{GITHUB_OAUTH_TOKEN}",
        'User-Agent' => 'chatops_deployer' #Mandatory field, just passing random value
      })
    end

    def deployment_failure(branch, reason)
      body = "Could not stage branch: #{branch}. Reason: #{reason}."
      HTTParty.post(@comments_url, body: {body: body}.to_json, headers: {
        'Authorization' => "token #{GITHUB_OAUTH_TOKEN}",
        'User-Agent' => 'chatops_deployer' #Mandatory field, just passing random value
      })
    end

    def destroy_success
      # NOOP
    end

    def destroy_failure
      # NOOP
    end
  end
end
