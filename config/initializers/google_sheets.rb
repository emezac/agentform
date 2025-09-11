# Google Sheets API Configuration
Rails.application.configure do
  # Only configure if Google APIs are available
  if defined?(Google::Apis)
    # Configure Google API client defaults
    Google::Apis.logger = Rails.logger
    Google::Apis::ClientOptions.default.application_name = "mydialogform"
    Google::Apis::ClientOptions.default.application_version = "1.0.0"
  end
  
  # Log configuration status after initialization
  config.after_initialize do
    # Use the new configuration service to log status
    if defined?(GoogleSheets::ConfigService)
      GoogleSheets::ConfigService.log_configuration_status
    else
      Rails.logger.warn "GoogleSheets::ConfigService not loaded - configuration status unknown"
    end
  end
end