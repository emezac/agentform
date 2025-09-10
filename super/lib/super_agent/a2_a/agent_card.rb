# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'active_model'

module SuperAgent
  module A2A
    # Agent Card represents the capabilities and metadata of an A2A agent
    class AgentCard
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :id, :name, :description, :version, :service_endpoint_url,
                    :supported_modalities, :authentication_requirements,
                    :capabilities, :metadata, :created_at, :updated_at

      validates :id, :name, :version, :service_endpoint_url, presence: true
      validates :capabilities, presence: true
      validates :service_endpoint_url, format: { with: URI::DEFAULT_PARSER.make_regexp }
      validate :capabilities_must_be_array_of_capabilities

      def initialize(attributes = {})
        super
        @id ||= SecureRandom.uuid
        @version ||= '1.0.0'
        @supported_modalities ||= %w[text json]
        @authentication_requirements ||= {}
        @capabilities ||= []
        @metadata ||= {}
        @created_at ||= Time.current.iso8601
        @updated_at ||= Time.current.iso8601
      end

      def to_json(*args)
        {
          id: id,
          name: name,
          description: description,
          version: version,
          serviceEndpointURL: service_endpoint_url,
          supportedModalities: supported_modalities,
          authenticationRequirements: authentication_requirements,
          capabilities: capabilities.map(&:to_h),
          metadata: metadata,
          createdAt: created_at,
          updatedAt: updated_at,
        }.to_json(*args)
      end

      def to_h
        JSON.parse(to_json)
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        from_hash(data)
      end

      def self.from_hash(data)
        new(
          id: data['id'],
          name: data['name'],
          description: data['description'],
          version: data['version'],
          service_endpoint_url: data['serviceEndpointURL'],
          supported_modalities: data['supportedModalities'],
          authentication_requirements: data['authenticationRequirements'],
          capabilities: data['capabilities']&.map { |cap| Capability.from_hash(cap) },
          metadata: data['metadata'],
          created_at: data['createdAt'],
          updated_at: data['updatedAt']
        )
      end

      # Generate Agent Card from a SuperAgent workflow class
      def self.from_workflow(workflow_class)
        definition = workflow_class.workflow_definition

        new(
          id: generate_agent_id(workflow_class),
          name: humanize_class_name(workflow_class.name),
          description: extract_description(workflow_class),
          version: extract_version(workflow_class),
          service_endpoint_url: build_service_url(workflow_class),
          supported_modalities: extract_modalities(definition),
          authentication_requirements: extract_auth_requirements,
          capabilities: extract_capabilities(definition),
          metadata: extract_metadata(workflow_class)
        )
      end

      # Generate Agent Card from multiple workflows (gateway mode)
      def self.from_workflow_registry(registry)
        capabilities = []
        supported_modalities = Set.new(%w[text json])

        registry.each do |path, workflow_class|
          definition = workflow_class.workflow_definition
          capabilities.concat(extract_capabilities(definition, path_prefix: path))
          supported_modalities.merge(extract_modalities(definition))
        end

        new(
          name: 'SuperAgent A2A Gateway',
          description: 'Multi-workflow SuperAgent instance with A2A Protocol support',
          service_endpoint_url: build_gateway_url,
          supported_modalities: supported_modalities.to_a,
          capabilities: capabilities
        )
      end

      def add_capability(capability)
        @capabilities << capability
        @updated_at = Time.current.iso8601
      end

      def remove_capability(name)
        @capabilities.reject! { |cap| cap.name == name }
        @updated_at = Time.current.iso8601
      end

      def find_capability(name)
        @capabilities.find { |cap| cap.name == name }
      end

      def supports_modality?(modality)
        @supported_modalities.include?(modality.to_s)
      end

      private

      def capabilities_must_be_array_of_capabilities
        return unless capabilities.is_a?(Array)

        capabilities.each_with_index do |capability, index|
          unless capability.is_a?(Capability)
            errors.add(:capabilities, "Capability at index #{index} must be a Capability instance")
          end
        end
      end

      class << self
        private

        def generate_agent_id(workflow_class)
          "superagent-#{workflow_class.name.underscore}-#{SecureRandom.hex(8)}"
        end

        def humanize_class_name(class_name)
          class_name.demodulize.underscore.humanize
        end

        def extract_description(workflow_class)
          # Try to get description from class comments or defined method
          if workflow_class.respond_to?(:description)
            workflow_class.description
          else
            "SuperAgent workflow: #{workflow_class.name}"
          end
        end

        def extract_version(workflow_class)
          if workflow_class.respond_to?(:version)
            workflow_class.version
          else
            defined?(SuperAgent::VERSION) ? SuperAgent::VERSION : '1.0.0'
          end
        end

        def build_service_url(workflow_class)
          base_url = SuperAgent.configuration.a2a_base_url ||
                     "http://localhost:#{SuperAgent.configuration.a2a_server_port}"
          "#{base_url}/agents/#{workflow_class.name.underscore}"
        end

        def build_gateway_url
          SuperAgent.configuration.a2a_base_url ||
            "http://localhost:#{SuperAgent.configuration.a2a_server_port}"
        end

        def extract_modalities(definition)
          modalities = %w[text json]

          # Analyze tasks to determine supported modalities
          definition.tasks.each do |task|
            case task.class.name
            when /FileTask/
              modalities << 'file'
            when /ImageTask/
              modalities << 'image'
            when /AudioTask/
              modalities << 'audio'
            end
          end

          modalities.uniq
        end

        def extract_auth_requirements
          config = SuperAgent.configuration
          return {} unless config.a2a_auth_token

          {
            type: 'bearer',
            description: 'Bearer token authentication required',
            required: true,
          }
        end

        def extract_capabilities(definition, path_prefix: nil)
          definition.tasks.map do |task|
            Capability.new(
              name: build_capability_name(task, path_prefix),
              description: extract_task_description(task),
              parameters: extract_task_parameters(task),
              returns: extract_task_returns(task),
              examples: extract_task_examples(task),
              tags: extract_task_tags(task)
            )
          end
        end

        def build_capability_name(task, path_prefix)
          name = task.name.to_s
          path_prefix ? "#{path_prefix.gsub('/', '_')}_#{name}" : name
        end

        def extract_task_description(task)
          if task.respond_to?(:description) && task.description.present?
            task.description
          else
            "Executes #{task.name} task"
          end
        end

        def extract_task_parameters(task)
          params = {}

          if task.respond_to?(:input_keys) && task.input_keys&.any?
            task.input_keys.each do |key|
              params[key.to_s] = {
                type: 'string',
                description: "Input parameter: #{key}",
                required: true,
              }
            end
          else
            params['*'] = {
              type: 'object',
              description: 'Dynamic parameters based on context',
              required: false,
            }
          end

          params
        end

        def extract_task_returns(task)
          if task.respond_to?(:output_key) && task.output_key
            {
              type: 'object',
              properties: {
                task.output_key.to_s => {
                  type: 'string',
                  description: 'Task execution result',
                },
              },
            }
          else
            {
              type: 'object',
              description: 'Task execution result',
            }
          end
        end

        def extract_task_examples(task)
          # Could be enhanced to extract examples from task definitions or tests
          []
        end

        def extract_task_tags(task)
          tags = [task.class.name.demodulize.underscore.gsub('_task', '')]

          case task.class.name
          when /LLM/
            tags << 'ai'
          when /Fetch/, /ActiveRecord/
            tags << 'data'
          when /A2A/
            tags << 'external'
          when /ActionMailer/
            tags << 'notification'
          end

          tags.uniq
        end

        def extract_metadata(workflow_class)
          {
            superagent_version: defined?(SuperAgent::VERSION) ? SuperAgent::VERSION : '1.0.0',
            workflow_class: workflow_class.name,
            ruby_version: RUBY_VERSION,
            created_with: 'SuperAgent A2A Integration',
          }
        end
      end
    end

    # Represents a single capability within an Agent Card
    class Capability
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :name, :description, :parameters, :returns,
                    :examples, :tags, :required_permissions

      validates :name, :description, presence: true

      def initialize(attributes = {})
        super
        @parameters ||= {}
        @returns ||= {}
        @examples ||= []
        @tags ||= []
        @required_permissions ||= []
      end

      def to_h
        {
          name: name,
          description: description,
          parameters: parameters,
          returns: returns,
          examples: examples,
          tags: tags,
          requiredPermissions: required_permissions,
        }.compact
      end

      def self.from_hash(data)
        new(
          name: data['name'],
          description: data['description'],
          parameters: data['parameters'] || {},
          returns: data['returns'] || {},
          examples: data['examples'] || [],
          tags: data['tags'] || [],
          required_permissions: data['requiredPermissions'] || []
        )
      end

      def add_parameter(name, type, description, required: false)
        @parameters[name.to_s] = {
          type: type,
          description: description,
          required: required,
        }
      end

      def add_example(input, output, description = nil)
        example = { input: input, output: output }
        example[:description] = description if description
        @examples << example
      end

      def add_tag(tag)
        @tags << tag.to_s unless @tags.include?(tag.to_s)
      end
    end
  end
end
