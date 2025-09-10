# frozen_string_literal: true

# PaymentConfigurationService manages payment setup status for users
# 
# This service provides comprehensive tracking and management of user payment
# configuration status, including Stripe setup and Premium subscription status.
# It includes caching for performance and integrates with existing payment services.
#
# Usage:
#   service = PaymentConfigurationService.new(user: user)
#   service.call
#   status = service.result
#
# Class methods:
#   PaymentConfigurationService.get_setup_status(user) - Get cached or fresh status
#   PaymentConfigurationService.calculate_progress(user) - Get progress percentage
#   PaymentConfigurationService.setup_complete?(user) - Check if setup is complete
#   PaymentConfigurationService.invalidate_cache(user) - Clear cached status
#
class PaymentConfigurationService < ApplicationService
  attribute :user, default: nil
  attribute :force_refresh, default: false

  CACHE_EXPIRY = 5.minutes
  SETUP_STEPS = %w[stripe_configuration premium_subscription].freeze

  def call
    validate_service_inputs
    return self if failure?

    update_user_status
    self
  end

  # Update user's payment setup status
  def update_user_status
    status_data = calculate_setup_status
    
    # Cache the status for performance (always cache the result)
    cache_setup_status(status_data)
    
    # Update user's cached setup completion if it has changed
    update_user_completion_cache(status_data)
    
    set_result(status_data)
    set_context(:status_updated_at, Time.current)
    set_context(:cache_used, get_context(:cache_hit) || false)
  end

  # Get cached setup status or calculate fresh
  def self.get_setup_status(user, force_refresh: false)
    service = new(user: user, force_refresh: force_refresh)
    service.call
    service.success? ? service.result : nil
  end

  # Calculate setup progress percentage
  def self.calculate_progress(user)
    return 0 unless user.is_a?(User)
    
    completed_steps = 0
    completed_steps += 1 if user.stripe_configured?
    completed_steps += 1 if user.premium?
    
    (completed_steps.to_f / SETUP_STEPS.length * 100).round
  end

  # Get next required setup step
  def self.next_required_step(user)
    return nil unless user.is_a?(User)
    
    return 'stripe_configuration' unless user.stripe_configured?
    return 'premium_subscription' unless user.premium?
    
    nil # All steps completed
  end

  # Get all missing setup steps
  def self.missing_steps(user)
    return SETUP_STEPS.dup unless user.is_a?(User)
    
    missing = []
    missing << 'stripe_configuration' unless user.stripe_configured?
    missing << 'premium_subscription' unless user.premium?
    
    missing
  end

  # Check if setup is complete
  def self.setup_complete?(user)
    return false unless user.is_a?(User)
    
    user.stripe_configured? && user.premium?
  end

  # Get setup requirements with actions
  def self.setup_requirements(user)
    return [] unless user.is_a?(User)
    
    requirements = []
    
    unless user.stripe_configured?
      requirements << stripe_configuration_requirement
    end
    
    unless user.premium?
      requirements << premium_subscription_requirement
    end
    
    requirements
  end

  # Invalidate cached setup status
  def self.invalidate_cache(user)
    return unless user.is_a?(User)
    
    Rails.cache.delete(cache_key(user.id))
    Rails.logger.debug "Invalidated payment setup cache for user #{user.id}"
  end

  # Bulk update setup status for multiple users
  def self.bulk_update_status(user_ids)
    return { updated: 0, errors: [] } if user_ids.blank?
    
    updated_count = 0
    errors = []
    
    User.where(id: user_ids).find_each do |user|
      begin
        service = new(user: user, force_refresh: true)
        service.call
        
        if service.success?
          updated_count += 1
        else
          errors << { user_id: user.id, errors: service.errors.full_messages }
        end
      rescue StandardError => e
        errors << { user_id: user.id, error: e.message }
      end
    end
    
    {
      updated: updated_count,
      errors: errors,
      total_processed: user_ids.length
    }
  end

  # Update status when Stripe configuration changes
  def self.handle_stripe_configuration_change(user)
    return unless user.is_a?(User)
    
    invalidate_cache(user)
    
    # Update status in background to avoid blocking the request
    PaymentSetupValidationJob.perform_async(user.id) if defined?(PaymentSetupValidationJob)
    
    Rails.logger.info "Payment configuration status update triggered for user #{user.id}"
  end

  # Update status when subscription changes
  def self.handle_subscription_change(user)
    return unless user.is_a?(User)
    
    invalidate_cache(user)
    
    # Update status immediately for subscription changes as they affect access
    service = new(user: user, force_refresh: true)
    service.call
    
    Rails.logger.info "Subscription status updated for user #{user.id}: #{service.success? ? 'success' : 'failed'}"
    
    service.result
  end

  # Get setup status with detailed breakdown for admin/debugging
  def self.detailed_status(user)
    return nil unless user.is_a?(User)
    
    service = new(user: user, force_refresh: true)
    service.call
    
    return nil unless service.success?
    
    status = service.result.dup
    
    # Add additional debugging information
    status[:debug_info] = {
      service_version: '1.0.0',
      calculated_by: service.class.name,
      user_methods: {
        stripe_configured: user.stripe_configured?,
        premium: user.premium?,
        can_accept_payments: user.can_accept_payments?
      },
      cache_info: {
        cache_key: cache_key(user.id),
        cache_hit: service.get_context(:cache_hit),
        cached_until: service.get_context(:cached_until)
      }
    }
    
    status
  end

  private

  def validate_service_inputs
    validate_required_attributes(:user)
    
    unless user.is_a?(User)
      add_error(:user, 'must be a User instance')
    end
  end

  def calculate_setup_status
    # Check cache first unless force refresh
    if !force_refresh && (cached_status = get_cached_status)
      set_context(:cache_hit, true)
      return cached_status
    end
    
    set_context(:cache_hit, false)
    
    # Calculate fresh status
    status = {
      user_id: user.id,
      setup_complete: false,
      progress_percentage: 0,
      completed_steps: [],
      missing_steps: [],
      next_step: nil,
      requirements: [],
      stripe_status: {},
      subscription_status: {},
      calculated_at: Time.current,
      expires_at: CACHE_EXPIRY.from_now
    }
    
    # Check Stripe configuration
    check_stripe_configuration(status)
    
    # Check subscription status
    check_subscription_status(status)
    
    # Calculate overall progress
    calculate_overall_progress(status)
    
    # Determine next steps
    determine_next_steps(status)
    
    # Generate requirements
    generate_requirements(status)
    
    status
  end

  def check_stripe_configuration(status)
    begin
      stripe_configured = user.stripe_configured?
      
      status[:stripe_status] = {
        configured: stripe_configured,
        has_publishable_key: user.stripe_publishable_key.present?,
        has_secret_key: user.stripe_secret_key.present?,
        has_webhook_secret: user.stripe_webhook_secret.present?,
        can_accept_payments: user.can_accept_payments?
      }
      
      if stripe_configured
        status[:completed_steps] << 'stripe_configuration'
        
        # Get detailed Stripe status
        begin
          stripe_details = StripeConfigurationChecker.configuration_status(user)
          status[:stripe_status].merge!(stripe_details)
        rescue StandardError => e
          Rails.logger.warn "Failed to get detailed Stripe status: #{e.message}"
          # Continue with basic status
        end
      else
        status[:missing_steps] << 'stripe_configuration'
      end
    rescue StandardError => e
      add_error(:stripe_configuration, "Failed to check Stripe configuration: #{e.message}")
      status[:stripe_status] = { configured: false, error: e.message }
      status[:missing_steps] << 'stripe_configuration'
    end
  end

  def check_subscription_status(status)
    begin
      is_premium = user.premium?
      
      status[:subscription_status] = {
        is_premium: is_premium,
        subscription_tier: user.subscription_tier,
        subscription_active: user.subscription_active?,
        subscription_expires_at: user.subscription_expires_at,
        trial_active: user.trial_active?,
        trial_expired: user.trial_expired?
      }
      
      if is_premium
        status[:completed_steps] << 'premium_subscription'
      else
        status[:missing_steps] << 'premium_subscription'
      end
    rescue StandardError => e
      add_error(:subscription_status, "Failed to check subscription status: #{e.message}")
      status[:subscription_status] = { is_premium: false, error: e.message }
      status[:missing_steps] << 'premium_subscription'
    end
  end

  def calculate_overall_progress(status)
    completed_count = status[:completed_steps].length
    total_steps = SETUP_STEPS.length
    
    status[:progress_percentage] = (completed_count.to_f / total_steps * 100).round
    status[:setup_complete] = status[:missing_steps].empty?
  end

  def determine_next_steps(status)
    if status[:missing_steps].any?
      # Prioritize Stripe configuration first, then subscription
      if status[:missing_steps].include?('stripe_configuration')
        status[:next_step] = 'stripe_configuration'
      elsif status[:missing_steps].include?('premium_subscription')
        status[:next_step] = 'premium_subscription'
      end
    end
  end

  def generate_requirements(status)
    requirements = []
    
    status[:missing_steps].each do |step|
      case step
      when 'stripe_configuration'
        requirements << self.class.stripe_configuration_requirement
      when 'premium_subscription'
        requirements << self.class.premium_subscription_requirement
      end
    end
    
    status[:requirements] = requirements
  end

  def get_cached_status
    Rails.cache.read(self.class.cache_key(user.id))
  end

  def cache_setup_status(status_data)
    Rails.cache.write(
      self.class.cache_key(user.id),
      status_data,
      expires_in: CACHE_EXPIRY
    )
    
    set_context(:cached_until, status_data[:expires_at])
  end

  def update_user_completion_cache(status_data)
    begin
      current_percentage = user.calculate_setup_completion
      new_percentage = status_data[:progress_percentage]
      
      # Only update if percentage has changed to avoid unnecessary DB writes
      if current_percentage != new_percentage
        # We could add a cached_setup_completion field to users table in the future
        # For now, we rely on the calculate_setup_completion method
        set_context(:completion_changed, true)
        set_context(:old_completion, current_percentage)
        set_context(:new_completion, new_percentage)
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to update user completion cache: #{e.message}"
      # Don't fail the service for cache update issues
    end
  end

  def self.cache_key(user_id)
    "payment_setup_status:#{user_id}"
  end

  def self.stripe_configuration_requirement
    {
      type: 'stripe_configuration',
      title: 'Configure Stripe Payments',
      description: 'Set up your Stripe account to accept payments from your forms',
      action_url: '/stripe_settings',
      action_text: 'Configure Stripe',
      priority: 'high',
      estimated_time: '5-10 minutes',
      benefits: [
        'Accept credit card payments',
        'Secure payment processing',
        'Automatic payment notifications'
      ]
    }
  end

  def self.premium_subscription_requirement
    {
      type: 'premium_subscription',
      title: 'Upgrade to Premium',
      description: 'Unlock payment features and advanced form capabilities',
      action_url: '/subscription_management',
      action_text: 'Upgrade to Premium',
      priority: 'high',
      estimated_time: '2-3 minutes',
      benefits: [
        'Payment question types',
        'Advanced analytics',
        'Custom branding',
        'Priority support'
      ]
    }
  end
end