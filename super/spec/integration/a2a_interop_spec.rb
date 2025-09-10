# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'A2A Interoperability', type: :a2a do
  let(:agent_url) { 'http://test-agent:8080' }
  let(:test_workflow) { build_test_workflow_with_a2a(agent_url: agent_url) }

  describe 'Agent Card Discovery' do
    it 'fetches and parses agent cards correctly' do
      capabilities = [
        {
          'name' => 'text_analysis',
          'description' => 'Analyzes text content',
          'parameters' => {
            'text' => { 'type' => 'string', 'required' => true },
            'options' => { 'type' => 'object', 'required' => false },
          },
          'returns' => {
            'type' => 'object',
            'properties' => {
              'sentiment' => { 'type' => 'string' },
              'entities' => { 'type' => 'array' },
            },
          },
          'tags' => %w[nlp analysis],
          'examples' => [
            {
              'input' => { 'text' => 'I love this product!' },
              'output' => { 'sentiment' => 'positive', 'entities' => ['product'] },
            },
          ],
        },
      ]

      mock_a2a_agent_card(agent_url, capabilities)

      client = SuperAgent::A2A::Client.new(agent_url)
      card = client.fetch_agent_card

      expect(card).to be_a(SuperAgent::A2A::AgentCard)
      expect(card).to be_valid
      expect(card.name).to eq('Test Agent')
      expect(card.capabilities.size).to eq(1)
      expect(card.capabilities.first.name).to eq('text_analysis')
      expect(card.capabilities.first.tags).to include('nlp')
      expect(card.supports_modality?('text')).to be true
      expect(card.supports_modality?('video')).to be false
    end

    it 'caches agent cards with TTL' do
      mock_a2a_agent_card(agent_url)

      client = SuperAgent::A2A::Client.new(agent_url, cache_ttl: 300)

      # First call
      card1 = client.fetch_agent_card

      # Second call should use cache
      card2 = client.fetch_agent_card

      expect(card1.id).to eq(card2.id)
      expect(WebMock).to have_requested(:get, "#{agent_url}/.well-known/agent.json").once
    end

    it 'handles force refresh of cached agent cards' do
      mock_a2a_agent_card(agent_url)

      client = SuperAgent::A2A::Client.new(agent_url)

      # First call
      client.fetch_agent_card

      # Force refresh
      card = client.fetch_agent_card(force_refresh: true)

      expect(card).to be_a(SuperAgent::A2A::AgentCard)
      expect(WebMock).to have_requested(:get, "#{agent_url}/.well-known/agent.json").twice
    end

    it 'validates agent card format and content' do
      mock_a2a_agent_card(agent_url)

      client = SuperAgent::A2A::Client.new(agent_url)
      card = client.fetch_agent_card

      # Validate required fields
      expect(card.id).to be_present
      expect(card.name).to be_present
      expect(card.version).to be_present
      expect(card.service_endpoint_url).to be_present
      expect(card.capabilities).to be_present

      # Validate URL format
      expect { URI.parse(card.service_endpoint_url) }.not_to raise_error

      # Validate capabilities structure
      card.capabilities.each do |capability|
        expect(capability.name).to be_present
        expect(capability.description).to be_present
      end
    end
  end

  describe 'Skill Invocation' do
    before do
      mock_a2a_agent_card(agent_url)
      mock_a2a_health_check(agent_url)
    end

    it 'successfully invokes remote skills' do
      expected_result = {
        'analysis' => 'positive',
        'confidence' => 0.95,
        'entities' => %w[product feature],
      }
      mock_a2a_skill_invocation(agent_url, 'test_skill', expected_result)

      client = SuperAgent::A2A::Client.new(agent_url)
      result = client.invoke_skill('test_skill', { input: 'test data', context: 'analysis' })

      expect(result['status']).to eq('completed')
      expect(result['result']).to eq(expected_result)

      assert_a2a_skill_called(agent_url, 'test_skill', { 'input' => 'test data' })
    end

    it 'handles skill invocation with complex parameters' do
      complex_params = {
        'text' => 'Analyze this complex text',
        'options' => {
          'language' => 'en',
          'include_sentiment' => true,
          'include_entities' => true,
          'confidence_threshold' => 0.8,
        },
        'metadata' => {
          'source' => 'user_input',
          'timestamp' => Time.current.iso8601,
        },
      }

      expected_result = {
        'sentiment' => { 'label' => 'positive', 'score' => 0.92 },
        'entities' => [
          { 'text' => 'complex text', 'type' => 'CONTENT', 'confidence' => 0.85 },
        ],
        'language' => 'en',
      }

      mock_a2a_skill_invocation(agent_url, 'text_analysis', expected_result)

      client = SuperAgent::A2A::Client.new(agent_url)
      result = client.invoke_skill('text_analysis', complex_params)

      expect(result['result']['sentiment']['label']).to eq('positive')
      expect(result['result']['entities']).to be_an(Array)
      assert_a2a_skill_called(agent_url, 'text_analysis')
    end

    it 'handles skill invocation errors gracefully' do
      stub_request(:post, "#{agent_url}/invoke")
        .to_return(
          status: 400,
          body: {
            'jsonrpc' => '2.0',
            'error' => {
              'code' => -32_602,
              'message' => "Invalid parameters: missing required field 'text'",
            },
            'id' => 'test-request',
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      client = SuperAgent::A2A::Client.new(agent_url)

      expect do
        client.invoke_skill('text_analysis', {})
      end.to raise_error(SuperAgent::A2A::InvocationError, /Invalid parameters/)
    end

    it 'validates skill exists before invocation' do
      # Mock agent card without the requested skill
      capabilities = [
        { 'name' => 'other_skill', 'description' => 'Different skill' },
      ]
      mock_a2a_agent_card(agent_url, capabilities)

      client = SuperAgent::A2A::Client.new(agent_url)

      expect do
        client.invoke_skill('nonexistent_skill', {})
      end.to raise_error(SuperAgent::A2A::SkillNotFoundError, /Available skills: other_skill/)
    end

    it 'includes request IDs for tracking' do
      mock_a2a_skill_invocation(agent_url, 'test_skill', { 'success' => true })

      client = SuperAgent::A2A::Client.new(agent_url)
      request_id = 'custom-request-123'

      result = client.invoke_skill('test_skill', { input: 'data' }, request_id: request_id)

      expect(WebMock).to(have_requested(:post, "#{agent_url}/invoke")
        .with do |req|
          body = JSON.parse(req.body)
          body['id'] == request_id &&
            body['params']['task']['id'] == request_id
        end)
    end
  end

  describe 'Workflow Integration' do
    before do
      mock_a2a_agent_card(agent_url)
      mock_a2a_health_check(agent_url)
    end

    it 'executes workflows with A2A tasks successfully' do
      expected_result = {
        'processed_text' => 'Hello A2A processed',
        'tokens' => 3,
        'metadata' => { 'processing_time' => '0.5s' },
      }
      mock_a2a_skill_invocation(agent_url, 'test_skill', expected_result)

      context = SuperAgent::Workflow::Context.new
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(test_workflow, context)

      expect(result).to be_completed
      expect(result.context.get(:external_result)).to eq(expected_result)
      expect(result.context.get(:processed)).to be_present
      expect(result.context.get(:processed)[:processed]).to eq(expected_result)
    end

    it 'handles A2A task failures based on configuration' do
      create_a2a_error_scenario(agent_url, :server_error)

      # Test with fail_on_error: true (default)
      context = SuperAgent::Workflow::Context.new
      engine = SuperAgent::WorkflowEngine.new

      expect do
        engine.execute(test_workflow, context)
      end.to raise_error(SuperAgent::Workflow::TaskError)
    end

    it 'continues workflow execution when fail_on_error is false' do
      workflow_class = Class.new(ApplicationWorkflow) do
        workflow do
          a2a_agent :tolerant_call do
            agent_url 'http://test-agent:8080'
            skill 'test_skill'
            fail_on_error false
            output :a2a_result
          end

          task :final_step do
            process { { status: 'completed_despite_a2a_failure' } }
          end
        end
      end

      create_a2a_error_scenario(agent_url, :server_error)

      context = SuperAgent::Workflow::Context.new
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(workflow_class, context)

      expect(result).to be_completed
      expect(result.context.get(:a2a_result)[:error]).to be_present
      expect(result.context.get(:status)).to eq('completed_despite_a2a_failure')
    end

    it 'properly passes context data to A2A agents' do
      workflow_class = Class.new(ApplicationWorkflow) do
        workflow do
          task :prepare_context do
            process do |context|
              context.set(:user_id, 123)
              context.set(:analysis_type, 'sentiment')
              context.set(:text_content, 'This is great!')
            end
          end

          a2a_agent :analyze_text do
            agent_url 'http://test-agent:8080'
            skill 'text_analysis'
            input :text_content, :analysis_type, :user_id
            output :analysis_result
          end
        end
      end

      mock_a2a_skill_invocation(agent_url, 'text_analysis', { 'sentiment' => 'positive' })

      context = SuperAgent::Workflow::Context.new
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(workflow_class, context)

      expect(result).to be_completed

      assert_a2a_skill_called(agent_url, 'text_analysis', {
                                'text_content' => 'This is great!',
                                'analysis_type' => 'sentiment',
                                'user_id' => 123,
                              })
    end
  end

  describe 'Streaming Support' do
    before do
      mock_a2a_agent_card(agent_url)
      mock_a2a_health_check(agent_url)
    end

    it 'handles streaming responses' do
      streaming_workflow = Class.new(ApplicationWorkflow) do
        workflow do
          a2a_agent :streaming_call do
            agent_url 'http://test-agent:8080'
            skill 'streaming_skill'
            stream true
            output :stream_result
          end
        end
      end

      events = [
        { event: 'start', data: { status: 'started', id: 'stream-123' } },
        { event: 'task_start', data: { task: 'processing', status: 'running' } },
        { event: 'task_complete',
          data: { task: 'processing', status: 'completed', result: { chunk: 1, data: 'first' } }, },
        { event: 'task_complete',
          data: { task: 'finalize', status: 'completed', result: { chunk: 2, data: 'second' } }, },
        { event: 'complete', data: { status: 'completed', result: { final: 'result', chunks_processed: 2 } } },
      ]

      mock_a2a_streaming_invocation(agent_url, 'streaming_skill', events)

      context = SuperAgent::Workflow::Context.new
      engine = SuperAgent::WorkflowEngine.new
      result = engine.execute(streaming_workflow, context)

      expect(result).to be_completed
      expect(result.context.get(:stream_result)).to be_present
      expect(result.context.get(:stream_result)[:chunks_processed]).to eq(2)
    end

    it 'handles streaming errors' do
      streaming_workflow = build_simple_a2a_workflow

      error_events = [
        { event: 'start', data: { status: 'started' } },
        { event: 'error', data: { status: 'failed', error: 'Processing failed' } },
      ]

      mock_a2a_streaming_invocation(agent_url, 'echo', error_events)

      context = SuperAgent::Workflow::Context.new
      engine = SuperAgent::WorkflowEngine.new

      expect do
        engine.execute(streaming_workflow, context)
      end.to raise_error(SuperAgent::A2A::InvocationError, /Streaming errors/)
    end
  end

  describe 'Authentication' do
    let(:auth_token) { 'test-auth-token-12345' }
    let(:authenticated_agent_url) { 'http://secure-agent:8080' }

    before do
      mock_a2a_agent_card(authenticated_agent_url)
      mock_a2a_health_check(authenticated_agent_url)
    end

    it 'includes authentication headers in requests' do
      mock_a2a_skill_invocation(authenticated_agent_url, 'test_skill', { 'authenticated' => true })

      client = SuperAgent::A2A::Client.new(authenticated_agent_url, auth_token: auth_token)
      result = client.invoke_skill('test_skill', { input: 'data' })

      expect(WebMock).to have_requested(:post, "#{authenticated_agent_url}/invoke")
        .with(headers: { 'Authorization' => "Bearer #{auth_token}" })
      expect(result['result']['authenticated']).to be true
    end

    it 'supports different authentication types' do
      auth_config = {
        type: :api_key,
        token: 'api-key-12345',
      }

      client = SuperAgent::A2A::Client.new(authenticated_agent_url, auth_token: auth_config)

      # Mock the request to check for API key header
      stub_request(:get, "#{authenticated_agent_url}/.well-known/agent.json")
        .with(headers: { 'X-API-Key' => 'api-key-12345' })
        .to_return(status: 200, body: mock_a2a_agent_card(authenticated_agent_url).to_json)

      client.fetch_agent_card

      expect(WebMock).to have_requested(:get, "#{authenticated_agent_url}/.well-known/agent.json")
        .with(headers: { 'X-API-Key' => 'api-key-12345' })
    end

    it 'handles authentication failures' do
      mock_a2a_auth_error(authenticated_agent_url)

      client = SuperAgent::A2A::Client.new(authenticated_agent_url, auth_token: 'invalid-token')

      expect do
        client.fetch_agent_card
      end.to raise_error(SuperAgent::A2A::AuthenticationError)
    end
  end

  describe 'Error Handling and Retries' do
    before do
      mock_a2a_agent_card(agent_url)
      mock_a2a_health_check(agent_url)
    end

    it 'retries on network failures' do
      # First two requests fail, third succeeds
      stub_request(:post, "#{agent_url}/invoke")
        .to_raise(Net::TimeoutError).then
        .to_raise(Errno::ECONNREFUSED).then
        .to_return(
          status: 200,
          body: {
            'jsonrpc' => '2.0',
            'result' => { 'status' => 'completed', 'result' => { 'retry_success' => true } },
            'id' => 'retry-test',
          }.to_json
        )

      client = SuperAgent::A2A::Client.new(agent_url, max_retries: 3)
      result = client.invoke_skill('test_skill', { input: 'retry_test' })

      expect(result['result']['retry_success']).to be true
      expect(WebMock).to have_requested(:post, "#{agent_url}/invoke").times(3)
    end

    it 'gives up after max retries' do
      stub_request(:post, "#{agent_url}/invoke")
        .to_raise(Net::TimeoutError)

      client = SuperAgent::A2A::Client.new(agent_url, max_retries: 2)

      expect do
        client.invoke_skill('test_skill', { input: 'fail_test' })
      end.to raise_error(SuperAgent::A2A::TimeoutError)

      expect(WebMock).to have_requested(:post, "#{agent_url}/invoke").times(2)
    end

    it 'wraps different error types appropriately' do
      test_cases = [
        { error: Net::TimeoutError.new('timeout'), expected: SuperAgent::A2A::TimeoutError },
        { error: SocketError.new('connection refused'), expected: SuperAgent::A2A::NetworkError },
        { error: JSON::ParserError.new('invalid json'), expected: SuperAgent::A2A::ProtocolError },
      ]

      test_cases.each do |test_case|
        stub_request(:post, "#{agent_url}/invoke")
          .to_raise(test_case[:error])

        client = SuperAgent::A2A::Client.new(agent_url, max_retries: 1)

        expect do
          client.invoke_skill('test_skill', {})
        end.to raise_error(test_case[:expected])
      end
    end
  end

  describe 'Client Configuration' do
    it 'respects timeout configuration' do
      client = SuperAgent::A2A::Client.new(agent_url, timeout: 5)

      expect(client.timeout).to eq(5)
    end

    it 'supports custom cache TTL' do
      client = SuperAgent::A2A::Client.new(agent_url, cache_ttl: 600)

      # Test that cache manager uses custom TTL
      expect(client.cache_manager.instance_variable_get(:@ttl)).to eq(600)
    end

    it 'provides client information' do
      client = SuperAgent::A2A::Client.new(agent_url, timeout: 15)
      info = client.agent_info

      expect(info[:url]).to eq(agent_url)
      expect(info[:timeout]).to eq(15)
      expect(info[:cache_size]).to be_a(Integer)
    end
  end
end
