# frozen_string_literal: true

# Controller concern for handling PaymentValidationError exceptions
# Provides consistent error responses and user guidance across controllers
module PaymentErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from PaymentValidationError, with: :handle_payment_validation_error
  end

  private

  # Handles PaymentValidationError exceptions with appropriate responses
  def handle_payment_validation_error(error)
    Rails.logger.warn "Payment validation error: #{error.message}"
    Rails.logger.warn "Error details: #{error.to_hash}"

    respond_to do |format|
      format.html { handle_payment_error_html(error) }
      format.json { handle_payment_error_json(error) }
      format.turbo_stream { handle_payment_error_turbo_stream(error) }
    end
  end

  # Handles HTML responses for payment validation errors
  def handle_payment_error_html(error)
    flash[:error] = error.message
    flash[:payment_error] = error.to_hash

    # Redirect to appropriate setup page if action URL is available
    if error.primary_action_url.present?
      redirect_to error.primary_action_url, 
                  notice: "#{error.message} Click here to complete setup."
    else
      redirect_back(fallback_location: root_path)
    end
  end

  # Handles JSON responses for payment validation errors
  def handle_payment_error_json(error)
    render json: {
      success: false,
      error: error.to_hash,
      status: 'payment_validation_failed'
    }, status: :unprocessable_entity
  end

  # Handles Turbo Stream responses for payment validation errors
  def handle_payment_error_turbo_stream(error)
    render turbo_stream: [
      turbo_stream.replace('flash-messages', 
        partial: 'shared/payment_error_flash', 
        locals: { error: error }
      ),
      turbo_stream.update('form-publish-button', 
        partial: 'shared/payment_setup_required_button',
        locals: { error: error }
      )
    ]
  end

  # Checks if the current request is for payment-related functionality
  def payment_related_request?
    params[:controller]&.include?('payment') || 
    params[:action]&.include?('payment') ||
    request.path.include?('payment')
  end

  # Adds payment error context to flash messages
  def add_payment_error_context(error)
    flash[:payment_error_context] = {
      error_type: error.error_type,
      required_actions: error.required_actions,
      action_url: error.primary_action_url,
      action_text: error.primary_action_text
    }
  end

  # Renders payment setup guidance partial
  def render_payment_setup_guidance(error)
    render partial: 'shared/payment_setup_guidance', 
           locals: { 
             error: error,
             show_actions: true,
             context: controller_name
           }
  end
end