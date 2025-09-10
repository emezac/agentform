#!/usr/bin/env ruby
# frozen_string_literal: true

# Test básico de conectividad con OpenRouter
require 'bundler/setup'
require 'super_agent'

puts "🔌 Test Básico de Conectividad - SuperAgent + OpenRouter"
puts "=" * 60

# Verificar API key
unless ENV['OPENROUTER_API_KEY']
  puts "❌ OPENROUTER_API_KEY no configurada"
  puts ""
  puts "Configura tu API key:"
  puts "export OPENROUTER_API_KEY='tu_api_key_aqui'"
  exit 1
end

# Mock Rails mínimo
module Rails
  extend self
  def logger; @logger ||= Logger.new($stdout, level: Logger::INFO); end
  def env; 'test'; end
end

# Configuración mínima
SuperAgent.configure do |config|
  config.llm_provider = :open_router
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']
  config.default_llm_model = 'openai/gpt-3.5-turbo'
  config.logger = Rails.logger
end

puts "✅ Configuración cargada"
puts "🔑 API Key: #{ENV['OPENROUTER_API_KEY'][0..10]}..."
puts "🤖 Modelo: #{SuperAgent.configuration.default_llm_model}"
puts ""

# Test 1: Verificar que podemos crear la interface
puts "📡 Test 1: Crear LLM Interface..."
begin
  interface = SuperAgent::LlmInterface.new
  puts "✅ Interface creada - Proveedor: #{interface.provider}"
rescue => e
  puts "❌ Error creando interface: #{e.message}"
  exit 1
end

# Test 2: Test de completado directo
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

# Test 3: Workflow simple - CORREGIDO
puts ""
puts "🔄 Test 3: Workflow simple..."

class MiniWorkflow < SuperAgent::WorkflowDefinition
  workflow do
    # Usar la sintaxis correcta para tareas LLM
    llm :simple_chat, "Responde solo con 'OK' a este mensaje" do
      model 'openai/gpt-3.5-turbo'
      max_tokens 5
    end
  end
end

begin
  context = SuperAgent::Workflow::Context.new
  engine = SuperAgent::WorkflowEngine.new
  
  puts "🚀 Ejecutando workflow..."
  result = engine.execute(MiniWorkflow, context)
  
  if result.completed?
    puts "✅ Workflow completado!"
    puts "📝 Respuesta: '#{result.output_for(:simple_chat)}'"
    puts "⏱️ Duración: #{result.duration_ms}ms"
  else
    puts "❌ Workflow falló: #{result.error_message}"
  end
rescue => e
  puts "❌ Error en workflow: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(3).join(' | ')}"
end

# Test 4: Verificar modelos disponibles (opcional)
puts ""
puts "🎯 Test 4: Modelos disponibles..."
begin
  models = interface.available_models
  puts "✅ Encontrados #{models.size} modelos"
  puts "🤖 Primeros 5 modelos:"
  models.first(5).each { |model| puts "   - #{model}" }
rescue => e
  puts "⚠️ No se pudieron obtener modelos: #{e.message}"
end

puts ""
puts "🏁 Tests básicos completados!"
puts ""
puts "💡 Si todos los tests pasan, SuperAgent está funcionando correctamente con OpenRouter"
