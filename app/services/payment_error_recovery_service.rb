# frozen_string_literal: true

# Service for guiding users through payment error recovery workflows
# Provides step-by-step guidance to resolve payment setup issues
class PaymentErrorRecoveryService < ApplicationService
  def initialize(error:, user:, context: {})
    @error = error
    @user = user
    @context = context
    @recovery_steps = []
    @current_step = 0
  end

  def call
    Rails.logger.info "Starting payment error recovery for error type: #{@error.error_type}"
    
    begin
      generate_recovery_workflow
      track_recovery_initiation
      
      success(
        recovery_workflow: {
          error_type: @error.error_type,
          total_steps: @recovery_steps.length,
          current_step: @current_step,
          steps: @recovery_steps,
          estimated_time: calculate_estimated_time,
          completion_url: generate_completion_url
        }
      )
    rescue StandardError => e
      Rails.logger.error "Error recovery workflow generation failed: #{e.message}"
      error(message: 'Could not generate recovery workflow', details: e.message)
    end
  end

  def self.get_next_step(error_type:, user:, completed_steps: [])
    service = new(
      error: PaymentValidationErrors.find_error_definition(error_type) || { error_type: error_type },
      user: user
    )
    service.send(:generate_recovery_workflow)
    
    # Find the next incomplete step
    next_step = service.instance_variable_get(:@recovery_steps).find do |step|
      !completed_steps.include?(step[:id])
    end
    
    next_step
  end

  def self.mark_step_completed(error_type:, user:, step_id:)
    # Track step completion
    Rails.logger.info "Marking step #{step_id} as completed for user #{user.id}"
    
    # You could store this in Redis, database, or user session
    # For now, we'll just log it
    if defined?(Rails.cache)
      cache_key = "payment_recovery:#{user.id}:#{error_type}"
      completed_steps = Rails.cache.read(cache_key) || []
      completed_steps << step_id unless completed_steps.include?(step_id)
      Rails.cache.write(cache_key, completed_steps, expires_in: 1.hour)
    end
    
    true
  end

  private

  attr_reader :error, :user, :context, :recovery_steps, :current_step

  def generate_recovery_workflow
    case @error.error_type || @error[:error_type]
    when 'stripe_not_configured'
      generate_stripe_setup_workflow
    when 'premium_subscription_required'
      generate_subscription_upgrade_workflow
    when 'multiple_requirements_missing'
      generate_multiple_requirements_workflow
    when 'invalid_payment_configuration'
      generate_configuration_fix_workflow
    else
      generate_generic_recovery_workflow
    end
  end

  def generate_stripe_setup_workflow
    @recovery_steps = [
      {
        id: 'stripe_account_creation',
        title: 'Create or Connect Stripe Account',
        description: 'Set up your Stripe account to process payments securely',
        action_url: '/stripe_settings',
        action_text: 'Go to Stripe Settings',
        estimated_minutes: 3,
        requirements: [],
        validation_endpoint: '/api/v1/payment_setup/validate_stripe_account',
        help_content: {
          overview: 'Stripe is a secure payment processor that handles all payment transactions for your forms.',
          steps: [
            'Click "Go to Stripe Settings" below',
            'Choose to create a new Stripe account or connect an existing one',
            'Follow the Stripe onboarding process',
            'Complete your business information and bank account details'
          ],
          common_issues: [
            'Make sure to use the same email address for consistency',
            'Have your business tax ID and bank account information ready',
            'Stripe may require additional verification for some business types'
          ]
        }
      },
      {
        id: 'stripe_webhook_configuration',
        title: 'Configure Webhooks',
        description: 'Set up webhooks so your forms can receive payment notifications',
        action_url: '/stripe_settings/webhooks',
        action_text: 'Configure Webhooks',
        estimated_minutes: 2,
        requirements: ['stripe_account_creation'],
        validation_endpoint: '/api/v1/payment_setup/validate_webhooks',
        help_content: {
          overview: 'Webhooks allow your forms to automatically update when payments are processed.',
          steps: [
            'Go to webhook configuration',
            'Copy the provided webhook URL',
            'Add the webhook URL to your Stripe dashboard',
            'Select the required webhook events'
          ],
          common_issues: [
            'Webhook URL must be exactly as provided',
            'Make sure to select all required webhook events',
            'Test the webhook connection before proceeding'
          ]
        }
      },
      {
        id: 'stripe_test_payment',
        title: 'Test Payment Processing',
        description: 'Verify that payments are working correctly with a test transaction',
        action_url: '/stripe_settings/test',
        action_text: 'Run Test Payment',
        estimated_minutes: 2,
        requirements: ['stripe_account_creation', 'stripe_webhook_configuration'],
        validation_endpoint: '/api/v1/payment_setup/test_payment',
        help_content: {
          overview: 'Testing ensures your payment setup is working correctly before going live.',
          steps: [
            'Click "Run Test Payment"',
            'Use the provided test card numbers',
            'Verify the test payment completes successfully',
            'Check that webhook notifications are received'
          ],
          common_issues: [
            'Use only test card numbers provided by Stripe',
            'Make sure you\'re in test mode, not live mode',
            'Check webhook logs if test payments fail'
          ]
        }
      }
    ]
  end

  def generate_subscription_upgrade_workflow
    @recovery_steps = [
      {
        id: 'review_premium_features',
        title: 'Review Premium Features',
        description: 'Learn about the payment features included in Premium plans',
        action_url: '/subscription_management',
        action_text: 'View Premium Plans',
        estimated_minutes: 2,
        requirements: [],
        validation_endpoint: nil,
        help_content: {
          overview: 'Premium plans unlock payment functionality and other advanced features.',
          steps: [
            'Review the available Premium plan options',
            'Compare features and pricing',
            'Consider your expected form volume and needs',
            'Choose the plan that best fits your requirements'
          ],
          features: [
            'Unlimited payment forms and transactions',
            'Advanced analytics and reporting',
            'Custom branding and white-label options',
            'Priority support and onboarding assistance',
            'API access and integrations'
          ]
        }
      },
      {
        id: 'select_premium_plan',
        title: 'Select and Purchase Premium Plan',
        description: 'Choose your Premium plan and complete the upgrade process',
        action_url: '/subscription_management/upgrade',
        action_text: 'Upgrade Now',
        estimated_minutes: 3,
        requirements: ['review_premium_features'],
        validation_endpoint: '/api/v1/subscription/validate_premium_status',
        help_content: {
          overview: 'Upgrading to Premium immediately unlocks payment features for your account.',
          steps: [
            'Select your preferred Premium plan',
            'Enter your payment information',
            'Review and confirm your subscription',
            'Wait for confirmation of successful upgrade'
          ],
          common_issues: [
            'Make sure your payment method is valid and has sufficient funds',
            'Check that your billing information is accurate',
            'Contact support if the upgrade doesn\'t process immediately'
          ]
        }
      },
      {
        id: 'verify_premium_access',
        title: 'Verify Premium Access',
        description: 'Confirm that your Premium features are active and accessible',
        action_url: '/profile',
        action_text: 'Check Account Status',
        estimated_minutes: 1,
        requirements: ['select_premium_plan'],
        validation_endpoint: '/api/v1/subscription/validate_premium_access',
        help_content: {
          overview: 'Verification ensures your Premium features are properly activated.',
          steps: [
            'Go to your account profile',
            'Verify your subscription status shows as Premium',
            'Check that payment features are now available',
            'Test creating a form with payment questions'
          ],
          common_issues: [
            'Premium activation may take a few minutes',
            'Refresh your browser if features don\'t appear immediately',
            'Contact support if Premium features aren\'t available after 10 minutes'
          ]
        }
      }
    ]
  end

  def generate_multiple_requirements_workflow
    # Combine steps from multiple workflows based on missing requirements
    missing_requirements = @error.user_guidance&.dig(:missing_requirements) || []
    
    @recovery_steps = []
    
    if missing_requirements.include?('stripe_configuration') || missing_requirements.include?('stripe_config')
      generate_stripe_setup_workflow
      stripe_steps = @recovery_steps.dup
      @recovery_steps = []
    end
    
    if missing_requirements.include?('premium_subscription') || missing_requirements.include?('premium')
      generate_subscription_upgrade_workflow
      premium_steps = @recovery_steps.dup
      @recovery_steps = []
    end
    
    # Merge and sequence the steps appropriately
    @recovery_steps = []
    @recovery_steps.concat(premium_steps) if defined?(premium_steps)
    @recovery_steps.concat(stripe_steps) if defined?(stripe_steps)
    
    # Add a final verification step
    @recovery_steps << {
      id: 'final_verification',
      title: 'Final Setup Verification',
      description: 'Verify that all payment requirements are now satisfied',
      action_url: @context[:return_url] || '/forms',
      action_text: 'Return to Form',
      estimated_minutes: 1,
      requirements: @recovery_steps.map { |step| step[:id] },
      validation_endpoint: '/api/v1/payment_setup/validate_complete_setup',
      help_content: {
        overview: 'Final verification ensures all payment setup requirements are met.',
        steps: [
          'Return to your form',
          'Verify that payment questions are working',
          'Test the complete form flow',
          'Publish your form when ready'
        ]
      }
    }
  end

  def generate_configuration_fix_workflow
    @recovery_steps = [
      {
        id: 'review_payment_questions',
        title: 'Review Payment Question Configuration',
        description: 'Check and fix configuration issues with your payment questions',
        action_url: @context[:form_edit_url] || '/forms',
        action_text: 'Edit Form',
        estimated_minutes: 5,
        requirements: [],
        validation_endpoint: '/api/v1/forms/validate_payment_questions',
        help_content: {
          overview: 'Payment questions need proper configuration to work correctly.',
          steps: [
            'Go to your form editor',
            'Review each payment question',
            'Check that amounts and currencies are set',
            'Verify that all required fields are completed'
          ],
          common_issues: [
            'Missing payment amounts or currency settings',
            'Invalid currency codes (use ISO 4217 codes like USD, EUR)',
            'Subscription plans without proper interval settings',
            'Donation questions without suggested amounts'
          ]
        }
      },
      {
        id: 'test_payment_questions',
        title: 'Test Payment Questions',
        description: 'Preview and test your payment questions to ensure they work correctly',
        action_url: @context[:form_preview_url] || '/forms',
        action_text: 'Preview Form',
        estimated_minutes: 3,
        requirements: ['review_payment_questions'],
        validation_endpoint: '/api/v1/forms/test_payment_flow',
        help_content: {
          overview: 'Testing helps identify any remaining configuration issues.',
          steps: [
            'Use the form preview feature',
            'Go through the complete form flow',
            'Test each payment question type',
            'Verify that payment processing works correctly'
          ]
        }
      }
    ]
  end

  def generate_generic_recovery_workflow
    @recovery_steps = [
      {
        id: 'contact_support',
        title: 'Contact Support for Assistance',
        description: 'Get help from our support team to resolve this payment setup issue',
        action_url: '/support',
        action_text: 'Contact Support',
        estimated_minutes: 1,
        requirements: [],
        validation_endpoint: nil,
        help_content: {
          overview: 'Our support team can help resolve complex payment setup issues.',
          steps: [
            'Click "Contact Support" below',
            'Describe your payment setup issue',
            'Include your error type and any relevant details',
            'Wait for a response from our support team'
          ]
        }
      }
    ]
  end

  def calculate_estimated_time
    @recovery_steps.sum { |step| step[:estimated_minutes] || 0 }
  end

  def generate_completion_url
    @context[:return_url] || '/forms'
  end

  def track_recovery_initiation
    if defined?(Rails.cache)
      Rails.cache.write(
        "payment_recovery_started:#{@user.id}:#{@error.error_type}",
        {
          started_at: Time.current,
          error_type: @error.error_type,
          total_steps: @recovery_steps.length
        },
        expires_in: 1.hour
      )
    end

    if window_analytics_available?
      # This would be called from the frontend
      Rails.logger.info "Payment error recovery initiated for user #{@user.id}, error: #{@error.error_type}"
    end
  end

  def window_analytics_available?
    # This is a placeholder - in reality, analytics tracking would happen on the frontend
    false
  end
end