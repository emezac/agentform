# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: 'noreply@agentform.com'

  def trial_welcome(user)
    @user = user
    @trial_days = TrialConfig.trial_period_days
    @trial_end_date = user.trial_ends_at&.strftime('%B %d, %Y')
    @login_url = new_user_session_url
    
    mail(
      to: @user.email,
      subject: "¡Bienvenido a AgentForm! Tu período de prueba ha comenzado"
    )
  end

  def premium_welcome(user)
    @user = user
    @login_url = new_user_session_url
    
    mail(
      to: @user.email,
      subject: "¡Bienvenido a AgentForm Premium!"
    )
  end

  def trial_expiring_soon(user)
    @user = user
    @days_remaining = user.trial_days_remaining
    @upgrade_url = new_subscription_upgrade_url
    
    mail(
      to: @user.email,
      subject: "Tu período de prueba de AgentForm expira pronto"
    )
  end

  def trial_expiring_today(user)
    @user = user
    @upgrade_url = new_subscription_upgrade_url
    
    mail(
      to: @user.email,
      subject: "Tu período de prueba de AgentForm expira hoy"
    )
  end

  def trial_expired(user)
    @user = user
    @upgrade_url = new_subscription_upgrade_url
    @login_url = new_user_session_url
    
    mail(
      to: @user.email,
      subject: "Tu período de prueba de AgentForm ha expirado"
    )
  end

  def account_confirmation(user)
    @user = user
    @confirmation_url = user_confirmation_url(confirmation_token: user.confirmation_token)
    mail(
      to: @user.email,
      subject: "Confirma tu cuenta de AgentForm"
    )
  end
end