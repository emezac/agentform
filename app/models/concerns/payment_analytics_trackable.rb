# frozen_string_literal: true

module PaymentAnalyticsTrackable
  extend ActiveSupport::Concern

  private

  def track_payment_event(event_type, user:, context: {})
    # Add request context if available
    enhanced_context = context.merge(extract_request_context)
    
    PaymentAnalyticsService.new.track_event(
      event_type,
      user: user,
      context: enhanced_context
    )
  rescue StandardError => e
    Rails.logger.error "Failed to track payment event #{event_type}: #{e.message}"
    # Don't let analytics failures break the main flow
  end

  def extract_request_context
    return {} unless defined?(request) && request

    {
      session_id: session.id,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      referer: request.referer,
      controller: controller_name,
      action: action_name
    }
  rescue StandardError
    {}
  end
end