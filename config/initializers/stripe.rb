# frozen_string_literal: true

# Configura la clave secreta de la API de Stripe
if Rails.application.credentials.stripe.present?
  Stripe.api_key = Rails.application.credentials.stripe[:secret_key]
  
  # Configura el "signing secret" para verificar la autenticidad de los webhooks
  # Esto es manejado por la gema stripe_event
  StripeEvent.signing_secret = Rails.application.credentials.stripe[:webhook_secret]
elsif Rails.env.test?
  # Use test keys for testing environment
  Stripe.api_key = 'sk_test_fake_key_for_testing'
  StripeEvent.signing_secret = 'whsec_fake_secret_for_testing'
end

# Configure webhook event handlers
StripeEvent.configure do |events|
  # Handle successful subscription creation
  events.subscribe 'checkout.session.completed' do |event|
    Stripe::CheckoutCompletedService.new(event).call
  end

  # Handle subscription updates (renewals, plan changes)
  events.subscribe 'invoice.payment_succeeded' do |event|
    Stripe::InvoicePaymentSucceededService.new(event).call
  end

  # Handle failed payments
  events.subscribe 'invoice.payment_failed' do |event|
    Stripe::InvoicePaymentFailedService.new(event).call
  end

  # Handle subscription cancellations
  events.subscribe 'customer.subscription.deleted' do |event|
    Stripe::SubscriptionDeletedService.new(event).call
  end

  # Handle subscription updates (cancellation scheduled, reactivated)
  events.subscribe 'customer.subscription.updated' do |event|
    Stripe::SubscriptionUpdatedService.new(event).call
  end

  # Handle setup intent completion (payment method updates)
  events.subscribe 'setup_intent.succeeded' do |event|
    Stripe::SetupIntentSucceededService.new(event).call
  end
end