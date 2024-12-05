# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) if !$LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "mass_git_clone"
  spec.version       = "0.2.0"
  spec.authors       = ["Discourse Team"]

  spec.summary       = %q{Tool for maintaining clones of a large number of git repositories}
  spec.description   = %q{Tool for maintaining clones of a large number of git repositories}
  spec.homepage      = "https://github.com/discourse/mass_git_clone"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_dependency "parallel", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-discourse"
  spec.add_development_dependency "syntax_tree"
end
