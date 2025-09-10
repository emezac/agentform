# frozen_string_literal: true

require 'webmock/rspec' if defined?(WebMock)

module A2ATestHelpers
  # Mock an A2A agent card response
  def mock_a2a_agent_card(agent_url, capabilities = [])
    default_capabilities = [
      {
        'name' => 'test_skill',
        'description' => 'Test skill for A2A integration',
        'parameters' => {
          'input' => { 'type' => 'string', 'required' => true },
          'options' => { 'type' => 'object', 'required' => false },
        },
        'returns' => {
          'type' => 'object',
          'properties' => {
            'result' => { 'type' => 'string' },
            'status' => { 'type' => 'string' },
          },
        },
        'examples' => [
          {
            'input' => { 'input' => 'test data' },
            'output' => { 'result' => 'processed', 'status' => 'completed' },
          },
        ],
        'tags' => %w[test example],
      },
    ]

    card_data = {
      'id' => "test-agent-#{SecureRandom.hex(4)}",
      'name' => 'Test Agent',
      'description' => 'Mock A2A agent for testing',
      'version' => '1.0.0',
      'serviceEndpointURL' => agent_url,
      'supportedModalities' => %w[text json],
      'authenticationRequirements' => {},
      'capabilities' => capabilities.presence || default_capabilities,
      'metadata' => {
        'superagent_version' => 'test',
        'created_with' => 'A2A Test Helpers',
      },
      'createdAt' => Time.current.iso8601,
      'updatedAt' => Time.current.iso8601,
    }

    if defined?(WebMock)
      stub_request(:get, "#{agent_url}/.well-known/agent.json")
        .to_return(
          status: 200,
          body: card_data.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'Cache-Control' => 'public, max-age=300',
            'ETag' => "\"#{Digest::MD5.hexdigest(card_data.to_json)}\"",
          }
        )
    end

    card_data
  end

  # Mock an A2A skill invocation response
  def mock_a2a_skill_invocation(agent_url, skill_name, result, status: 200, request_id: nil)
    response_body = {
      'jsonrpc' => '2.0',
      'result' => {
        'status' => 'completed',
        'result' => result,
        'metadata' => {
          'execution_time' => Time.current.iso8601,
          'request_id' => request_id || "test-#{SecureRandom.hex(4)}",
        },
      },
      'id' => request_id || 'test-request',
    }

    if defined?(WebMock)
      stub_request(:post, "#{agent_url}/invoke")
        .with(
          body: hash_including(
            'method' => 'invoke',
            'params' => hash_including(
              'task' => hash_including('skill' => skill_name)
            )
          ),
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(
          status: status,
          body: response_body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    response_body
  end

  # Mock A2A streaming response
  def mock_a2a_streaming_invocation(agent_url, skill_name, events)
    sse_response = events.map do |event|
      "event: #{event[:event]}\n" +
        "data: #{event[:data].to_json}\n\n"
    end.join

    if defined?(WebMock)
      stub_request(:post, "#{agent_url}/invoke")
        .with(
          headers: { 'Accept' => 'text/event-stream' }
        )
        .to_return(
          status: 200,
          body: sse_response,
          headers: { 'Content-Type' => 'text/event-stream' }
        )
    end

    sse_response
  end

  # Mock A2A health check
  def mock_a2a_health_check(agent_url, healthy: true)
    status_code = healthy ? 200 : 503
    body = {
      'status' => healthy ? 'healthy' : 'unhealthy',
      'timestamp' => Time.current.iso8601,
      'uptime_seconds' => 3600,
      'version' => '1.0.0',
    }

    if defined?(WebMock)
      stub_request(:get, "#{agent_url}/health")
        .to_return(
          status: status_code,
          body: body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    body
  end

  # Mock A2A authentication error
  def mock_a2a_auth_error(agent_url)
    return unless defined?(WebMock)

    stub_request(:any, /#{Regexp.escape(agent_url)}.*/)
      .to_return(
        status: 401,
        body: { 'error' => 'Unauthorized', 'code' => 'auth_required' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Mock A2A network error
  def mock_a2a_network_error(agent_url, error_class: SocketError)
    return unless defined?(WebMock)

    stub_request(:any, /#{Regexp.escape(agent_url)}.*/)
      .to_raise(error_class.new('Connection refused'))
  end

  # Build a test workflow with A2A tasks
  def build_test_workflow_with_a2a(agent_url: 'http://test-agent:8080', skill: 'test_skill')
    Class.new(ApplicationWorkflow) do
      workflow do
        task :prepare_data do
          process { |context| context.set(:test_input, 'Hello A2A') }
        end

        a2a_agent :call_external_agent do
          agent_url agent_url
          skill skill
          input :test_input
          output :external_result
          timeout 30
        end

        task :process_result do
          input :external_result
          process { |result| { processed: result, timestamp: Time.current.iso8601 } }
        end
      end
    end
  end

  # Build a simple A2A workflow for testing
  def build_simple_a2a_workflow(agent_url: 'http://test-agent:8080')
    Class.new(ApplicationWorkflow) do
      workflow do
        a2a_agent :simple_call do
          agent_url agent_url
          skill 'echo'
          process { |context| { message: 'test' } }
        end
      end
    end
  end

  # Create a mock A2A agent card object
  def create_test_agent_card(name: 'Test Agent', capabilities: nil)
    capabilities ||= [
      SuperAgent::A2A::Capability.new(
        name: 'test_skill',
        description: 'Test skill for A2A integration',
        parameters: { 'input' => { 'type' => 'string' } },
        returns: { 'type' => 'object' }
      ),
    ]

    SuperAgent::A2A::AgentCard.new(
      name: name,
      description: 'Test agent for A2A integration',
      version: '1.0.0',
      service_endpoint_url: 'http://test-agent:8080',
      capabilities: capabilities
    )
  end

  # Create a test A2A client with mocked responses
  def create_test_a2a_client(agent_url: 'http://test-agent:8080', capabilities: nil)
    mock_a2a_agent_card(agent_url, capabilities)
    mock_a2a_health_check(agent_url)

    SuperAgent::A2A::Client.new(agent_url)
  end

  # Assert A2A skill was called with expected parameters
  def assert_a2a_skill_called(agent_url, skill_name, parameters = {})
    return unless defined?(WebMock)

    expect(WebMock).to(have_requested(:post, "#{agent_url}/invoke")
      .with do |req|
        body = JSON.parse(req.body)
        body['method'] == 'invoke' &&
          body['params']['task']['skill'] == skill_name &&
          (parameters.empty? || body['params']['task']['parameters'].include?(parameters.stringify_keys))
      end)
  end

  # Create A2A error scenarios
  def create_a2a_error_scenario(agent_url, error_type)
    case error_type
    when :timeout
      if defined?(WebMock)
        stub_request(:any, /#{Regexp.escape(agent_url)}.*/)
          .to_timeout
      end
    when :server_error
      if defined?(WebMock)
        stub_request(:any, /#{Regexp.escape(agent_url)}.*/)
          .to_return(status: 500, body: 'Internal Server Error')
      end
    when :skill_not_found
      mock_a2a_skill_invocation(agent_url, 'nonexistent_skill', {}, status: 400)
    when :invalid_response
      if defined?(WebMock)
        stub_request(:any, /#{Regexp.escape(agent_url)}.*/)
          .to_return(status: 200, body: 'invalid json', headers: { 'Content-Type' => 'application/json' })
      end
    end
  end

  # Helpers for testing streaming
  def mock_streaming_events
    [
      { event: 'start', data: { status: 'started', id: 'test-123' } },
      { event: 'task_start', data: { task: 'process_data', status: 'running' } },
      { event: 'task_complete', data: { task: 'process_data', status: 'completed', result: { processed: true } } },
      { event: 'complete', data: { status: 'completed', result: { final_result: 'success' } } },
    ]
  end

  # Helper to test A2A server responses
  def test_a2a_server_response(path, expected_status: 200, expected_content_type: 'application/json')
    response = get path

    expect(response.status).to eq(expected_status)
    expect(response.headers['Content-Type']).to include(expected_content_type)

    if expected_content_type.include?('json')
      JSON.parse(response.body)
    else
      response.body
    end
  end

  # Validate A2A message format
  def validate_a2a_message(message_data)
    expect(message_data).to have_key('id')
    expect(message_data).to have_key('role')
    expect(message_data).to have_key('parts')
    expect(message_data).to have_key('timestamp')
    expect(message_data['parts']).to be_an(Array)
  end

  # Validate A2A artifact format
  def validate_a2a_artifact(artifact_data)
    expect(artifact_data).to have_key('id')
    expect(artifact_data).to have_key('type')
    expect(artifact_data).to have_key('name')
    expect(artifact_data).to have_key('content')
    expect(artifact_data).to have_key('createdAt')
  end

  # Helper for testing authentication
  def with_a2a_auth_token(token)
    old_token = SuperAgent.configuration.a2a_auth_token
    SuperAgent.configuration.a2a_auth_token = token
    yield
  ensure
    SuperAgent.configuration.a2a_auth_token = old_token
  end

  # Helper for testing different environments
  def with_a2a_config(config_hash)
    old_config = {}
    config_hash.each do |key, value|
      old_config[key] = SuperAgent.configuration.public_send(key)
      SuperAgent.configuration.public_send("#{key}=", value)
    end
    yield
  ensure
    old_config.each do |key, value|
      SuperAgent.configuration.public_send("#{key}=", value)
    end
  end
end

# RSpec configuration
if defined?(RSpec)
  RSpec.configure do |config|
    config.include A2ATestHelpers, type: :a2a
    config.include A2ATestHelpers, a2a: true

    # Setup WebMock for A2A tests
    config.before(:each, type: :a2a) do
      WebMock.disable_net_connect!(allow_localhost: true) if defined?(WebMock)
    end

    config.after(:each, type: :a2a) do
      WebMock.reset! if defined?(WebMock)
    end
  end
end
