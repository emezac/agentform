# frozen_string_literal: true

module GoogleSheets
  class ConfigService
    class << self
      # Get Google OAuth client credentials
      def oauth_client_id
        if Rails.env.production?
          ENV['GOOGLE_SHEETS_CLIENT_ID']
        else
          Rails.application.credentials.dig(:google_sheets_integration, :client_id)
        end
      end

      def oauth_client_secret
        if Rails.env.production?
          ENV['GOOGLE_SHEETS_CLIENT_SECRET']
        else
          Rails.application.credentials.dig(:google_sheets_integration, :client_secret)
        end
      end

      # Check if OAuth credentials are configured
      def oauth_configured?
        oauth_client_id.present? && oauth_client_secret.present?
      end

      # Get service account credentials (for API access)
      def service_account_credentials
        if Rails.env.production?
          # In production, we might use service account JSON from env var
          service_account_json = ENV['GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON']
          if service_account_json.present?
            JSON.parse(service_account_json)
          else
            nil
          end
        else
          # In development, use Rails credentials
          Rails.application.credentials.google_sheets
        end
      end

      # Check if service account is configured
      def service_account_configured?
        if Rails.env.production?
          ENV['GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON'].present?
        else
          Rails.application.credentials.google_sheets.present?
        end
      end

      # Get configuration summary for debugging
      def configuration_summary
        {
          environment: Rails.env,
          oauth_configured: oauth_configured?,
          service_account_configured: service_account_configured?,
          oauth_client_id_present: oauth_client_id.present?,
          oauth_client_secret_present: oauth_client_secret.present?,
          production_env_vars: Rails.env.production? ? {
            google_sheets_client_id: ENV['GOOGLE_SHEETS_CLIENT_ID'].present?,
            google_sheets_client_secret: ENV['GOOGLE_SHEETS_CLIENT_SECRET'].present?,
            google_sheets_service_account_json: ENV['GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON'].present?
          } : nil
        }
      end

      # Log configuration status
      def log_configuration_status
        summary = configuration_summary
        
        Rails.logger.info "Google Sheets Configuration Summary:"
        Rails.logger.info "  Environment: #{summary[:environment]}"
        Rails.logger.info "  OAuth configured: #{summary[:oauth_configured]}"
        Rails.logger.info "  Service Account configured: #{summary[:service_account_configured]}"
        
        if Rails.env.production? && summary[:production_env_vars]
          Rails.logger.info "  Production Environment Variables:"
          summary[:production_env_vars].each do |key, present|
            status = present ? "✅" : "❌"
            Rails.logger.info "    #{key.to_s.upcase}: #{status}"
          end
        end

        unless summary[:oauth_configured]
          Rails.logger.warn "Google Sheets OAuth not configured - integration features will be disabled"
        end

        unless summary[:service_account_configured]
          Rails.logger.warn "Google Sheets Service Account not configured - API features may be limited"
        end
      end
    end
  end
end