#!/usr/bin/env ruby
# frozen_string_literal: true

# Google Sheets Configuration Verification Script
# This script verifies that Google Sheets is properly configured for production

require_relative '../config/environment'

class GoogleSheetsConfigVerification
  def initialize
    @issues = []
    @warnings = []
  end

  def run_verification
    puts "🔍 Google Sheets Configuration Verification"
    puts "=" * 50
    puts "Environment: #{Rails.env}"
    puts "Timestamp: #{Time.current}"
    puts

    check_environment_variables
    check_oauth_configuration
    check_service_account_configuration
    check_configuration_service
    test_oauth_client_creation

    print_summary
    provide_recommendations
  end

  private

  def check_environment_variables
    puts "🌍 Checking Environment Variables"
    puts "-" * 30

    required_env_vars = [
      'GOOGLE_SHEETS_CLIENT_ID',
      'GOOGLE_SHEETS_CLIENT_SECRET'
    ]

    optional_env_vars = [
      'GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON',
      'GOOGLE_SHEETS_RATE_LIMIT_PER_MINUTE'
    ]

    required_env_vars.each do |var|
      value = ENV[var]
      if value.present?
        # Show first 10 characters for security
        display_value = "#{value[0..10]}..." if value.length > 10
        success("#{var}: #{display_value || value}")
      else
        error("#{var}: Not set (REQUIRED)")
        @issues << "Missing required environment variable: #{var}"
      end
    end

    optional_env_vars.each do |var|
      value = ENV[var]
      if value.present?
        display_value = var.include?('JSON') ? "#{value[0..20]}..." : value
        success("#{var}: #{display_value}")
      else
        warning("#{var}: Not set (optional)")
      end
    end

    puts
  end

  def check_oauth_configuration
    puts "🔐 Checking OAuth Configuration"
    puts "-" * 30

    if GoogleSheets::ConfigService.oauth_configured?
      success("OAuth credentials are configured")
      
      client_id = GoogleSheets::ConfigService.oauth_client_id
      client_secret = GoogleSheets::ConfigService.oauth_client_secret
      
      puts "  Client ID: #{client_id[0..20]}..." if client_id
      puts "  Client Secret: #{client_secret[0..10]}..." if client_secret
    else
      error("OAuth credentials are NOT configured")
      @issues << "OAuth credentials missing - Google Sheets integration will not work"
    end

    puts
  end

  def check_service_account_configuration
    puts "🔧 Checking Service Account Configuration"
    puts "-" * 30

    if GoogleSheets::ConfigService.service_account_configured?
      success("Service Account credentials are configured")
      
      credentials = GoogleSheets::ConfigService.service_account_credentials
      if credentials
        puts "  Type: #{credentials['type']}"
        puts "  Project ID: #{credentials['project_id']}"
        puts "  Client Email: #{credentials['client_email']}"
      end
    else
      warning("Service Account credentials are NOT configured")
      @warnings << "Service Account not configured - some advanced features may be limited"
    end

    puts
  end

  def check_configuration_service
    puts "⚙️ Checking Configuration Service"
    puts "-" * 30

    begin
      summary = GoogleSheets::ConfigService.configuration_summary
      
      puts "Configuration Summary:"
      summary.each do |key, value|
        next if key == :production_env_vars
        
        status = value ? "✅" : "❌"
        puts "  #{key}: #{status} #{value}"
      end

      if summary[:production_env_vars]
        puts "  Production Environment Variables:"
        summary[:production_env_vars].each do |key, present|
          status = present ? "✅" : "❌"
          puts "    #{key}: #{status}"
        end
      end

      success("Configuration service is working")
    rescue => e
      error("Configuration service error: #{e.message}")
      @issues << "Configuration service is not working properly"
    end

    puts
  end

  def test_oauth_client_creation
    puts "🧪 Testing OAuth Client Creation"
    puts "-" * 30

    begin
      # Try to create an OAuth client like the application would
      client_id = GoogleSheets::ConfigService.oauth_client_id
      client_secret = GoogleSheets::ConfigService.oauth_client_secret

      if client_id.present? && client_secret.present?
        # Test creating a Signet OAuth2 client
        require 'signet/oauth2/client'
        
        client = Signet::OAuth2::Client.new(
          client_id: client_id,
          client_secret: client_secret,
          authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
          token_credential_uri: 'https://oauth2.googleapis.com/token',
          redirect_uri: 'http://localhost:3000/google_oauth/callback'
        )

        if client
          success("OAuth client creation successful")
          puts "  Client ID configured: #{client.client_id.present?}"
          puts "  Client Secret configured: #{client.client_secret.present?}"
        else
          error("OAuth client creation failed")
          @issues << "Cannot create OAuth client with provided credentials"
        end
      else
        error("Cannot test OAuth client - credentials missing")
        @issues << "OAuth credentials not available for testing"
      end
    rescue => e
      error("OAuth client test failed: #{e.message}")
      @issues << "OAuth client creation test failed: #{e.message}"
    end

    puts
  end

  def success(message)
    puts "  ✅ #{message}"
  end

  def warning(message)
    puts "  ⚠️  #{message}"
    @warnings << message
  end

  def error(message)
    puts "  ❌ #{message}"
  end

  def print_summary
    puts "📊 VERIFICATION SUMMARY"
    puts "=" * 30

    puts "Issues found: #{@issues.size}"
    puts "Warnings: #{@warnings.size}"

    if @issues.any?
      puts "\n🚨 CRITICAL ISSUES:"
      @issues.each_with_index do |issue, index|
        puts "  #{index + 1}. #{issue}"
      end
    end

    if @warnings.any?
      puts "\n⚠️  WARNINGS:"
      @warnings.each_with_index do |warning, index|
        puts "  #{index + 1}. #{warning}"
      end
    end

    if @issues.empty? && @warnings.empty?
      puts "\n🎉 ALL CHECKS PASSED!"
      puts "Google Sheets integration is properly configured."
    end

    puts
  end

  def provide_recommendations
    puts "💡 RECOMMENDATIONS"
    puts "=" * 30

    if @issues.any?
      puts "🔧 To fix critical issues:"
      puts
      
      if @issues.any? { |i| i.include?('GOOGLE_SHEETS_CLIENT_ID') }
        puts "1. Set GOOGLE_SHEETS_CLIENT_ID environment variable:"
        puts "   heroku config:set GOOGLE_SHEETS_CLIENT_ID=your-client-id --app mydialogform"
        puts
      end

      if @issues.any? { |i| i.include?('GOOGLE_SHEETS_CLIENT_SECRET') }
        puts "2. Set GOOGLE_SHEETS_CLIENT_SECRET environment variable:"
        puts "   heroku config:set GOOGLE_SHEETS_CLIENT_SECRET=your-client-secret --app mydialogform"
        puts
      end
    end

    if @warnings.any?
      puts "⚠️  Optional improvements:"
      puts
      
      if @warnings.any? { |w| w.include?('Service Account') }
        puts "1. Configure Service Account for advanced features:"
        puts "   heroku config:set GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON='your-service-account-json' --app mydialogform"
        puts
      end

      puts "2. Set rate limiting (optional):"
      puts "   heroku config:set GOOGLE_SHEETS_RATE_LIMIT_PER_MINUTE=60 --app mydialogform"
      puts
    end

    puts "📋 Next steps:"
    puts "1. Verify environment variables are set in Heroku"
    puts "2. Test Google OAuth flow in the application"
    puts "3. Create a test Google Sheets integration"
    puts "4. Monitor logs for any Google API errors"
    puts
  end
end

# Run verification if executed directly
if __FILE__ == $0
  verification = GoogleSheetsConfigVerification.new
  verification.run_verification
end