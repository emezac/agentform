class StripeSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_premium_user

  def show
    authorize current_user, :update?
    @stripe_configured = current_user.stripe_configured?
    @test_mode = current_user.stripe_publishable_key&.start_with?('pk_test_')
  end

  def update
    authorize current_user, :update?
    if current_user.update(stripe_params)
      # Encrypt sensitive keys before saving
      current_user.encrypt_stripe_keys!
      current_user.save!
      
      redirect_to stripe_settings_path, notice: 'Stripe settings updated successfully!'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def test_connection
    authorize current_user, :update?
    unless current_user.stripe_configured?
      render json: { success: false, error: 'Stripe not configured' }
      return
    end

    begin
      # Test the connection by retrieving account info
      client = current_user.stripe_client
      account = client.accounts.retrieve
      
      render json: {
        success: true,
        account_id: account.id,
        business_name: account.business_profile&.name || account.email,
        country: account.country,
        currency: account.default_currency&.upcase,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled
      }
    rescue Stripe::AuthenticationError
      render json: { 
        success: false, 
        error: 'Invalid API keys. Please check your Stripe credentials.' 
      }
    rescue Stripe::StripeError => e
      render json: { 
        success: false, 
        error: "Stripe error: #{e.message}" 
      }
    rescue StandardError => e
      render json: { 
        success: false, 
        error: "Connection error: #{e.message}" 
      }
    end
  end

  def disable
    authorize current_user, :update?
    current_user.update!(
      stripe_enabled: false,
      stripe_publishable_key: nil,
      stripe_secret_key: nil,
      stripe_webhook_secret: nil,
      stripe_account_id: nil
    )
    
    redirect_to stripe_settings_path, notice: 'Stripe integration disabled successfully.'
  end

  private

  def ensure_premium_user
    unless current_user.premium?
      redirect_to profile_path, alert: 'Payment processing requires a premium subscription. Please upgrade your account.'
    end
  end

  def stripe_params
    params.require(:user).permit(
      :stripe_publishable_key, 
      :stripe_secret_key, 
      :stripe_webhook_secret,
      :stripe_enabled
    )
  end
end