# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ratelimit/bucketbased/version'

Gem::Specification.new do |spec|
	spec.name          = "ratelimit-bucketbased"
	spec.version       = RateLimit::BucketBased::VERSION
	spec.authors       = ["chrislee35"]
	spec.email         = ["rubygems@chrislee.dhs.org"]
	spec.description   = %q{Simple rate limiting gem useful for regulating the speed at which service is provided, this provides an in-memory data structure for administering rate limits}
	spec.summary       = %q{Simple rate limiting gem useful for regulating the speed at which service is provided}
	spec.homepage      = "http://github.com/chrislee35/ratelimit-bucketbased"
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]

	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rake"
	spec.add_development_dependency "sqlite3", ">= 1.3.6"
	spec.add_development_dependency "memcache", ">= 1.2.13"
	spec.add_development_dependency "redis", "~> 3.0.1"

	spec.signing_key   = "#{File.dirname(__FILE__)}/../gem-private_key.pem"
	spec.cert_chain    = ["#{File.dirname(__FILE__)}/../gem-public_cert.pem"]

	spec.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
end
