# Google ADK Web Integration with SuperAgent Rails

## 🌐 Overview

With SuperAgent's A2A Protocol implementation, you can seamlessly connect **Google ADK Web** to your Rails applications, enabling visual interaction with your AI workflows through a web interface. This integration transforms your SuperAgent workflows into universally accessible AI services.

## ✅ Compatibility & Features

### Full A2A Protocol Compliance
- **✅ Agent Discovery**: ADK Web automatically discovers your SuperAgent capabilities
- **✅ Skill Invocation**: Direct execution of workflow tasks from the web interface
- **✅ Real-time Streaming**: Live updates during workflow execution
- **✅ Authentication**: Secure token-based access control
- **✅ Error Handling**: Standardized error responses and recovery

### Standard A2A Endpoints
Once your A2A server is running, Google ADK Web can access:

```
GET  /.well-known/agent.json  # Agent capability discovery
GET  /health                  # Health check and status
POST /invoke                  # Skill invocation (JSON-RPC 2.0)
```

---

## 🚀 Quick Start Guide

### Step 1: Configure SuperAgent for A2A

Create or update your SuperAgent configuration:

```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  # Enable A2A server
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
  config.a2a_server_host = '0.0.0.0'  # Accessible externally
  
  # Authentication (optional but recommended)
  config.a2a_auth_token = ENV['SUPER_AGENT_A2A_TOKEN']
  
  # Base URL for agent discovery
  config.a2a_base_url = ENV['SUPER_AGENT_BASE_URL'] || 'http://localhost:8080'
  
  # Performance settings
  config.a2a_default_timeout = 30
  config.a2a_max_retries = 2
  config.a2a_cache_ttl = 300
end
```

### Step 2: Create A2A-Compatible Workflows

Design workflows that expose skills for ADK Web:

```ruby
# app/workflows/customer_support_workflow.rb
class CustomerSupportWorkflow < ApplicationWorkflow
  workflow do
    # This task becomes a "skill" available to ADK Web
    task :resolve_customer_query do
      input :customer_query, :customer_id, :priority_level
      output :resolution_response
      
      # Step 1: Analyze customer query with AI
      llm :analyze_query do
        model "gpt-4o"
        system_prompt "You are an expert customer support analyst."
        prompt """
        Analyze this customer query and determine:
        1. Issue category
        2. Urgency level  
        3. Required information
        4. Suggested resolution approach
        
        Query: {{customer_query}}
        Priority: {{priority_level}}
        """
      end
      
      # Step 2: Fetch customer information
      fetch :get_customer_data do
        model "Customer"
        find_by id: "{{customer_id}}"
        includes :orders, :support_tickets
      end
      
      # Step 3: Check knowledge base
      search :search_knowledge_base do
        query "{{customer_query}} {{analyze_query.category}}"
        search_context_size 5
      end
      
      # Step 4: Generate personalized response
      llm :generate_response do
        model "gpt-4o"
        system_prompt "Generate a helpful, personalized customer support response."
        prompt """
        Customer: {{get_customer_data.name}}
        Query: {{customer_query}}
        Analysis: {{analyze_query}}
        Knowledge Base Results: {{search_knowledge_base}}
        
        Generate a comprehensive response that:
        1. Addresses the specific issue
        2. Provides step-by-step solutions
        3. Includes relevant links or resources
        4. Maintains a friendly, professional tone
        """
      end
      
      # Step 5: Log interaction and return structured response
      task :finalize_response do
        input :generate_response, :analyze_query, :get_customer_data
        
        process do |response, analysis, customer|
          # Log the interaction
          SupportInteraction.create!(
            customer_id: customer.id,
            query: context.get(:customer_query),
            response: response,
            category: analysis["category"],
            resolved_at: Time.current
          )
          
          # Return structured response for ADK Web
          {
            response_text: response,
            customer_name: customer.name,
            issue_category: analysis["category"],
            urgency_level: analysis["urgency"],
            resolution_status: "completed",
            next_steps: analysis["suggested_actions"],
            interaction_id: SupportInteraction.last.id
          }
        end
      end
    end
    
    # Additional skill for escalation
    task :escalate_to_human do
      input :customer_id, :issue_description, :escalation_reason
      output :escalation_response
      
      email :notify_support_team do
        mailer "SupportMailer"
        action "escalation_notification"
        locals do
          {
            customer_id: "{{customer_id}}",
            issue: "{{issue_description}}",
            reason: "{{escalation_reason}}"
          }
        end
      end
      
      task :create_escalation_ticket do
        input :customer_id, :issue_description
        process do |customer_id, description|
          ticket = SupportTicket.create!(
            customer_id: customer_id,
            description: description,
            priority: "high",
            status: "escalated",
            assigned_to: nil
          )
          
          {
            ticket_id: ticket.id,
            status: "escalated",
            message: "Your issue has been escalated to our support team.",
            estimated_response_time: "2-4 hours"
          }
        end
      end
    end
  end
end
```

### Step 3: Create Additional Business Workflows

```ruby
# app/workflows/sales_qualification_workflow.rb
class SalesQualificationWorkflow < ApplicationWorkflow
  workflow do
    task :qualify_lead do
      input :lead_email, :company_name, :use_case_description
      output :qualification_result
      
      # Enrich lead data
      search :research_company do
        query "{{company_name}} company information"
      end
      
      # AI qualification
      llm :analyze_lead_potential do
        model "gpt-4o"
        system_prompt "You are a sales qualification expert."
        prompt """
        Analyze this lead:
        Company: {{company_name}}
        Use Case: {{use_case_description}}
        Research: {{research_company}}
        
        Provide:
        1. Lead score (1-10)
        2. Qualification status (hot/warm/cold)
        3. Recommended next steps
        4. Key decision factors
        """
      end
      
      # Update CRM
      task :update_crm do
        input :lead_email, :analyze_lead_potential
        process do |email, analysis|
          Lead.find_by(email: email)&.update!(
            score: analysis["lead_score"],
            status: analysis["qualification_status"],
            notes: analysis["key_factors"]
          )
          
          {
            crm_updated: true,
            lead_score: analysis["lead_score"],
            qualification_status: analysis["qualification_status"],
            next_steps: analysis["recommended_actions"]
          }
        end
      end
    end
  end
end
```

### Step 4: Start the A2A Server

```bash
# Option 1: Rake task (recommended)
rake super_agent:a2a:serve

# Option 2: Rails runner
rails runner "SuperAgent::A2A::Server.new.start"

# Option 3: Background process
nohup rake super_agent:a2a:serve > log/a2a_server.log 2>&1 &
```

---

## 🔧 Google ADK Web Configuration

### Step 1: Connect to Your SuperAgent Instance

1. **Open Google ADK Web** in your browser
2. **Add New Agent Connection**:
   - **Agent URL**: `http://your-server:8080`
   - **Authentication Type**: Bearer Token (if configured)
   - **Token**: Your `SUPER_AGENT_A2A_TOKEN` value

### Step 2: Verify Connection

ADK Web will automatically:
1. **Fetch agent capabilities** from `/.well-known/agent.json`
2. **Display available skills**:
   - `resolve_customer_query`
   - `escalate_to_human`
   - `qualify_lead`
3. **Show parameter requirements** for each skill

### Step 3: Test Skill Invocation

Example interaction in ADK Web:

**Skill**: `resolve_customer_query`
**Parameters**:
```json
{
  "customer_query": "My order hasn't arrived and it's been 2 weeks",
  "customer_id": "12345",
  "priority_level": "high"
}
```

**Expected Response**:
```json
{
  "response_text": "Hi John! I understand your concern about your delayed order...",
  "customer_name": "John Smith",
  "issue_category": "shipping_delay",
  "urgency_level": "high",
  "resolution_status": "completed",
  "next_steps": ["Track package", "Contact shipping carrier"],
  "interaction_id": 456
}
```

---

## 🔒 Security & Authentication

### Token-Based Authentication

Configure secure access:

```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  config.a2a_auth_token = ENV['SUPER_AGENT_A2A_TOKEN']
end
```

Set environment variable:
```bash
export SUPER_AGENT_A2A_TOKEN="your-secure-token-here"
```

In ADK Web, add the token to your agent connection settings.

### SSL/TLS Configuration

For production environments:

```ruby
SuperAgent.configure do |config|
  config.a2a_ssl_cert_path = ENV['SSL_CERT_PATH']
  config.a2a_ssl_key_path = ENV['SSL_KEY_PATH']
end
```

### Authorization with Pundit

Integrate authorization policies:

```ruby
class CustomerSupportWorkflow < ApplicationWorkflow
  workflow do
    # Check permissions before processing
    task :authorize_support_access do
      input :current_user_id, :customer_id
      
      task :check_permissions, :pundit_policy do
        policy "CustomerSupportPolicy"
        action "access?"
        resource_id "{{customer_id}}"
        user_id "{{current_user_id}}"
      end
    end
    
    # ... rest of workflow
  end
end
```

---

## 🌊 Advanced Features

### Real-Time Streaming

Enable streaming for long-running workflows:

```ruby
workflow do
  llm :generate_detailed_analysis do
    model "gpt-4o"
    stream true  # ADK Web receives real-time updates
    prompt "Generate comprehensive analysis of {{data}}"
  end
end
```

ADK Web will display streaming updates as they arrive.

### File Processing

Handle file uploads from ADK Web:

```ruby
workflow do
  task :analyze_document do
    input :document_url, :analysis_type
    
    upload_file :process_document do
      file_path "{{document_url}}"
      purpose "assistants"
    end
    
    file_search :extract_insights do
      query "{{analysis_type}} insights from document"
    end
    
    llm :summarize_findings do
      prompt "Summarize key findings: {{extract_insights}}"
    end
  end
end
```

### Multi-Step Conversations

Create conversational workflows:

```ruby
workflow do
  task :conversation_handler do
    input :message_history, :current_message, :conversation_id
    
    # Load conversation context
    fetch :get_conversation do
      model "Conversation"
      find_by id: "{{conversation_id}}"
    end
    
    # Generate contextual response
    llm :generate_response do
      model "gpt-4o"
      system_prompt "Continue this conversation naturally."
      messages do
        conversation_history = context.get(:get_conversation)&.messages || []
        conversation_history + [
          { role: "user", content: context.get(:current_message) }
        ]
      end
    end
    
    # Save conversation state
    task :update_conversation do
      input :conversation_id, :current_message, :generate_response
      process do |conv_id, message, response|
        conversation = Conversation.find(conv_id)
        conversation.messages << {
          role: "user",
          content: message,
          timestamp: Time.current
        }
        conversation.messages << {
          role: "assistant", 
          content: response,
          timestamp: Time.current
        }
        conversation.save!
        
        {
          response: response,
          conversation_updated: true,
          message_count: conversation.messages.size
        }
      end
    end
  end
end
```

---

## 📊 Monitoring & Observability

### Health Monitoring

The A2A server provides comprehensive health information:

```bash
curl http://localhost:8080/health
```

Response:
```json
{
  "status": "healthy",
  "uptime": 3600,
  "uptime_human": "1h 0m 0s",
  "registered_workflows": 3,
  "version": "1.0.0",
  "timestamp": "2025-01-10T15:30:00Z",
  "server_info": {
    "host": "0.0.0.0",
    "port": 8080,
    "ssl": false,
    "authentication": true
  }
}
```

### Logging Integration

Enable detailed logging:

```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  config.logger = Rails.logger
  config.log_level = :info
  
  # Enable A2A request logging
  config.a2a_request_logging = true
end
```

View logs:
```bash
tail -f log/production.log | grep "A2A"
```

### Metrics Collection

Track usage metrics:

```ruby
# app/models/a2a_metric.rb
class A2aMetric < ApplicationRecord
  def self.log_invocation(skill_name, duration, status)
    create!(
      skill_name: skill_name,
      execution_time: duration,
      status: status,
      timestamp: Time.current
    )
  end
end

# In your workflows
workflow do
  after_all do |context, result|
    A2aMetric.log_invocation(
      context.workflow_name,
      result.duration,
      result.status
    )
  end
end
```

---

## 🔄 Development Workflow

### Local Development Setup

1. **Start Rails development server**:
   ```bash
   rails server -p 3000
   ```

2. **Start A2A server in development**:
   ```bash
   RAILS_ENV=development rake super_agent:a2a:serve
   ```

3. **Configure ADK Web for local testing**:
   - Agent URL: `http://localhost:8080`
   - No authentication required in development

### Testing Integration

Create integration tests:

```ruby
# spec/integration/adk_web_integration_spec.rb
require 'rails_helper'

RSpec.describe "ADK Web Integration", type: :integration do
  let(:server) { SuperAgent::A2A::Server.new(port: 9999) }
  
  before do
    server.register_workflow(CustomerSupportWorkflow)
    # Start server in background for testing
  end
  
  it "exposes workflow as A2A skill" do
    response = HTTParty.get("http://localhost:9999/.well-known/agent.json")
    
    expect(response.code).to eq(200)
    agent_card = JSON.parse(response.body)
    
    expect(agent_card['capabilities']).to include(
      hash_including('name' => 'resolve_customer_query')
    )
  end
  
  it "processes skill invocation correctly" do
    payload = {
      jsonrpc: "2.0",
      method: "invoke",
      params: {
        task: {
          skill: "resolve_customer_query",
          parameters: {
            customer_query: "Test query",
            customer_id: "123",
            priority_level: "medium"
          }
        }
      },
      id: "test-1"
    }
    
    response = HTTParty.post(
      "http://localhost:9999/invoke",
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    
    expect(response.code).to eq(200)
    result = JSON.parse(response.body)
    expect(result['result']['status']).to eq('completed')
  end
end
```

---

## 🚀 Production Deployment

### Docker Configuration

```dockerfile
# Dockerfile.a2a
FROM ruby:3.2-slim

WORKDIR /app
COPY . .

RUN bundle install --deployment

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["rake", "super_agent:a2a:serve"]
```

### Docker Compose

```yaml
# docker-compose.a2a.yml
version: '3.8'

services:
  superagent-a2a:
    build: 
      context: .
      dockerfile: Dockerfile.a2a
    ports:
      - "8080:8080"
    environment:
      - RAILS_ENV=production
      - SUPER_AGENT_A2A_TOKEN=${A2A_TOKEN}
      - DATABASE_URL=${DATABASE_URL}
    volumes:
      - ./log:/app/log
    restart: unless-stopped
    
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl
    depends_on:
      - superagent-a2a
```

### Environment Variables

```bash
# .env.production
SUPER_AGENT_A2A_TOKEN=your-secure-production-token
SUPER_AGENT_BASE_URL=https://your-domain.com
RAILS_ENV=production
DATABASE_URL=postgresql://user:pass@db:5432/superagent_production
OPENAI_API_KEY=your-openai-key
```

---

## 🎯 Use Cases & Examples

### Customer Support Chatbot
- **ADK Web Interface**: Customer service dashboard
- **SuperAgent Backend**: Complex query resolution workflows
- **Integration**: Real-time customer data and knowledge base access

### Sales Lead Qualification
- **ADK Web Interface**: Sales team lead scoring interface
- **SuperAgent Backend**: AI-powered lead analysis and CRM integration
- **Integration**: Automated lead routing and follow-up scheduling

### Content Generation Platform
- **ADK Web Interface**: Content creator dashboard
- **SuperAgent Backend**: Multi-step content generation workflows
- **Integration**: Brand guidelines, SEO optimization, and publishing workflows

### Technical Support Automation
- **ADK Web Interface**: Support ticket management interface
- **SuperAgent Backend**: Automated troubleshooting and solution generation
- **Integration**: Knowledge base search, escalation workflows, and solution tracking

---

## 🔍 Troubleshooting

### Common Issues

**Connection Refused**:
```bash
# Check if A2A server is running
curl http://localhost:8080/health

# Check server logs
tail -f log/a2a_server.log
```

**Authentication Failed**:
```bash
# Verify token configuration
echo $SUPER_AGENT_A2A_TOKEN

# Test with curl
curl -H "Authorization: Bearer your-token" http://localhost:8080/health
```

**Skill Not Found**:
- Verify workflow is registered with server
- Check workflow class name matches expected skill name
- Ensure workflow inherits from `ApplicationWorkflow`

### Debug Mode

Enable verbose logging:

```ruby
SuperAgent.configure do |config|
  config.log_level = :debug
  config.a2a_request_logging = true
end
```

---

## 📚 Additional Resources

- [A2A Implementation Summary](A2A_IMPLEMENTATION_SUMMARY.md)
- [A2A Validation Report](A2A_VALIDATION_REPORT.md)
- [SuperAgent Workflow DSL Guide](README.md#usage-guide)
- [A2A Protocol Specification](https://github.com/google/agent-protocol)

---

## 🎉 Conclusion

With this integration, **Google ADK Web becomes a universal interface** for your SuperAgent Rails workflows, enabling:

- **Visual Workflow Management**: Graphical interface for complex AI workflows
- **Real-time Monitoring**: Live execution tracking and debugging
- **Team Collaboration**: Shared interface for business users and developers
- **Rapid Prototyping**: Quick testing and iteration of AI workflows
- **Enterprise Integration**: Seamless connection with existing Google Workspace tools

Your SuperAgent Rails application is now part of the broader A2A ecosystem, providing powerful AI capabilities through an intuitive web interface! 🚀