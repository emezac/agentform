# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SuperAgent::LlmInterface do
  before do
    # Reset configuration before each test
    SuperAgent.reset_configuration
    SuperAgent.configure do |config|
      config.openai_api_key = 'test-openai-key'
      config.open_router_api_key = 'test-openrouter-key'
      config.anthropic_api_key = 'test-anthropic-key'
      config.open_router_site_name = 'TestApp'
      config.open_router_site_url = 'https://test.com'
    end
  end

  describe 'initialization' do
    context 'with OpenAI provider' do
      before do
        SuperAgent.configuration.llm_provider = :openai
      end

      it 'creates OpenAI client' do
        interface = described_class.new
        expect(interface.provider).to eq(:openai)
        expect(interface.client).to be_a(OpenAI::Client)
      end
    end

    context 'with OpenRouter provider' do
      let(:mock_client) { double('OpenRouter::Client') }

      before do
        SuperAgent.configuration.llm_provider = :open_router
        
        # Create a more complete mock of OpenRouter
        open_router_module = Module.new do
          def self.configure
            # Mock implementation
          end
        end
        
        open_router_client_class = Class.new do
          def initialize(*args)
            # Mock constructor that accepts any arguments
          end
        end
        
        stub_const('OpenRouter', open_router_module)
        stub_const('OpenRouter::Client', open_router_client_class)
        
        # Mock the client creation to return our mock
        allow(OpenRouter::Client).to receive(:new).and_return(mock_client)
      end

      it 'creates OpenRouter client' do
        interface = described_class.new
        expect(interface.provider).to eq(:open_router)
        expect(interface.client).to eq(mock_client)
      end
    end

    context 'with Anthropic provider' do
      let(:mock_client) { double('Anthropic::Client') }

      before do
        SuperAgent.configuration.llm_provider = :anthropic
        
        # Create a mock class that accepts the access_token argument
        anthropic_client_class = Class.new do
          def initialize(access_token: nil)
            # Mock constructor that accepts access_token
          end
        end
        
        stub_const('Anthropic', Module.new)
        stub_const('Anthropic::Client', anthropic_client_class)
        
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      end

      it 'creates Anthropic client' do
        interface = described_class.new
        expect(interface.provider).to eq(:anthropic)
        expect(interface.client).to eq(mock_client)
      end
    end

    context 'with custom provider' do
      let(:mock_client) { double('Anthropic::Client') }

      before do
        # Create a mock class that accepts the access_token argument
        anthropic_client_class = Class.new do
          def initialize(access_token: nil)
            # Mock constructor that accepts access_token
          end
        end
        
        stub_const('Anthropic', Module.new)
        stub_const('Anthropic::Client', anthropic_client_class)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      end

      it 'allows overriding provider' do
        SuperAgent.configuration.llm_provider = :openai
        interface = described_class.new(provider: :anthropic)
        expect(interface.provider).to eq(:anthropic)
      end
    end

    context 'with invalid provider' do
      before do
        SuperAgent.configuration.llm_provider = :invalid
      end

      it 'raises configuration error' do
        expect { described_class.new }.to raise_error(SuperAgent::ConfigurationError)
      end
    end
  end

  describe '#complete' do
    context 'with OpenAI provider' do
      let(:mock_client) { double('OpenAI::Client') }
      let(:interface) { described_class.new(provider: :openai) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        # Stub the client method to return our mock
        allow(interface).to receive(:client).and_return(mock_client)
      end

      it 'calls OpenAI completion' do
        response = {
          'choices' => [
            { 'message' => { 'content' => 'Hello, world!' } }
          ]
        }
        
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(
            model: 'gpt-4',
            messages: [{ role: 'user', content: 'Hello' }],
            temperature: 0.7
          )
        ).and_return(response)

        result = interface.complete(prompt: 'Hello', model: 'gpt-4')
        expect(result).to eq('Hello, world!')
      end

      it 'handles max_tokens parameter' do
        response = {
          'choices' => [
            { 'message' => { 'content' => 'Response' } }
          ]
        }
        
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(max_tokens: 100)
        ).and_return(response)

        interface.complete(prompt: 'Hello', max_tokens: 100)
      end

      it 'handles array of messages' do
        messages = [
          { role: 'system', content: 'You are helpful' },
          { role: 'user', content: 'Hello' }
        ]
        
        response = {
          'choices' => [
            { 'message' => { 'content' => 'Hi there!' } }
          ]
        }
        
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(messages: messages)
        ).and_return(response)

        result = interface.complete(prompt: messages)
        expect(result).to eq('Hi there!')
      end
    end

    context 'with OpenRouter provider' do
      let(:mock_client) { double('OpenRouter::Client') }
      let(:interface) { described_class.new(provider: :open_router) }

      before do
        # Create a more complete mock of OpenRouter
        open_router_module = Module.new do
          def self.configure
            # Mock implementation
          end
        end
        
        open_router_client_class = Class.new do
          def initialize(*args)
            # Mock constructor that accepts any arguments
          end
        end
        
        stub_const('OpenRouter', open_router_module)
        stub_const('OpenRouter::Client', open_router_client_class)
        
        allow(OpenRouter::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
      end

      it 'calls OpenRouter completion' do
        response = {
          'choices' => [
            { 'message' => { 'content' => 'OpenRouter response' } }
          ]
        }
        
        # Asegurar que el mock_client tenga el método chat
        allow(mock_client).to receive(:chat).with(
          parameters: hash_including(
            model: 'openai/gpt-4',
            messages: [{ role: 'user', content: 'Hello' }],
            temperature: 0.7
          )
        ).and_return(response)

        result = interface.complete(prompt: 'Hello', model: 'openai/gpt-4')
        expect(result).to eq('OpenRouter response')
      end
    end

    context 'with Anthropic provider' do
      let(:mock_client) { double('Anthropic::Client') }
      let(:interface) { described_class.new(provider: :anthropic) }

      before do
        # Create a mock class that accepts the access_token argument
        anthropic_client_class = Class.new do
          def initialize(access_token: nil)
            # Mock constructor that accepts access_token
          end
        end
        
        stub_const('Anthropic', Module.new)
        stub_const('Anthropic::Client', anthropic_client_class)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
      end

      it 'calls Anthropic completion with proper format' do
        messages = [
          { role: 'system', content: 'You are helpful' },
          { role: 'user', content: 'Hello' }
        ]
        
        response = {
          'content' => [
            { 'text' => 'Anthropic response' }
          ]
        }
        
        expect(mock_client).to receive(:messages).with(
          parameters: hash_including(
            model: 'claude-3-sonnet-20240229',
            system: 'You are helpful',
            messages: [{ role: 'user', content: 'Hello' }],
            max_tokens: 1000
          )
        ).and_return(response)

        result = interface.complete(prompt: messages, model: 'claude-3-sonnet-20240229')
        expect(result).to eq('Anthropic response')
      end
    end

    context 'error handling' do
      let(:mock_client) { double('OpenAI::Client') }
      let(:interface) { described_class.new(provider: :openai) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
      end

      it 'raises TaskError on API errors' do
        expect(mock_client).to receive(:chat).and_raise(StandardError.new('API Error'))

        expect {
          interface.complete(prompt: 'Hello')
        }.to raise_error(SuperAgent::TaskError, /API Error/)
      end
    end
  end

  describe '#generate_image' do
    context 'with OpenAI provider' do
      let(:mock_client) { double('OpenAI::Client') }
      let(:images_mock) { double('images') }
      let(:interface) { described_class.new(provider: :openai) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
        allow(mock_client).to receive(:images).and_return(images_mock)
      end

      it 'generates image with OpenAI' do
        response = {
          'data' => [
            { 'url' => 'https://example.com/image.png' }
          ]
        }
        
        expect(images_mock).to receive(:generate).with(
          parameters: hash_including(prompt: 'A beautiful sunset')
        ).and_return(response)

        result = interface.generate_image(prompt: 'A beautiful sunset')
        expect(result).to eq({ 'url' => 'https://example.com/image.png' })
      end
    end

    context 'with unsupported provider' do
      let(:mock_client) { double('Anthropic::Client') }
      let(:interface) { described_class.new(provider: :anthropic) }

      before do
        # Create a mock class that accepts the access_token argument
        anthropic_client_class = Class.new do
          def initialize(access_token: nil)
            # Mock constructor that accepts access_token
          end
        end
        
        stub_const('Anthropic', Module.new)
        stub_const('Anthropic::Client', anthropic_client_class)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
      end

      it 'raises error for unsupported provider' do
        expect {
          interface.generate_image(prompt: 'Test')
        }.to raise_error(SuperAgent::TaskError, /Image generation not supported/)
      end
    end
  end

  describe '#available_models' do
    context 'with OpenAI' do
      let(:mock_client) { double('OpenAI::Client') }
      let(:models_mock) { double('models') }
      let(:interface) { described_class.new(provider: :openai) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
        allow(mock_client).to receive(:models).and_return(models_mock)
      end

      it 'fetches models from OpenAI' do
        models_response = {
          'data' => [
            { 'id' => 'gpt-4' },
            { 'id' => 'gpt-3.5-turbo' }
          ]
        }
        
        expect(models_mock).to receive(:list).and_return(models_response)

        result = interface.available_models
        expect(result).to eq(['gpt-4', 'gpt-3.5-turbo'])
      end

      it 'handles API errors gracefully' do
        expect(models_mock).to receive(:list).and_raise(StandardError.new('API Error'))

        result = interface.available_models
        expect(result).to eq([])
      end
    end

    context 'with OpenRouter' do
      let(:mock_client) { double('OpenRouter::Client') }
      let(:interface) { described_class.new(provider: :open_router) }

      before do
        # Create a more complete mock of OpenRouter
        open_router_module = Module.new do
          def self.configure
            # Mock implementation
          end
        end
        
        open_router_client_class = Class.new do
          def initialize(*args)
            # Mock constructor that accepts any arguments
          end
        end
        
        stub_const('OpenRouter', open_router_module)
        stub_const('OpenRouter::Client', open_router_client_class)
        
        allow(OpenRouter::Client).to receive(:new).and_return(mock_client)
        allow(interface).to receive(:client).and_return(mock_client)
      end

      it 'fetches models from OpenRouter' do
        models = [
          { 'id' => 'openai/gpt-4' },
          { 'id' => 'anthropic/claude-3-sonnet' }
        ]
        
        expect(mock_client).to receive(:models).and_return(models)

        result = interface.available_models
        expect(result).to eq(['openai/gpt-4', 'anthropic/claude-3-sonnet'])
      end
    end

    context 'with Anthropic' do
      let(:interface) { described_class.new(provider: :anthropic) }

      before do
        # Create a mock class that accepts the access_token argument
        anthropic_client_class = Class.new do
          def initialize(access_token: nil)
            # Mock constructor that accepts access_token
          end
        end
        
        stub_const('Anthropic', Module.new)
        stub_const('Anthropic::Client', anthropic_client_class)
        allow(Anthropic::Client).to receive(:new).and_return(double)
      end

      it 'returns known Anthropic models' do
        result = interface.available_models
        expect(result).to include('claude-3-5-sonnet-20241022')
        expect(result).to include('claude-3-haiku-20240307')
        expect(result).to include('claude-3-opus-20240229')
      end
    end
  end

  describe 'message normalization' do
    let(:interface) { described_class.new }

    it 'converts string to user message' do
      result = interface.send(:normalize_messages, 'Hello')
      expect(result).to eq([{ role: 'user', content: 'Hello' }])
    end

    it 'keeps array messages unchanged' do
      messages = [
        { role: 'system', content: 'System' },
        { role: 'user', content: 'User' }
      ]
      result = interface.send(:normalize_messages, messages)
      expect(result).to eq(messages)
    end

    it 'converts hash to array' do
      message = { role: 'user', content: 'Hello' }
      result = interface.send(:normalize_messages, message)
      expect(result).to eq([message])
    end

    it 'converts other types to string user message' do
      result = interface.send(:normalize_messages, 42)
      expect(result).to eq([{ role: 'user', content: '42' }])
    end
  end
end