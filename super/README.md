# SuperAgent 🤖

**A Rails-native AI workflow orchestration framework for building truly agentic applications.**

SuperAgent unifies complex AI workflow orchestration with native Rails MVC interactions, allowing you to build powerful SaaS applications that go beyond simple chatbots.

[![Gem Version](https://badge.fury.io/rb/super_agent.svg)](https://badge.fury.io/rb/super_agent)
[![Build Status](https://github.com/superagent-rb/super_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/superagent-rb/super_agent/actions/workflows/ci.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/YOUR_BADGE_ID/maintainability)](https://codeclimate.com/github/superagent-rb/super_agent/maintainability)

---

## What is SuperAgent?

SuperAgent is a framework designed for Rails developers who want to integrate advanced AI capabilities into their applications. Instead of making isolated calls to an LLM API, SuperAgent allows you to define, orchestrate, and execute multi-step workflows written in a Ruby DSL. These workflows can interact with your database models, send emails, authorize users, perform web searches, and much more.

It's the logic layer that connects your AI models with the rest of your Rails application, enabling you to build complex, autonomous systems.

## Core Concepts

-   **Workflows:** The heart of SuperAgent. They are definitions of multi-step processes written in a Ruby DSL (Domain-Specific Language). A workflow could be anything from generating a blog post (research → writing → saving) to qualifying a sales lead (validation → enrichment → analysis → action).
-   **Tasks:** The building blocks of a workflow. Each `task` is an individual step with a specific purpose. SuperAgent comes with a rich library of predefined tasks (LLM, ActiveRecord, ActionMailer, Pundit, etc.), and you can easily create your own.
-   **Agents:** The bridge between your Rails application (e.g., a controller) and your Workflows. Agents manage the creation of the initial context, security (like the current user), and decide which workflow to execute.
-   **Context:** An immutable object that carries state through a workflow. The output of one task is merged into the context, making it available to subsequent tasks.

## ✨ Key Features

-   **Fluent and Expressive DSL:** Define complex workflows in a readable and maintainable way directly in Ruby.
-   **A2A Protocol Integration:** 🆕 Connect with Google ADK and other A2A-compatible systems for distributed AI workflows.
-   **Deep Rails Integration:**
    -   **ActiveRecord:** Query and find database records as a native step.
    -   **ActionMailer:** Send emails directly from a workflow.
    -   **Pundit:** Apply authorization policies before executing tasks.
    -   **Turbo Streams:** Send real-time UI updates as the workflow progresses.
    -   **ActiveJob:** Execute long-running workflows in the background without blocking requests.
-   **Multi-Provider LLM Support:** Easily switch between **OpenAI**, **OpenRouter**, and **Anthropic** without changing your workflow logic.
-   **Agent Interoperability:** Call external A2A agents from workflows and expose workflows as A2A services.
-   **Extensive Task Library:** Includes tasks for LLM calls, web search, image generation, file operations (upload, RAG search), Vector Store management, scheduled tasks (cron), A2A agent calls, and more.
-   **Conditional Logic and Error Handling:** Control the execution flow with `run_if` / `skip_if` and define retry policies and `on_error` handlers at the workflow or task level.
-   **Real-time Streaming:** Offer your users an interactive experience by showing workflow progress step-by-step.
-   **Code Generators:** Quickly scaffold new workflows, agents, A2A integrations, and complete resources with `rails generate`.
-   **Observability and Persistence:** Detailed logging and an optional `ExecutionModel` to track every workflow execution in your database.

## 🚀 Installation

1.  Add the gem to your `Gemfile`:

    ```ruby
    gem 'super_agent'
    ```

2.  Install the gem:

    ```bash
    bundle install
    ```

3.  Run the SuperAgent installation generator:

    ```bash
    rails generate super_agent:install
    ```

    This will create the following files:
    -   `config/initializers/super_agent.rb`
    -   `app/agents/application_agent.rb`
    -   `app/workflows/application_workflow.rb`

4.  (Optional) To persist workflow executions, generate and run the migration:
    ```bash
    rails generate super_agent:migration
    rails db:migrate
    ```

## ⚙️ Configuration

Open `config/initializers/super_agent.rb` and configure your API keys. At a minimum, you'll need one for your primary LLM provider.

```ruby
# config/initializers/super_agent.rb

SuperAgent.configure do |config|
  # Choose your primary LLM provider: :openai, :open_router, :anthropic
  config.llm_provider = :openai

  # --- OpenAI Configuration ---
  config.openai_api_key = ENV['OPENAI_API_KEY']

  # --- OpenRouter Configuration ---
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']

  # --- Anthropic Configuration ---
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # Default LLM model
  config.default_llm_model = "gpt-4o-mini"

  # Assign the Rails logger
  config.logger = Rails.logger
end
```

## 🏁 Quick Start Guide

Let's create a simple workflow that takes a piece of text, generates a summary, and determines its sentiment.

**1. Create the Workflow**

Use the generator to create a new workflow file:
```bash
rails generate super_agent:workflow TextAnalysis
```

Now, edit `app/workflows/text_analysis_workflow.rb`:

```ruby
# app/workflows/text_analysis_workflow.rb
class TextAnalysisWorkflow < ApplicationWorkflow
  workflow do
    # Step 1: Generate a summary using an LLM
    llm :summarize_text do
      input :text_content # Expects :text_content from the initial context
      output :summary     # The output will be saved as :summary in the context

      model "gpt-4o-mini"
      system_prompt "You are an expert in text summarization."
      # The template uses double curly braces to access context data
      prompt "Summarize the following text in one sentence: {{text_content}}"
    end

    # Step 2: Analyze the sentiment of the summary
    llm :analyze_sentiment do
      input :summarize_text # The input is the complete output from the previous step
      output :sentiment     # The output will be :sentiment

      system_prompt "You are an expert in sentiment analysis."
      prompt "What is the sentiment of the following text? (Positive, Negative, or Neutral): {{summarize_text}}"
    end

    # Step 3: Format the final output
    task :format_output do
      input :summarize_text, :analyze_sentiment

      # 'process' defines a simple Ruby block to execute
      process do |summary, sentiment|
        {
          final_summary: summary.strip,
          detected_sentiment: sentiment.strip.downcase
        }
      end
    end
  end
end
```

**2. Create the Agent**

```bash
rails generate super_agent:agent Text
```

Edit `app/agents/text_agent.rb` to call our new workflow:

```ruby
# app/agents/text_agent.rb
class TextAgent < ApplicationAgent
  def analyze(text)
    # Run the workflow synchronously, passing the text as initial input
    run_workflow(TextAnalysisWorkflow, initial_input: { text_content: text })
  end
end
```

**3. Use it in a Rails Controller**

```ruby
# app/controllers/texts_controller.rb
class TextsController < ApplicationController
  def analyze
    text_to_analyze = params[:text]
    agent = TextAgent.new(current_user: current_user) # Pass Rails context to the agent

    result = agent.analyze(text_to_analyze)

    if result.completed?
      render json: result.final_output
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end
end
```

And that's it! You've just orchestrated a multi-step AI workflow fully integrated into your Rails application.

## 📖 Usage Guide

### Defining Workflows

The `workflow` DSL is the core of SuperAgent. Here's a breakdown of its capabilities:

```ruby
class MyWorkflow < ApplicationWorkflow
  workflow do
    # --- Workflow-level Configuration ---
    timeout 60  # Global timeout in seconds
    retry_policy max_retries: 2, delay: 1 # Default retry policy

    # --- Task Definitions ---

    # 1. Simple Ruby Task
    task :prepare_data do
      input :raw_data
      output :prepared_data
      process { |data| { processed: data.upcase } }
    end

    # 2. LLM Task
    llm :generate_content do
      input :prepared_data
      model "gpt-4o-mini"
      temperature 0.7
      response_format :json # Automatically parses the LLM output as JSON
      prompt "Generate content based on: {{prepared_data.processed}}"
    end

    # 3. Conditional Logic
    task :notify_admin do
      # Only runs if the condition is true
      run_if { |context| context.get(:generate_content)["needs_review"] }

      # Also available: skip_if, run_when(:key, value), skip_when(:key, value)

      process do |context|
        # ... logic to send notification
        { notified: true }
      end
    end

    # 4. Error Handling
    on_error :generate_content do |error, context|
      # This block runs if 'generate_content' fails
      Rails.logger.error "LLM failed: #{error.message}"
      { fallback_content: "Content not available." } # Return a fallback value
    end
  end
end
```

### Asynchronous Execution

For long-running tasks, avoid blocking the Rails request/response cycle by running the workflow in the background with ActiveJob.

```ruby
# in your agent
class MyAgent < ApplicationAgent
  def perform_async(data)
    # This enqueues a job and returns immediately
    run_workflow_later(MyWorkflow, initial_input: { raw_data: data })
  end
end

# in your controller
def create
  agent = MyAgent.new
  agent.perform_async(params[:my_data])
  render json: { message: "Processing has started in the background." }, status: :accepted
end
```

### Available Tasks

SuperAgent comes with a wide range of task types out of the box.

| Task Type                     | Description                                                                 | Example Usage                                                                                              |
| ----------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `task` (`:direct_handler`)    | Executes a Ruby code block.                                                 | `task(:my_logic) { process { ... } }`                                                                       |
| `llm` / `chat`                | Makes a call to an LLM for chat completion.                                 | `llm(:summarize, "Summarize: {{text}}")`                                                                    |
| `validate`                    | A task for validation logic.                                                | `validate(:is_valid) { process { ... } }`                                                                  |
| `fetch` / `query`             | Queries your database using ActiveRecord.                                   | `fetch(:get_user, "User") { find_by id: 1 }`                                                                |
| `email`                       | Sends an email using ActionMailer.                                          | `email(:welcome, "UserMailer", "welcome")`                                                                 |
| `stream`                      | Sends a Turbo Stream update to the UI.                                      | `stream(:update_ui) { target "#my_div" }`                                                                  |
| `image`                       | Generates an image using a model like DALL-E 3.                             | `image(:create_logo, "A logo for...")`                                                                      |
| `search`                      | Performs a web search.                                                      | `search(:research, "Latest news on AI")`                                                                   |
| `upload_file`                 | Uploads a file to OpenAI (for use with Assistants/RAG).                     | `upload_file(:upload_doc, "path/to/doc.pdf")`                                                              |
| `vector_store_management`     | Creates or manages OpenAI Vector Stores for RAG.                            | `task(:create_vs, :vector_store_management)`                                                               |
| `file_search`                 | Performs a semantic search within your Vector Stores.                       | `task(:search_docs, :file_search)`                                                                         |
| `:cron`                       | Schedules a workflow to run on a recurring basis.                           | `task(:daily_report, :cron, schedule: "0 9 * * *")`                                                         |
| `:pundit_policy`              | Verifies a Pundit policy before proceeding.                                 | `task(:authorize, :pundit_policy, action: :update?)`                                                        |

### Generators

Speed up your development with Rails generators:

-   `rails g super_agent:install`: Sets up SuperAgent in your application.
-   `rails g super_agent:workflow [WorkflowName]`: Creates a new workflow.
-   `rails g super_agent:agent [AgentName]`: Creates a new agent.
-   `rails g super_agent:resource [ResourceName]`: Creates a workflow, agent, and test files for a CRUD resource.

### Testing

Testing your workflows is straightforward. You can test the workflow logic in isolation without making real API calls.

```ruby
# spec/workflows/text_analysis_workflow_spec.rb
require 'rails_helper'

RSpec.describe TextAnalysisWorkflow, type: :workflow do
  let(:context) { SuperAgent::Workflow::Context.new(text_content: "This is a test text.") }
  let(:engine) { SuperAgent::WorkflowEngine.new }

  it "completes the workflow successfully" do
    # Mock the LLM response
    allow_any_instance_of(SuperAgent::Workflow::Tasks::LlmTask).to receive(:execute)
      .with(anything) # The first call (summary)
      .and_return("Test summary.")
      .once

    allow_any_instance_of(SuperAgent::Workflow::Tasks::LlmTask).to receive(:execute)
      .with(anything) # The second call (sentiment)
      .and_return("Positive")
      .once

    result = engine.execute(TextAnalysisWorkflow, context)

    expect(result).to be_completed
    expect(result.final_output[:final_summary]).to eq("Test summary.")
    expect(result.final_output[:detected_sentiment]).to eq("positive")
  end
end
```

## 🔗 A2A Protocol Integration

SuperAgent now supports the **A2A (Agent-to-Agent) Protocol**, enabling seamless interoperability with Google ADK and other A2A-compatible systems. This allows you to build distributed AI workflows across multiple agent services.

### Calling External A2A Agents

Use the `a2a_agent` task to call external A2A services from your workflows:

```ruby
class OrderProcessingWorkflow < ApplicationWorkflow
  workflow do
    # Check inventory with external A2A service
    a2a_agent :check_inventory do
      agent_url "http://inventory-service:8080"
      skill "check_stock"
      input :items
      output :inventory_status
      timeout 30
      auth_env "INVENTORY_SERVICE_TOKEN"
    end

    # Process payment with external A2A service
    a2a_agent :process_payment do
      agent_url "http://payment-processor:8080"
      skill "charge_card"
      input :customer_id, :total_amount
      output :payment_result
      timeout 45
      fail_on_error true
    end

    # Finalize order locally
    task :create_order do
      input :inventory_status, :payment_result
      process { |inventory, payment| create_order_logic(inventory, payment) }
    end
  end
end
```

### Exposing SuperAgent as A2A Service

Start the A2A server to expose your workflows as A2A-compatible services:

```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  # Enable A2A server
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
  config.a2a_auth_token = ENV['SUPER_AGENT_A2A_TOKEN']
end
```

Start the server:
```bash
rake super_agent:a2a:serve
```

Your workflows are now accessible via standard A2A endpoints:
- `GET /.well-known/agent.json` - Agent capability discovery
- `GET /health` - Health check
- `POST /invoke` - Skill invocation via JSON-RPC 2.0

### A2A Configuration Options

```ruby
SuperAgent.configure do |config|
  # Server settings
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
  config.a2a_server_host = '0.0.0.0'
  config.a2a_auth_token = ENV['A2A_AUTH_TOKEN']
  
  # Client settings
  config.a2a_default_timeout = 30
  config.a2a_max_retries = 2
  config.a2a_cache_ttl = 300
  
  # SSL/TLS (optional)
  config.a2a_ssl_cert_path = ENV['A2A_SSL_CERT']
  config.a2a_ssl_key_path = ENV['A2A_SSL_KEY']
end
```

### A2A Generators

Generate A2A-ready workflows:

```bash
# Generate A2A workflow with external service integration
rails generate super_agent:a2a:workflow PaymentProcessor

# Generate Docker deployment configuration
rails generate super_agent:a2a:deploy
```

### Authentication Options

The A2A integration supports multiple authentication methods:

```ruby
a2a_agent :secure_service do
  agent_url "https://secure-service:8080"
  skill "process_data"
  
  # Bearer token from environment
  auth_env "SERVICE_TOKEN"
  
  # Or API key authentication
  auth_config :api_key_config
  
  # Or dynamic authentication
  auth { |context| generate_token(context) }
end
```

**Documentation:**
- [A2A Implementation Guide](A2A_IMPLEMENTATION_SUMMARY.md)
- [A2A Validation Report](A2A_VALIDATION_REPORT.md)
- [Google ADK Web Integration](GOOGLE_ADK_WEB_INTEGRATION.md)
- [A2A Demo Script](examples/a2a_demo.rb)

## Migrating?

If you're coming from another framework like `ActiveAgent` or `rdawn`, check out our [Migration Guide](examples/migration_guide.md) for an easy transition.

## 🤝 Contributing

Contributions are welcome! Please open an issue to discuss significant changes or submit a pull request.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add new feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new Pull Request.

## 📜 License

This project is licensed under the terms of the MIT license. See the [LICENSE.txt](LICENSE.txt) file for details.
