require 'ostruct'

class SubscriptionManagementService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :user
  attribute :plan_type, :string, default: 'premium'

  PLANS = {
    'premium' => {
      name: 'Premium',
      price_monthly: 2900, # $29.00 in cents
      price_yearly: 29000, # $290.00 in cents (2 months free)
      features: [
        'Unlimited forms and responses',
        'Payment processing via Stripe',
        'Advanced AI features',
        'Priority support',
        'Custom branding removal',
        'Advanced analytics'
      ]
    }
  }.freeze

  def self.plans
    PLANS
  end

  def initialize(attributes = {})
    super
    @stripe_client = Stripe::StripeClient.new
  end

  # Create a new subscription
  def create_subscription(billing_cycle: 'monthly', discount_code: nil, success_url:, cancel_url:)
    return failure('User is required') unless user.present?
    return failure('User already has active subscription') if user_has_active_subscription?

    begin
      # Validate and process discount code if provided
      discount_data = nil
      if discount_code.present?
        discount_result = validate_and_prepare_discount(discount_code, billing_cycle)
        return discount_result unless discount_result.success?
        discount_data = discount_result.data
      end

      # Create or retrieve Stripe customer
      customer = find_or_create_stripe_customer

      # Get the appropriate price ID
      price_id = get_price_id(billing_cycle)
      return failure('Invalid billing cycle') unless price_id

      # Create checkout session
      session = create_checkout_session(
        customer: customer,
        price_id: price_id,
        discount_data: discount_data,
        success_url: success_url,
        cancel_url: cancel_url
      )

      success(checkout_url: session.url, session_id: session.id, discount_applied: discount_data.present?)
    rescue Stripe::StripeError => e
      failure("Stripe error: #{e.message}")
    rescue StandardError => e
      failure("Unexpected error: #{e.message}")
    end
  end

  # Cancel subscription
  def cancel_subscription(at_period_end: true)
    return failure('User has no active subscription') unless user_has_active_subscription?

    begin
      subscription = get_user_stripe_subscription
      return failure('No Stripe subscription found') unless subscription

      if at_period_end
        # Cancel at period end (user keeps access until billing period ends)
        updated_subscription = @stripe_client.subscriptions.update(
          subscription.id,
          { cancel_at_period_end: true }
        )
        
        user.update!(
          subscription_status: 'canceling',
          subscription_expires_at: Time.at(updated_subscription.current_period_end)
        )
        
        success(message: 'Subscription will be canceled at the end of the billing period')
      else
        # Cancel immediately
        @stripe_client.subscriptions.cancel(subscription.id)
        
        user.update!(
          subscription_status: 'canceled',
          subscription_tier: 'basic',
          subscription_expires_at: Time.current
        )
        
        success(message: 'Subscription canceled immediately')
      end
    rescue Stripe::StripeError => e
      failure("Stripe error: #{e.message}")
    end
  end

  # Reactivate a canceled subscription
  def reactivate_subscription
    return failure('User has no subscription to reactivate') unless user.stripe_customer_id.present?

    begin
      subscription = get_user_stripe_subscription
      return failure('No subscription found') unless subscription

      if subscription.cancel_at_period_end
        # Remove the cancellation
        updated_subscription = @stripe_client.subscriptions.update(
          subscription.id,
          { cancel_at_period_end: false }
        )
        
        user.update!(
          subscription_status: 'active',
          subscription_expires_at: nil
        )
        
        success(message: 'Subscription reactivated successfully')
      else
        failure('Subscription is not scheduled for cancellation')
      end
    rescue Stripe::StripeError => e
      failure("Stripe error: #{e.message}")
    end
  end

  # Update payment method
  def update_payment_method(success_url:, cancel_url:)
    return failure('User has no active subscription') unless user_has_active_subscription?

    begin
      customer = @stripe_client.customers.retrieve(user.stripe_customer_id)
      
      session = @stripe_client.checkout.sessions.create({
        customer: customer.id,
        payment_method_types: ['card'],
        mode: 'setup',
        success_url: success_url,
        cancel_url: cancel_url,
      })

      success(checkout_url: session.url, session_id: session.id)
    rescue Stripe::StripeError => e
      failure("Stripe error: #{e.message}")
    end
  end

  # Get subscription details
  def subscription_details
    # If user doesn't have a Stripe customer ID, they might be a manually upgraded user
    unless user.stripe_customer_id.present?
      return user.premium? ? manual_subscription_details : {}
    end

    begin
      subscription = get_user_stripe_subscription
      return user.premium? ? manual_subscription_details : {} unless subscription

      {
        status: subscription.status,
        current_period_start: Time.at(subscription.current_period_start),
        current_period_end: Time.at(subscription.current_period_end),
        cancel_at_period_end: subscription.cancel_at_period_end,
        canceled_at: subscription.canceled_at ? Time.at(subscription.canceled_at) : nil,
        plan_name: subscription.items.data.first&.price&.nickname || 'Premium',
        amount: subscription.items.data.first&.price&.unit_amount,
        currency: subscription.items.data.first&.price&.currency&.upcase,
        interval: subscription.items.data.first&.price&.recurring&.interval,
        source: 'stripe'
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to get subscription details: #{e.message}"
      user.premium? ? manual_subscription_details : {}
    end
  end

  # Check if user has active subscription
  def user_has_active_subscription?
    # Simply check if user is premium - this covers both Stripe subscriptions and manual upgrades
    user.present? && user.premium?
  end

  private

  def manual_subscription_details
    {
      status: 'active',
      plan_name: 'Premium (Complimentary)',
      amount: 0,
      currency: 'USD',
      interval: 'month',
      source: 'manual'
    }
  end

  def find_or_create_stripe_customer
    if user.stripe_customer_id.present?
      @stripe_client.customers.retrieve(user.stripe_customer_id)
    else
      customer = @stripe_client.customers.create({
        email: user.email,
        name: user.full_name,
        metadata: {
          user_id: user.id,
          app: 'AgentForm'
        }
      })
      
      user.update!(stripe_customer_id: customer.id)
      customer
    end
  end

  def get_price_id(billing_cycle)
    case billing_cycle
    when 'monthly'
      Rails.application.credentials.stripe[:premium_monthly_price_id]
    when 'yearly'
      Rails.application.credentials.stripe[:premium_yearly_price_id]
    else
      nil
    end
  end

  def validate_and_prepare_discount(discount_code, billing_cycle)
    # Use DiscountCodeService to validate the code
    discount_service = DiscountCodeService.new(user: user, code: discount_code)
    discount_service.validate_code
    
    unless discount_service.success?
      return failure(discount_service.errors.full_messages.first || 'Invalid discount code')
    end
    
    discount_code_obj = discount_service.result[:discount_code]
    
    # Calculate discount for the billing cycle
    original_amount = get_plan_amount(billing_cycle)
    discount_calculation = discount_service.calculate_discount(discount_code_obj, original_amount)
    
    success({
      discount_code: discount_code_obj,
      calculation: discount_calculation
    })
  end

  def get_plan_amount(billing_cycle)
    case billing_cycle
    when 'yearly'
      PLANS['premium'][:price_yearly]
    else
      PLANS['premium'][:price_monthly]
    end
  end

  def create_checkout_session(customer:, price_id:, discount_data: nil, success_url:, cancel_url:)
    session_params = {
      customer: customer.id,
      payment_method_types: ['card'],
      line_items: [{
        price: price_id,
        quantity: 1,
      }],
      mode: 'subscription',
      success_url: success_url,
      cancel_url: cancel_url,
      allow_promotion_codes: true,
      billing_address_collection: 'required',
      metadata: {
        user_id: user.id,
        plan_type: plan_type
      }
    }
    
    # Add discount information to metadata if present
    if discount_data
      session_params[:metadata][:discount_code] = discount_data[:discount_code].code
      session_params[:metadata][:discount_percentage] = discount_data[:discount_code].discount_percentage
      session_params[:metadata][:original_amount] = discount_data[:calculation][:original_amount]
      session_params[:metadata][:discount_amount] = discount_data[:calculation][:discount_amount]
      session_params[:metadata][:final_amount] = discount_data[:calculation][:final_amount]
      
      # Apply discount as a Stripe coupon (we'll create this dynamically)
      coupon_id = create_or_get_stripe_coupon(discount_data[:discount_code])
      if coupon_id
        session_params[:discounts] = [{ coupon: coupon_id }]
      end
    end
    
    @stripe_client.checkout.sessions.create(session_params)
  end

  def create_or_get_stripe_coupon(discount_code)
    # Create a unique coupon ID based on the discount code
    coupon_id = "discount_#{discount_code.code.downcase}_#{discount_code.discount_percentage}pct"
    
    begin
      # Try to retrieve existing coupon
      @stripe_client.coupons.retrieve(coupon_id)
      coupon_id
    rescue Stripe::InvalidRequestError
      # Coupon doesn't exist, create it
      begin
        @stripe_client.coupons.create({
          id: coupon_id,
          percent_off: discount_code.discount_percentage,
          duration: 'once', # Apply only to first payment
          name: "#{discount_code.discount_percentage}% off (#{discount_code.code})",
          metadata: {
            discount_code_id: discount_code.id,
            created_by: 'agentform_system'
          }
        })
        coupon_id
      rescue Stripe::StripeError => e
        Rails.logger.error "Failed to create Stripe coupon: #{e.message}"
        nil
      end
    end
  end

  def get_user_stripe_subscription
    return nil unless user.stripe_customer_id.present?

    subscriptions = @stripe_client.subscriptions.list({
      customer: user.stripe_customer_id,
      status: 'all',
      limit: 1
    })

    subscriptions.data.first
  end

  def success(data = {})
    OpenStruct.new(success?: true, data: data, error: nil)
  end

  def failure(error_message)
    OpenStruct.new(success?: false, data: {}, error: error_message)
  end
end