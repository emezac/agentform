# frozen_string_literal: true

class PaymentReadinessChecker < ApplicationService
  attribute :form, default: nil
  attribute :user, default: nil

  def call
    validate_service_inputs
    return self if failure?

    perform_comprehensive_readiness_check
    self
  end

  private

  def validate_service_inputs
    # Form is required, user can be derived from form
    validate_required_attributes(:form)
    
    unless form.is_a?(Form)
      add_error(:form, 'must be a Form instance')
      return
    end

    # Set user from form if not provided
    self.user = form.user if user.nil?
    
    unless user.is_a?(User)
      add_error(:user, 'must be a User instance')
    end
  end

  def perform_comprehensive_readiness_check
    readiness_results = {
      ready: true,
      errors: [],
      actions: [],
      checks_performed: [],
      form_id: form.id,
      user_id: user.id,
      checked_at: Time.current
    }

    # Perform all readiness checks
    check_payment_questions_presence(readiness_results)
    check_user_subscription_status(readiness_results)
    check_stripe_configuration(readiness_results)
    check_payment_questions_configuration(readiness_results)
    check_webhook_configuration(readiness_results)
    check_form_publish_eligibility(readiness_results)

    # Set overall readiness status
    readiness_results[:ready] = readiness_results[:errors].empty?

    # Generate recovery actions if not ready
    if readiness_results[:errors].any?
      generate_recovery_actions(readiness_results)
    end

    set_result(readiness_results)
    set_context(:checks_count, readiness_results[:checks_performed].length)
    set_context(:errors_count, readiness_results[:errors].length)
  end

  def check_payment_questions_presence(results)
    results[:checks_performed] << 'payment_questions_presence'

    return unless form.has_payment_questions?

    payment_questions_count = form.payment_questions.count
    
    if payment_questions_count.zero?
      # This shouldn't happen if has_payment_questions? is true, but defensive check
      results[:errors] << {
        type: 'no_payment_questions',
        severity: 'info',
        message: 'No payment questions detected in form'
      }
    else
      set_context(:payment_questions_count, payment_questions_count)
    end
  end

  def check_user_subscription_status(results)
    results[:checks_performed] << 'user_subscription_status'

    return unless form.has_payment_questions?

    unless user.premium?
      results[:errors] << {
        type: 'premium_subscription_required',
        severity: 'high',
        message: 'Premium subscription required for payment features',
        current_tier: user.subscription_tier,
        required_tier: 'premium'
      }
    end
  end

  def check_stripe_configuration(results)
    results[:checks_performed] << 'stripe_configuration'

    return unless form.has_payment_questions?

    stripe_status = StripeConfigurationChecker.configuration_status(user)
    
    unless stripe_status[:configured]
      results[:errors] << {
        type: 'stripe_not_configured',
        severity: 'high',
        message: 'Stripe configuration incomplete',
        missing_elements: stripe_status[:missing_elements] || [],
        configuration_url: '/stripe_settings'
      }
    end
  end

  def check_payment_questions_configuration(results)
    results[:checks_performed] << 'payment_questions_configuration'

    return unless form.has_payment_questions?

    form.payment_questions.each do |question|
      question_errors = validate_payment_question_configuration(question)
      
      question_errors.each do |error|
        results[:errors] << {
          type: 'payment_question_invalid',
          severity: 'high',
          message: "Payment question '#{question.title}' has configuration issues",
          question_id: question.id,
          question_title: question.title,
          validation_error: error
        }
      end
    end
  end

  def check_webhook_configuration(results)
    results[:checks_performed] << 'webhook_configuration'

    return unless form.has_payment_questions?

    # Check if webhooks are properly configured for payment processing
    webhook_status = check_stripe_webhooks

    unless webhook_status[:configured]
      results[:errors] << {
        type: 'webhook_configuration_incomplete',
        severity: 'medium',
        message: 'Webhook configuration incomplete for payment processing',
        issues: webhook_status[:issues] || [],
        setup_url: '/stripe_settings/webhooks'
      }
    end
  end

  def check_form_publish_eligibility(results)
    results[:checks_performed] << 'form_publish_eligibility'

    # Check if form meets basic publishing requirements
    if form.name.blank?
      results[:errors] << {
        type: 'form_name_missing',
        severity: 'high',
        message: 'Form name is required for publishing'
      }
    end

    if form.form_questions.empty?
      results[:errors] << {
        type: 'no_questions',
        severity: 'high',
        message: 'Form must have at least one question to be published'
      }
    end

    # Check if form is already published
    if form.published?
      results[:errors] << {
        type: 'already_published',
        severity: 'info',
        message: 'Form is already published'
      }
    end
  end

  def validate_payment_question_configuration(question)
    errors = []
    config = question.question_config || {}

    # Required fields for payment questions
    required_fields = %w[amount currency description]
    
    required_fields.each do |field|
      if config[field].blank?
        errors << "Missing required field: #{field}"
      end
    end

    # Validate amount format
    if config['amount'].present?
      begin
        amount = Float(config['amount'])
        if amount <= 0
          errors << "Amount must be greater than 0"
        end
      rescue ArgumentError
        errors << "Amount must be a valid number"
      end
    end

    # Validate currency format
    if config['currency'].present?
      unless config['currency'].match?(/\A[A-Z]{3}\z/)
        errors << "Currency must be a valid 3-letter ISO code (e.g., USD, EUR)"
      end
    end

    # Validate description length
    if config['description'].present? && config['description'].length > 500
      errors << "Description must be 500 characters or less"
    end

    errors
  end

  def check_stripe_webhooks
    # Basic webhook configuration check
    # This would be expanded with actual Stripe webhook validation
    {
      configured: user.stripe_webhook_secret.present?,
      issues: user.stripe_webhook_secret.present? ? [] : ['Webhook secret not configured']
    }
  end

  def generate_recovery_actions(results)
    # Group errors by type and generate appropriate actions
    error_types = results[:errors].map { |error| error[:type] }.uniq

    error_types.each do |error_type|
      action = case error_type
               when 'premium_subscription_required'
                 {
                   type: 'upgrade_subscription',
                   title: 'Upgrade to Premium',
                   description: 'Unlock payment features',
                   url: '/subscription_management',
                   priority: 'high'
                 }
               when 'stripe_not_configured'
                 {
                   type: 'configure_stripe',
                   title: 'Configure Stripe',
                   description: 'Set up payment processing',
                   url: '/stripe_settings',
                   priority: 'high'
                 }
               when 'payment_question_invalid'
                 {
                   type: 'fix_payment_questions',
                   title: 'Fix Payment Questions',
                   description: 'Complete payment question configuration',
                   url: "/forms/#{form.id}/edit",
                   priority: 'high'
                 }
               when 'webhook_configuration_incomplete'
                 {
                   type: 'configure_webhooks',
                   title: 'Configure Webhooks',
                   description: 'Set up payment notifications',
                   url: '/stripe_settings/webhooks',
                   priority: 'medium'
                 }
               when 'form_name_missing'
                 {
                   type: 'add_form_name',
                   title: 'Add Form Name',
                   description: 'Give your form a name',
                   url: "/forms/#{form.id}/edit",
                   priority: 'high'
                 }
               when 'no_questions'
                 {
                   type: 'add_questions',
                   title: 'Add Questions',
                   description: 'Add questions to your form',
                   url: "/forms/#{form.id}/edit",
                   priority: 'high'
                 }
               end

      results[:actions] << action if action
    end

    # Remove duplicate actions
    results[:actions].uniq! { |action| action[:type] }
  end
end