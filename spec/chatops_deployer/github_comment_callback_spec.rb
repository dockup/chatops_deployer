require 'chatops_deployer/github_comment_callback'
require 'webmock/rspec'

describe ChatopsDeployer::GithubCommentCallback do
  let(:endpoint) { 'http://fake-endpoint' }
  let(:callback) { ChatopsDeployer::GithubCommentCallback.new(endpoint) }
  before do
    ChatopsDeployer::GITHUB_OAUTH_TOKEN = 'fake_token'
  end

  describe '#deployment_success' do
    let(:exposed_urls) do
      {
        'web' => {'3000' => 'url1', '3001' => 'url2'},
        'db' => {'1234' => 'url3'}
      }
    end

    it 'sends an HTTP POST request to the comments_url with markdown comment text' do
      stub_request(:post, endpoint)
        .with(
          body: {
            body: "Deployed branch branch at url: [web (port: 3000)](url1), [web (port: 3001)](url2), [db (port: 1234)](url3)"
          }.to_json,
          headers: {
            'Authorization'=>'token fake_token',
            'User-Agent'=>'chatops_deployer'
          }
        ).to_return(status: 200)
      callback.deployment_success('branch', exposed_urls)
    end
  end

  describe '#deployment_failure' do
    it 'sends an HTTP POST request to the callback url with failure reason' do
      stub_request(:post, endpoint)
        .with(
          body: {
            body: "Could not deploy branch: branch. Reason: failure_reason."
          }.to_json,
          headers: {
            'Authorization'=>'token fake_token',
            'User-Agent'=>'chatops_deployer'
          }
        ).to_return(status: 200)
      callback.deployment_failure('branch', 'failure_reason')
    end
  end
end

