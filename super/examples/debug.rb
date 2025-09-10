#!/usr/bin/env ruby
# frozen_string_literal: true

# Test específico del engine
require 'bundler/setup'
require 'super_agent'

puts "🔍 Debug Específico del WorkflowEngine"
puts "=" * 40

# Mock Rails
module Rails
  extend self
  def logger; @logger ||= Logger.new($stdout, level: Logger::INFO); end
  def env; 'test'; end
end

# Configuración
SuperAgent.configure do |config|
  config.llm_provider = :open_router
  config.open_router_api_key = ENV['OPENROUTER_API_KEY'] || 'test-key'
  config.default_llm_model = 'openai/gpt-3.5-turbo'
  config.logger = Rails.logger
end

# Workflow de test
class TestWorkflow < SuperAgent::WorkflowDefinition
  workflow do
    llm :simple_chat, "Responde solo con 'OK' a este mensaje" do
      model 'openai/gpt-3.5-turbo'
      max_tokens 5
    end
  end
end

puts "✅ Workflow definido"
puts ""

# Crear un engine personalizado para debug
class DebugWorkflowEngine < SuperAgent::WorkflowEngine
  def create_task(step_name, step_config)
    puts "🔍 create_task llamado:"
    puts "  step_name: #{step_name.inspect}"
    puts "  step_config keys: #{step_config.keys.inspect}"
    puts "  step_config: #{step_config.inspect}"
    
    task_type = step_config[:uses]
    puts "  task_type: #{task_type.inspect}"
    
    case task_type
    when :llm, :llm_task
      puts "  📝 Creando LlmTask con configuración completa"
      puts "  📝 Configuración que se pasa: #{step_config.inspect}"
      
      task = SuperAgent::Workflow::Tasks::LlmTask.new(step_name, step_config)
      
      puts "  📝 Tarea creada con config: #{task.config.inspect}"
      puts "  📝 ¿Tiene prompt?: #{task.config.key?(:prompt)}"
      puts "  📝 Prompt value: #{task.config[:prompt].inspect}"
      
      return task
    else
      puts "  ❌ Tipo de tarea no LLM: #{task_type}"
      return super
    end
  end
end

puts "🔍 Creando contexto y engine de debug..."
context = SuperAgent::Workflow::Context.new
engine = DebugWorkflowEngine.new

puts ""
puts "🔍 Verificando steps del workflow antes de ejecutar:"
TestWorkflow.all_steps.each do |step|
  puts "  Step: #{step[:name]}"
  puts "  Config: #{step[:config].inspect}"
end

puts ""
puts "🚀 Ejecutando workflow con engine de debug..."

begin
  result = engine.execute(TestWorkflow, context)
  
  if result.completed?
    puts "✅ Workflow completado exitosamente!"
    puts "📝 Respuesta: '#{result.output_for(:simple_chat)}'"
  else
    puts "❌ Workflow falló: #{result.error_message}"
    puts "🔍 Tarea fallida: #{result.failed_task_name}"
  end
rescue => e
  puts "❌ Error en ejecución: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(5).join(' | ')}"
end

puts ""
puts "🏁 Debug del engine completado"
