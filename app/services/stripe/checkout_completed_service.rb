# frozen_string_literal: true

module Stripe
  class CheckoutCompletedService
    def initialize(event)
      @event = event
    end

    def call
      session = @event.data.object
      user_id = session.metadata.user_id

      user = User.find_by(id: user_id)

      unless user
        Rails.logger.error "Stripe Webhook: User not found with ID #{user_id}"
        return
      end

      # Process discount usage if discount was applied
      process_discount_usage(session, user) if discount_applied?(session)

      # Update user to premium with active subscription (no trial in Stripe)
      user.update!(
        subscription_tier: 'premium',
        stripe_customer_id: session.customer,
        subscription_status: 'active'
      )

      # Confirm user so they can log in (if using Devise confirmable)
      user.confirm if user.respond_to?(:confirm)
      
      # Send premium welcome email
      UserMailer.premium_welcome(user).deliver_later

      Rails.logger.info "Stripe Webhook: User #{user.email} successfully upgraded to premium."
    end

    private

    def discount_applied?(session)
      session.metadata.discount_code.present?
    end

    def process_discount_usage(session, user)
      discount_code = DiscountCode.find_by(code: session.metadata.discount_code)
      
      unless discount_code
        Rails.logger.error "Stripe Webhook: Discount code '#{session.metadata.discount_code}' not found"
        return
      end

      # Prepare subscription details for usage recording
      subscription_details = {
        subscription_id: session.subscription,
        original_amount: session.metadata.original_amount.to_i,
        discount_amount: session.metadata.discount_amount.to_i,
        final_amount: session.metadata.final_amount.to_i
      }

      # Record discount usage
      discount_service = DiscountCodeService.new(user: user)
      discount_service.record_usage(discount_code, subscription_details)

      if discount_service.success?
        Rails.logger.info "Stripe Webhook: Discount usage recorded for user #{user.email} with code #{discount_code.code}"
      else
        Rails.logger.error "Stripe Webhook: Failed to record discount usage: #{discount_service.errors.full_messages.join(', ')}"
      end
    rescue StandardError => e
      Rails.logger.error "Stripe Webhook: Error processing discount usage: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end