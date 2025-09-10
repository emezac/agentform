module Stripe
  class InvoicePaymentSucceededService
    def initialize(event)
      @event = event
    end

    def call
      invoice = @event.data.object
      customer_id = invoice.customer
      subscription_id = invoice.subscription

      user = User.find_by(stripe_customer_id: customer_id)
      unless user
        Rails.logger.error "Stripe Webhook: User not found with customer ID #{customer_id}"
        return
      end

      # Get subscription details from Stripe
      subscription = ::Stripe::Subscription.retrieve(subscription_id)
      
      # Update user subscription status
      user.update!(
        subscription_status: 'active',
        subscription_tier: 'premium',
        subscription_expires_at: Time.at(subscription.current_period_end)
      )

      # Log successful renewal
      Rails.logger.info "Stripe Webhook: Subscription renewed for user #{user.email}"

      # Send renewal confirmation email (optional)
      # UserMailer.subscription_renewed(user).deliver_later

    rescue ::Stripe::StripeError => e
      Rails.logger.error "Stripe API error in invoice payment succeeded: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Error processing invoice payment succeeded: #{e.message}"
    end
  end
end