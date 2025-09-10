# SuperAgent Integration Guide for Rails

This document provides a comprehensive guide for integrating the `super_agent` gem into a Rails application. It covers everything from initial setup and configuration to creating complex AI-powered workflows and agents.

## 1. Installation & Setup

First, add the `super_agent` gem to your `Gemfile`:

```ruby
# Gemfile
gem 'super_agent'
```

Then, run `bundle install`. After installation, use the built-in generator to set up the necessary files and configurations in your Rails application.

```bash
rails generate super_agent:install
```

This command will create the following essential files:
*   `config/initializers/super_agent.rb`: The central configuration file for the gem.
*   `app/agents/application_agent.rb`: A base class for all your agents to inherit from.
*   `app/workflows/application_workflow.rb`: A base class for all your workflows to inherit from.

## 2. Core Concepts: The Agentic Architecture

SuperAgent promotes a structured, scalable architecture for building AI features. The logic flows through a clear, predictable pattern:

`Controller → Agent → Workflow → Task`

1.  **Controller:** Handles incoming HTTP requests. Its only job is to gather parameters and delegate the business logic to an `Agent`.
2.  **Agent (`SuperAgent::Base`):** A high-level class that orchestrates business goals. An agent's method will typically initialize and run a specific `Workflow`. It's the bridge between your Rails app and the workflow engine.
3.  **Workflow (`SuperAgent::WorkflowDefinition`):** The heart of the gem. A workflow defines a series of steps (Tasks) to achieve a complex goal. It manages the state and data flow between tasks.
4.  **Task (`SuperAgent::Workflow::Task`):** An atomic unit of work within a workflow. SuperAgent provides many built-in tasks for common operations like LLM calls, database queries, sending emails, and more.

## 3. Configuration

All configuration is handled in `config/initializers/super_agent.rb`.

### LLM Provider Configuration

SuperAgent supports multiple LLM providers. You must configure at least one.

```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  # Choose your primary provider: :openai, :open_router, :anthropic
  config.llm_provider = :openai

  # --- API Keys ---
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # --- Default Model & Settings ---
  config.default_llm_model = "gpt-4o-mini"
  config.default_llm_timeout = 30 # seconds

  # --- Logging ---
  config.logger = Rails.logger
end
```

### Background Processing

For asynchronous operations, SuperAgent integrates with ActiveJob.

```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  # Default queue for async workflows
  config.async_queue = :default

  # Workflow timeout for long-running jobs
  config.workflow_timeout = 300 # 5 minutes

  # Default retry policy for workflows
  config.max_retries = 3
  config.retry_delay = 1 # second
end
```

## 4. Creating Your First Workflow

Workflows define the logic of your AI processes. Use the generator to create a new workflow file.

```bash
rails generate super_agent:workflow LeadAnalysis
```
This creates `app/workflows/lead_analysis_workflow.rb`.

Workflows are defined using a powerful and readable DSL.

```ruby
# app/workflows/lead_analysis_workflow.rb
class LeadAnalysisWorkflow < ApplicationWorkflow
  workflow do
    # Define global settings for this workflow
    timeout 60
    retry_policy max_retries: 2, delay: 1

    # Step 1: Validate the incoming lead data
    validate :check_lead_data do
      input :lead_email, :company_size
      process do |email, size|
        raise "A valid email is required." unless email =~ URI::MailTo::EMAIL_REGEXP
        raise "Company size must be a positive number." unless size.to_i > 0
        { valid: true }
      end
    end

    # Step 2: Use an LLM to enrich the lead
    llm :enrich_lead, "Analyze and score this lead:" do
      # Run this step only if the previous validation passed
      run_when :check_lead_data, { valid: true }

      input :lead_email, :company_size
      output :analysis
      model "gpt-4o-mini"
      response_format :json
      
      # The prompt automatically interpolates values from context
      prompt <<~PROMPT
        Lead Email: {{lead_email}}
        Company Size: {{company_size}} employees

        Based on this, provide a qualification score (1-100) and identify potential needs.
        Return JSON with keys: "score", "potential_needs", "category" (hot/warm/cold).
      PROMPT
    end

    # Step 3: Save the analysis to the database
    task :save_analysis do
      input :analysis
      process do |analysis|
        # In a real app, you would save this to your Lead model
        # Lead.find_by(email: ...).update(analysis_data: analysis)
        puts "Saving analysis: #{analysis.inspect}"
        { saved: true, score: analysis["score"] }
      end
    end
  end
end
```

## 5. Creating Your Agent

Agents connect your Rails application logic to your workflows.

```bash
rails generate super_agent:agent Lead
```
This creates `app/agents/lead_agent.rb`.

Inside the agent, define methods that execute your workflows.

```ruby
# app/agents/lead_agent.rb
class LeadAgent < ApplicationAgent
  # Synchronous execution: waits for the workflow to complete.
  def qualify_lead(email, company_size)
    run_workflow(
      LeadAnalysisWorkflow,
      initial_input: { lead_email: email, company_size: company_size }
    )
  end

  # Asynchronous execution: runs the workflow in the background via ActiveJob.
  def qualify_lead_later(email, company_size)
    run_workflow_later(
      LeadAnalysisWorkflow,
      initial_input: { lead_email: email, company_size: company_size }
    )
  end
end
```

## 6. Using Agents in Controllers

Finally, use your agent in a Rails controller to handle user requests.

```ruby
# app/controllers/leads_controller.rb
class LeadsController < ApplicationController
  def create
    # Instantiate the agent, passing in Rails context like current_user
    lead_agent = LeadAgent.new(current_user: current_user)

    # Run the workflow asynchronously
    lead_agent.qualify_lead_later(params[:email], params[:company_size])

    # Respond immediately to the user
    render json: { message: "Lead analysis has started and will be processed in the background." }, status: :accepted
  end

  def show
    # Example of a synchronous call
    lead_agent = LeadAgent.new
    result = lead_agent.qualify_lead(params[:email], params[:company_size])

    if result.completed?
      render json: { analysis: result.final_output }
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end
end
```

## 7. The Workflow DSL in Detail

### Global Configuration (within `workflow do ... end`)

*   `timeout <seconds>`: Sets a maximum execution time for the entire workflow.
*   `retry_policy max_retries: <num>, delay: <seconds>`: Configures automatic retries on failure.
*   `on_error do |error, context| ... end`: Defines a global error handler.
*   `before_all do |context| ... end`: A hook that runs before any task.
*   `after_all do |context| ... end`: A hook that runs after all tasks complete.

### Task Configuration (within a task block)

*   `input :key1, :key2`: Specifies which keys from the context are passed as arguments to the `process` block.
*   `output :result_key`: Maps the return value of the `process` block to a specific key in the context.
*   `run_if { |context| ... }`: A block that must return true for the task to run.
*   `run_when :previous_task, <value>`: Runs the task only if the output of a previous task matches the value.
*   `skip_if { |context| ... }`: Skips the task if the block returns true.
*   `description "..."`: Adds a human-readable description.

### Built-in Task Reference

SuperAgent includes a rich set of built-in tasks, used via the `task :name, :type` or a shortcut method.

| Task Type (`:type`)         | Shortcut Method         | Description & Key Options                                                                                                    |
| --------------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `:direct_handler`           | `task :name do ... end` | Executes a Ruby block. The primary building block for custom logic.                                                          |
| `:llm`                      | `llm :name do ... end`  | Executes a Large Language Model call. Options: `:model`, `:prompt`, `:temperature`, `:response_format`.                       |
| `:active_record_find`       | `fetch :name do ... end`| Finds an ActiveRecord record. Options: `:model` (class name string), `:find_by` (hash of conditions).                        |
| `:active_record_scope`      | `query :name do ... end`| Executes an ActiveRecord query. Options: `:model`, `:where` (hash of conditions), `:limit`, `:order`.                      |
| `:action_mailer`            | `email :name do ... end`| Sends an email via ActionMailer. Options: `:mailer` (class name), `:action` (method name), `:params` (hash).                 |
| `:pundit_policy`            | `task :name, :pundit_policy` | Checks authorization using Pundit. Options: `:policy_class`, `:action`. Requires a user object in context.             |
| `:turbo_stream`             | `stream :name do ... end` | Broadcasts a Turbo Stream update. Options: `:target` (DOM ID), `:action` (:append, :replace), `:partial` (view path).      |
| `:a2a`                      | `a2a_agent :name do ... end` | Invokes a skill on another A2A-compatible agent. Options: `:agent_url`, `:skill`, `:auth`.                                   |
| `:image_generation`         | `image :name do ... end` | Generates an image using DALL-E. Options: `:prompt`, `:size`, `:quality`.                                                     |
| `:file_upload`              | `upload_file :name do ... end` | Uploads a local file to OpenAI. Options: `:file_path`, `:purpose`.                                                           |
| `:file_search`              | `search :name, :file_search` | Performs RAG by searching content within files in an OpenAI Vector Store. Options: `:query`, `:vector_store_ids`.           |
| `:vector_store_management`  | `task :name, :vector_store` | Manages OpenAI Vector Stores. Options: `:operation` (:create, :add_file, :delete), `:name`, `:file_ids`.                   |
| `:web_search`               | `search :name, :web_search` | Performs a web search. Options: `:query`, `:search_context_size`.                                                          |
| `:assistant`                | `task :name, :assistant` | Uses the OpenAI Assistant API with file search capabilities. Options: `:instructions`, `:prompt`, `:file_ids`.           |

## 8. Advanced Feature: A2A (Agent-to-Agent) Protocol

SuperAgent includes a server and client for machine-to-machine communication, allowing your application to expose its workflows as "skills" to other AI systems.

**To set up an A2A server:**

1.  Run the generator: `rails generate super_agent:a2a_server --auth`
2.  Configure your token in `.env.a2a` and the initializer at `config/initializers/super_agent_a2a.rb`.
3.  Start the server with the rake task: `rake super_agent:a2a:serve`

Your application will now expose an `agent.json` card describing its capabilities, which can be invoked by other A2A clients.

## 9. Testing Your Workflows

Testing is crucial for reliable AI systems. SuperAgent is designed to be testable.

Create a workflow spec using the generator:
`rails generate super_agent:workflow LeadAnalysis --spec`

```ruby
# spec/workflows/lead_analysis_workflow_spec.rb
require 'rails_helper'

RSpec.describe LeadAnalysisWorkflow, type: :workflow do
  let(:context) { SuperAgent::Workflow::Context.new(lead_email: "test@example.com", company_size: 50) }
  let(:engine) { SuperAgent::WorkflowEngine.new }

  it "successfully qualifies a valid lead" do
    # Mock external dependencies, especially LLM calls
    # This ensures your test is fast and deterministic.
    allow_any_instance_of(SuperAgent::LlmInterface).to receive(:complete)
      .and_return('{"score": 85, "potential_needs": ["CRM"], "category": "hot"}')

    # Execute the workflow
    result = engine.execute(LeadAnalysisWorkflow, context)

    # Assert the outcome
    expect(result).to be_completed
    
    # Check the output of specific steps
    enrichment_output = result.output_for(:enrich_lead)
    expect(enrichment_output["score"]).to eq(85)
    
    final_output = result.final_output
    expect(final_output[:saved]).to be true
  end

  it "fails when lead data is invalid" do
    invalid_context = SuperAgent::Workflow::Context.new(lead_email: "invalid", company_size: -1)
    
    result = engine.execute(LeadAnalysisWorkflow, invalid_context)
    
    expect(result).to be_failed
    expect(result.failed_task_name).to eq(:check_lead_data)
    expect(result.error_message).to include("Company size must be a positive number")
  end
end
