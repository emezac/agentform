# frozen_string_literal: true

require 'spec_helper_minimal'

RSpec.describe SuperAgent::A2A::AgentCard do
  describe '#initialize' do
    it 'creates a valid agent card with required attributes' do
      card = described_class.new(
        name: 'Test Agent',
        description: 'A test agent',
        version: '1.0.0',
        service_endpoint_url: 'http://localhost:8080',
        capabilities: [
          SuperAgent::A2A::Capability.new(
            name: 'test_capability',
            description: 'Test capability'
          ),
        ]
      )

      expect(card).to be_valid
      expect(card.name).to eq('Test Agent')
      expect(card.version).to eq('1.0.0')
      expect(card.id).to be_present
      expect(card.supported_modalities).to include('text', 'json')
    end

    it 'generates a UUID if id is not provided' do
      card = described_class.new(
        name: 'Test Agent',
        service_endpoint_url: 'http://localhost:8080',
        capabilities: []
      )

      expect(card.id).to match(/\A[\w\-]+\z/)
      expect(card.id.length).to be > 8
    end

    it 'sets default values for optional fields' do
      card = described_class.new(
        name: 'Test Agent',
        service_endpoint_url: 'http://localhost:8080',
        capabilities: []
      )

      expect(card.version).to eq('1.0.0')
      expect(card.supported_modalities).to eq(%w[text json])
      expect(card.authentication_requirements).to eq({})
      expect(card.metadata).to eq({})
      expect(card.created_at).to be_present
      expect(card.updated_at).to be_present
    end
  end

  describe 'validations' do
    it 'requires name, version, service_endpoint_url, and capabilities' do
      card = described_class.new

      expect(card).not_to be_valid
      expect(card.errors[:name]).to include("can't be blank")
      expect(card.errors[:version]).to include("can't be blank")
      expect(card.errors[:service_endpoint_url]).to include("can't be blank")
      expect(card.errors[:capabilities]).to include("can't be blank")
    end

    it 'validates service_endpoint_url format' do
      card = described_class.new(
        name: 'Test',
        version: '1.0.0',
        service_endpoint_url: 'invalid-url',
        capabilities: []
      )

      expect(card).not_to be_valid
      expect(card.errors[:service_endpoint_url]).to be_present
    end

    it 'validates capabilities are Capability objects' do
      card = described_class.new(
        name: 'Test',
        version: '1.0.0',
        service_endpoint_url: 'http://localhost:8080',
        capabilities: ['invalid', SuperAgent::A2A::Capability.new(name: 'valid', description: 'Valid')]
      )

      expect(card).not_to be_valid
      expect(card.errors[:capabilities]).to include('Capability at index 0 must be a Capability instance')
    end
  end

  describe '#to_json' do
    let(:capability) do
      SuperAgent::A2A::Capability.new(
        name: 'test_capability',
        description: 'Test capability',
        parameters: { 'input' => { 'type' => 'string' } },
        returns: { 'type' => 'object' }
      )
    end

    let(:card) do
      described_class.new(
        name: 'Test Agent',
        description: 'A test agent',
        version: '1.0.0',
        service_endpoint_url: 'http://localhost:8080',
        capabilities: [capability]
      )
    end

    it 'generates valid JSON with correct structure' do
      json_data = JSON.parse(card.to_json)

      expect(json_data).to have_key('id')
      expect(json_data).to have_key('name')
      expect(json_data).to have_key('serviceEndpointURL')
      expect(json_data).to have_key('capabilities')
      expect(json_data['name']).to eq('Test Agent')
      expect(json_data['serviceEndpointURL']).to eq('http://localhost:8080')
      expect(json_data['capabilities']).to be_an(Array)
      expect(json_data['capabilities'].first['name']).to eq('test_capability')
    end

    it 'uses camelCase for JSON keys' do
      json_data = JSON.parse(card.to_json)

      expect(json_data).to have_key('serviceEndpointURL')
      expect(json_data).to have_key('supportedModalities')
      expect(json_data).to have_key('authenticationRequirements')
      expect(json_data).to have_key('createdAt')
      expect(json_data).to have_key('updatedAt')
    end
  end

  describe '.from_json' do
    let(:json_data) do
      {
        'id' => 'test-id-123',
        'name' => 'Test Agent',
        'description' => 'A test agent',
        'version' => '1.0.0',
        'serviceEndpointURL' => 'http://localhost:8080',
        'supportedModalities' => %w[text json],
        'authenticationRequirements' => {},
        'capabilities' => [
          {
            'name' => 'test_capability',
            'description' => 'Test capability',
            'parameters' => { 'input' => { 'type' => 'string' } },
            'returns' => { 'type' => 'object' },
          },
        ],
        'metadata' => { 'version' => '1.0' },
        'createdAt' => '2023-01-01T00:00:00Z',
        'updatedAt' => '2023-01-01T00:00:00Z',
      }
    end

    it 'creates an agent card from JSON string' do
      card = described_class.from_json(json_data.to_json)

      expect(card.id).to eq('test-id-123')
      expect(card.name).to eq('Test Agent')
      expect(card.service_endpoint_url).to eq('http://localhost:8080')
      expect(card.capabilities.size).to eq(1)
      expect(card.capabilities.first).to be_a(SuperAgent::A2A::Capability)
      expect(card.capabilities.first.name).to eq('test_capability')
    end

    it 'handles missing optional fields gracefully' do
      minimal_data = {
        'id' => 'test-id-123',
        'name' => 'Test Agent',
        'version' => '1.0.0',
        'serviceEndpointURL' => 'http://localhost:8080',
        'capabilities' => [],
      }

      card = described_class.from_json(minimal_data.to_json)

      expect(card.description).to be_nil
      expect(card.metadata).to eq({})
      expect(card.supported_modalities).to be_nil
    end
  end

  describe 'capability management' do
    let(:card) do
      described_class.new(
        name: 'Test Agent',
        service_endpoint_url: 'http://localhost:8080',
        capabilities: []
      )
    end

    let(:capability) do
      SuperAgent::A2A::Capability.new(
        name: 'new_capability',
        description: 'New capability'
      )
    end

    describe '#add_capability' do
      it 'adds a new capability' do
        expect { card.add_capability(capability) }
          .to change { card.capabilities.size }.by(1)

        expect(card.capabilities.last).to eq(capability)
      end

      it 'updates the updated_at timestamp' do
        original_time = card.updated_at

        # Ensure time difference
        sleep(0.01)
        card.add_capability(capability)

        expect(card.updated_at).not_to eq(original_time)
      end
    end

    describe '#remove_capability' do
      before do
        card.add_capability(capability)
      end

      it 'removes capability by name' do
        expect { card.remove_capability('new_capability') }
          .to change { card.capabilities.size }.by(-1)
      end

      it 'updates the updated_at timestamp' do
        original_time = card.updated_at

        sleep(0.01)
        card.remove_capability('new_capability')

        expect(card.updated_at).not_to eq(original_time)
      end
    end

    describe '#find_capability' do
      before do
        card.add_capability(capability)
      end

      it 'finds capability by name' do
        found = card.find_capability('new_capability')
        expect(found).to eq(capability)
      end

      it 'returns nil for non-existent capability' do
        found = card.find_capability('non_existent')
        expect(found).to be_nil
      end
    end

    describe '#supports_modality?' do
      it 'checks if agent supports a specific modality' do
        card.supported_modalities = %w[text json image]

        expect(card.supports_modality?('text')).to be true
        expect(card.supports_modality?(:json)).to be true
        expect(card.supports_modality?('video')).to be false
      end
    end
  end
end

RSpec.describe SuperAgent::A2A::Capability do
  describe '#initialize' do
    it 'creates a valid capability with required attributes' do
      capability = described_class.new(
        name: 'test_capability',
        description: 'Test capability'
      )

      expect(capability).to be_valid
      expect(capability.name).to eq('test_capability')
      expect(capability.description).to eq('Test capability')
      expect(capability.parameters).to eq({})
      expect(capability.returns).to eq({})
      expect(capability.examples).to eq([])
      expect(capability.tags).to eq([])
      expect(capability.required_permissions).to eq([])
    end
  end

  describe 'validations' do
    it 'requires name and description' do
      capability = described_class.new

      expect(capability).not_to be_valid
      expect(capability.errors[:name]).to include("can't be blank")
      expect(capability.errors[:description]).to include("can't be blank")
    end
  end

  describe '#to_h' do
    let(:capability) do
      described_class.new(
        name: 'test_capability',
        description: 'Test capability',
        parameters: { 'input' => { 'type' => 'string' } },
        returns: { 'type' => 'object' },
        examples: [{ 'input' => 'test', 'output' => 'result' }],
        tags: ['test'],
        required_permissions: ['read']
      )
    end

    it 'generates correct hash structure' do
      hash = capability.to_h

      expect(hash).to have_key(:name)
      expect(hash).to have_key(:description)
      expect(hash).to have_key(:parameters)
      expect(hash).to have_key(:returns)
      expect(hash).to have_key(:examples)
      expect(hash).to have_key(:tags)
      expect(hash).to have_key(:requiredPermissions)
    end

    it 'omits empty values' do
      minimal_capability = described_class.new(
        name: 'minimal',
        description: 'Minimal capability'
      )

      hash = minimal_capability.to_h

      expect(hash[:parameters]).to eq({})
      expect(hash[:examples]).to eq([])
    end
  end

  describe 'parameter management' do
    let(:capability) do
      described_class.new(
        name: 'test_capability',
        description: 'Test capability'
      )
    end

    describe '#add_parameter' do
      it 'adds a new parameter' do
        capability.add_parameter('input', 'string', 'Input text', required: true)

        expect(capability.parameters['input']).to eq({
                                                       type: 'string',
                                                       description: 'Input text',
                                                       required: true,
                                                     })
      end
    end

    describe '#add_example' do
      it 'adds a new example' do
        capability.add_example({ input: 'test' }, { output: 'result' }, 'Test example')

        expect(capability.examples.size).to eq(1)
        expect(capability.examples.first[:input]).to eq({ input: 'test' })
        expect(capability.examples.first[:description]).to eq('Test example')
      end
    end

    describe '#add_tag' do
      it 'adds a new tag' do
        capability.add_tag('ai')
        capability.add_tag(:nlp)

        expect(capability.tags).to include('ai', 'nlp')
      end

      it 'prevents duplicate tags' do
        capability.add_tag('ai')
        capability.add_tag('ai')

        expect(capability.tags.count('ai')).to eq(1)
      end
    end
  end
end
