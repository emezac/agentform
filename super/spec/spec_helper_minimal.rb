# frozen_string_literal: true

require 'bundler/setup'
require 'logger'

# Minimal Rails mock
module Rails
  extend self
  
  def logger
    @logger ||= Logger.new(IO::NULL)
  end
  
  def env
    'test'
  end
end

# Load SuperAgent
require 'super_agent'
require 'openai'

module SuperAgentTestHelpers
  def setup_super_agent_config
    SuperAgent.reset_configuration
    SuperAgent.configure do |config|
      config.llm_provider = :openai
      config.openai_api_key = 'test-openai-key'
      config.default_llm_model = 'gpt-4'
      config.deprecation_warnings = false
      config.logger = Logger.new(IO::NULL)
    end
  end

  def create_test_context(data = {})
    SuperAgent::Workflow::Context.new({ user_id: 123 }.merge(data))
  end
end

RSpec.configure do |config|
  config.include SuperAgentTestHelpers
  
  config.disable_monkey_patching!
  
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:each) do
    setup_super_agent_config
  end
end
