# frozen_string_literal: true

require_relative 'lib/super_agent/version'

Gem::Specification.new do |spec|
  spec.name = 'super_agent'
  spec.version = SuperAgent::VERSION
  spec.authors = ['Enrique Meza C']
  spec.email = ['emezac@gmail.com']

  spec.summary = 'A Rails framework for building AI-powered SaaS applications with workflow orchestration'
  spec.description = 'SuperAgent unifies AI workflow orchestration with Rails-native MVC interactions to create truly agentic applications that go beyond simple chatbots'
  spec.homepage = 'https://github.com/emezac/super_agent'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = 'https://github.com/superagent-rb/super_agent'
  spec.metadata['source_code_uri'] = 'https://github.com/superagent-rb/super_agent'
  spec.metadata['changelog_uri'] = 'https://github.com/superagent-rb/super_agent/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile]) ||
        f.end_with?('.gem')
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'activejob', '>= 7.1'
  spec.add_dependency 'activesupport', '>= 7.1'
  spec.add_dependency 'dry-struct', '~> 1.6'
  spec.add_dependency 'dry-types', '~> 1.7'
  spec.add_dependency 'httpx', '~> 1.2'
  spec.add_dependency 'open_router', '~> 0.1'
  spec.add_dependency 'rack', '~> 3.0'
  spec.add_dependency 'ruby-openai', '~> 7.0'
  spec.add_dependency 'webrick', '~> 1.8'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  # Development dependencies
  spec.add_development_dependency 'factory_bot_rails', '~> 6.4'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'pry-rails', '~> 0.3'
  spec.add_development_dependency 'rspec-rails', '~> 8.0'
  spec.add_development_dependency 'rubocop-rails', '~> 2.23'
  spec.add_development_dependency 'semantic_logger', '~> 4.15'
  spec.add_development_dependency 'sqlite3', '~> 1.6'
end
