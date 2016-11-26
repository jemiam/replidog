# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'replidog/version'

Gem::Specification.new do |spec|
  spec.name          = "replidog"
  spec.version       = Replidog::VERSION
  spec.authors       = ["Manabu Ejima"]
  spec.email         = ["jemiam@gmail.com"]
  spec.summary       = "master-slave replication helper for ActiveRecord"
  spec.homepage      = "https://github.com/jemiam/replidog"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", '>= 3.2.0'
  spec.add_dependency "activesupport", '>= 3.2.0'
  spec.add_dependency "concurrent-ruby", "~> 1.0", ">= 1.0.2"
  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "coffee-rails", ">= 3.2.0"
  spec.add_development_dependency "database_rewinder", "~> 0.6.0"
  spec.add_development_dependency "jquery-rails"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-rails"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rails", ">= 3.2.0"
  spec.add_development_dependency "rspec", ">= 3"
  spec.add_development_dependency "rspec-rails", ">= 3"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "uglifier"
  spec.add_development_dependency "mysql2", "> 0.3"
  spec.add_development_dependency "test-unit", '~> 3.0'

  if RUBY_VERSION < '2.0.0'
    spec.add_development_dependency 'pry-debugger'
  else
    spec.add_development_dependency 'pry-byebug'
  end
end
