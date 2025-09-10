# frozen_string_literal: true

# Service for fallback payment validation when background jobs fail
# Provides synchronous validation as a backup to async job processing
class PaymentFallbackValidationService < ApplicationService
  def initialize(form:, user: nil)
    @form = form
    @user = user || form.user
    @validation_errors = []
    @required_actions = []
  end

  def call
    Rails.logger.info "Starting fallback payment validation for form #{@form.id}"
    
    begin
      validate_form_payment_requirements
      validate_user_payment_setup
      validate_payment_question_configuration
      
      if @validation_errors.any?
        create_validation_error
      else
        success_result
      end
    rescue StandardError => e
      Rails.logger.error "Fallback validation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Return a generic error if fallback validation itself fails
      error_result(
        message: 'Payment validation could not be completed',
        errors: ['validation_system_error'],
        actions: [{ type: 'contact_support', url: '/support', text: 'Contact Support' }]
      )
    end
  end

  private

  attr_reader :form, :user, :validation_errors, :required_actions

  def validate_form_payment_requirements
    return unless form_has_payment_questions?

    Rails.logger.debug "Form has payment questions, validating requirements"
    
    # Check if form is properly configured for payments
    unless form.payment_enabled?
      add_validation_error(
        type: 'payment_not_enabled',
        title: 'Payment functionality not enabled',
        description: 'Form contains payment questions but payment functionality is not enabled'
      )
    end

    # Validate payment question configuration
    validate_payment_questions_structure
  end

  def validate_user_payment_setup
    return unless form_has_payment_questions?

    Rails.logger.debug "Validating user payment setup"
    
    # Check Stripe configuration
    unless user_has_stripe_configured?
      add_validation_error(
        type: 'stripe_not_configured',
        title: 'Stripe configuration required',
        description: 'Stripe must be configured to process payments'
      )
      add_required_action('configure_stripe', '/stripe_settings', 'Configure Stripe')
    end

    # Check Premium subscription
    unless user_has_premium_access?
      add_validation_error(
        type: 'premium_subscription_required',
        title: 'Premium subscription required',
        description: 'Payment features require a Premium subscription'
      )
      add_required_action('upgrade_subscription', '/subscription_management', 'Upgrade to Premium')
    end
  end

  def validate_payment_question_configuration
    return unless form_has_payment_questions?

    Rails.logger.debug "Validating payment question configuration"
    
    payment_questions = form.form_questions.where(question_type: payment_question_types)
    
    payment_questions.each do |question|
      validate_individual_payment_question(question)
    end
  end

  def validate_individual_payment_question(question)
    question_config = question.configuration || {}
    
    # Validate required payment fields
    case question.question_type
    when 'payment'
      validate_payment_question_config(question, question_config)
    when 'subscription'
      validate_subscription_question_config(question, question_config)
    when 'donation'
      validate_donation_question_config(question, question_config)
    end
  end

  def validate_payment_question_config(question, config)
    if config['amount'].blank? && config['allow_custom_amount'] != true
      add_validation_error(
        type: 'payment_question_configuration',
        title: 'Payment amount not configured',
        description: "Payment question '#{question.title}' must have an amount or allow custom amounts"
      )
    end

    if config['currency'].blank?
      add_validation_error(
        type: 'payment_question_configuration',
        title: 'Payment currency not configured',
        description: "Payment question '#{question.title}' must specify a currency"
      )
    end
  end

  def validate_subscription_question_config(question, config)
    if config['plans'].blank? || !config['plans'].is_a?(Array) || config['plans'].empty?
      add_validation_error(
        type: 'payment_question_configuration',
        title: 'Subscription plans not configured',
        description: "Subscription question '#{question.title}' must have at least one plan configured"
      )
    end

    config['plans']&.each_with_index do |plan, index|
      if plan['amount'].blank? || plan['interval'].blank?
        add_validation_error(
          type: 'payment_question_configuration',
          title: 'Incomplete subscription plan',
          description: "Plan #{index + 1} in '#{question.title}' is missing amount or interval"
        )
      end
    end
  end

  def validate_donation_question_config(question, config)
    if config['suggested_amounts'].blank? && config['allow_custom_amount'] != true
      add_validation_error(
        type: 'payment_question_configuration',
        title: 'Donation amounts not configured',
        description: "Donation question '#{question.title}' must have suggested amounts or allow custom amounts"
      )
    end
  end

  def form_has_payment_questions?
    @form_has_payment_questions ||= form.form_questions.where(question_type: payment_question_types).exists?
  end

  def payment_question_types
    %w[payment subscription donation]
  end

  def user_has_stripe_configured?
    return false unless user.stripe_account_id.present?
    return false unless user.stripe_publishable_key.present?
    
    # Additional checks could be added here for webhook configuration, etc.
    true
  end

  def user_has_premium_access?
    user.premium? || user.subscription_tier == 'premium' || user.subscription_tier == 'pro'
  end

  def add_validation_error(type:, title:, description:)
    @validation_errors << {
      type: type,
      title: title,
      description: description
    }
  end

  def add_required_action(action_type, url, text)
    @required_actions << {
      type: action_type,
      url: url,
      text: text
    }
  end

  def create_validation_error
    primary_error = @validation_errors.first
    error_type = primary_error[:type]

    case error_type
    when 'stripe_not_configured'
      raise PaymentValidationErrors.stripe_not_configured(
        additional_actions: @required_actions.map { |a| a[:type] }
      )
    when 'premium_subscription_required'
      raise PaymentValidationErrors.premium_required(
        additional_actions: @required_actions.map { |a| a[:type] }
      )
    when 'payment_question_configuration'
      raise PaymentValidationErrors.invalid_payment_configuration(
        details: @validation_errors.map { |e| e[:description] },
        additional_actions: @required_actions.map { |a| a[:type] }
      )
    else
      # Multiple errors or unknown error type
      missing_requirements = @validation_errors.map { |e| e[:type] }.uniq
      raise PaymentValidationErrors.multiple_requirements(
        missing_requirements,
        additional_actions: @required_actions.map { |a| a[:type] }
      )
    end
  end

  def success_result
    success(
      message: 'Payment validation completed successfully',
      validation_status: 'passed',
      errors: [],
      actions: []
    )
  end

  def error_result(message:, errors:, actions:)
    error(
      message: message,
      validation_status: 'failed',
      errors: errors,
      actions: actions
    )
  end

  # Class method for quick validation check
  def self.validate_form_payment_setup(form)
    new(form: form).call
  end

  # Class method for validating multiple forms
  def self.validate_multiple_forms(forms)
    results = {}
    
    forms.each do |form|
      begin
        results[form.id] = validate_form_payment_setup(form)
      rescue PaymentValidationError => e
        results[form.id] = {
          success: false,
          error: e.to_hash,
          form_id: form.id
        }
      rescue StandardError => e
        Rails.logger.error "Unexpected error validating form #{form.id}: #{e.message}"
        results[form.id] = {
          success: false,
          error: {
            error_type: 'validation_system_error',
            message: 'Validation system error',
            required_actions: ['contact_support']
          },
          form_id: form.id
        }
      end
    end
    
    results
  end
end