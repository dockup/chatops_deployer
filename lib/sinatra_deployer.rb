require 'flynn_deployer/version'
require 'json'

module FlynnDeployer
  def get_auth_key
    uri = URI("#{ENV['DISCOVERD']}/services/flynn-controller/instances")
    response = Net::HTTP.get_response(uri)
    if response.is_a? Net::HTTPSuccess
      JSON.parse(x.body)[0]['meta']['AUTH_KEY']
    else
      nil
    end
  rescue
    nil
  end

  def get_insta
end
