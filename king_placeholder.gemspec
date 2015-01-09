# -*- encoding: utf-8 -*-
require File.expand_path('../lib/king_placeholder/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Georg Leciejewski"]
  gem.email         = ["gl@salesking.eu"]
  gem.description   = %q{}
  gem.summary       = %q{Placeholder Parsing in Strings}
  gem.homepage      = 'https://github.com/salesking/king_placeholder.git'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "king_placeholder"
  gem.require_paths = ["lib"]
  gem.version       = KingPlaceholder::VERSION

  gem.add_runtime_dependency 'statemachine'
  gem.add_runtime_dependency 'activesupport', '>3.0'

  gem.add_development_dependency 'activerecord'
  gem.add_development_dependency 'rdoc'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'rake', '>= 0.9.2'
end
