# frozen_string_literal: true

class PaymentSetupValidationService < ApplicationService
  include PaymentAnalyticsTrackable
  
  attribute :user, default: nil
  attribute :required_features, default: -> { [] }
  attribute :track_analytics, default: true

  def call
    validate_service_inputs
    return self if failure?

    validate_user_requirements
    track_setup_events if track_analytics
    self
  end

  private

  def validate_service_inputs
    validate_required_attributes(:user)
    
    unless user.is_a?(User)
      add_error(:user, 'must be a User instance')
    end

    unless required_features.is_a?(Array)
      add_error(:required_features, 'must be an array')
    end
  end

  def validate_user_requirements
    validation_results = {
      valid: true,
      missing_requirements: [],
      setup_actions: [],
      user_id: user.id,
      validated_at: Time.current
    }

    # Check each required feature
    required_features.each do |feature|
      case feature
      when 'stripe_payments'
        validate_stripe_configuration(validation_results)
      when 'premium_subscription'
        validate_subscription_level(validation_results)
      when 'subscription_management'
        validate_subscription_management(validation_results)
      when 'webhook_configuration'
        validate_webhook_configuration(validation_results)
      end
    end

    # Generate setup actions for missing requirements
    generate_setup_actions(validation_results)

    # Set overall validity
    validation_results[:valid] = validation_results[:missing_requirements].empty?

    set_result(validation_results)
    set_context(:features_validated, required_features.length)
    set_context(:requirements_missing, validation_results[:missing_requirements].length)
  end

  def validate_stripe_configuration(validation_results)
    unless user.stripe_configured?
      validation_results[:missing_requirements] << {
        type: 'stripe_configuration',
        title: 'Stripe Configuration Required',
        description: 'Configure Stripe to accept payments',
        details: ['Stripe keys not configured'],
        priority: 'high'
      }
    end
  end

  def validate_subscription_level(validation_results)
    unless user.premium?
      validation_results[:missing_requirements] << {
        type: 'premium_subscription',
        title: 'Premium Subscription Required',
        description: 'Upgrade to Premium to use payment features',
        current_tier: user.subscription_tier,
        required_tier: 'premium',
        priority: 'high'
      }
    end
  end

  def validate_subscription_management(validation_results)
    # Check if user has subscription management capabilities
    unless user.premium? && user.stripe_configured?
      validation_results[:missing_requirements] << {
        type: 'subscription_management',
        title: 'Subscription Management Setup',
        description: 'Configure recurring payment and subscription settings',
        dependencies: ['premium_subscription', 'stripe_configuration'],
        priority: 'medium'
      }
    end
  end

  def validate_webhook_configuration(validation_results)
    # Check webhook configuration - required regardless of current Stripe status
    webhook_status = check_webhook_configuration
    
    unless webhook_status[:configured]
      validation_results[:missing_requirements] << {
        type: 'webhook_configuration',
        title: 'Webhook Configuration',
        description: 'Configure webhooks for payment status updates',
        details: webhook_status[:issues],
        priority: 'medium'
      }
    end
  end

  def generate_setup_actions(validation_results)
    validation_results[:missing_requirements].each do |requirement|
      action = case requirement[:type]
               when 'stripe_configuration'
                 generate_stripe_setup_action
               when 'premium_subscription'
                 generate_subscription_upgrade_action
               when 'subscription_management'
                 generate_subscription_management_action
               when 'webhook_configuration'
                 generate_webhook_setup_action
               end
      
      validation_results[:setup_actions] << action if action
    end
  end

  def generate_stripe_setup_action
    {
      type: 'stripe_setup',
      title: 'Configure Stripe Payments',
      description: 'Set up your Stripe account to accept payments',
      action_url: '/stripe_settings',
      action_text: 'Configure Stripe',
      estimated_time: '5-10 minutes',
      priority: 'high'
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
      priority: 'high'
    }
  end

  def generate_subscription_management_action
    {
      type: 'subscription_management_setup',
      title: 'Configure Subscription Management',
      description: 'Set up recurring payment and subscription options',
      action_url: '/subscription_management/setup',
      action_text: 'Configure Subscriptions',
      estimated_time: '3-5 minutes',
      priority: 'medium',
      dependencies: ['stripe_setup', 'subscription_upgrade']
    }
  end

  def generate_webhook_setup_action
    {
      type: 'webhook_setup',
      title: 'Configure Payment Webhooks',
      description: 'Set up webhooks for real-time payment notifications',
      action_url: '/stripe_settings/webhooks',
      action_text: 'Configure Webhooks',
      estimated_time: '2-3 minutes',
      priority: 'medium'
    }
  end

  def check_webhook_configuration
    # Basic webhook configuration check
    # This would be expanded with actual Stripe webhook validation
    {
      configured: user.stripe_webhook_secret.present?,
      issues: user.stripe_webhook_secret.present? ? [] : ['Webhook secret not configured']
    }
  end

  def track_setup_events
    validation_result = result
    
    if validation_result[:valid]
      track_payment_event(
        'payment_setup_completed',
        user: user,
        context: {
          required_features: required_features,
          setup_completion_time: Time.current,
          features_validated: required_features.length
        }
      )
    elsif validation_result[:missing_requirements].any?
      track_payment_event(
        'payment_setup_started',
        user: user,
        context: {
          required_features: required_features,
          missing_requirements: validation_result[:missing_requirements].map { |req| req[:type] },
          setup_actions_count: validation_result[:setup_actions].length
        }
      )
    end
  end
end