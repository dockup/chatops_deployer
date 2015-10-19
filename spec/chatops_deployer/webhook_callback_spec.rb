require 'chatops_deployer/webhook_callback'
require 'webmock/rspec'

describe ChatopsDeployer::WebhookCallback do
  let(:endpoint) { 'http://fake-endpoint' }
  let(:callback) { ChatopsDeployer::WebhookCallback.new(endpoint) }

  describe '#deployment_success' do
    let(:exposed_urls) do
      {
        'web' => {'3000' => 'url1', '3001' => 'url2'},
        'db' => {'1234' => 'url3'}
      }
    end

    it 'sends an HTTP POST request to the callback url with exposed urls' do
      stub_request(:post, endpoint)
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
      callback.deployment_success('branch', exposed_urls)
    end
  end

  describe '#deployment_failure' do
    it 'sends an HTTP POST request to the callback url with failure reason' do
      stub_request(:post, endpoint)
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
      callback.deployment_failure('branch', 'failure_reason')
    end
  end

  describe '#destroy_success' do
    it 'sends an HTTP POST request to the callback url' do
      stub_request(:post, endpoint)
        .with(
          body: {
            status: 'destroy_success',
            branch: 'branch'
          }.to_json,
          headers: {
            'Content-Type' => 'application/json'
          }
        ).to_return(status: 200)
      callback.destroy_success('branch')
    end
  end

  describe '#destroy_failure' do
    it 'sends an HTTP POST request to the callback url' do
      stub_request(:post, endpoint)
        .with(
          body: {
            reason: 'failure_reason',
            status: 'destroy_failure',
            branch: 'branch'
          }.to_json,
          headers: {
            'Content-Type' => 'application/json'
          }
        ).to_return(status: 200)
      callback.destroy_failure('branch', 'failure_reason')
    end
  end
end
