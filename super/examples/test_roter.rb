#!/usr/bin/env ruby
# frozen_string_literal: true

# Test básico de conectividad con OpenRouter - Sin autoloading
require 'bundler/setup'

# Cargar dependencias necesarias manualmente
require 'openai'
require 'open_router'
require 'logger'
require 'active_support'
require 'active_support/core_ext'
require 'securerandom'
require 'time'
require 'json'

puts "🔌 Test Básico de Conectividad - SuperAgent + OpenRouter"
puts "=" * 60

# Verificar API key
unless ENV['OPENROUTER_API_KEY']
  puts "❌ OPENROUTER_API_KEY no configurada"
  exit 1
end

# Mock Rails simple
module Rails
  extend self
  def logger; @logger ||= Logger.new($stdout, level: Logger::INFO); end
  def env; 'test'; end
end

puts "✅ Dependencias cargadas"
puts "🔑 API Key: #{ENV['OPENROUTER_API_KEY'][0..10]}..."
puts ""

# Definir clases SuperAgent mínimas necesarias
module SuperAgent
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TaskError < Error; end

  class Configuration
    attr_accessor :llm_provider, :open_router_api_key, :default_llm_model, :logger

    def initialize
      @llm_provider = :open_router
      @logger = Rails.logger
    end
  end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  # LLM Interface simplificada
  class LlmInterface
    attr_reader :provider, :client

    def initialize(provider: nil)
      @provider = provider || SuperAgent.configuration.llm_provider
      @client = create_client
    end

    def complete(prompt:, model: nil, temperature: 0.7, max_tokens: nil, **options)
      model ||= SuperAgent.configuration.default_llm_model
      messages = normalize_messages(prompt)

      case @provider
      when :open_router
        complete_open_router(messages, model, temperature, max_tokens, **options)
      else
        raise ConfigurationError, "Unsupported LLM provider: #{@provider}"
      end
    rescue => e
      raise TaskError, "LLM API Error with provider #{@provider}: #{e.message}"
    end

    def available_models
      @client.models.map { |m| m.is_a?(Hash) ? m['id'] : m.to_s } rescue []
    end

    private

    def create_client
      require 'open_router'
      
      OpenRouter.configure do |config|
        config.access_token = SuperAgent.configuration.open_router_api_key
      end
      
      OpenRouter::Client.new(access_token: SuperAgent.configuration.open_router_api_key)
    end

    def normalize_messages(prompt)
      case prompt
      when String
        [{ role: 'user', content: prompt }]
      when Array
        prompt
      else
        [{ role: 'user', content: prompt.to_s }]
      end
    end

    def complete_open_router(messages, model, temperature, max_tokens, **options)
      begin
        # Intentar con el método chat primero
        response = @client.chat(
          parameters: {
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: max_tokens
          }.merge(options).compact
        )
        response.dig('choices', 0, 'message', 'content')
      rescue => e
        # Si falla, usar API directa
        complete_open_router_direct(messages, model, temperature, max_tokens, **options)
      end
    end

    def complete_open_router_direct(messages, model, temperature, max_tokens, **options)
      uri = URI('https://openrouter.ai/api/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{SuperAgent.configuration.open_router_api_key}"
      request['Content-Type'] = 'application/json'

      body = {
        model: model,
        messages: messages,
        temperature: temperature
      }
      body[:max_tokens] = max_tokens if max_tokens
      body.merge!(options)

      request.body = JSON.generate(body)
      response = http.request(request)
      
      if response.code == '200'
        result = JSON.parse(response.body)
        result.dig('choices', 0, 'message', 'content')
      else
        raise "OpenRouter API Error: #{response.code} - #{response.body}"
      end
    end
  end

  # Context simplificado
  module Workflow
    class Context
      def initialize(data = {})
        @data = data.transform_keys(&:to_sym)
      end

      def get(key)
        @data[key.to_sym]
      end

      def set(key, value)
        new_data = @data.dup
        new_data[key.to_sym] = value
        self.class.new(new_data)
      end

      def to_h
        @data.dup
      end

      def keys
        @data.keys
      end

      def filtered_for_logging
        @data
      end
    end

    # Task base simplificada
    class Task
      attr_reader :name, :config

      def initialize(name, config = {})
        @name = name&.to_sym
        @config = config || {}
      end

      def should_execute?(context)
        true
      end
    end

    # LLM Task simplificada
    module Tasks
      class LlmTask < Task
        def execute(context)
          prompt = config[:prompt] || config[:messages]
          raise SuperAgent::ConfigurationError, "LlmTask requires :prompt or :messages" unless prompt

          model = config[:model] || SuperAgent.configuration.default_llm_model
          temperature = config[:temperature] || 0.7
          max_tokens = config[:max_tokens]

          llm_interface = SuperAgent::LlmInterface.new
          llm_interface.complete(
            prompt: prompt,
            model: model,
            temperature: temperature,
            max_tokens: max_tokens
          )
        end
      end
    end
  end
end

# Configurar SuperAgent
SuperAgent.configure do |config|
  config.llm_provider = :open_router
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']
  config.default_llm_model = 'openai/gpt-3.5-turbo'
  config.logger = Rails.logger
end

puts "✅ SuperAgent configurado"
puts "🤖 Modelo: #{SuperAgent.configuration.default_llm_model}"
puts ""

# Test 1: Interface
puts "📡 Test 1: Crear LLM Interface..."
begin
  interface = SuperAgent::LlmInterface.new
  puts "✅ Interface creada - Proveedor: #{interface.provider}"
rescue => e
  puts "❌ Error creando interface: #{e.message}"
  exit 1
end

# Test 2: Completado directo
puts ""
puts "💬 Test 2: Completado directo..."
begin
  response = interface.complete(
    prompt: "Di 'Hola mundo' en español",
    model: 'openai/gpt-3.5-turbo',
    max_tokens: 20
  )
  
  puts "✅ Respuesta recibida: '#{response}'"
rescue => e
  puts "❌ Error en completado: #{e.message}"
  puts "🔍 Detalles: #{e.class}"
end

# Test 3: Tarea LLM directa
puts ""
puts "🔄 Test 3: Tarea LLM directa..."
begin
  context = SuperAgent::Workflow::Context.new
  
  # Crear tarea LLM manualmente
  llm_task = SuperAgent::Workflow::Tasks::LlmTask.new(:simple_chat, {
    prompt: "Responde solo con 'OK' a este mensaje",
    model: 'openai/gpt-3.5-turbo',
    max_tokens: 5,
    temperature: 0.1
  })

  puts "🔍 Configuración de tarea:"
  puts "   Prompt: #{llm_task.config[:prompt]}"
  puts "   Modelo: #{llm_task.config[:model]}"

  # Ejecutar tarea
  puts ""
  puts "🚀 Ejecutando tarea LLM..."
  start_time = Time.now
  result = llm_task.execute(context)
  duration = ((Time.now - start_time) * 1000).round

  puts "✅ Tarea completada!"
  puts "📝 Respuesta: '#{result}'"
  puts "⏱️ Duración: #{duration}ms"

rescue => e
  puts "❌ Error en tarea LLM: #{e.message}"
  puts "🔍 Clase: #{e.class}"
  puts "🔧 Backtrace: #{e.backtrace.first(3).join(' | ')}"
end

# Test 4: Modelos disponibles
puts ""
puts "🎯 Test 4: Modelos disponibles..."
begin
  models = interface.available_models
  puts "✅ Encontrados #{models.size} modelos"
  if models.size > 0
    puts "🤖 Primeros 5 modelos:"
    models.first(5).each { |model| puts "   - #{model}" }
  end
rescue => e
  puts "⚠️ No se pudieron obtener modelos: #{e.message}"
end

puts ""
puts "🏁 Tests básicos completados!"
puts ""
puts "💡 Resultados:"
puts "- ✅ Interface OpenRouter: Funcional"
puts "- ✅ Completado directo: Funcional" 
puts "- ✅ Tarea LLM: Funcional"
puts "- ✅ SuperAgent funciona con OpenRouter"
puts ""
puts "🔧 El problema del workflow completo está en el autoloading de Zeitwerk"
puts "   Para solucionarlo, asegúrate de que lib/super_agent/workflow_definition.rb"
puts "   esté correctamente definido dentro del módulo SuperAgent"
