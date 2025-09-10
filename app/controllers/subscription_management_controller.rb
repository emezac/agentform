class SubscriptionManagementController < ApplicationController
  before_action :authenticate_user!

  def show
    @subscription_service = SubscriptionManagementService.new(user: current_user)
    @subscription_details = @subscription_service.subscription_details
    @plans = SubscriptionManagementService.plans
  end

  def create
    @subscription_service = SubscriptionManagementService.new(user: current_user)
    
    result = @subscription_service.create_subscription(
      billing_cycle: params[:billing_cycle] || 'monthly',
      discount_code: params[:discount_code],
      success_url: subscription_success_url,
      cancel_url: subscription_management_url
    )

    if result.success?
      redirect_to result.data[:checkout_url], allow_other_host: true
    else
      redirect_to subscription_management_path, alert: result.error
    end
  end

  def cancel
    @subscription_service = SubscriptionManagementService.new(user: current_user)
    
    result = @subscription_service.cancel_subscription(
      at_period_end: params[:immediate] != 'true'
    )

    if result.success?
      redirect_to subscription_management_path, notice: result.data[:message]
    else
      redirect_to subscription_management_path, alert: result.error
    end
  end

  def reactivate
    @subscription_service = SubscriptionManagementService.new(user: current_user)
    
    result = @subscription_service.reactivate_subscription

    if result.success?
      redirect_to subscription_management_path, notice: result.data[:message]
    else
      redirect_to subscription_management_path, alert: result.error
    end
  end

  def update_payment_method
    @subscription_service = SubscriptionManagementService.new(user: current_user)
    
    result = @subscription_service.update_payment_method(
      success_url: payment_method_success_url,
      cancel_url: subscription_management_url
    )

    if result.success?
      redirect_to result.data[:checkout_url], allow_other_host: true
    else
      redirect_to subscription_management_path, alert: result.error
    end
  end

  def success
    flash[:notice] = 'Subscription updated successfully!'
    redirect_to subscription_management_path
  end

  def payment_method_success
    flash[:notice] = 'Payment method updated successfully!'
    redirect_to subscription_management_path
  end

  private

  def subscription_params
    params.permit(:billing_cycle, :immediate, :discount_code)
  end
end