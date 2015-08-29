# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chatops_deployer/version'

Gem::Specification.new do |spec|
  spec.name          = "chatops_deployer"
  spec.version       = ChatopsDeployer::VERSION
  spec.authors       = ["Emil Soman"]
  spec.email         = ["emil@codemancers.com"]

  spec.summary       = %q{An opinionated Chatops backend}
  spec.description   = %q{ChatopsDeployer deploys containerized services in isolated VMs and exposes public facing URLs}
  spec.homepage      = "https://github.com/code-mancers/chatops-deployer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sinatra"
  spec.add_dependency "sucker_punch"
  spec.add_dependency "httparty"
  spec.add_dependency "command"
end
