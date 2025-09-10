# SuperAgent A2A Protocol Implementation

This document describes the complete A2A (Agent-to-Agent) Protocol integration for SuperAgent, enabling seamless communication with other AI systems and agents.

## 🎯 Overview

The A2A Protocol implementation provides:

- **Standards Compliance**: Full compatibility with A2A protocol specification
- **Seamless Integration**: Native integration with SuperAgent's workflow DSL
- **Production Ready**: Comprehensive error handling, retry logic, caching, and monitoring
- **Interoperability**: Communication with Google ADK and other A2A-compatible systems

## 📦 Components Implemented

### 1. Core A2A Classes

**Agent Card Management (`lib/super_agent/a2a/agent_card.rb`)**
- `AgentCard` - Represents agent capabilities and metadata
- `Capability` - Individual skills/capabilities 
- Auto-generation from SuperAgent workflows
- JSON serialization with A2A schema compliance

**Message & Communication (`lib/super_agent/a2a/message.rb`, `part.rb`)**
- `Message` - Structured messages with parts
- `TextPart`, `FilePart`, `DataPart` - Different content types
- Content validation and serialization

**Artifacts (`lib/super_agent/a2a/artifact.rb`)**
- `Artifact` - Base artifact class
- `DocumentArtifact`, `ImageArtifact`, `DataArtifact`, `CodeArtifact`
- Content processing and metadata management

### 2. Client & Server Implementation

**A2A Client (`lib/super_agent/a2a/client.rb`)**
- HTTP client with authentication support
- Retry logic with exponential backoff
- Agent card caching with TTL
- Streaming support via Server-Sent Events
- Multiple authentication methods (Bearer, API Key, OAuth2, Basic)

**A2A Server (`lib/super_agent/a2a/server.rb`)**
- Full Rack-based HTTP server
- Middleware stack (authentication, CORS, logging)
- Standard A2A endpoints (/.well-known/agent.json, /health, /invoke)
- SSL/TLS support
- Multi-workflow gateway mode

**Middleware Components**
- `AuthMiddleware` - Token-based authentication
- `CorsMiddleware` - Cross-origin resource sharing
- `LoggingMiddleware` - Structured request/response logging

**Request Handlers**
- `AgentCardHandler` - Serves agent capability discovery
- `HealthHandler` - Comprehensive health monitoring
- `InvokeHandler` - Skill invocation with streaming support

### 3. Workflow Integration

**A2A Task (`lib/super_agent/workflow/tasks/a2a_task.rb`)**
- Native SuperAgent task for calling external A2A agents
- Configurable authentication, timeouts, and error handling
- Support for streaming and webhook notifications
- Artifact processing and context integration

**DSL Extensions (`lib/super_agent/workflow_definition.rb`)**
```ruby
workflow do
  a2a_agent :call_external_service do
    agent_url "http://external-agent:8080"
    skill "process_data"
    input :user_data
    output :processed_result
    auth_env "EXTERNAL_SERVICE_TOKEN"
    timeout 30
    stream true
  end
end
```

### 4. Configuration & Setup

**Configuration Extensions (`lib/super_agent/configuration.rb`)**
- A2A server settings (port, host, auth, SSL)
- Client settings (timeout, retries, cache TTL)
- Agent registry for known A2A services

**Generators (`lib/generators/super_agent/a2a_server/`)**
- `rails generate super_agent:a2a_server` - Complete server setup
- Initializer, startup scripts, Docker files, systemd services
- SSL configuration and environment variable templates

### 5. Management Tools

**Rake Tasks (`lib/tasks/super_agent_a2a.rake`)**
- `super_agent:a2a:serve` - Start A2A server
- `super_agent:a2a:generate_card` - Generate agent cards
- `super_agent:a2a:test_agent` - Test connectivity
- `super_agent:a2a:benchmark` - Performance testing
- `super_agent:a2a:list` - Show A2A status and configuration

### 6. Testing Framework

**Test Helpers (`spec/support/a2a_test_helpers.rb`)**
- Mocking utilities for A2A interactions
- WebMock integration for HTTP requests
- Workflow builders for testing
- Authentication and error scenario helpers

**Integration Tests (`spec/integration/a2a_interop_spec.rb`)**
- End-to-end A2A protocol testing
- Agent card discovery validation
- Skill invocation scenarios
- Streaming and authentication tests
- Error handling and retry logic

**Unit Tests (`spec/super_agent/a2a/agent_card_spec.rb`)**
- Individual component testing
- Validation logic verification
- JSON serialization/deserialization
- Edge case handling

## 🚀 Quick Start

### 1. Generate A2A Server

```bash
rails generate super_agent:a2a_server --port=8080 --auth --ssl
```

### 2. Configure Environment

```bash
cp .env.a2a.example .env.a2a
# Edit .env.a2a with your settings
```

### 3. Start Server

```bash
bin/super_agent_a2a
# or
rake super_agent:a2a:serve
```

### 4. Use in Workflows

```ruby
class MyWorkflow < ApplicationWorkflow
  workflow do
    a2a_agent :call_analytics do
      agent_url ENV['ANALYTICS_SERVICE_URL']
      skill "analyze_sentiment"
      input :user_text
      output :sentiment_analysis
      auth_env "ANALYTICS_TOKEN"
      timeout 15
    end
  end
end
```

## 🔧 Configuration

### Server Configuration

```ruby
SuperAgent.configure do |config|
  # Server settings
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
  config.a2a_server_host = '0.0.0.0'
  config.a2a_auth_token = ENV['A2A_AUTH_TOKEN']
  
  # SSL settings
  config.a2a_ssl_cert_path = 'config/ssl/cert.pem'
  config.a2a_ssl_key_path = 'config/ssl/key.pem'
  
  # Client settings
  config.a2a_default_timeout = 30
  config.a2a_max_retries = 3
  config.a2a_cache_ttl = 300
  
  # Register external agents
  config.register_a2a_agent(:inventory, 'http://inventory:8080')
  config.register_a2a_agent(:analytics, 'http://analytics:8080', 
                            auth: { type: :env, key: 'ANALYTICS_TOKEN' })
end
```

### Authentication Options

```ruby
# Bearer token
a2a_agent :secure_call do
  auth_token "your-bearer-token"
end

# Environment variable
a2a_agent :env_auth do
  auth_env "SERVICE_TOKEN"
end

# Configuration key
a2a_agent :config_auth do
  auth_config :service_token
end

# Dynamic authentication
a2a_agent :dynamic_auth do
  auth { |context| context.get(:user_token) }
end
```

## 📊 Monitoring & Observability

### Health Checks

```bash
curl http://localhost:8080/health
```

Returns comprehensive system status including:
- Server uptime and performance
- Registered workflows and capabilities
- Memory usage and thread count
- Dependency status checks

### Logging

Structured logging with request IDs:
```json
{
  "event": "a2a_request",
  "request_id": "req-123",
  "method": "POST",
  "path": "/invoke",
  "duration_ms": 245.7
}
```

### Metrics

Built-in performance monitoring:
- Request/response times
- Success/failure rates
- Cache hit rates
- Retry statistics

## 🧪 Testing

### Running Tests

```bash
# All A2A tests
rspec spec/integration/a2a_interop_spec.rb

# Unit tests
rspec spec/super_agent/a2a/

# With test helpers
rspec --tag a2a
```

### Test Agent Connectivity

```bash
rake super_agent:a2a:test_agent[http://agent:8080,skill_name]
```

### Performance Benchmarking

```bash
rake super_agent:a2a:benchmark[http://agent:8080,skill_name,100]
```

## 🐳 Deployment

### Docker

```bash
# Build image
docker build -f Dockerfile.a2a -t superagent-a2a .

# Run container
docker run -p 8080:8080 -e SUPER_AGENT_A2A_TOKEN=token superagent-a2a
```

### Docker Compose

```bash
docker-compose -f docker-compose.a2a.yml up
```

### Production Systemd

```bash
sudo cp config/super_agent_a2a.service /etc/systemd/system/
sudo systemctl enable super_agent_a2a
sudo systemctl start super_agent_a2a
```

## 🔍 Troubleshooting

### Common Issues

1. **Agent Card Not Found**
   ```bash
   curl http://localhost:8080/.well-known/agent.json
   ```

2. **Authentication Failures**
   ```bash
   # Check token configuration
   rake super_agent:a2a:list
   ```

3. **Network Connectivity**
   ```bash
   rake super_agent:a2a:test_agent[http://target:8080]
   ```

4. **Performance Issues**
   ```bash
   rake super_agent:a2a:benchmark[http://target:8080,skill,10]
   ```

### Debug Mode

Set `DEBUG=true` for detailed error traces:
```bash
DEBUG=true rake super_agent:a2a:serve
```

## 📚 API Reference

### Standard Endpoints

- `GET /.well-known/agent.json` - Agent Card discovery
- `GET /health` - Health check and system status
- `POST /invoke` - Skill invocation (JSON-RPC 2.0)
- `GET /` - Server information

### Agent Card Format

```json
{
  "id": "superagent-workflow-abc123",
  "name": "SuperAgent Workflow",
  "version": "1.0.0",
  "serviceEndpointURL": "http://localhost:8080",
  "supportedModalities": ["text", "json"],
  "capabilities": [
    {
      "name": "process_data",
      "description": "Process user data",
      "parameters": {
        "input": {"type": "string", "required": true}
      },
      "returns": {"type": "object"}
    }
  ]
}
```

### Skill Invocation

```json
{
  "jsonrpc": "2.0",
  "method": "invoke",
  "params": {
    "task": {
      "id": "req-123",
      "skill": "process_data",
      "parameters": {"input": "user data"}
    }
  },
  "id": "req-123"
}
```

## 🎉 Implementation Complete

✅ **All 8 phases completed successfully:**

1. ✅ Foundation & Error Handling
2. ✅ Agent Card Management  
3. ✅ Message & Artifacts
4. ✅ A2A Client Implementation
5. ✅ A2A Server Implementation
6. ✅ Workflow Task Integration
7. ✅ Generators & Tools
8. ✅ Testing Framework

The SuperAgent A2A Protocol integration is now production-ready with comprehensive features for building interoperable AI agent systems!