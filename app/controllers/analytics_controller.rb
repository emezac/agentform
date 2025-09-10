class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  
  # Skip Pundit authorization for this controller
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # POST /analytics/payment_setup
  def payment_setup
    event_data = params.require(:event).permit(
      :has_payment_questions,
      :stripe_configured,
      :is_premium,
      :event_type,
      :timestamp,
      :action,
      required_features: []
    )

    # Log the event (in a real app, this would go to an analytics service)
    Rails.logger.info "Payment Setup Event: #{event_data.to_h}"

    # You could also store this in a database table for analytics
    # AnalyticsEvent.create!(
    #   user: current_user,
    #   event_type: 'payment_setup_interaction',
    #   event_data: event_data.to_h
    # )

    render json: { success: true }
  rescue ActionController::ParameterMissing => e
    render json: {
      success: false,
      error: "Missing required parameter: #{e.param}"
    }, status: :bad_request
  rescue StandardError => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  # POST /analytics/payment_errors
  def payment_errors
    event_data = params.require(:event).permit(
      :error_type,
      :event_type,
      :timestamp,
      :action,
      required_actions: []
    )

    # Log the error event
    Rails.logger.info "Payment Error Event: #{event_data.to_h}"

    render json: { success: true }
  rescue ActionController::ParameterMissing => e
    render json: {
      success: false,
      error: "Missing required parameter: #{e.param}"
    }, status: :bad_request
  rescue StandardError => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end
end