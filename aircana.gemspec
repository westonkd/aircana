# frozen_string_literal: true

require_relative "lib/aircana/version"

Gem::Specification.new do |spec|
  spec.name = "aircana"
  spec.version = Aircana::VERSION
  spec.authors = ["Weston Dransfield"]
  spec.email = ["weston@dransfield.dev"]
  spec.homepage = "https://github.com/westonkd/aircana"

  spec.summary = "Humble workflow and context utilities for engineering with agents"
  spec.description = "Aircana provides context management and workflow utilities for " \
                     "software engineering with AI agents, including file organization and template generation."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/westonkd/aircana"
  spec.metadata["changelog_uri"] = "https://github.com/westonkd/aircana/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/westonkd/aircana/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "httparty", "~> 0.21"
  spec.add_dependency "reverse_markdown", "~> 2.1"
  spec.add_dependency "thor", "~> 0.19.1"
  spec.add_dependency "tty-progressbar", "~> 0.18"
  spec.add_dependency "tty-prompt", "~> 0.23.1"
  spec.add_dependency "tty-spinner", "~> 0.9"
end
