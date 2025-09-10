# frozen_string_literal: true

class PaymentValidationWorkflow < ApplicationWorkflow
  
  workflow do
    # Step 1: Validate and prepare template for analysis
    task :validate_and_prepare_template do
      process do |context|
        template = context.get(:template)
        
        Rails.logger.info "Starting payment validation workflow for template: #{template&.id}"
        
        # Validate required inputs
        if template.nil?
          raise ArgumentError, "Missing required inputs: template"
        end
        
        # Ensure template exists and is valid
        unless template.respond_to?(:id) && template.id.present?
          raise ArgumentError, "Invalid template provided"
        end
        
        # Check if template has questions to analyze
        questions_count = if template.respond_to?(:questions_config)
                           template.questions_config.length
                         elsif template.respond_to?(:form_questions)
                           template.form_questions.count
                         elsif template.respond_to?(:questions)
                           template.questions.count
                         else
                           0
                         end
        
        if questions_count == 0
          Rails.logger.warn "Template #{template.id} has no questions to analyze"
          {
            template: template,
            questions_count: 0,
            has_questions: false,
            validation_status: 'no_questions'
          }
        else
        
        Rails.logger.info "Template validation successful - #{questions_count} questions found"
        
        {
          template: template,
          questions_count: questions_count,
          has_questions: true,
          validation_status: 'valid'
        }
        end
      end
    end

    # Step 2: Analyze payment requirements using TemplateAnalysisService
    task :analyze_payment_requirements do
      process do |context|
        validation_result = context.get(:validate_and_prepare_template)
        template = validation_result[:template]
        
        # Skip analysis if no questions
        if !validation_result[:has_questions]
          {
            has_payment_questions: false,
            required_features: [],
            setup_complexity: 'none',
            analysis_status: 'skipped_no_questions'
          }
        else
        
        Rails.logger.info "Analyzing payment requirements for template #{template.id}"
        
        begin
          # Use TemplateAnalysisService to analyze payment requirements
          analysis_service = TemplateAnalysisService.call(template: template)
          
          unless analysis_service.success?
            raise "Template analysis failed: #{analysis_service.errors.full_messages.join(', ')}"
          end
          
          analysis_result = analysis_service.result
          
          # Validate analysis result structure
          unless analysis_result.is_a?(Hash)
            raise "Invalid analysis result format from TemplateAnalysisService"
          end
          
          required_keys = [:has_payment_questions, :required_features, :setup_complexity]
          missing_keys = required_keys.select { |key| !analysis_result.key?(key) }
          
          if missing_keys.any?
            raise "Missing keys in analysis result: #{missing_keys.join(', ')}"
          end
          
          Rails.logger.info "Payment analysis completed - has_payment_questions: #{analysis_result[:has_payment_questions]}"
          
          {
            has_payment_questions: analysis_result[:has_payment_questions],
            required_features: analysis_result[:required_features] || [],
            setup_complexity: analysis_result[:setup_complexity] || 'none',
            analysis_status: 'completed',
            payment_question_types: analysis_result[:payment_question_types] || []
          }
          
        rescue StandardError => e
          Rails.logger.error "Payment requirements analysis failed: #{e.message}"
          
          # Return safe defaults on analysis failure
          {
            has_payment_questions: false,
            required_features: [],
            setup_complexity: 'unknown',
            analysis_status: 'failed',
            analysis_error: e.message
          }
        end
        end
      end
    end

    # Step 3: Validate user setup using PaymentSetupValidationService
    task :validate_user_setup do
      process do |context|
        user = context.get(:user)
        requirements_result = context.get(:analyze_payment_requirements)
        
        Rails.logger.info "Validating user setup for user: #{user&.id}"
        
        # Validate required inputs
        if user.nil?
          raise ArgumentError, "Missing required inputs: user"
        end
        
        # Skip validation if no payment requirements
        unless requirements_result[:has_payment_questions]
          {
            setup_valid: true,
            missing_requirements: [],
            setup_actions: [],
            validation_status: 'no_payment_requirements'
          }
        else
        
        required_features = requirements_result[:required_features]
        
        begin
          # Use PaymentSetupValidationService to validate user setup
          validation_service = PaymentSetupValidationService.call(user: user, required_features: required_features)
          
          unless validation_service.success?
            raise "User setup validation failed: #{validation_service.errors.full_messages.join(', ')}"
          end
          
          validation_result = validation_service.result
          
          # Validate service result structure
          unless validation_result.is_a?(Hash)
            raise "Invalid validation result format from PaymentSetupValidationService"
          end
          
          required_keys = [:valid, :missing_requirements, :setup_actions]
          missing_keys = required_keys.select { |key| !validation_result.key?(key) }
          
          if missing_keys.any?
            raise "Missing keys in validation result: #{missing_keys.join(', ')}"
          end
          
          Rails.logger.info "User setup validation completed - valid: #{validation_result[:valid]}"
          
          {
            setup_valid: validation_result[:valid],
            missing_requirements: validation_result[:missing_requirements] || [],
            setup_actions: validation_result[:setup_actions] || [],
            validation_status: 'completed',
            user_capabilities: validation_result[:user_capabilities] || {}
          }
          
        rescue StandardError => e
          Rails.logger.error "User setup validation failed: #{e.message}"
          
          # Return conservative defaults on validation failure
          {
            setup_valid: false,
            missing_requirements: ['validation_failed'],
            setup_actions: [{
              type: 'validation_error',
              message: 'Unable to validate payment setup',
              action_url: nil,
              action_text: 'Contact Support'
            }],
            validation_status: 'failed',
            validation_error: e.message
          }
        end
        end
      end
    end

    # Step 4: Generate user guidance based on validation results
    task :generate_user_guidance do
      process do |context|
        requirements_result = context.get(:analyze_payment_requirements)
        validation_result = context.get(:validate_user_setup)
        template_result = context.get(:validate_and_prepare_template)
        
        Rails.logger.info "Generating user guidance"
        
        # If no payment requirements, provide success guidance
        if !requirements_result[:has_payment_questions]
          {
            guidance_type: 'no_payment_setup_needed',
            message: 'This template does not require payment configuration.',
            can_proceed: true,
            setup_required: false,
            actions: [],
            guidance_status: 'completed'
          }
        # If setup is valid, provide success guidance
        elsif validation_result[:setup_valid]
          {
            guidance_type: 'setup_complete',
            message: 'Your payment configuration is complete. You can use this template.',
            can_proceed: true,
            setup_required: false,
            actions: [],
            guidance_status: 'completed'
          }
        else
        
        # Generate guidance for incomplete setup
        missing_requirements = validation_result[:missing_requirements] || []
        setup_actions = validation_result[:setup_actions] || []
        
        # Determine guidance type based on missing requirements
        guidance_type = case missing_requirements.length
                       when 0
                         'setup_complete'
                       when 1
                         case missing_requirements.first
                         when 'stripe_configuration'
                           'stripe_setup_required'
                         when 'premium_subscription'
                           'premium_upgrade_required'
                         else
                           'single_requirement_missing'
                         end
                       else
                         'multiple_requirements_missing'
                       end
        
        # Generate appropriate message
        message = generate_guidance_message(guidance_type, missing_requirements, requirements_result[:setup_complexity])
        
        # Enhance setup actions with additional context
        enhanced_actions = setup_actions.map do |action|
          action.merge(
            template_id: template_result[:template].id,
            required_features: requirements_result[:required_features],
            setup_complexity: requirements_result[:setup_complexity]
          )
        end
        
        Rails.logger.info "User guidance generated - type: #{guidance_type}, actions: #{enhanced_actions.length}"
        
        {
          guidance_type: guidance_type,
          message: message,
          can_proceed: false,
          setup_required: true,
          missing_requirements: missing_requirements,
          actions: enhanced_actions,
          setup_complexity: requirements_result[:setup_complexity],
          estimated_setup_time: estimate_setup_time(missing_requirements, requirements_result[:setup_complexity]),
          guidance_status: 'completed'
        }
        end
      end
    end
  end

  private

  def generate_guidance_message(guidance_type, missing_requirements, setup_complexity)
    case guidance_type
    when 'stripe_setup_required'
      "To use this payment-enabled template, you need to configure Stripe for payment processing."
    when 'premium_upgrade_required'
      "This template includes premium payment features. Upgrade to Premium to use payment questions."
    when 'multiple_requirements_missing'
      requirements_text = missing_requirements.map do |req|
        case req
        when 'stripe_configuration'
          'Stripe payment configuration'
        when 'premium_subscription'
          'Premium subscription'
        else
          req.humanize
        end
      end.join(' and ')
      
      "To use this payment-enabled template, you need: #{requirements_text}."
    when 'single_requirement_missing'
      requirement = missing_requirements.first&.humanize || 'payment setup'
      "To use this template, you need to complete: #{requirement}."
    else
      "Payment setup is required to use this template."
    end
  end

  def estimate_setup_time(missing_requirements, setup_complexity)
    base_time = case setup_complexity
               when 'simple'
                 5
               when 'moderate'
                 10
               when 'complex'
                 20
               else
                 10
               end
    
    # Add time for each missing requirement
    additional_time = missing_requirements.length * 3
    
    total_minutes = base_time + additional_time
    
    if total_minutes <= 5
      "5 minutes"
    elsif total_minutes <= 15
      "10-15 minutes"
    elsif total_minutes <= 30
      "20-30 minutes"
    else
      "30+ minutes"
    end
  end
end