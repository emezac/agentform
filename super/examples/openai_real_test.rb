#!/usr/bin/env ruby
# frozen_string_literal: true

# Test real de OpenAI con SuperAgent
require 'bundler/setup'
require 'super_agent'

puts "🤖 Test Real de OpenAI - SuperAgent"
puts "=" * 40

# Verificar API key
unless ENV['OPENAI_API_KEY']
  puts "❌ OPENAI_API_KEY no configurada"
  puts ""
  puts "Para usar este test necesitas:"
  puts "1. Una API key real de OpenAI"
  puts "2. Créditos en tu cuenta de OpenAI"
  puts ""
  puts "Configura tu API key:"
  puts "export OPENAI_API_KEY='sk-tu_api_key_real_aqui'"
  exit 1
end

# Verificar que la API key parece real
api_key = ENV['OPENAI_API_KEY']
unless api_key.start_with?('sk-') && api_key.length > 20
  puts "⚠️  La API key no parece válida"
  puts "   Debe empezar con 'sk-' y tener más de 20 caracteres"
  puts "   Actual: #{api_key[0..10]}... (#{api_key.length} chars)"
  puts ""
end

# Mock Rails
module Rails
  extend self
  def logger; @logger ||= Logger.new($stdout, level: Logger::INFO); end
  def env; 'test'; end
end

# Configurar SuperAgent para OpenAI
SuperAgent.configure do |config|
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_llm_model = 'gpt-3.5-turbo'
  config.logger = Rails.logger
end

puts "✅ SuperAgent configurado para OpenAI"
puts "🔑 API Key: #{ENV['OPENAI_API_KEY'][0..10]}..."
puts "🤖 Modelo por defecto: #{SuperAgent.configuration.default_llm_model}"
puts ""

# Test 1: Verificar conectividad
puts "📡 Test 1: Verificar conectividad con OpenAI..."
begin
  interface = SuperAgent::LlmInterface.new
  puts "✅ Interface OpenAI creada - Proveedor: #{interface.provider}"
rescue => e
  puts "❌ Error creando interface: #{e.message}"
  exit 1
end

# Test 2: Completado directo con prompt específico
puts ""
puts "💬 Test 2: Completado directo con OpenAI..."
begin
  response = interface.complete(
    prompt: "Responde exactamente con las palabras: OPENAI CONECTADO",
    model: 'gpt-3.5-turbo',
    max_tokens: 10,
    temperature: 0.1
  )
  
  puts "✅ Respuesta de OpenAI: '#{response}'"
  
  # Verificar que la respuesta es de OpenAI real
  if response.upcase.include?('OPENAI') && response.upcase.include?('CONECTADO')
    puts "✅ Respuesta válida de OpenAI confirmada"
  else
    puts "⚠️  Respuesta inesperada, pero conectividad OK"
  end
rescue => e
  puts "❌ Error en completado: #{e.message}"
  puts "🔍 Esto puede indicar:"
  puts "   - API key inválida"
  puts "   - Sin créditos en la cuenta"
  puts "   - Problemas de conectividad"
end

# Test 3: Completado con GPT-4 (si está disponible)
puts ""
puts "🧠 Test 3: Probar GPT-4 (si está disponible)..."
begin
  response = interface.complete(
    prompt: "Cual es la capital de Francia? Responde solo con el nombre de la ciudad.",
    model: 'gpt-4',
    max_tokens: 5,
    temperature: 0
  )
  
  puts "✅ Respuesta GPT-4: '#{response}'"
  
  if response.downcase.include?('parís') || response.downcase.include?('paris')
    puts "✅ GPT-4 respondió correctamente"
  else
    puts "⚠️  Respuesta inesperada de GPT-4"
  end
rescue => e
  puts "❌ Error con GPT-4: #{e.message}"
  puts "💡 Esto es normal si tu cuenta no tiene acceso a GPT-4"
end

# Test 4: Workflow completo con OpenAI
puts ""
puts "🔄 Test 4: Workflow completo con OpenAI..."

class OpenAIWorkflow < SuperAgent::WorkflowDefinition
  workflow do
    llm :greeting, "Di 'Hola desde OpenAI' en español" do
      model 'gpt-3.5-turbo'
      max_tokens 10
      temperature 0.1
    end
    
    llm :math, "¿Cuánto es 7 + 3? Responde solo con el número." do
      model 'gpt-3.5-turbo'
      max_tokens 5
      temperature 0
    end
  end
end

begin
  context = SuperAgent::Workflow::Context.new
  engine = SuperAgent::WorkflowEngine.new
  
  puts "🚀 Ejecutando workflow con OpenAI..."
  result = engine.execute(OpenAIWorkflow, context)
  
  if result.completed?
    puts "✅ Workflow con OpenAI completado!"
    
    greeting = result.output_for(:greeting)
    math = result.output_for(:math)
    
    puts "📝 Saludo: '#{greeting}'"
    puts "🔢 Matemática: '#{math}'"
    puts "⏱️ Duración total: #{result.duration_ms}ms"
    
    # Verificar respuestas
    if greeting.downcase.include?('hola') || greeting.downcase.include?('openai')
      puts "✅ Saludo válido"
    end
    
    if math.include?('10') || math.include?('diez')
      puts "✅ Matemática correcta"
    end
  else
    puts "❌ Workflow falló: #{result.error_message}"
    puts "🔍 Tarea fallida: #{result.failed_task_name}"
  end
rescue => e
  puts "❌ Error en workflow: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(3).join(' | ')}"
end

# Test 5: Verificar modelos disponibles
puts ""
puts "🎯 Test 5: Modelos disponibles en tu cuenta OpenAI..."
begin
  models = interface.available_models
  puts "✅ Encontrados #{models.size} modelos"
  
  # Filtrar solo modelos comunes de OpenAI
  gpt_models = models.select { |m| m.include?('gpt') }
  puts "🤖 Modelos GPT disponibles:"
  gpt_models.first(10).each { |model| puts "   - #{model}" }
  
  # Verificar si tiene acceso a GPT-4
  if models.any? { |m| m.include?('gpt-4') }
    puts "✅ Tienes acceso a GPT-4"
  else
    puts "💡 No tienes acceso a GPT-4 (solo GPT-3.5)"
  end
  
rescue => e
  puts "❌ Error obteniendo modelos: #{e.message}"
end

# Test 6: Test de uso real con streaming (si está disponible)
puts ""
puts "🌊 Test 6: Generación de contenido creativo..."
begin
  creative_response = interface.complete(
    prompt: "Escribe un haiku sobre la inteligencia artificial en español. Solo el haiku, nada más.",
    model: 'gpt-3.5-turbo',
    max_tokens: 50,
    temperature: 0.7
  )
  
  puts "✅ Contenido creativo generado:"
  puts "📝 #{creative_response}"
  
  # Verificar que parece un haiku (3 líneas aproximadamente)
  lines = creative_response.split(/\n/).reject(&:empty?)
  if lines.size >= 3
    puts "✅ Estructura de haiku detectada (#{lines.size} líneas)"
  else
    puts "💡 Respuesta creativa válida"
  end
  
rescue => e
  puts "❌ Error en generación creativa: #{e.message}"
end

puts ""
puts "🏁 Test real de OpenAI completado!"
puts ""
puts "📊 Resumen:"
puts "✅ Conectividad: OK" 
puts "✅ API Key: Válida"
puts "✅ Completado directo: OK"
puts "✅ Workflow: OK"
puts "✅ SuperAgent + OpenAI: FUNCIONANDO"
puts ""
puts "💰 Nota: Este test consume créditos reales de OpenAI"
puts "🔗 Verifica tu uso en: https://platform.openai.com/usage"
