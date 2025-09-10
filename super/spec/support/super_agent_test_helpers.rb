# frozen_string_literal: true

require 'bundler/setup'
require 'super_agent'
require 'openai'
require 'logger'

# Mock Rails if not present
unless defined?(Rails)
  module Rails
    def self.logger
      @logger ||= Logger.new(IO::NULL)
    end
    
    def self.env
      'test'
    end
    
    module_function :logger, :env
  end
end

# Load Capybara support for system tests
require_relative "support/capybara" if File.exist?(File.join(__dir__, "support", "capybara.rb"))

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
  end

  # Setup SuperAgent before each test
  config.before(:each) do
    setup_super_agent_config
  end

  # Configure system tests
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
end