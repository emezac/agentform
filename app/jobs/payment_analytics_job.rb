# frozen_string_literal: true

class PaymentAnalyticsJob < ApplicationJob
  queue_as :analytics
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(event_type, user_id, context = {})
    user = User.find(user_id)
    
    PaymentAnalyticsService.new.track_event(
      event_type,
      user: user,
      context: context
    )
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "PaymentAnalyticsJob: User not found - #{e.message}"
    # Don't retry if user doesn't exist
  rescue StandardError => e
    Rails.logger.error "PaymentAnalyticsJob failed: #{e.message}"
    raise # This will trigger retry
  end
end