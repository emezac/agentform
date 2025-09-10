module Stripe
  class SubscriptionUpdatedService
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

      # Determine the appropriate status based on subscription state
      status = determine_subscription_status(subscription)
      
      # Update user subscription details
      user.update!(
        subscription_status: status,
        subscription_expires_at: subscription.cancel_at_period_end ? 
          Time.at(subscription.current_period_end) : nil
      )

      # Log the update
      Rails.logger.info "Stripe Webhook: Subscription updated for user #{user.email}, status: #{status}"

      # Send appropriate notification based on the change
      if subscription.cancel_at_period_end && status == 'canceling'
        # UserMailer.subscription_will_cancel(user, Time.at(subscription.current_period_end)).deliver_later
      elsif !subscription.cancel_at_period_end && user.subscription_status_was == 'canceling'
        # UserMailer.subscription_reactivated(user).deliver_later
      end

    rescue StandardError => e
      Rails.logger.error "Error processing subscription update: #{e.message}"
    end

    private

    def determine_subscription_status(subscription)
      case subscription.status
      when 'active'
        subscription.cancel_at_period_end ? 'canceling' : 'active'
      when 'trialing'
        'trialing'
      when 'past_due'
        'past_due'
      when 'canceled'
        'canceled'
      when 'unpaid'
        'past_due'
      else
        subscription.status
      end
    end
  end
end