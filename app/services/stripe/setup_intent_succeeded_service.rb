module Stripe
  class SetupIntentSucceededService
    def initialize(event)
      @event = event
    end

    def call
      setup_intent = @event.data.object
      customer_id = setup_intent.customer
      
      user = User.find_by(stripe_customer_id: customer_id)
      unless user
        Rails.logger.error "Stripe Webhook: User not found with customer ID #{customer_id}"
        return
      end

      Rails.logger.info "Stripe Webhook: Payment method updated for user #{user.email}"

      # Send payment method update confirmation email (optional)
      # UserMailer.payment_method_updated(user).deliver_later

    rescue StandardError => e
      Rails.logger.error "Error processing setup intent succeeded: #{e.message}"
    end
  end
end