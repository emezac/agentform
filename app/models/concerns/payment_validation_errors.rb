# frozen_string_literal: true

# Module containing predefined payment validation error types and responses
# Provides consistent error messaging and guidance across the application
module PaymentValidationErrors
  # Error type for missing Stripe configuration
  STRIPE_NOT_CONFIGURED = {
    type: 'stripe_not_configured',
    message: 'Stripe configuration required for payment questions',
    description: 'Your form contains payment questions but Stripe is not configured. Set up Stripe to accept payments.',
    action_url: '/stripe_settings',
    action_text: 'Configure Stripe',
    severity: 'error',
    category: 'payment_setup'
  }.freeze

  # Error type for missing Premium subscription
  PREMIUM_REQUIRED = {
    type: 'premium_subscription_required',
    message: 'Premium subscription required for payment features',
    description: 'Payment questions are a Premium feature. Upgrade your subscription to use payment functionality.',
    action_url: '/subscription_management',
    action_text: 'Upgrade to Premium',
    severity: 'error',
    category: 'subscription'
  }.freeze

  # Error type for multiple missing requirements
  MULTIPLE_REQUIREMENTS = {
    type: 'multiple_requirements_missing',
    message: 'Multiple setup steps required for payment features',
    description: 'Your form requires payment functionality, but several setup steps are incomplete.',
    action_url: '/payment_setup_guide',
    action_text: 'Complete Setup',
    severity: 'error',
    category: 'payment_setup'
  }.freeze

  # Error type for invalid payment question configuration
  INVALID_PAYMENT_CONFIGURATION = {
    type: 'invalid_payment_configuration',
    message: 'Payment questions are not properly configured',
    description: 'One or more payment questions in your form have invalid configuration.',
    action_url: nil,
    action_text: 'Review Questions',
    severity: 'warning',
    category: 'configuration'
  }.freeze

  # Error type for insufficient permissions
  INSUFFICIENT_PERMISSIONS = {
    type: 'insufficient_permissions',
    message: 'Insufficient permissions for payment features',
    description: 'Your account does not have the necessary permissions to use payment features.',
    action_url: '/profile',
    action_text: 'Contact Support',
    severity: 'error',
    category: 'permissions'
  }.freeze

  # All available error types
  ALL_ERROR_TYPES = [
    STRIPE_NOT_CONFIGURED,
    PREMIUM_REQUIRED,
    MULTIPLE_REQUIREMENTS,
    INVALID_PAYMENT_CONFIGURATION,
    INSUFFICIENT_PERMISSIONS
  ].freeze

  class << self
    # Creates a PaymentValidationError for Stripe not configured
    def stripe_not_configured(additional_actions: [])
      PaymentValidationError.new(
        error_type: STRIPE_NOT_CONFIGURED[:type],
        required_actions: ['configure_stripe'] + additional_actions,
        user_guidance: STRIPE_NOT_CONFIGURED
      )
    end

    # Creates a PaymentValidationError for Premium subscription required
    def premium_required(additional_actions: [])
      PaymentValidationError.new(
        error_type: PREMIUM_REQUIRED[:type],
        required_actions: ['upgrade_subscription'] + additional_actions,
        user_guidance: PREMIUM_REQUIRED
      )
    end

    # Creates a PaymentValidationError for multiple missing requirements
    def multiple_requirements(missing_requirements, additional_actions: [])
      actions = missing_requirements.map { |req| "complete_#{req}" } + additional_actions
      
      PaymentValidationError.new(
        error_type: MULTIPLE_REQUIREMENTS[:type],
        required_actions: actions,
        user_guidance: MULTIPLE_REQUIREMENTS.merge(
          missing_requirements: missing_requirements
        )
      )
    end

    # Creates a PaymentValidationError for invalid payment configuration
    def invalid_payment_configuration(details: nil, additional_actions: [])
      guidance = INVALID_PAYMENT_CONFIGURATION.dup
      guidance[:details] = details if details

      PaymentValidationError.new(
        error_type: INVALID_PAYMENT_CONFIGURATION[:type],
        required_actions: ['review_payment_questions'] + additional_actions,
        user_guidance: guidance
      )
    end

    # Creates a PaymentValidationError for insufficient permissions
    def insufficient_permissions(additional_actions: [])
      PaymentValidationError.new(
        error_type: INSUFFICIENT_PERMISSIONS[:type],
        required_actions: ['contact_support'] + additional_actions,
        user_guidance: INSUFFICIENT_PERMISSIONS
      )
    end

    # Creates a custom PaymentValidationError
    def custom_error(error_type:, message:, required_actions: [], **user_guidance_options)
      PaymentValidationError.new(
        error_type: error_type,
        required_actions: required_actions,
        user_guidance: {
          type: error_type,
          message: message
        }.merge(user_guidance_options)
      )
    end

    # Finds error definition by type
    def find_error_definition(error_type)
      ALL_ERROR_TYPES.find { |error| error[:type] == error_type.to_s }
    end

    # Returns all error types grouped by category
    def errors_by_category
      ALL_ERROR_TYPES.group_by { |error| error[:category] }
    end

    # Returns all error types with specific severity
    def errors_by_severity(severity)
      ALL_ERROR_TYPES.select { |error| error[:severity] == severity.to_s }
    end
  end
end