# Google ADK Web Integration - Quick Start

## 🚀 5-Minute Setup

### 1. Configure SuperAgent
```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
  config.a2a_auth_token = ENV['SUPER_AGENT_A2A_TOKEN']
end
```

### 2. Create A2A-Ready Workflow
```ruby
# app/workflows/demo_workflow.rb
class DemoWorkflow < ApplicationWorkflow
  workflow do
    task :process_request do
      input :user_query
      
      llm :generate_response do
        model "gpt-4o"
        prompt "Process this request: {{user_query}}"
      end
      
      task :format_output do
        input :generate_response
        process { |response| { result: response, status: "completed" } }
      end
    end
  end
end
```

### 3. Start A2A Server
```bash
rake super_agent:a2a:serve
```

### 4. Connect ADK Web
- **Agent URL**: `http://localhost:8080`
- **Auth Token**: Your `SUPER_AGENT_A2A_TOKEN`

### 5. Test Skill
**Skill**: `process_request`  
**Input**: `{"user_query": "Hello from ADK Web!"}`

## 📋 Verification Checklist

- [ ] A2A server responds at `http://localhost:8080/health`
- [ ] Agent card available at `http://localhost:8080/.well-known/agent.json`
- [ ] ADK Web successfully connects to your agent
- [ ] Skills are visible in ADK Web interface
- [ ] Test skill invocation returns expected results

## 🔗 Full Documentation
See [GOOGLE_ADK_WEB_INTEGRATION.md](GOOGLE_ADK_WEB_INTEGRATION.md) for complete setup, advanced features, and production deployment.

## 🎯 Key Benefits
- **Visual Interface**: Manage AI workflows through Google's web UI
- **Real-time Streaming**: Live execution feedback
- **Enterprise Integration**: Connect with Google Workspace
- **Team Collaboration**: Shared interface for technical and business users
- **Rapid Prototyping**: Quick testing without code changes