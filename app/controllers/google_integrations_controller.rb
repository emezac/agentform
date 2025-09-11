# frozen_string_literal: true

class GoogleIntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_premium_user
  
  def show
    @integration = current_user.google_integration
    @recent_exports = current_user.export_jobs.google_sheets.recent.limit(10)
  end
  
  def connect
    redirect_to google_oauth_path, allow_other_host: true
  end
  
  def callback
    auth = request.env['omniauth.auth']
    
    if auth.present?
      create_or_update_integration(auth)
      redirect_to google_integration_path, notice: 'Successfully connected to Google Sheets!'
    else
      redirect_to google_integration_path, alert: 'Failed to connect to Google Sheets.'
    end
  end
  
  def disconnect
    integration = current_user.google_integration
    if integration
      # Revocar el token en Google
      revoke_google_token(integration)
      integration.destroy
      
      flash[:notice] = 'Successfully disconnected from Google Sheets.'
    end
    
    redirect_to google_integration_path
  end
  
  def test_connection
    integration = current_user.google_integration
    
    if integration&.active?
      result = GoogleSheets::ConnectionTestService.call(integration: integration)
      
      if result.success?
        render json: { 
          success: true, 
          message: 'Connection successful',
          user_info: result.result[:user_info]
        }
      else
        render json: { 
          success: false, 
          error: result.errors.join(', ') 
        }
      end
    else
      render json: { 
        success: false, 
        error: 'No active Google integration found' 
      }
    end
  end
  
  private
  
  def create_or_update_integration(auth)
    integration = current_user.google_integration || current_user.build_google_integration
    
    integration.assign_attributes(
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      token_expires_at: Time.at(auth.credentials.expires_at),
      scope: auth.extra.scope,
      user_info: {
        email: auth.info.email,
        name: auth.info.name,
        image: auth.info.image
      },
      active: true,
      last_used_at: Time.current
    )
    
    integration.save!
    
    # Audit log
    AuditLog.create!(
      user: current_user,
      event_type: 'google_integration_connected',
      details: {
        user_email: auth.info.email,
        scope: auth.extra.scope
      }
    )
  end
  
  def revoke_google_token(integration)
    begin
      auth = Signet::OAuth2::Client.new(
        client_id: GoogleSheets::ConfigService.oauth_client_id,
        client_secret: GoogleSheets::ConfigService.oauth_client_secret,
        access_token: integration.access_token
      )
      
      auth.revoke!
    rescue StandardError => e
      Rails.logger.warn "Failed to revoke Google token: #{e.message}"
    end
  end
  
  def ensure_premium_user
    unless current_user.premium?
      redirect_to subscription_management_path, 
                  alert: 'Google Sheets integration requires a Premium subscription.'
    end
  end
  
  def google_oauth_path
    "/users/auth/google_oauth2?scope=https://www.googleapis.com/auth/spreadsheets"
  end
end