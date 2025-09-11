#!/usr/bin/env ruby
# frozen_string_literal: true

# Cookie Domain Test Script
# This script helps verify cookie configuration for custom domains

puts "🍪 Cookie Domain Configuration Test"
puts "=" * 50
puts "Timestamp: #{Time.now}"
puts

if defined?(Rails)
  puts "⚙️  Rails Session Configuration:"
  
  # Get session store configuration
  session_options = Rails.application.config.session_options
  
  if session_options
    puts "  Session Store: #{Rails.application.config.session_store}"
    puts "  Session Key: #{session_options[:key]}"
    puts "  Domain: #{session_options[:domain] || 'Not set (will use request domain)'}"
    puts "  Secure: #{session_options[:secure]}"
    puts "  HttpOnly: #{session_options[:httponly]}"
    puts "  SameSite: #{session_options[:same_site]}"
  else
    puts "  Session options not found"
  end
  puts
  
  puts "🌐 ActionCable Configuration:"
  if Rails.application.config.action_cable.allowed_request_origins
    puts "  Allowed Origins:"
    Rails.application.config.action_cable.allowed_request_origins.each do |origin|
      puts "    - #{origin}"
    end
  else
    puts "  No specific origins configured (allows all)"
  end
  puts
  
  puts "🛡️  CSRF Configuration:"
  puts "  CSRF Protection: #{Rails.application.config.force_ssl ? 'Enabled (SSL required)' : 'Standard'}"
  puts "  Forgery Protection: #{ActionController::Base.allow_forgery_protection}"
  puts
  
  puts "🔧 Environment Variables:"
  puts "  APP_DOMAIN: #{ENV['APP_DOMAIN'] || 'Not set'}"
  puts "  RAILS_ENV: #{Rails.env}"
  puts
  
else
  puts "⚠️  Rails not available - run this script in Rails context"
  puts
end

puts "🧪 Cookie Domain Testing:"
puts "Expected behavior:"
puts "  - Cookies set with domain='.mydialogform.com'"
puts "  - Should work for both mydialogform.com and www.mydialogform.com"
puts "  - CSRF tokens should be valid across both domains"
puts
puts "🔍 Browser Testing Steps:"
puts "1. Open browser developer tools (F12)"
puts "2. Go to Application/Storage tab"
puts "3. Check Cookies section"
puts "4. Verify '_mydialogform_session' cookie exists"
puts "5. Check that Domain shows '.mydialogform.com'"
puts "6. Verify Secure and HttpOnly flags are set"
puts
puts "🚨 Troubleshooting:"
puts "If cookies are not working:"
puts "1. Clear all cookies for the domain"
puts "2. Try accessing both www and non-www versions"
puts "3. Check that HTTPS is working properly"
puts "4. Verify no mixed content warnings"