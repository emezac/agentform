module Stripe
  class SubscriptionDeletedService
    def initialize(event)
      @event = event
    end

    def call
      subscription = @event.data.object
      customer_id = subscription.customer
      
      user = User.find_by(stripe_customer_id: customer_id)
      unless user
        Rails.logger.error "Stripe Webhook: User not found with customer ID #{customer_id}"
        return
      end

      # Update user to reflect canceled subscription
      user.update!(
        subscription_status: 'canceled',
        subscription_tier: 'basic',
        subscription_expires_at: Time.current
      )

      Rails.logger.info "Stripe Webhook: Subscription canceled for user #{user.email}"

      # Send cancellation confirmation email (optional)
      # UserMailer.subscription_canceled(user).deliver_later

    rescue StandardError => e
      Rails.logger.error "Error processing subscription deletion: #{e.message}"
    end
  end
end