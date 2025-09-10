# frozen_string_literal: true

# Helper module for consistent payment error message formatting and display
module PaymentErrorHelper
  # Formats a PaymentValidationError for display in views
  def format_payment_error(error)
    return nil unless error.is_a?(PaymentValidationError)

    {
      type: error.error_type,
      message: error.message,
      description: error.user_guidance[:description],
      severity: error.user_guidance[:severity] || 'error',
      category: error.user_guidance[:category] || 'payment_setup',
      actionable: error.actionable?,
      primary_action: format_primary_action(error),
      additional_actions: format_additional_actions(error),
      help_available: help_available_for_error?(error.error_type)
    }
  end

  # Renders payment error flash message with appropriate styling
  def payment_error_flash(error, options = {})
    return nil unless error

    formatted_error = error.is_a?(PaymentValidationError) ? format_payment_error(error) : error
    
    render partial: 'shared/payment_error_flash', 
           locals: { 
             error: formatted_error.is_a?(Hash) ? OpenStruct.new(formatted_error) : error,
             **options 
           }
  end

  # Renders payment setup guidance component
  def payment_setup_guidance(error = nil, options = {})
    render partial: 'shared/payment_setup_guidance',
           locals: {
             error: error,
             show_actions: options.fetch(:show_actions, true),
             context: options.fetch(:context, 'general'),
             compact: options.fetch(:compact, false)
           }
  end

  # Renders payment setup required button
  def payment_setup_required_button(error = nil, options = {})
    render partial: 'shared/payment_setup_required_button',
           locals: {
             error: error,
             button_text: options.fetch(:button_text, 'Complete Setup to Publish'),
             button_class: options.fetch(:button_class, 'btn-primary'),
             show_icon: options.fetch(:show_icon, true)
           }
  end

  # Returns CSS classes for error severity
  def payment_error_severity_classes(severity)
    case severity.to_s
    when 'error'
      'bg-red-50 border-red-200 text-red-800'
    when 'warning'
      'bg-yellow-50 border-yellow-200 text-yellow-800'
    when 'info'
      'bg-blue-50 border-blue-200 text-blue-800'
    else
      'bg-gray-50 border-gray-200 text-gray-800'
    end
  end

  # Returns icon for error type
  def payment_error_icon(error_type)
    icons = {
      'stripe_not_configured' => 'credit-card',
      'premium_subscription_required' => 'star',
      'multiple_requirements_missing' => 'exclamation-triangle',
      'invalid_payment_configuration' => 'cog',
      'insufficient_permissions' => 'lock-closed'
    }
    
    icons[error_type.to_s] || 'exclamation-circle'
  end

  # Humanizes requirement names for display
  def humanize_payment_requirement(requirement)
    requirements_map = {
      'stripe_configuration' => 'Stripe Configuration',
      'stripe_config' => 'Stripe Setup',
      'premium_subscription' => 'Premium Subscription',
      'premium' => 'Premium Plan',
      'payment_setup' => 'Payment Setup',
      'payment_questions' => 'Payment Questions Setup',
      'webhook_configuration' => 'Webhook Configuration',
      'test_payment' => 'Payment Testing'
    }
    
    requirements_map[requirement.to_s] || requirement.to_s.humanize
  end

  # Returns estimated setup time for error type
  def estimated_setup_time(error_type)
    times = {
      'stripe_not_configured' => '5-10 minutes',
      'premium_subscription_required' => '2-3 minutes',
      'multiple_requirements_missing' => '10-15 minutes',
      'invalid_payment_configuration' => '3-5 minutes',
      'insufficient_permissions' => 'Contact support'
    }
    
    times[error_type.to_s] || 'Varies'
  end

  # Checks if contextual help is available for error type
  def help_available_for_error?(error_type)
    %w[
      stripe_not_configured
      premium_subscription_required
      multiple_requirements_missing
      invalid_payment_configuration
    ].include?(error_type.to_s)
  end

  # Returns help URL for error type
  def help_url_for_error(error_type)
    case error_type.to_s
    when 'stripe_not_configured'
      '/help/stripe-setup'
    when 'premium_subscription_required'
      '/help/premium-features'
    when 'multiple_requirements_missing'
      '/help/payment-setup-guide'
    when 'invalid_payment_configuration'
      '/help/payment-questions'
    else
      '/help/payment-setup'
    end
  end

  # Formats error for analytics tracking
  def payment_error_analytics_data(error)
    return {} unless error

    {
      error_type: error.error_type,
      error_category: error.user_guidance[:category],
      error_severity: error.user_guidance[:severity],
      has_actions: error.actionable?,
      action_count: error.required_actions.length,
      timestamp: Time.current.iso8601
    }
  end

  # Generates structured data for error recovery
  def payment_error_recovery_data(error, context = {})
    return {} unless error

    {
      error_type: error.error_type,
      recovery_available: true,
      estimated_time: estimated_setup_time(error.error_type),
      context: context,
      help_url: help_url_for_error(error.error_type),
      support_contact: 'support@agentform.com'
    }
  end

  # Renders error-specific educational content
  def payment_error_education(error_type)
    content = case error_type.to_s
    when 'stripe_not_configured'
      {
        title: 'About Stripe Integration',
        description: 'Stripe is a secure payment processor that handles all payment transactions for your forms.',
        benefits: [
          'PCI compliance and security handled automatically',
          'Support for 135+ currencies and multiple payment methods',
          'Detailed analytics and reporting',
          'Fraud protection and dispute management'
        ],
        setup_time: '5-10 minutes'
      }
    when 'premium_subscription_required'
      {
        title: 'Premium Features',
        description: 'Payment functionality is included in our Premium plans.',
        benefits: [
          'Unlimited payment forms and transactions',
          'Advanced analytics and reporting',
          'Custom branding and white-label options',
          'Priority support and onboarding assistance'
        ],
        setup_time: '2-3 minutes'
      }
    else
      {
        title: 'Payment Setup',
        description: 'Complete payment setup to unlock powerful form monetization features.',
        benefits: [
          'Accept payments directly through your forms',
          'Automated payment processing and notifications',
          'Secure, PCI-compliant payment handling',
          'Detailed payment analytics and reporting'
        ],
        setup_time: 'Varies'
      }
    end

    render partial: 'shared/payment_error_education', locals: { content: content }
  end

  private

  def format_primary_action(error)
    return nil unless error.primary_action_url.present?

    {
      text: error.primary_action_text || 'Take Action',
      url: error.primary_action_url,
      style: 'primary'
    }
  end

  def format_additional_actions(error)
    actions = []
    
    if help_available_for_error?(error.error_type)
      actions << {
        text: 'Get Help',
        action: 'show_help',
        style: 'secondary'
      }
    end
    
    if error.user_guidance[:missing_requirements].present?
      actions << {
        text: 'Setup Checklist',
        action: 'show_checklist',
        style: 'secondary'
      }
    end
    
    actions << {
      text: 'Contact Support',
      action: 'contact_support',
      style: 'secondary'
    }
    
    actions
  end
end