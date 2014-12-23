# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hawkins/version'

Gem::Specification.new do |spec|
  spec.name = "hawkins"
  spec.version = Hawkins::VERSION
  spec.authors = ["Alex Wood"]
  spec.email = ["awood@redhat.com"]
  spec.summary = "A Jekyll extension that adds in Live Reload and page isolation"
  spec.homepage = "http://github.com/awood/hawkins"
  spec.license = "MIT"

  spec.files = %x(git ls-files -z).split("\x0")
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("guard", "~> 2.8")
  spec.add_runtime_dependency("guard-livereload")
  spec.add_runtime_dependency("jekyll", "~> 2.0.0")
  spec.add_runtime_dependency("rack")
  spec.add_runtime_dependency("rack-livereload")
  spec.add_runtime_dependency("safe_yaml")
  spec.add_runtime_dependency("stringex")
  spec.add_runtime_dependency("thin")
  spec.add_runtime_dependency("thor")

  spec.add_development_dependency("bundler", "~> 1.6")
  spec.add_development_dependency("mocha")
  spec.add_development_dependency("rspec-core")
  spec.add_development_dependency("rspec-expectations")
  spec.add_development_dependency("rspec-mocks")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("rdoc", "~> 3.12")
  # Rubocop can issue new releases with new checks which can result
  # in errors we don't want.  We'll manage the version very strictly.
  spec.add_development_dependency("rubocop", "= 0.24.1")
  spec.add_development_dependency("simplecov")
end
