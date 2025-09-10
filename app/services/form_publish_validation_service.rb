# frozen_string_literal: true

class FormPublishValidationService < ApplicationService
  include PaymentAnalyticsTrackable
  
  attribute :form, default: nil
  attribute :track_analytics, default: true

  def call
    validate_service_inputs
    return self if failure?

    validate_payment_readiness
    track_validation_events if track_analytics
    self
  end

  private

  def validate_service_inputs
    validate_required_attributes(:form)
    
    unless form.is_a?(Form)
      add_error(:form, 'must be a Form instance')
    end
  end

  def validate_payment_readiness
    validation_results = {
      can_publish: true,
      validation_errors: [],
      required_actions: [],
      form_id: form.id,
      validated_at: Time.current
    }

    # Check if form has payment questions
    if form.has_payment_questions?
      validate_payment_questions_configuration(validation_results)
      validate_user_payment_setup(validation_results)
    end

    # Use PaymentReadinessChecker for comprehensive validation
    readiness_check = PaymentReadinessChecker.new(form: form).call
    
    if readiness_check.failure?
      validation_results[:can_publish] = false
      validation_results[:validation_errors].concat(readiness_check.result[:errors] || [])
      validation_results[:required_actions].concat(readiness_check.result[:actions] || [])
    end

    # Generate publish guidance if validation fails
    if validation_results[:validation_errors].any?
      generate_publish_guidance(validation_results)
    end

    # Set overall publish status
    validation_results[:can_publish] = validation_results[:validation_errors].empty?

    set_result(validation_results)
    set_context(:payment_questions_count, form.payment_questions.count)
    set_context(:validation_errors_count, validation_results[:validation_errors].length)
  end

  def validate_payment_questions_configuration(validation_results)
    payment_questions = form.payment_questions

    payment_questions.each do |question|
      # Validate question configuration
      unless question.question_config.present?
        validation_results[:validation_errors] << {
          type: 'payment_question_configuration',
          question_id: question.id,
          title: 'Payment Question Configuration Missing',
          description: "Payment question '#{question.title}' is not properly configured",
          details: ['Payment configuration is required for payment questions'],
          priority: 'high'
        }
      end

      # Validate required payment fields
      if question.question_config.present?
        validate_payment_question_fields(question, validation_results)
      end
    end
  end

  def validate_payment_question_fields(question, validation_results)
    config = question.question_config
    missing_fields = []

    # Check for required payment configuration fields
    missing_fields << 'amount' unless config['amount'].present?
    missing_fields << 'currency' unless config['currency'].present?
    missing_fields << 'description' unless config['description'].present?

    if missing_fields.any?
      validation_results[:validation_errors] << {
        type: 'payment_question_fields',
        question_id: question.id,
        title: 'Payment Question Fields Missing',
        description: "Payment question '#{question.title}' is missing required fields",
        details: missing_fields.map { |field| "Missing #{field}" },
        priority: 'high'
      }
    end
  end

  def validate_user_payment_setup(validation_results)
    user = form.user

    # Check Stripe configuration
    unless user.stripe_configured?
      validation_results[:validation_errors] << {
        type: 'stripe_not_configured',
        title: 'Stripe Configuration Required',
        description: 'Configure Stripe to accept payments before publishing forms with payment questions',
        details: ['Stripe keys not configured', 'Payment processing unavailable'],
        priority: 'high'
      }
    end

    # Check Premium subscription
    unless user.premium?
      validation_results[:validation_errors] << {
        type: 'premium_subscription_required',
        title: 'Premium Subscription Required',
        description: 'Upgrade to Premium to publish forms with payment questions',
        details: [
          "Current tier: #{user.subscription_tier}",
          'Premium subscription required for payment features'
        ],
        priority: 'high'
      }
    end

    # Check if user can accept payments (combined check)
    unless user.can_accept_payments?
      validation_results[:validation_errors] << {
        type: 'payment_acceptance_disabled',
        title: 'Payment Acceptance Not Available',
        description: 'Complete payment setup to publish forms with payment questions',
        details: ['Both Stripe configuration and Premium subscription are required'],
        priority: 'high'
      }
    end
  end

  def generate_publish_guidance(validation_results)
    validation_results[:validation_errors].each do |error|
      action = case error[:type]
               when 'stripe_not_configured'
                 generate_stripe_setup_action
               when 'premium_subscription_required'
                 generate_subscription_upgrade_action
               when 'payment_question_configuration'
                 generate_question_configuration_action(error)
               when 'payment_question_fields'
                 generate_question_fields_action(error)
               when 'payment_acceptance_disabled'
                 generate_complete_setup_action
               end
      
      validation_results[:required_actions] << action if action
    end

    # Remove duplicate actions
    validation_results[:required_actions].uniq! { |action| action[:type] }
  end

  def generate_stripe_setup_action
    {
      type: 'stripe_setup',
      title: 'Configure Stripe Payments',
      description: 'Set up your Stripe account to accept payments',
      action_url: '/stripe_settings',
      action_text: 'Configure Stripe',
      estimated_time: '5-10 minutes',
      priority: 'high',
      icon: 'credit-card'
    }
  end

  def generate_subscription_upgrade_action
    {
      type: 'subscription_upgrade',
      title: 'Upgrade to Premium',
      description: 'Unlock payment features with a Premium subscription',
      action_url: '/subscription_management',
      action_text: 'Upgrade Now',
      estimated_time: '2-3 minutes',
      priority: 'high',
      icon: 'star'
    }
  end

  def generate_question_configuration_action(error)
    {
      type: 'configure_payment_question',
      title: 'Configure Payment Question',
      description: 'Complete the configuration for your payment question',
      action_url: "/forms/#{form.id}/questions/#{error[:question_id]}/edit",
      action_text: 'Configure Question',
      estimated_time: '2-3 minutes',
      priority: 'high',
      icon: 'settings'
    }
  end

  def generate_question_fields_action(error)
    {
      type: 'complete_payment_fields',
      title: 'Complete Payment Fields',
      description: 'Add required fields to your payment question',
      action_url: "/forms/#{form.id}/questions/#{error[:question_id]}/edit",
      action_text: 'Complete Fields',
      estimated_time: '1-2 minutes',
      priority: 'high',
      icon: 'edit'
    }
  end

  def generate_complete_setup_action
    {
      type: 'complete_payment_setup',
      title: 'Complete Payment Setup',
      description: 'Finish setting up both Stripe and Premium subscription',
      action_url: '/payment_setup_guide',
      action_text: 'Complete Setup',
      estimated_time: '10-15 minutes',
      priority: 'high',
      icon: 'check-circle'
    }
  end

  def track_validation_events
    validation_result = result
    
    if validation_result[:can_publish]
      track_payment_event(
        'payment_form_published',
        user: form.user,
        context: {
          form_id: form.id,
          form_title: form.title,
          payment_questions_count: form.payment_questions.count,
          published_at: Time.current
        }
      )
    elsif validation_result[:validation_errors].any?
      validation_result[:validation_errors].each do |error|
        track_payment_event(
          'payment_validation_errors',
          user: form.user,
          context: {
            form_id: form.id,
            error_type: error[:type],
            error_title: error[:title],
            resolution_path: validation_result[:required_actions].find { |action| 
              action[:type].to_s.include?(error[:type].to_s.split('_').first) 
            }&.dig(:type),
            priority: error[:priority]
          }
        )
      end
    end
  end
end