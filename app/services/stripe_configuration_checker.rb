# frozen_string_literal: true

class StripeConfigurationChecker
  # Check if user has complete Stripe configuration
  def self.configured?(user)
    return false unless user.is_a?(User)
    
    user.stripe_configured?
  end

  # Get detailed configuration status
  def self.configuration_status(user)
    return default_unconfigured_status unless user.is_a?(User)

    status = {
      configured: false,
      user_id: user.id,
      checked_at: Time.current,
      configuration_steps: {},
      missing_steps: [],
      overall_completion: 0
    }

    check_stripe_keys(user, status)
    check_stripe_account_status(user, status)
    check_webhook_configuration(user, status)
    check_payment_methods(user, status)

    calculate_completion_percentage(status)
    determine_overall_status(status)

    status
  end

  # Get specific missing configuration elements
  def self.missing_configuration_steps(user)
    return ['All Stripe configuration missing'] unless user.is_a?(User)

    status = configuration_status(user)
    status[:missing_steps]
  end

  # Check if user can accept live payments
  def self.can_accept_live_payments?(user)
    return false unless configured?(user)

    status = configuration_status(user)
    status[:configuration_steps][:stripe_keys] == 'complete' &&
      status[:configuration_steps][:account_status] == 'complete'
  end

  # Get configuration requirements for user
  def self.configuration_requirements(user)
    status = configuration_status(user)
    
    requirements = []
    
    status[:missing_steps].each do |step|
      requirement = case step
                   when 'stripe_keys'
                     stripe_keys_requirement
                   when 'account_verification'
                     account_verification_requirement
                   when 'webhook_setup'
                     webhook_setup_requirement
                   when 'payment_methods'
                     payment_methods_requirement
                   end
      
      requirements << requirement if requirement
    end

    requirements
  end

  # Validate Stripe API keys format
  def self.validate_stripe_keys(publishable_key, secret_key)
    errors = []

    if publishable_key.blank?
      errors << 'Publishable key is required'
    elsif !publishable_key.start_with?('pk_')
      errors << 'Publishable key must start with pk_'
    end

    if secret_key.blank?
      errors << 'Secret key is required'
    elsif !secret_key.start_with?('sk_')
      errors << 'Secret key must start with sk_'
    end

    # Check if keys are test or live
    test_mode = publishable_key&.include?('test') || secret_key&.include?('test')
    
    {
      valid: errors.empty?,
      errors: errors,
      test_mode: test_mode,
      live_mode: !test_mode && errors.empty?
    }
  end

  # Test Stripe connection
  def self.test_stripe_connection(user)
    return { success: false, error: 'User not configured for Stripe' } unless configured?(user)

    begin
      stripe_client = user.stripe_client
      return { success: false, error: 'Stripe client not available' } unless stripe_client

      # Test connection by retrieving account information
      account = stripe_client.accounts.retrieve
      
      {
        success: true,
        account_id: account.id,
        account_type: account.type,
        country: account.country,
        default_currency: account.default_currency,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        details_submitted: account.details_submitted
      }
    rescue Stripe::AuthenticationError => e
      { success: false, error: 'Invalid Stripe API keys', details: e.message }
    rescue Stripe::StripeError => e
      { success: false, error: 'Stripe API error', details: e.message }
    rescue StandardError => e
      { success: false, error: 'Connection test failed', details: e.message }
    end
  end

  private

  def self.default_unconfigured_status
    {
      configured: false,
      user_id: nil,
      checked_at: Time.current,
      configuration_steps: {},
      missing_steps: ['All configuration missing'],
      overall_completion: 0
    }
  end

  def self.check_stripe_keys(user, status)
    if user.stripe_publishable_key.present? && user.stripe_secret_key.present?
      # Validate key format
      validation = validate_stripe_keys(user.stripe_publishable_key, user.decrypt_stripe_secret_key)
      
      if validation[:valid]
        status[:configuration_steps][:stripe_keys] = 'complete'
      else
        status[:configuration_steps][:stripe_keys] = 'invalid'
        status[:missing_steps] << 'stripe_keys'
      end
    else
      status[:configuration_steps][:stripe_keys] = 'missing'
      status[:missing_steps] << 'stripe_keys'
    end
  end

  def self.check_stripe_account_status(user, status)
    if user.stripe_configured?
      connection_test = test_stripe_connection(user)
      
      if connection_test[:success]
        if connection_test[:charges_enabled] && connection_test[:details_submitted]
          status[:configuration_steps][:account_status] = 'complete'
        else
          status[:configuration_steps][:account_status] = 'incomplete'
          status[:missing_steps] << 'account_verification'
        end
      else
        status[:configuration_steps][:account_status] = 'error'
        status[:missing_steps] << 'account_verification'
      end
    else
      status[:configuration_steps][:account_status] = 'not_configured'
      status[:missing_steps] << 'account_verification'
    end
  end

  def self.check_webhook_configuration(user, status)
    if user.stripe_webhook_secret.present?
      status[:configuration_steps][:webhook_setup] = 'complete'
    else
      status[:configuration_steps][:webhook_setup] = 'missing'
      status[:missing_steps] << 'webhook_setup'
    end
  end

  def self.check_payment_methods(user, status)
    # For now, assume payment methods are configured if Stripe is set up
    # This could be expanded to check actual Stripe payment method configuration
    if user.stripe_configured?
      status[:configuration_steps][:payment_methods] = 'complete'
    else
      status[:configuration_steps][:payment_methods] = 'not_configured'
      status[:missing_steps] << 'payment_methods'
    end
  end

  def self.calculate_completion_percentage(status)
    total_steps = 4 # stripe_keys, account_status, webhook_setup, payment_methods
    completed_steps = status[:configuration_steps].count { |_, step_status| step_status == 'complete' }
    
    status[:overall_completion] = (completed_steps.to_f / total_steps * 100).round
  end

  def self.determine_overall_status(status)
    status[:configured] = status[:missing_steps].empty?
  end

  def self.stripe_keys_requirement
    {
      type: 'stripe_keys',
      title: 'Stripe API Keys',
      description: 'Configure your Stripe publishable and secret keys',
      action_url: '/stripe_settings',
      priority: 'high',
      estimated_time: '2-3 minutes'
    }
  end

  def self.account_verification_requirement
    {
      type: 'account_verification',
      title: 'Stripe Account Verification',
      description: 'Complete your Stripe account verification to accept payments',
      action_url: 'https://dashboard.stripe.com/account',
      external: true,
      priority: 'high',
      estimated_time: '10-15 minutes'
    }
  end

  def self.webhook_setup_requirement
    {
      type: 'webhook_setup',
      title: 'Webhook Configuration',
      description: 'Set up webhooks for payment status notifications',
      action_url: '/stripe_settings/webhooks',
      priority: 'medium',
      estimated_time: '3-5 minutes'
    }
  end

  def self.payment_methods_requirement
    {
      type: 'payment_methods',
      title: 'Payment Methods',
      description: 'Configure accepted payment methods in Stripe',
      action_url: 'https://dashboard.stripe.com/settings/payment_methods',
      external: true,
      priority: 'medium',
      estimated_time: '2-3 minutes'
    }
  end
end