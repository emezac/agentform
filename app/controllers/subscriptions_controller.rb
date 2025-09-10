# frozen_string_literal: true

class SubscriptionsController < ApplicationController

  skip_before_action :authenticate_user!

  skip_after_action :verify_authorized, unless: :skip_authorization?
  skip_after_action :verify_policy_scoped, unless: :skip_authorization?

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      # Check if trial is enabled
      if TrialConfig.trial_enabled?
        # Start trial immediately without Stripe
        @user.update!(
          subscription_tier: 'premium',
          subscription_status: 'trialing',
          trial_ends_at: TrialConfig.trial_end_date(Time.current)
        )
        
        # Send trial welcome email
        UserMailer.trial_welcome(@user).deliver_later
        
        # Send confirmation email if user is not confirmed
        unless @user.confirmed?
          UserMailer.account_confirmation(@user).deliver_later
        end
        
        flash[:notice] = "¡Bienvenido! Tu período de prueba de #{TrialConfig.trial_period_days} días ha comenzado. Revisa tu correo (#{@user.email}) para confirmar tu cuenta."
        redirect_to success_subscriptions_path
      else
        # Normal Stripe flow for immediate payment
        begin
          checkout_session = Stripe::Checkout::Session.create({
            payment_method_types: ['card'],
            line_items: [{
              price: Rails.application.credentials.stripe[:premium_plan_price_id],
              quantity: 1,
            }],
            mode: 'subscription',
            success_url: success_subscriptions_url + "?session_id={CHECKOUT_SESSION_ID}",
            cancel_url: cancel_subscriptions_url,
            metadata: {
              user_id: @user.id
            }
          })
          
          redirect_to checkout_session.url, allow_other_host: true, status: :see_other
        rescue Stripe::StripeError => e
          @user.destroy
          flash[:alert] = "Hubo un error con el pago: #{e.message}"
          redirect_to new_subscription_path
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def success
    # This method handles both trial and Stripe success
    # The specific message is set in the create method
    redirect_to new_user_session_path
  end

  def cancel
    flash[:alert] = "El proceso de pago fue cancelado. Puedes intentarlo de nuevo."
    redirect_to new_user_registration_path
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end