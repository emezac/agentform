#!/usr/bin/env ruby
# frozen_string_literal: true

# Ejemplo de PersonalizationWorkflow usando la nueva sintaxis DSL
require 'bundler/setup'
require 'super_agent'

class PersonalizationWorkflow < SuperAgent::WorkflowDefinition
  include SuperAgent::WorkflowHelpers

  workflow do
    # =====================
    # CONFIGURACIÓN GLOBAL
    # =====================
    
    timeout 60  # 60 segundos máximo
    retry_policy max_retries: 2, delay: 1
    
    # Manejo de errores global
    on_error do |error, context|
      Rails.logger.error "Personalization failed: #{error.message}"
      # Retornar oferta por defecto en caso de error
      default_response(:offer)
    end

    # Hook antes de ejecutar
    before_all do |context|
      Rails.logger.info "Starting personalization for session: #{context.get(:session_id)}"
    end

    # =====================
    # STEP 1: EVALUACIÓN INICIAL
    # =====================
    
    validate :evaluate_trigger do
      input :session_id
      description "Evaluate if personalization should trigger"
      
      process do |session_id|
        # Usar servicio existente
        trigger_service = Agent::AgentTriggerService.new(session_id: session_id)
        should_trigger = trigger_service.should_trigger?
        
        Rails.logger.info "Trigger evaluation: #{should_trigger}"
        should_trigger
      end
    end

    # =====================
    # STEP 2: ANÁLISIS DE SESIÓN (Condicional)
    # =====================
    
    task :analyze_session do
      input :session_id
      output :analysis
      description "Analyze user session behavior"
      run_when :evaluate_trigger, true  # Solo si el trigger es true
      
      process do |session_id|
        with_fallback(default_response(:analysis)) do
          Agent::SessionAnalysisService.call(session_id)
        end
      end
    end

    # =====================
    # STEP 3: CONSULTA DE APRENDIZAJE
    # =====================
    
    task :query_learning do
      input :analysis
      output :learning
      run_when :evaluate_trigger, true
      
      process do |analysis|
        with_fallback(default_response(:learning)) do
          Learning::LearningQueryService.call(analysis)
        end
      end
    end

    # =====================
    # STEP 4: SELECCIÓN DE PRODUCTOS
    # =====================
    
    task :select_products do
      input :analysis
      output :products
      run_when :evaluate_trigger, true
      
      process do |analysis|
        with_fallback(default_response(:products)) do
          Agent::ProductSelectionService.call(analysis)
        end
      end
    end

    # =====================
    # STEP 5: GENERACIÓN CON LLM
    # =====================
    
    llm :generate_offer do
      input :analysis, :learning, :products
      output :offer_data
      run_when :evaluate_trigger, true
      
      # Configuración del LLM
      model "gpt-4o-mini"
      temperature 0.3
      max_tokens 1000
      response_format :json
      
      # Prompt con interpolación automática
      prompt <<~PROMPT
        You are rdawn v2.0, an AI personalization engine. Generate a compelling offer.

        CONTEXT:
        - User Intent: {{analysis.detected_intent}}
        - Confidence Score: {{analysis.confidence_score}}%
        - Session Duration: {{analysis.session_duration}} minutes
        - Pages Viewed: {{analysis.pages_viewed}}
        - User Segment: {{analysis.user_segment}}

        LEARNING DATA:
        - Strategy Success Rate: {{learning.strategy_success_rate}}%
        - Recommended Discount: {{learning.recommended_discount_range}}%
        - Historical Performance: {{learning.confidence_adjustment}}

        AVAILABLE PRODUCTS:
        {{products}}

        Generate a JSON response with:
        {
          "offer_type": "discount|bundle|free_shipping|limited_time",
          "title": "Compelling offer title",
          "description": "Detailed offer description",
          "products": ["product_ids"],
          "original_price": 0.00,
          "final_price": 0.00,
          "discount_percentage": 0,
          "urgency_timer": 300,
          "call_to_action": "Shop Now",
          "reasoning": "Why this offer was chosen"
        }

        Make it personalized and compelling!
      PROMPT
    end

    # =====================
    # STEP 6: DEPLOY CON TURBO STREAMS
    # =====================
    
    stream :deploy_offer do
      input :offer_data, :session_id
      run_when :evaluate_trigger, true
      
      target do |ctx|
        "session_#{ctx.get(:session_id)}"
      end
      turbo_action :append
      partial "offers/personalized_toast"
      locals do |ctx|
        { offer: ctx.get(:offer_data), session: ctx.get(:session_id) }
      end
    end

    # =====================
    # STEP 7: TRACKING Y ANALYTICS
    # =====================
    
    task :track_offer do
      input :offer_data, :session_id, :analysis
      run_when :evaluate_trigger, true
      
      process do |offer, session_id, analysis|
        # Tracking del offer generado
        Agent::OfferTrackingService.call(
          offer: offer,
          session_id: session_id,
          user_analysis: analysis,
          timestamp: Time.current
        )
        
        { tracked: true, offer_id: offer[:id] || SecureRandom.uuid }
      end
    end

    # =====================
    # STEP 8: FALLBACK PARA USUARIOS SIN TRIGGER
    # =====================
    
    task :fallback_engagement do
      run_when :evaluate_trigger, false  # Solo si el trigger es false
      
      process do |context|
        # Engagement básico para usuarios que no califican para ofertas
        {
          message: "Thanks for visiting!",
          action: "newsletter_signup",
          incentive: "10% off your first order"
        }
      end
    end

    # Hook después de ejecutar
    after_all do |context|
      duration = Time.current - context.get(:start_time, Time.current)
      Rails.logger.info "Personalization completed in #{humanize_duration(duration)}"
    end
  end
end

# =====================
# EJEMPLO DE USO
# =====================

if __FILE__ == $0
  puts "🚀 SuperAgent Enhanced Personalization Demo"
  puts "=" * 50

  # Mock Rails simple
  module Rails
    extend self
    def logger; @logger ||= Logger.new($stdout, level: Logger::INFO); end
    def env; 'test'; end
  end

  # Mock servicios necesarios
  module Agent
    class AgentTriggerService
      def initialize(session_id:)
        @session_id = session_id
      end

      def should_trigger?
        # Simular lógica de trigger basada en session_id
        @session_id.include?('high') || @session_id.include?('medium')
      end
    end

    class SessionAnalysisService
      def self.call(session_id)
        # Simular análisis de sesión
        if session_id.include?('high')
          {
            detected_intent: :purchase_ready,
            confidence_score: 0.85,
            session_duration: 300,
            pages_viewed: 5,
            user_segment: :premium
          }
        elsif session_id.include?('medium')
          {
            detected_intent: :browsing,
            confidence_score: 0.60,
            session_duration: 180,
            pages_viewed: 3,
            user_segment: :regular
          }
        else
          {
            detected_intent: :exploring,
            confidence_score: 0.30,
            session_duration: 60,
            pages_viewed: 1,
            user_segment: :new
          }
        end
      end
    end

    class ProductSelectionService
      def self.call(analysis)
        case analysis[:user_segment]
        when :premium
          [
            { id: 'prod_1', name: 'Premium Product', price: 299.99 },
            { id: 'prod_2', name: 'Luxury Item', price: 499.99 }
          ]
        when :regular
          [
            { id: 'prod_3', name: 'Regular Product', price: 99.99 },
            { id: 'prod_4', name: 'Popular Item', price: 149.99 }
          ]
        else
          [
            { id: 'prod_5', name: 'Starter Product', price: 29.99 },
            { id: 'prod_6', name: 'Basic Item', price: 49.99 }
          ]
        end
      end
    end

    class OfferTrackingService
      def self.call(params)
        puts "📊 Tracking offer: #{params[:offer][:title] rescue 'Unknown'}"
        true
      end
    end
  end

  module Learning
    class LearningQueryService
      def self.call(analysis)
        # Simular datos de aprendizaje
        {
          strategy_success_rate: rand(40..80),
          recommended_discount_range: [10, 25],
          confidence_adjustment: rand(-0.1..0.1).round(2)
        }
      end
    end
  end

  # Datos de prueba
  test_sessions = [
    { session_id: "sess_high_intent", user_type: "returning", pages: 5, duration: 300 },
    { session_id: "sess_medium_intent", user_type: "new", pages: 2, duration: 120 },
    { session_id: "sess_low_intent", user_type: "bounce", pages: 1, duration: 30 }
  ]

  # Configurar SuperAgent para el ejemplo
  SuperAgent.configure do |config|
    config.llm_provider = :openai  # o :open_router
    config.openai_api_key = ENV['OPENAI_API_KEY'] || 'demo-key'
    config.default_llm_model = "gpt-4o-mini"
    config.deprecation_warnings = false
  end

  # Crear agente
  class PersonalizationAgent < SuperAgent::Base
    def personalize(session_data)
      context_data = session_data.merge(start_time: Time.current)
      run_workflow(PersonalizationWorkflow, initial_input: context_data)
    end
  end

  agent = PersonalizationAgent.new

  test_sessions.each do |session|
    puts "\n🎯 Processing Session: #{session[:session_id]}"
    puts "   Type: #{session[:user_type]}, Pages: #{session[:pages]}, Duration: #{session[:duration]}s"
    
    begin
      result = agent.personalize(session)
      
      if result.completed?
        puts "✅ Personalization successful!"
        
        # Mostrar resultados de cada step
        if result.output_for(:evaluate_trigger)
          puts "   🎯 Trigger: #{result.output_for(:evaluate_trigger) ? 'YES' : 'NO'}"
        end
        
        if result.output_for(:analyze_session)
          analysis = result.output_for(:analyze_session)
          puts "   📊 Analysis: Intent=#{analysis[:detected_intent]}, Score=#{analysis[:confidence_score]}"
        end
        
        if result.output_for(:generate_offer)
          offer = result.output_for(:generate_offer)
          puts "   🎁 Offer: #{offer[:title]} (#{offer[:offer_type]})"
          puts "   💰 Price: $#{offer[:original_price]} → $#{offer[:final_price]} (#{offer[:discount_percentage]}% off)"
        end
        
        if result.output_for(:fallback_engagement)
          fallback = result.output_for(:fallback_engagement)
          puts "   📢 Fallback: #{fallback[:message]}"
        end
        
        puts "   ⏱️ Total time: #{result.duration_ms}ms"
      else
        puts "❌ Error: #{result.error_message}"
      end
    rescue => e
      puts "💥 Exception: #{e.message}"
    end
  end

  puts "\n🎉 Demo completed!"
  puts "\nNew DSL Features Demonstrated:"
  puts "✅ Simplified task definition with input/output"
  puts "✅ Conditional execution with run_when/skip_when"
  puts "✅ Built-in error handling with fallbacks"
  puts "✅ LLM shortcuts with automatic prompt interpolation"
  puts "✅ Workflow-level configuration (timeout, retries)"
  puts "✅ Hooks for before/after execution"
  puts "✅ Rich helper methods for common operations"
  puts "✅ Multi-provider LLM support"
end
