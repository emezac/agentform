# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2024-08-05

### 🎉 Initial Release

#### ✨ Added
- **Core Workflow Engine**: Immutable context management and task orchestration
- **Multiple Task Types**: LLM, Pundit Policy, ActiveRecord, ActionMailer, TurboStream, DirectHandler
- **Rails Integration**: Native Rails 7.1+ integration with generators
- **Real-time Streaming**: Turbo Streams support for progressive UI updates
- **Async Processing**: ActiveJob integration with background execution
- **Security Features**: Pundit integration and sensitive data filtering
- **Comprehensive Testing**: 200+ tests including system specs with Capybara
- **Observability**: Structured logging with workflow execution correlation
- **Error Handling**: Built-in retry mechanisms and error recovery
- **Configuration**: Flexible configuration system with environment support

#### 📚 Documentation
- Complete README with quick start guide
- API documentation with YARD
- Practical usage examples
- Migration guides from Active Agent and rdawn
- Rails integration examples

#### 🧪 Testing
- Unit tests for all components
- Integration tests with Rails
- System tests with Capybara
- Performance benchmarks

#### 🏗️ Project Structure
- Modular gem architecture
- Zeitwerk-based autoloading
- Rails generators for easy setup
- Dummy Rails app for testing

### Supported Ruby Versions
- Ruby 3.0.0 and above
- Rails 7.1 and above

### Dependencies
- dry-struct and dry-types for type safety
- Zeitwerk for autoloading
- ActiveJob for background processing
- ruby-openai for LLM integration
- Turbo Rails for streaming support

---

## 🗺️ Roadmap

### Next Releases

#### [1.1.0] - Coming Soon
- **Additional LLM Providers**: Anthropic, Gemini, Azure OpenAI
- **Web UI**: Dashboard for workflow monitoring
- **Performance Monitoring**: Built-in metrics and analytics
- **Additional Task Types**: Webhooks, file processing, external APIs
- **Advanced Error Recovery**: Circuit breakers and fallbacks

#### [1.2.0] - Future
- **Visual Workflow Editor**: Drag-and-drop workflow builder
- **Caching Layer**: Redis-based caching for expensive operations
- **Rate Limiting**: Built-in rate limiting for API calls
- **A/B Testing**: Built-in experimentation framework
- **Team Collaboration**: Multi-user workflow editing

#### [2.0.0] - Vision
- **Workflow Registry**: Centralized workflow management
- **Cross-service Orchestration**: Distributed workflow execution
- **Advanced Analytics**: Performance insights and optimization
- **Enterprise Features**: SSO, audit logs, compliance
- **Plugin Ecosystem**: Third-party task and provider plugins

---

## 🔄 Breaking Changes

This is the initial release, so no breaking changes from previous versions.

## 📋 Migration Notes

For users migrating from Active Agent or rdawn, see the [Migration Guide](https://github.com/superagent-rb/super_agent/blob/main/examples/migration_guide.md).

## 🙏 Acknowledgments

- Inspired by [rdawn](https://github.com/rdawn/rdawn) for workflow orchestration concepts
- Inspired by [Active Agent](https://github.com/active-agent/active-agent) for Rails integration patterns
- Built with ❤️ for the Ruby on Rails community

---

**Release Date**: August 5, 2024  
**Git Tag**: v1.0.0  
**RubyGems**: [super_agent](https://rubygems.org/gems/super_agent)