require 'chatops_deployer/github_comment_callback'
require 'webmock/rspec'

describe ChatopsDeployer::GithubCommentCallback do
  let(:endpoint) { 'http://fake-endpoint' }
  let(:default_post_url) { 'http://default_post_url' }
  let(:callback) { ChatopsDeployer::GithubCommentCallback.new(endpoint) }
  before do
    ChatopsDeployer::GITHUB_OAUTH_TOKEN = 'fake_token'
    ChatopsDeployer::DEFAULT_POST_URL = default_post_url
  end

  describe '#deployment_success' do
    let(:exposed_urls) do
      {
        'web' => {'3000' => 'url1', '3001' => 'url2'},
        'db' => {'1234' => 'url3'}
      }
    end

    it 'sends an HTTP POST request to the comments_url with markdown comment text and DEFAULT_POST_URL' do
      stub_request(:post, default_post_url)
        .with(
          body: {
            urls: exposed_urls.to_json,
            status: 'deployment_success',
            branch: 'branch'
          }.to_json,
          headers: {
            'Content-Type' => 'application/json'
          }
        ).to_return(status: 200)

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
    it 'sends an HTTP POST request to comments_url and DEFAULT_POST_URL with failure reason' do
      stub_request(:post, default_post_url)
        .with(
          body: {
            reason: 'failure_reason',
            status: 'deployment_failure',
            branch: 'branch'
          }.to_json,
          headers: {
            'Content-Type' => 'application/json'
          }
        ).to_return(status: 200)

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
      callback.deployment_failure('branch', instance_double("Error", message: 'failure_reason'))
    end

    context 'when the error is about not having config files for deployment' do
      it 'ignores the error and does not make any HTTP requests' do
        error = ChatopsDeployer::Project::ConfigNotFoundError.new('failure_reason')
        callback.deployment_failure('branch', error)
        expect(WebMock).not_to have_requested(:post, default_post_url)
        expect(WebMock).not_to have_requested(:post, endpoint)
      end
    end
  end
end
