#!/usr/bin/env ruby
# frozen_string_literal: true

# Domain Configuration Diagnostic Script
# This script helps diagnose domain-related issues in production

puts "🔍 Domain Configuration Diagnostics"
puts "=" * 50
puts "Timestamp: #{Time.current}"
puts

# Environment variables
puts "📋 Environment Variables:"
puts "  APP_DOMAIN: #{ENV['APP_DOMAIN'] || 'NOT SET'}"
puts "  RAILS_ENV: #{ENV['RAILS_ENV'] || 'NOT SET'}"
puts

# Rails configuration (if available)
if defined?(Rails)
  puts "⚙️  Rails Configuration:"
  puts "  Environment: #{Rails.env}"
  
  # Action Mailer configuration
  if Rails.application.config.action_mailer.default_url_options
    mailer_config = Rails.application.config.action_mailer.default_url_options
    puts "  Action Mailer Host: #{mailer_config[:host]}"
    puts "  Action Mailer Protocol: #{mailer_config[:protocol]}"
  else
    puts "  Action Mailer: Not configured"
  end
  
  # Allowed hosts
  puts "  Allowed Hosts:"
  if Rails.application.config.hosts.any?
    Rails.application.config.hosts.each do |host|
      puts "    - #{host}"
    end
  else
    puts "    - All hosts allowed (no restrictions)"
  end
  puts
  
  # CSP configuration
  puts "🛡️  Content Security Policy:"
  if Rails.application.config.content_security_policy_policy
    puts "  CSP is configured"
    
    # Try to get CSP directives
    begin
      csp_policy = Rails.application.config.content_security_policy_policy
      puts "  Default-src: #{csp_policy.instance_variable_get(:@directives)['default-src']&.join(' ')}"
      puts "  Connect-src: #{csp_policy.instance_variable_get(:@directives)['connect-src']&.join(' ')}"
      puts "  Script-src: #{csp_policy.instance_variable_get(:@directives)['script-src']&.join(' ')}"
    rescue => e
      puts "  Error reading CSP directives: #{e.message}"
    end
  else
    puts "  CSP is not configured"
  end
  puts
  
  # CORS configuration
  puts "🌐 CORS Configuration:"
  cors_middleware = Rails.application.middleware.detect { |m| m.klass.name == 'Rack::Cors' }
  if cors_middleware
    puts "  CORS middleware is configured"
  else
    puts "  CORS middleware not found"
  end
  puts
else
  puts "⚠️  Rails not available - run this script in Rails context"
  puts
end

# Network connectivity tests
puts "🌍 Network Connectivity Tests:"
domains_to_test = [
  'mydialogform.com',
  'www.mydialogform.com',
  'mydialogform-b93454ae9225.herokuapp.com'
]

domains_to_test.each do |domain|
  puts "Testing #{domain}:"
  
  # Test HTTP connectivity
  begin
    require 'net/http'
    require 'uri'
    
    uri = URI("https://#{domain}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5
    
    request = Net::HTTP::Get.new('/')
    response = http.request(request)
    
    puts "  HTTPS Response: #{response.code} #{response.message}"
    
    # Check for important headers
    if response['content-security-policy']
      puts "  CSP Header: Present"
    else
      puts "  CSP Header: Missing"
    end
    
    if response['access-control-allow-origin']
      puts "  CORS Header: #{response['access-control-allow-origin']}"
    else
      puts "  CORS Header: Missing"
    end
    
  rescue => e
    puts "  HTTPS Test: Failed (#{e.message})"
  end
  
  puts
end

# JavaScript/Turbo specific tests
puts "🔧 JavaScript/Turbo Configuration:"
puts "  Check browser console for specific error messages"
puts "  Common issues:"
puts "    - Mixed content (HTTP resources on HTTPS page)"
puts "    - CSP blocking inline scripts or external resources"
puts "    - CORS blocking AJAX requests"
puts "    - Incorrect domain references in JavaScript"
puts

# Recommendations
puts "💡 Troubleshooting Steps:"
puts "1. Check browser Network tab for failed requests"
puts "2. Look for CSP violations in browser console"
puts "3. Verify all asset URLs use HTTPS"
puts "4. Check for hardcoded domain references"
puts "5. Test with CSP temporarily disabled"
puts

puts "🔍 Browser Debugging Commands:"
puts "  Open browser console and run:"
puts "  console.log('Current domain:', window.location.hostname);"
puts "  console.log('CSP violations:', window.cspViolations || 'None logged');"
puts

puts "📞 Next Steps:"
puts "  If issues persist:"
puts "  1. Temporarily disable CSP to isolate the problem"
puts "  2. Check application logs for detailed error messages"
puts "  3. Use browser developer tools to inspect failed requests"
puts "  4. Verify all environment variables are correctly set"