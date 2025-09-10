# frozen_string_literal: true

class PaymentAnalyticsService
  PAYMENT_EVENTS = %w[
    template_payment_interaction
    payment_setup_started
    payment_setup_completed
    payment_setup_abandoned
    payment_form_published
    payment_validation_errors
  ].freeze

  def track_event(event_type, user:, context: {})
    return { success: false, error: 'Invalid event type' } unless PAYMENT_EVENTS.include?(event_type.to_s)

    analytics_data = build_analytics_data(event_type, user, context)
    
    # Store in database for dashboard metrics
    PaymentAnalytic.create!(analytics_data)
    
    # Send to external analytics if configured
    send_to_external_analytics(event_type, analytics_data) if external_analytics_enabled?
    
    { success: true, data: analytics_data }
  rescue StandardError => e
    Rails.logger.error "PaymentAnalyticsService error: #{e.message}"
    { success: false, error: "Failed to track event: #{e.message}" }
  end

  def get_dashboard_metrics(date_range: 30.days.ago..Time.current)
    {
      setup_completion_rate: calculate_setup_completion_rate(date_range),
      common_failure_points: identify_common_failure_points(date_range),
      template_interaction_stats: calculate_template_interaction_stats(date_range),
      job_performance_metrics: calculate_job_performance_metrics(date_range),
      error_resolution_paths: analyze_error_resolution_paths(date_range)
    }
  end

  private

  def build_analytics_data(event_type, user, context)
    {
      event_type: event_type,
      user_id: user.id,
      user_subscription_tier: user.subscription_tier,
      timestamp: Time.current,
      context: sanitize_context(context) || {},
      session_id: context[:session_id],
      user_agent: context[:user_agent],
      ip_address: context[:ip_address]&.then { |ip| anonymize_ip(ip) }
    }
  end

  def sanitize_context(context)
    return {} if context.blank?
    
    # Remove sensitive information and limit context size
    sanitized = context.except(:password, :token, :api_key, :secret)
    json_string = sanitized.to_json.truncate(1000) # Limit context size
    JSON.parse(json_string) # Ensure valid JSON
  rescue JSON::ParserError, StandardError
    { error: 'Invalid context data' }
  end

  def anonymize_ip(ip_address)
    # Anonymize IP for privacy compliance
    IPAddr.new(ip_address).mask(24).to_s
  rescue IPAddr::InvalidAddressError
    'unknown'
  end

  def calculate_setup_completion_rate(date_range)
    started_count = PaymentAnalytic.where(
      event_type: 'payment_setup_started',
      timestamp: date_range
    ).count

    completed_count = PaymentAnalytic.where(
      event_type: 'payment_setup_completed',
      timestamp: date_range
    ).count

    return 0 if started_count.zero?
    
    (completed_count.to_f / started_count * 100).round(2)
  end

  def identify_common_failure_points(date_range)
    PaymentAnalytic.where(
      event_type: 'payment_validation_errors',
      timestamp: date_range
    ).group("context->>'error_type'")
     .count
     .sort_by { |_, count| -count }
     .first(5)
     .to_h
  end

  def calculate_template_interaction_stats(date_range)
    interactions = PaymentAnalytic.where(
      event_type: 'template_payment_interaction',
      timestamp: date_range
    )

    {
      total_interactions: interactions.count,
      unique_users: interactions.distinct.count(:user_id),
      templates_by_popularity: interactions.group("context->>'template_id'").count.sort_by { |_, count| -count }.first(10).to_h
    }
  end

  def calculate_job_performance_metrics(date_range)
    # This would integrate with Sidekiq metrics if available
    # For now, return placeholder structure
    {
      average_processing_time: 0,
      error_rate: 0,
      queue_depth: 0,
      retry_rate: 0
    }
  end

  def analyze_error_resolution_paths(date_range)
    error_events = PaymentAnalytic.where(
      event_type: 'payment_validation_errors',
      timestamp: date_range
    )

    resolution_stats = {}
    
    error_events.find_each do |error_event|
      error_type = error_event.context['error_type']
      resolution_path = error_event.context['resolution_path']
      
      resolution_stats[error_type] ||= {}
      resolution_stats[error_type][resolution_path] ||= 0
      resolution_stats[error_type][resolution_path] += 1
    end

    resolution_stats
  end

  def send_to_external_analytics(event_type, data)
    # Integration point for external analytics services
    # Could integrate with Google Analytics, Mixpanel, etc.
    Rails.logger.info "External analytics: #{event_type} - #{data}"
  end

  def external_analytics_enabled?
    Rails.application.credentials.dig(:analytics, :enabled) || false
  end
end