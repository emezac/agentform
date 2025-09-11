# frozen_string_literal: true

namespace :google_sheets do
  desc "Verify Google Sheets configuration"
  task verify_config: :environment do
    puts "🔍 Verifying Google Sheets configuration..."
    
    # Load and run the verification script
    verification_script = Rails.root.join('script', 'verify_google_sheets_config.rb')
    
    if File.exist?(verification_script)
      load verification_script
      
      verification = GoogleSheetsConfigVerification.new
      verification.run_verification
    else
      puts "❌ Verification script not found at: #{verification_script}"
      exit 1
    end
  end

  desc "Show Google Sheets configuration status"
  task show_config: :environment do
    puts "📋 Google Sheets Configuration Status"
    puts "=" * 40
    puts "Environment: #{Rails.env}"
    puts "Timestamp: #{Time.current}"
    puts

    # Show environment variables (masked for security)
    env_vars = {
      'GOOGLE_SHEETS_CLIENT_ID' => ENV['GOOGLE_SHEETS_CLIENT_ID'],
      'GOOGLE_SHEETS_CLIENT_SECRET' => ENV['GOOGLE_SHEETS_CLIENT_SECRET'],
      'GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON' => ENV['GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON'],
      'GOOGLE_SHEETS_RATE_LIMIT_PER_MINUTE' => ENV['GOOGLE_SHEETS_RATE_LIMIT_PER_MINUTE']
    }

    puts "Environment Variables:"
    env_vars.each do |key, value|
      if value.present?
        # Mask sensitive values
        if key.include?('SECRET') || key.include?('JSON')
          display_value = "#{value[0..10]}... (#{value.length} chars)"
        else
          display_value = value.length > 30 ? "#{value[0..30]}..." : value
        end
        puts "  ✅ #{key}: #{display_value}"
      else
        puts "  ❌ #{key}: Not set"
      end
    end

    puts
    puts "Configuration Service Status:"
    
    if defined?(GoogleSheets::ConfigService)
      summary = GoogleSheets::ConfigService.configuration_summary
      
      puts "  OAuth configured: #{summary[:oauth_configured] ? '✅' : '❌'}"
      puts "  Service Account configured: #{summary[:service_account_configured] ? '✅' : '❌'}"
      
      if Rails.env.production?
        puts "  Production environment variables:"
        summary[:production_env_vars]&.each do |key, present|
          status = present ? '✅' : '❌'
          puts "    #{key}: #{status}"
        end
      end
    else
      puts "  ❌ GoogleSheets::ConfigService not available"
    end

    puts
  end

  desc "Test Google OAuth client creation"
  task test_oauth: :environment do
    puts "🧪 Testing Google OAuth Client Creation"
    puts "=" * 40

    begin
      unless GoogleSheets::ConfigService.oauth_configured?
        puts "❌ OAuth not configured"
        puts "Please set GOOGLE_SHEETS_CLIENT_ID and GOOGLE_SHEETS_CLIENT_SECRET environment variables"
        exit 1
      end

      require 'signet/oauth2/client'
      
      client = Signet::OAuth2::Client.new(
        client_id: GoogleSheets::ConfigService.oauth_client_id,
        client_secret: GoogleSheets::ConfigService.oauth_client_secret,
        authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        redirect_uri: 'http://localhost:3000/google_oauth/callback'
      )

      puts "✅ OAuth client created successfully"
      puts "  Client ID: #{client.client_id[0..20]}..."
      puts "  Client Secret: #{client.client_secret[0..10]}..."
      puts "  Authorization URI: #{client.authorization_uri}"
      puts "  Token URI: #{client.token_credential_uri}"

      # Test authorization URL generation
      auth_url = client.authorization_uri(
        scope: ['https://www.googleapis.com/auth/spreadsheets'],
        access_type: 'offline',
        approval_prompt: 'force'
      )

      puts "✅ Authorization URL generation successful"
      puts "  URL length: #{auth_url.to_s.length} characters"
      puts "  Contains client_id: #{auth_url.to_s.include?(client.client_id)}"

    rescue => e
      puts "❌ OAuth client test failed: #{e.message}"
      puts "  Error class: #{e.class}"
      puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
      exit 1
    end
  end

  desc "Show Google Sheets integration usage instructions"
  task usage: :environment do
    puts "📖 Google Sheets Integration Usage"
    puts "=" * 40
    puts

    puts "🔧 Setup Instructions:"
    puts "1. Configure environment variables in Heroku:"
    puts "   heroku config:set GOOGLE_SHEETS_CLIENT_ID=your-client-id --app mydialogform"
    puts "   heroku config:set GOOGLE_SHEETS_CLIENT_SECRET=your-client-secret --app mydialogform"
    puts

    puts "2. Optional: Configure service account for advanced features:"
    puts "   heroku config:set GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON='your-json' --app mydialogform"
    puts

    puts "3. Optional: Set rate limiting:"
    puts "   heroku config:set GOOGLE_SHEETS_RATE_LIMIT_PER_MINUTE=60 --app mydialogform"
    puts

    puts "🧪 Testing Commands:"
    puts "  rake google_sheets:verify_config    # Full configuration verification"
    puts "  rake google_sheets:show_config      # Show current configuration"
    puts "  rake google_sheets:test_oauth       # Test OAuth client creation"
    puts

    puts "🔍 Troubleshooting:"
    puts "1. Check Heroku config vars:"
    puts "   heroku config --app mydialogform | grep GOOGLE"
    puts

    puts "2. Check application logs:"
    puts "   heroku logs --tail --app mydialogform | grep -i google"
    puts

    puts "3. Test in Rails console:"
    puts "   heroku run rails console --app mydialogform"
    puts "   > GoogleSheets::ConfigService.oauth_configured?"
    puts "   > GoogleSheets::ConfigService.configuration_summary"
    puts
  end
end