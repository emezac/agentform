# frozen_string_literal: true

module GoogleSheets
  class TokenRefreshService < BaseService
    def initialize(integration:)
      @integration = integration
    end
    
    def call
      refresh_authorization_token
      ServiceResult.success(integration: @integration)
    rescue Google::Apis::AuthorizationError => e
      @integration.update!(active: false)
      @integration.log_error(e)
      ServiceResult.failure("Authorization expired. Please reconnect your Google account.")
    rescue StandardError => e
      @integration.log_error(e)
      ServiceResult.failure("Token refresh failed: #{e.message}")
    end
    
    private
    
    def refresh_authorization_token
      auth = Signet::OAuth2::Client.new(
        client_id: Rails.application.credentials.dig(:google_sheets_integration, :client_id),
        client_secret: Rails.application.credentials.dig(:google_sheets_integration, :client_secret),
        refresh_token: @integration.refresh_token
      )
      
      auth.refresh!
      
      @integration.update!(
        access_token: auth.access_token,
        token_expires_at: Time.current + auth.expires_in.seconds,
        last_used_at: Time.current
      )
      
      Rails.logger.info "Token refreshed for user #{@integration.user_id}"
    end
  end
end