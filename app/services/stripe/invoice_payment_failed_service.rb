module Stripe
  class InvoicePaymentFailedService
    def initialize(event)
      @event = event
    end

    def call
      invoice = @event.data.object
      customer_id = invoice.customer
      
      user = User.find_by(stripe_customer_id: customer_id)
      unless user
        Rails.logger.error "Stripe Webhook: User not found with customer ID #{customer_id}"
        return
      end

      # Update subscription status to indicate payment issues
      user.update!(
        subscription_status: 'past_due'
      )

      # Log the failed payment
      Rails.logger.warn "Stripe Webhook: Payment failed for user #{user.email}, invoice #{invoice.id}"

      # Send payment failure notification email (optional)
      # UserMailer.payment_failed(user, invoice).deliver_later

      # If this is the final attempt, downgrade the user
      if invoice.attempt_count >= 3
        user.update!(
          subscription_status: 'canceled',
          subscription_tier: 'basic',
          subscription_expires_at: Time.current
        )
        
        Rails.logger.warn "Stripe Webhook: User #{user.email} downgraded due to failed payments"
        # UserMailer.subscription_canceled_due_to_payment_failure(user).deliver_later
      end

    rescue StandardError => e
      Rails.logger.error "Error processing invoice payment failed: #{e.message}"
    end
  end
end