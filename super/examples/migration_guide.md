# 🚀 Migration Guide

This guide helps you migrate from existing AI frameworks to SuperAgent.

## 📋 From Active Agent

Active Agent is great for simple LLM interactions, but SuperAgent provides more powerful workflow orchestration.

### Key Differences

| Feature | Active Agent | SuperAgent |
|---------|--------------|------------|
| **Workflow Orchestration** | ❌ Single prompts | ✅ Multi-step workflows |
| **Task Types** | ❌ LLM only | ✅ LLM, DB, Mail, Policies |
| **State Management** | ❌ Instance variables | ✅ Immutable context |
| **Streaming** | ❌ Basic | ✅ Turbo Streams |
| **Error Handling** | ❌ Manual | ✅ Built-in retry/logic |
| **Testing** | ❌ Integration | ✅ Unit + System tests |

### Migration Steps

#### 1. Convert Active Agent to SuperAgent

**Before (Active Agent):**
```ruby
class LeadAnalysisAgent < ActiveAgent::Base
  agent_name "lead_analyzer"
  
  def analyze_lead(lead_data)
    prompt = "Analyze this lead: #{lead_data.to_json}"
    response = chat(prompt)
    JSON.parse(response)
  end
end
```

**After (SuperAgent):**
```ruby
class LeadAnalysisAgent < SuperAgent::Base
  def analyze_lead(lead_data)
    result = run_workflow(LeadAnalysisWorkflow, initial_input: lead_data)
    result.completed? ? result.final_output : handle_error(result)
  end
end

class LeadAnalysisWorkflow < SuperAgent::WorkflowDefinition
  define_task :analyze_with_llm, :llm do |config|
    config.system_prompt = "Analyze this lead for sales qualification"
    config.template = "Lead data: {{lead_data}}"
  end
  
  define_task :format_response, :direct_handler do |config|
    config.handler = ->(context) {
      JSON.parse(context.get(:analyze_with_llm))
    }
  end
end
```

#### 2. Update Configuration

**Before:**
```ruby
# config/initializers/active_agent.rb
ActiveAgent.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```

**After:**
```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.logger = Rails.logger
end
```

## 📋 From rdawn

rdawn provides workflow orchestration, but SuperAgent offers better Rails integration.

### Key Differences

| Feature | rdawn | SuperAgent |
|---------|--------|------------|
| **Rails Integration** | ❌ Generic Ruby | ✅ Rails-native |
| **Context Management** | ❌ Mutable state | ✅ Immutable |
| **Task Types** | ❌ Custom only | ✅ Built-in types |
| **Database** | ❌ Manual | ✅ ActiveRecord |
| **Security** | ❌ DIY | ✅ Pundit |
| **UI Updates** | ❌ Manual | ✅ Turbo Streams |

### Migration Steps

#### 1. Convert rdawn Workflows

**Before (rdawn):**
```ruby
class LeadWorkflow < Dawn::Workflow
  task :validate_data do |context|
    # Custom validation logic
    context[:valid] = context[:data][:email].present?
  end
  
  task :process_lead do |context|
    # Manual LLM call
    response = OpenAI::Client.new.chat(
      parameters: { messages: [{ role: "user", content: "Process #{context[:data]}" }] }
    )
    context[:result] = response.dig("choices", 0, "message", "content")
  end
end
```

**After (SuperAgent):**
```ruby
class LeadWorkflow < SuperAgent::WorkflowDefinition
  define_task :validate_data, :pundit_policy do |config|
    config.policy_class = LeadPolicy
    config.action = :process?
  end
  
  define_task :process_lead, :llm do |config|
    config.system_prompt = "Process lead for sales qualification"
    config.template = "Lead data: {{data}}"
  end
end
```

#### 2. Update Context Usage

**Before:**
```ruby
context = { data: lead_data }
workflow.execute(context)
result = context[:result]
```

**After:**
```ruby
context = SuperAgent::Workflow::Context.new(data: lead_data)
result = engine.execute(LeadWorkflow, context)
final_output = result.final_output
```

## 🔧 Common Patterns

### Error Handling Migration

**Before:**
```ruby
begin
  agent.process(data)
rescue StandardError => e
  Rails.logger.error "Processing failed: #{e.message}"
end
```

**After:**
```ruby
result = agent.process(data)
if result.failed?
  Rails.logger.error "Processing failed: #{result.error_message}"
end
```

### Background Processing Migration

**Before:**
```ruby
# Manual ActiveJob
class ProcessLeadJob < ApplicationJob
  def perform(lead_id)
    lead = Lead.find(lead_id)
    agent = LeadAgent.new
    agent.process(lead.data)
  end
end
```

**After:**
```ruby
# Built-in background support
agent.run_workflow_later(LeadWorkflow, initial_input: lead.data)
```

### Testing Migration

**Before:**
```ruby
RSpec.describe LeadAgent do
  it "processes leads" do
    agent = LeadAgent.new
    result = agent.process(lead_data)
    expect(result[:score]).to be > 50
  end
end
```

**After:**
```ruby
RSpec.describe LeadWorkflow do
  let(:context) { SuperAgent::Workflow::Context.new(data: lead_data) }
  let(:engine) { SuperAgent::WorkflowEngine.new }

  it "processes leads successfully" do
    result = engine.execute(LeadWorkflow, context)
    expect(result.completed?).to be true
    expect(result.final_output[:score]).to be > 50
  end
end
```

## 🚀 Migration Checklist

### Phase 1: Setup
- [ ] Install SuperAgent gem
- [ ] Run `rails generate super_agent:install`
- [ ] Configure API keys
- [ ] Set up basic structure

### Phase 2: Convert Core Logic
- [ ] Identify existing agents/workflows
- [ ] Convert to SuperAgent workflows
- [ ] Update task definitions
- [ ] Test basic functionality

### Phase 3: Advanced Features
- [ ] Add Pundit policies
- [ ] Implement streaming
- [ ] Add background processing
- [ ] Set up monitoring

### Phase 4: Cleanup
- [ ] Remove old gem dependencies
- [ ] Update documentation
- [ ] Train team on new patterns
- [ ] Deploy to production

## 💡 Tips

1. **Start Small**: Convert one agent at a time
2. **Test Thoroughly**: Use the comprehensive test suite
3. **Leverage Rails**: Use built-in Rails features
4. **Monitor Performance**: Use the logging and observability features
5. **Gradual Rollout**: Use feature flags for deployment

## 📚 Resources

- [SuperAgent Documentation](https://superagent-rb.org)
- [Migration Examples](https://github.com/superagent-rb/super_agent/tree/main/examples)
- [Community Support](https://github.com/superagent-rb/super_agent/discussions)

---

Need help with migration? [Open an issue](https://github.com/superagent-rb/super_agent/issues) or [start a discussion](https://github.com/superagent-rb/super_agent/discussions)!