# TODO LIST: SuperAgent ↔ Google ADK Integration via A2A Protocol

## 🚀 FASE 1: Investigación y Setup Inicial (1-2 semanas)

### 1.1 Análisis del Protocolo A2A
- [ ] **T1.1.1** Descargar especificación A2A de Linux Foundation
- [ ] **T1.1.2** Estudiar implementación de referencia del ADK de Google
- [ ] **T1.1.3** Analizar Agent Cards generadas por ADK Python
- [ ] **T1.1.4** Documentar endpoints requeridos: `/.well-known/agent.json`, `/invoke`, `/health`
- [ ] **T1.1.5** Mapear esquemas JSON para Request/Response entre SuperAgent y ADK

### 1.2 Setup del Proyecto
- [ ] **T1.2.1** Crear rama `feature/a2a-integration` en SuperAgent
- [ ] **T1.2.2** Crear estructura de directorios para módulo A2A
```ruby
# Estructura propuesta:
lib/super_agent/a2a/
├── client.rb
├── server.rb
├── agent_card.rb
├── message.rb
└── tasks/
    └── a2a_task.rb
```
- [ ] **T1.2.3** Actualizar `super_agent.gemspec` con nuevas dependencias
- [ ] **T1.2.4** Configurar entorno de testing con ADK Python

## 📦 FASE 2: Implementación del Protocolo A2A Core (2-3 semanas)

### 2.1 Agent Card Generator
```ruby
# lib/super_agent/a2a/agent_card.rb
class SuperAgent::A2A::AgentCard
  def self.generate_from_workflow(workflow_class)
    # Convierte WorkflowDefinition a Agent Card JSON
  end
end
```

- [ ] **T2.1.1** Implementar clase `AgentCard`
```ruby
class SuperAgent::A2A::AgentCard
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :id, :name, :description, :version, :url, :skills

  validates :id, :name, :version, :url, presence: true
  validates :skills, presence: true

  def to_json
    {
      id: id,
      name: name,
      description: description,
      version: version,
      url: url,
      skills: skills.map(&:to_h)
    }.to_json
  end

  def self.from_workflow(workflow_class)
    new(
      id: generate_id(workflow_class),
      name: workflow_class.name.humanize,
      description: extract_description(workflow_class),
      version: "1.0.0",
      url: build_url(workflow_class),
      skills: extract_skills(workflow_class)
    )
  end

  private

  def self.extract_skills(workflow_class)
    # Analizar las tareas del workflow y convertirlas en skills
    workflow_class.workflow_definition.tasks.map do |task|
      {
        name: task.name.to_s,
        description: task.description || "Executes #{task.name}",
        parameters: extract_parameters(task)
      }
    end
  end
end
```

- [ ] **T2.1.2** Implementar extracción automática de skills desde SuperAgent workflows
- [ ] **T2.1.3** Crear validación de Agent Cards
- [ ] **T2.1.4** Añadir tests unitarios para `AgentCard`

### 2.2 Cliente A2A
```ruby
# lib/super_agent/a2a/client.rb
class SuperAgent::A2A::Client
  def initialize(agent_url, auth_token: nil)
    @agent_url = agent_url
    @auth_token = auth_token
    @http_client = build_http_client
  end

  def fetch_agent_card
    # GET /.well-known/agent.json
  end

  def invoke_skill(skill_name, parameters, request_id: SecureRandom.uuid)
    # POST /invoke
  end

  def health_check
    # GET /health
  end
end
```

- [ ] **T2.2.1** Implementar clase base `A2A::Client`
```ruby
class SuperAgent::A2A::Client
  include SuperAgent::Loggable

  attr_reader :agent_url, :auth_token

  def initialize(agent_url, auth_token: nil, timeout: 30)
    @agent_url = agent_url.chomp('/')
    @auth_token = auth_token
    @timeout = timeout
    @agent_card_cache = {}
  end

  def fetch_agent_card
    return @agent_card_cache[:card] if card_cached_and_valid?

    response = http_get("#{@agent_url}/.well-known/agent.json")
    card = JSON.parse(response.body)
    
    @agent_card_cache = {
      card: card,
      cached_at: Time.current,
      ttl: 300 # 5 minutes
    }

    card
  rescue => e
    log_error("Failed to fetch agent card: #{e.message}")
    raise SuperAgent::A2A::AgentCardError, e.message
  end

  def invoke_skill(skill_name, parameters, request_id: SecureRandom.uuid)
    payload = {
      skill: skill_name,
      parameters: parameters,
      request_id: request_id
    }

    response = http_post("#{@agent_url}/invoke", payload)
    parse_a2a_response(response.body)
  rescue => e
    log_error("Skill invocation failed: #{e.message}")
    raise SuperAgent::A2A::InvocationError, e.message
  end

  private

  def http_get(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = @timeout

    request = Net::HTTP::Get.new(uri)
    add_auth_headers(request)
    
    http.request(request)
  end

  def http_post(url, payload)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = @timeout

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    add_auth_headers(request)
    request.body = payload.to_json
    
    http.request(request)
  end

  def add_auth_headers(request)
    return unless @auth_token
    request['Authorization'] = "Bearer #{@auth_token}"
  end

  def card_cached_and_valid?
    return false unless @agent_card_cache[:cached_at]
    Time.current - @agent_card_cache[:cached_at] < @agent_card_cache[:ttl]
  end
end
```

- [ ] **T2.2.2** Implementar cache de Agent Cards con TTL
- [ ] **T2.2.3** Añadir retry logic con exponential backoff
- [ ] **T2.2.4** Implementar manejo de errores HTTP específicos
- [ ] **T2.2.5** Crear tests unitarios para cliente

### 2.3 Servidor A2A
```ruby
# lib/super_agent/a2a/server.rb
class SuperAgent::A2A::Server
  def initialize(port: 8080, auth_token: nil)
    @port = port
    @auth_token = auth_token
    @app = build_rack_app
  end

  def start
    # Iniciar servidor Rack
  end

  private

  def build_rack_app
    # Construir aplicación Rack con middlewares
  end
end
```

- [ ] **T2.3.1** Implementar servidor base usando Rack
```ruby
class SuperAgent::A2A::Server
  def initialize(port: 8080, auth_token: nil)
    @port = port
    @auth_token = auth_token
    @workflow_registry = {}
  end

  def register_workflow(workflow_class, path = nil)
    path ||= "/agents/#{workflow_class.name.underscore}"
    @workflow_registry[path] = workflow_class
  end

  def start
    app = build_rack_app
    Rack::Handler::WEBrick.run(app, Port: @port)
  end

  private

  def build_rack_app
    registry = @workflow_registry
    auth_token = @auth_token

    Rack::Builder.new do
      use Rack::Logger
      use SuperAgent::A2A::AuthMiddleware, auth_token: auth_token
      use SuperAgent::A2A::CorsMiddleware

      map "/.well-known/agent.json" do
        run ->(env) {
          agent_card = SuperAgent::A2A::AgentCard.generate_from_registry(registry)
          [200, {"Content-Type" => "application/json"}, [agent_card.to_json]]
        }
      end

      map "/invoke" do
        run SuperAgent::A2A::InvokeHandler.new(registry)
      end

      map "/health" do
        run ->(env) {
          [200, {"Content-Type" => "application/json"}, ['{"status":"healthy"}']]
        }
      end
    end
  end
end
```

- [ ] **T2.3.2** Implementar endpoint `/.well-known/agent.json`
- [ ] **T2.3.3** Implementar endpoint `/invoke` para ejecutar workflows
- [ ] **T2.3.4** Implementar endpoint `/health`
- [ ] **T2.3.5** Añadir middleware de autenticación
- [ ] **T2.3.6** Crear tests de integración para servidor

### 2.4 Message Handling
- [ ] **T2.4.1** Implementar clase `A2A::Message` para validación
```ruby
class SuperAgent::A2A::Message
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :skill, :parameters, :request_id

  validates :skill, :parameters, :request_id, presence: true

  def self.from_a2a_request(request_body)
    data = JSON.parse(request_body)
    new(
      skill: data['skill'],
      parameters: data['parameters'],
      request_id: data['request_id']
    )
  end

  def to_superagent_context
    SuperAgent::Workflow::Context.new(parameters.merge(
      _a2a_skill: skill,
      _a2a_request_id: request_id
    ))
  end
end
```

- [ ] **T2.4.2** Implementar conversión de A2A requests a SuperAgent Context
- [ ] **T2.4.3** Implementar conversión de SuperAgent results a A2A responses
- [ ] **T2.4.4** Añadir validación JSON Schema

## 🔧 FASE 3: Integración con SuperAgent DSL (2 semanas)

### 3.1 Nueva Tarea A2A
- [ ] **T3.1.1** Crear `SuperAgent::Workflow::Tasks::A2ATask`
```ruby
# lib/super_agent/workflow/tasks/a2a_task.rb
class SuperAgent::Workflow::Tasks::A2ATask < SuperAgent::Workflow::Tasks::BaseTask
  include SuperAgent::Workflow::Tasks::Concerns::Retryable

  attr_reader :agent_url, :skill_name, :timeout, :auth_token

  def initialize(name, agent_url:, skill:, timeout: 30, auth_token: nil, **options)
    super(name, **options)
    @agent_url = agent_url
    @skill_name = skill
    @timeout = timeout
    @auth_token = auth_token
  end

  def execute(context)
    client = SuperAgent::A2A::Client.new(@agent_url, 
                                         auth_token: @auth_token, 
                                         timeout: @timeout)
    
    # Validate skill exists
    agent_card = client.fetch_agent_card
    validate_skill_exists!(agent_card, @skill_name)

    # Prepare parameters from context
    parameters = extract_parameters(context)
    
    # Invoke remote skill
    response = client.invoke_skill(@skill_name, parameters)
    
    # Return result for context merging
    parse_response(response)
  rescue SuperAgent::A2A::AgentCardError => e
    handle_error("Agent unreachable: #{e.message}")
  rescue SuperAgent::A2A::InvocationError => e
    handle_error("Skill invocation failed: #{e.message}")
  end

  private

  def validate_skill_exists!(agent_card, skill_name)
    skills = agent_card['skills'] || []
    unless skills.any? { |skill| skill['name'] == skill_name }
      raise SuperAgent::A2A::SkillNotFoundError, 
            "Skill '#{skill_name}' not found in agent"
    end
  end

  def extract_parameters(context)
    if @input_keys.any?
      @input_keys.each_with_object({}) do |key, params|
        params[key] = context.get(key)
      end
    else
      context.to_h.except(:_a2a_skill, :_a2a_request_id)
    end
  end

  def parse_response(response)
    if response['status'] == 'success'
      response['result'] || {}
    else
      handle_error("Remote agent error: #{response['error']}")
    end
  end
end
```

- [ ] **T3.1.2** Registrar tarea en `ToolRegistry`
```ruby
# En SuperAgent::ToolRegistry
register_task(:a2a_agent, SuperAgent::Workflow::Tasks::A2ATask)
```

- [ ] **T3.1.3** Añadir validación de configuración
- [ ] **T3.1.4** Implementar manejo de timeouts y errores
- [ ] **T3.1.5** Crear tests unitarios para `A2ATask`

### 3.2 Extensión del DSL
- [ ] **T3.2.1** Extender `WorkflowBuilder` con método `a2a_agent`
```ruby
# En SuperAgent::WorkflowDefinition::WorkflowBuilder
def a2a_agent(name, agent_url = nil, &block)
  if block_given?
    configurator = A2ATaskConfigurator.new(name, agent_url)
    configurator.instance_eval(&block)
    task = configurator.build
  else
    # Configuración inline
    task = SuperAgent::Workflow::Tasks::A2ATask.new(name, agent_url: agent_url)
  end
  
  add_task(task)
end
```

- [ ] **T3.2.2** Crear `A2ATaskConfigurator` para configuración fluida
```ruby
class SuperAgent::A2A::TaskConfigurator
  def initialize(name, agent_url = nil)
    @name = name
    @agent_url = agent_url
    @options = {}
  end

  def agent_url(url)
    @agent_url = url
  end

  def skill(skill_name)
    @options[:skill] = skill_name
  end

  def timeout(seconds)
    @options[:timeout] = seconds
  end

  def auth_token(token)
    @options[:auth_token] = token
  end

  def input(*keys)
    @options[:input] = keys
  end

  def output(key)
    @options[:output] = key
  end

  def build
    raise ArgumentError, "agent_url is required" unless @agent_url
    raise ArgumentError, "skill is required" unless @options[:skill]

    SuperAgent::Workflow::Tasks::A2ATask.new(@name, 
                                             agent_url: @agent_url, 
                                             **@options)
  end
end
```

- [ ] **T3.2.3** Añadir soporte para autenticación en DSL
- [ ] **T3.2.4** Integrar con sistema de helpers existente
- [ ] **T3.2.5** Crear documentación del nuevo DSL

### 3.3 CLI y Herramientas
- [ ] **T3.3.1** Crear comando `rails generate super_agent:a2a_server`
- [ ] **T3.3.2** Crear tarea Rake para generar Agent Cards
```ruby
# lib/tasks/super_agent_a2a.rake
namespace :super_agent do
  namespace :a2a do
    desc "Generate Agent Card for a workflow"
    task :generate_card, [:workflow_class] => :environment do |t, args|
      workflow_class = args[:workflow_class].constantize
      card = SuperAgent::A2A::AgentCard.from_workflow(workflow_class)
      puts card.to_json
    end

    desc "Start A2A server for workflows"
    task :serve, [:port] => :environment do |t, args|
      port = args[:port]&.to_i || 8080
      server = SuperAgent::A2A::Server.new(port: port)
      
      # Auto-register all workflows
      SuperAgent::WorkflowRegistry.all.each do |workflow_class|
        server.register_workflow(workflow_class)
      end
      
      puts "Starting A2A server on port #{port}..."
      server.start
    end
  end
end
```

- [ ] **T3.3.3** Crear script ejecutable `bin/super_agent_a2a`
- [ ] **T3.3.4** Implementar comando de validación de Agent Cards

## 🧪 FASE 4: Testing e Interoperabilidad (2 semanas)

### 4.1 Testing Unitario
- [ ] **T4.1.1** Tests para `A2A::Client` con mocking HTTP
- [ ] **T4.1.2** Tests para `A2A::Server` usando Rack::Test
- [ ] **T4.1.3** Tests para `A2ATask` con mock agents
- [ ] **T4.1.4** Tests para `AgentCard` generation
- [ ] **T4.1.5** Tests para conversión de mensajes A2A ↔ SuperAgent

### 4.2 Testing de Integración
- [ ] **T4.2.1** Setup de entorno con ADK Python
- [ ] **T4.2.2** Test: SuperAgent client → ADK Python server
```ruby
# spec/integration/a2a_interop_spec.rb
RSpec.describe "A2A Interoperability", type: :integration do
  before(:all) do
    # Start ADK Python server on port 8081
    @adk_server = start_adk_test_server
  end

  after(:all) do
    @adk_server&.terminate
  end

  it "can call ADK Python agent from SuperAgent workflow" do
    workflow = Class.new(ApplicationWorkflow) do
      workflow do
        a2a_agent :call_adk do
          agent_url "http://localhost:8081"
          skill "text_analysis" 
          input :text_data
          output :analysis_result
        end
      end
    end

    context = SuperAgent::Workflow::Context.new(text_data: "Hello world")
    result = SuperAgent::WorkflowEngine.new.execute(workflow, context)

    expect(result).to be_completed
    expect(result.get(:analysis_result)).to be_present
  end
end
```

- [ ] **T4.2.3** Test: ADK Python client → SuperAgent server
- [ ] **T4.2.4** Test de workflow completo bidireccional
- [ ] **T4.2.5** Performance tests (latencia <200ms target)

### 4.3 Ejemplo Práctico
- [ ] **T4.3.1** Crear ejemplo de e-commerce con agentes especializados
```ruby
# examples/ecommerce_agents/
# ├── inventory_workflow.rb      (SuperAgent)
# ├── recommendation_agent.py    (ADK Python)  
# └── order_processing_workflow.rb (SuperAgent que llama ambos)

class OrderProcessingWorkflow < ApplicationWorkflow
  workflow do
    # Step 1: Check inventory (local SuperAgent workflow)
    fetch :get_product do
      model "Product"
      find_by id: "{{product_id}}"
    end

    # Step 2: Get recommendations (external ADK Python agent)
    a2a_agent :get_recommendations do
      agent_url "http://recommendations-service:8080"
      skill "product_recommendations"
      input :get_product
      output :recommendations
      timeout 10.seconds
    end

    # Step 3: Process order (local logic)
    task :create_order do
      input :get_product, :recommendations
      process do |product, recs|
        # Create order with cross-sells
        Order.create!(
          product: product,
          recommended_items: recs['items'],
          total: calculate_total(product, recs)
        )
      end
    end
  end
end
```

## 📚 FASE 5: Documentación y Release (1 semana)

### 5.1 Documentación
- [ ] **T5.1.1** README con sección A2A integration
- [ ] **T5.1.2** Tutorial: "Connecting SuperAgent with Google ADK"
- [ ] **T5.1.3** API reference para clases A2A
- [ ] **T5.1.4** Troubleshooting guide
- [ ] **T5.1.5** Security best practices para A2A

### 5.2 Ejemplos y Demos
- [ ] **T5.2.1** Demo app: Multi-agent chat system
- [ ] **T5.2.2** Video tutorial de configuración
- [ ] **T5.2.3** Docker compose con SuperAgent + ADK
- [ ] **T5.2.4** Benchmark comparando con implementaciones nativas

### 5.3 Release Preparation
- [ ] **T5.3.1** Update CHANGELOG.md
- [ ] **T5.3.2** Version bump y tag release
- [ ] **T5.3.3** Actualizar gemspec dependencies
- [ ] **T5.3.4** CI/CD para tests de interoperabilidad
- [ ] **T5.3.5** Release notes y communication plan

## 🔧 FASE 6: Configuración y Deployment (1 semana)

### 6.1 Configuración
- [ ] **T6.1.1** Extender `SuperAgent::Configuration`
```ruby
# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  # Existing config...
  
  # A2A Configuration
  config.a2a_server_port = ENV['SUPER_AGENT_A2A_PORT'] || 8080
  config.a2a_auth_token = ENV['SUPER_AGENT_A2A_TOKEN']
  config.a2a_timeout = 30
  config.a2a_retry_attempts = 3
  config.a2a_cache_ttl = 300
end
```

- [ ] **T6.1.2** Generador de configuración Rails
- [ ] **T6.1.3** Environment-specific settings
- [ ] **T6.1.4** SSL/TLS configuration para producción

### 6.2 Monitoring y Observabilidad
- [ ] **T6.2.1** Métricas A2A en SuperAgent::Metrics
- [ ] **T6.2.2** Logging estructurado para requests A2A
- [ ] **T6.2.3** Health checks para agentes remotos
- [ ] **T6.2.4** Dashboard básico de monitoreo

## Cronograma Total: 10-12 semanas

- **Semanas 1-2**: Fase 1 (Investigación y Setup)
- **Semanas 3-5**: Fase 2 (Core A2A Implementation)  
- **Semanas 6-7**: Fase 3 (DSL Integration)
- **Semanas 8-9**: Fase 4 (Testing e Interoperabilidad)
- **Semana 10**: Fase 5 (Documentación)
- **Semanas 11-12**: Fase 6 (Deployment y Release)

## Riesgos y Mitigaciones

1. **Compatibilidad ADK**: Testing continuo con múltiples versiones
2. **Performance**: Benchmarking temprano con métricas claras
3. **Complejidad DSL**: Mantener sintaxis simple y consistente
4. **Debugging**: Logging detallado y herramientas de diagnóstico

Esta implementación permitirá que SuperAgent se convierta en un ciudadano de primera clase en el ecosistema A2A, manteniendo su filosofía Rails-native mientras añade capacidades enterprise de interoperabilidad.
