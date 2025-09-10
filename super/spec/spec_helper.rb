# frozen_string_literal: true

require 'bundler/setup'
require 'logger'
require 'pathname'

# Load simple Rails mock before SuperAgent
require_relative 'support/simple_rails_mock'

# Now load SuperAgent
require 'super_agent'
require 'openai'

# Shims for ActiveSupport methods
class String
  def truncate(length)
    self.length > length ? self[0, length] + "..." : self
  end
end

class Integer
  def minutes
    self * 60
  end
end

module SuperAgentTestHelpers
  def setup_super_agent_config
    SuperAgent.reset_configuration
    SuperAgent.configure do |config|
      config.llm_provider = :openai
      config.openai_api_key = 'test-openai-key'
      config.open_router_api_key = 'test-openrouter-key'
      config.anthropic_api_key = 'test-anthropic-key'
      config.default_llm_model = 'gpt-4'
      config.deprecation_warnings = false
      config.logger = Logger.new(IO::NULL) # Silent logger for tests
    end
  end

  def mock_openai_client
    mock_client = double('OpenAI::Client')
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    mock_client
  end

  def mock_open_router_client
    # Mock OpenRouter dependencies
    stub_const('OpenRouter', double('OpenRouter'))
    allow(OpenRouter).to receive(:configure)
    
    mock_client = double('OpenRouter::Client')
    client_class = double('OpenRouter::Client')
    allow(client_class).to receive(:new).and_return(mock_client)
    stub_const('OpenRouter::Client', client_class)
    
    mock_client
  end

  def mock_anthropic_client
    mock_client = double('Anthropic::Client')
    client_class = double('Anthropic::Client')
    allow(client_class).to receive(:new).and_return(mock_client)
    stub_const('Anthropic::Client', client_class)
    
    mock_client
  end

  def standard_llm_response(content = "Test response")
    {
      'choices' => [
        { 'message' => { 'content' => content } }
      ]
    }
  end

  def create_test_context(data = {})
    default_data = { user_id: 123, name: "Test User" }
    SuperAgent::Workflow::Context.new(default_data.merge(data))
  end

  def execute_workflow_safely(workflow_class, context)
    engine = SuperAgent::WorkflowEngine.new
    engine.execute(workflow_class, context)
  rescue => e
    # Return a failed result for easier testing
    SuperAgent::WorkflowResult.new(
      status: :failed,
      error: e.message,
      failed_task_name: :unknown,
      full_trace: [],
      final_output: {},
      duration_ms: 0
    )
  end
end

RSpec.configure do |config|
  config.include SuperAgentTestHelpers
  
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
    # This option will default to `true` in RSpec 4
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # Setup SuperAgent before each test
  config.before(:each) do
    setup_super_agent_config
  end

  # Suppress deprecation warnings in tests
  config.before(:suite) do
    RSpec::Expectations.configuration.on_potential_false_positives = :nothing
  end
end
