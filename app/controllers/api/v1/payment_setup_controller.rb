class Api::V1::PaymentSetupController < Api::BaseController
  before_action :authenticate_user!

  # GET /api/v1/payment_setup/status
  def status
    setup_status = {
      stripe_configured: current_user.stripe_configured?,
      premium_subscription: current_user.premium?,
      can_accept_payments: current_user.stripe_configured? && current_user.premium?,
      setup_completion_percentage: calculate_setup_completion
    }

    render json: {
      success: true,
      setup_status: setup_status
    }
  rescue StandardError => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  private

  def calculate_setup_completion
    total_steps = 2 # Stripe + Premium
    completed_steps = 0
    completed_steps += 1 if current_user.stripe_configured?
    completed_steps += 1 if current_user.premium?
    (completed_steps.to_f / total_steps * 100).round
  end
end