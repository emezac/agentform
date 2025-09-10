# frozen_string_literal: true

class SubscriptionUpgradesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_trial_expired, only: [:new, :create]

  def new
    # Show upgrade form for users whose trial has expired
  end

  def create
    # Handle upgrade to premium subscription
    service = SubscriptionManagementService.new(user: current_user)
    
    result = service.create_subscription(
      billing_cycle: params[:billing_cycle] || 'monthly',
      discount_code: params[:discount_code],
      success_url: subscription_upgrade_success_url,
      cancel_url: subscription_upgrade_cancel_url
    )

    if result.success?
      redirect_to result.data[:checkout_url], allow_other_host: true
    else
      flash[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def success
    flash[:notice] = "¡Gracias por suscribirte! Tu cuenta premium está ahora activa."
    redirect_to root_path
  end

  def cancel
    flash[:alert] = "El proceso de pago fue cancelado. Puedes intentarlo de nuevo cuando gustes."
    redirect_to subscription_upgrade_path
  end

  private

  def ensure_trial_expired
    unless current_user.trial_expired? || current_user.subscription_status == 'expired'
      redirect_to root_path, notice: 'Tu período de prueba aún está activo.'
    end
  end
end