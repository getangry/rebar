Gem::Specification.new do |spec|
  spec.name          = "rebar-sdk"
  spec.version       = "0.1.0"
  spec.authors       = ["Rebar Contributors"]
  spec.email         = ["hello@rebar.dev"]

  spec.summary       = "Ruby SDK for Rebar ReBAC authorization service"
  spec.description   = "Official Ruby client for interacting with Rebar relationship-based access control API"
  spec.homepage      = "https://github.com/getangry/rebar"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files         = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
