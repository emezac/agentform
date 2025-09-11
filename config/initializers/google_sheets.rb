# Google Sheets API Configuration
Rails.application.configure do
  # Only configure if Google APIs are available
  if defined?(Google::Apis)
    # Configure Google API client defaults
    Google::Apis.logger = Rails.logger
    Google::Apis::ClientOptions.default.application_name = "AgentForm"
    Google::Apis::ClientOptions.default.application_version = "1.0.0"
  end
  
  # Validate credentials in a separate block that doesn't depend on Google constants
  config.after_initialize do
    # Ensure Google Sheets credentials are available
    if Rails.application.credentials.google_sheets.present?
      # Validate required credentials
      required_keys = %w[type project_id private_key_id private_key client_email client_id auth_uri token_uri]
      
      missing_keys = required_keys.select do |key|
        Rails.application.credentials.google_sheets[key.to_sym].blank?
      end
      
      if missing_keys.any?
        Rails.logger.warn "Google Sheets: Missing required credentials: #{missing_keys.join(', ')}"
      else
        Rails.logger.info "Google Sheets: Credentials loaded successfully"
      end
    else
      if Rails.env.development?
        Rails.logger.warn "Google Sheets: No credentials found. Please configure credentials with 'rails credentials:edit'"
        Rails.logger.warn "Google Sheets: Required structure:"
        Rails.logger.warn <<~CREDENTIALS
          google_sheets:
            type: service_account
            project_id: your-project-id
            private_key_id: your-private-key-id
            private_key: |
              -----BEGIN PRIVATE KEY-----
              your-private-key-content
              -----END PRIVATE KEY-----
            client_email: your-service-account@your-project.iam.gserviceaccount.com
            client_id: your-client-id
            auth_uri: https://accounts.google.com/o/oauth2/auth
            token_uri: https://oauth2.googleapis.com/token
            auth_provider_x509_cert_url: https://www.googleapis.com/oauth2/v1/certs
            client_x509_cert_url: https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com
        CREDENTIALS
      else
        Rails.logger.info "Google Sheets: Credentials not configured (optional feature)"
      end
    end
  end
end