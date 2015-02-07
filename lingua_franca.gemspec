# -*- encoding: utf-8 -*-
require File.expand_path('../lib/lingua_franca/version', __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |gem|
  gem.name          = "lingua_franca"
  gem.authors       = ["Godwin"]
  gem.email         = ["goodgodwin@hotmail.com"]
  gem.description   = "Lingua Franca creates an I18n collaborative environment where users can add translations. It also integrates into your test environment to scrape for translatable content which helps to ensure test and translation coverage"
  gem.summary       = "Let's users collaborate to provide translations and helps to ensure test and translation coverage"
  gem.homepage      = "http://bikecollectives.org"
  gem.licenses      = ["MIT"]

  gem.files         = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  gem.require_paths = ["lib", "app/models"]
  gem.version       = LinguaFranca::VERSION

  gem.add_dependency "rails", "~> 4.2.0.rc2"
  gem.add_dependency "i18n"
  gem.add_dependency "rails-i18n"
  gem.add_dependency "forgery"
  gem.add_dependency "rubyzip"
  gem.add_dependency "http_accept_language"
  gem.add_dependency "diffy"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rspec-mocks"
end
