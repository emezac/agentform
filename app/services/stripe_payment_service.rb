class StripePaymentService
  include ApplicationService

  def initialize(user:, form:, form_response:, payment_data:)
    @user = user
    @form = form
    @form_response = form_response
    @payment_data = payment_data
    @stripe_client = user.stripe_client
  end

  def call
    return failure('User does not have Stripe configured') unless @user.stripe_configured?
    return failure('User cannot accept payments') unless @user.can_accept_payments?
    return failure('Invalid payment data') unless valid_payment_data?

    begin
      create_payment_intent
    rescue Stripe::StripeError => e
      failure("Stripe error: #{e.message}")
    rescue StandardError => e
      failure("Payment processing error: #{e.message}")
    end
  end

  private

  def valid_payment_data?
    @payment_data[:amount].present? && 
    @payment_data[:amount].to_f > 0 &&
    @payment_data[:currency].present? &&
    @payment_data[:payment_method].present?
  end

  def create_payment_intent
    # Create payment intent with user's Stripe account
    payment_intent = @stripe_client.payment_intents.create(
      amount: amount_in_cents,
      currency: @payment_data[:currency].downcase,
      payment_method_types: [stripe_payment_method_type],
      metadata: payment_metadata,
      description: payment_description,
      receipt_email: @form_response.email_address,
      setup_future_usage: 'off_session' # For future payments if needed
    )

    # Create our payment transaction record
    transaction = create_payment_transaction(payment_intent)

    success(
      payment_intent: payment_intent,
      transaction: transaction,
      client_secret: payment_intent.client_secret
    )
  end

  def create_payment_transaction(payment_intent)
    PaymentTransaction.create!(
      user: @user,
      form: @form,
      form_response: @form_response,
      stripe_payment_intent_id: payment_intent.id,
      amount: @payment_data[:amount].to_f,
      currency: @payment_data[:currency].upcase,
      status: payment_intent.status,
      payment_method: @payment_data[:payment_method],
      metadata: {
        form_name: @form.name,
        form_response_id: @form_response.id,
        created_via: 'form_submission',
        stripe_payment_intent_id: payment_intent.id
      }
    )
  end

  def amount_in_cents
    (@payment_data[:amount].to_f * 100).to_i
  end

  def stripe_payment_method_type
    case @payment_data[:payment_method]
    when 'credit_card'
      'card'
    when 'apple_pay'
      'card' # Apple Pay uses card payment method type
    when 'google_pay'
      'card' # Google Pay uses card payment method type
    else
      'card'
    end
  end

  def payment_metadata
    {
      form_id: @form.id,
      form_name: @form.name,
      form_response_id: @form_response.id,
      user_id: @user.id,
      payment_source: 'agentform'
    }
  end

  def payment_description
    "Payment for #{@form.name} - AgentForm"
  end
end