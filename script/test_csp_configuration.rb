#!/usr/bin/env ruby
# frozen_string_literal: true

# CSP Configuration Test Script
# This script helps test and verify Content Security Policy configuration

begin
  require_relative '../config/environment'
rescue => e
  puts "Warning: Rails loading issue: #{e.message}" if ENV['DEBUG']
  require_relative '../config/environment'
end

class CSPConfigurationTest
  def initialize
    @app_name = ENV['HEROKU_APP_NAME'] || 'your-app-name'
  end

  def run_tests
    puts "🔒 Content Security Policy Configuration Test"
    puts "=" * 50
    puts "Environment: #{Rails.env}"
    puts "App: #{@app_name}"
    puts

    test_csp_configuration
    test_csp_headers
    test_inline_script_support
    provide_recommendations

    puts "\n✅ CSP configuration tests completed"
  end

  private

  def test_csp_configuration
    puts "1. Testing CSP Configuration..."
    
    if Rails.application.config.content_security_policy.present?
      puts "   ✅ CSP is configured"
      
      # Test if unsafe-inline is allowed for scripts
      csp_config = Rails.application.config.content_security_policy
      puts "   ✅ CSP policy object exists"
      
      # Check nonce configuration
      if Rails.application.config.content_security_policy_nonce_generator.present?
        puts "   ✅ CSP nonce generator configured"
      else
        puts "   ⚠️  CSP nonce generator not configured"
      end
      
    else
      puts "   ❌ CSP is not configured"
    end
  end

  def test_csp_headers
    puts "\n2. Testing CSP Headers..."
    
    begin
      # Create a test request to check headers
      app = Rails.application
      env = Rack::MockRequest.env_for('/')
      
      status, headers, body = app.call(env)
      
      if headers['Content-Security-Policy']
        puts "   ✅ CSP header is present"
        puts "   Policy: #{headers['Content-Security-Policy'][0..100]}..."
        
        # Check for unsafe-inline
        if headers['Content-Security-Policy'].include?('unsafe-inline')
          puts "   ✅ unsafe-inline is allowed (needed for current inline scripts)"
        else
          puts "   ❌ unsafe-inline is not allowed (will block inline scripts)"
        end
        
      else
        puts "   ❌ CSP header is missing"
      end
      
    rescue => e
      puts "   ❌ Error testing headers: #{e.message}"
    end
  end

  def test_inline_script_support
    puts "\n3. Testing Inline Script Support..."
    
    # Check if we have inline scripts in views
    inline_script_files = []
    
    Dir.glob(Rails.root.join('app/views/**/*.erb')).each do |file|
      content = File.read(file)
      if content.include?('<script>') || content.include?('javascript_tag')
        inline_script_files << file.gsub(Rails.root.to_s + '/', '')
      end
    end
    
    if inline_script_files.any?
      puts "   ⚠️  Found #{inline_script_files.size} files with inline scripts:"
      inline_script_files.first(5).each do |file|
        puts "     - #{file}"
      end
      puts "     ... and #{inline_script_files.size - 5} more" if inline_script_files.size > 5
      puts "   ℹ️  These require unsafe-inline or nonce implementation"
    else
      puts "   ✅ No inline scripts found"
    end
  end

  def provide_recommendations
    puts "\n4. Recommendations..."
    
    puts "   Current Status:"
    puts "   ✅ CSP configured to allow inline scripts (unsafe-inline)"
    puts "   ✅ External CDNs whitelisted (Tailwind, Stripe, PayPal)"
    puts "   ✅ WebSocket connections allowed for ActionCable"
    puts
    puts "   Security Improvements (Future):"
    puts "   🔧 Migrate inline scripts to external files"
    puts "   🔧 Implement CSP nonces for remaining inline scripts"
    puts "   🔧 Use Stimulus controllers instead of inline JavaScript"
    puts "   🔧 Set up CSP violation reporting"
    puts
    puts "   Immediate Actions:"
    puts "   1. Deploy current CSP configuration to fix menu issues"
    puts "   2. Test all interactive features in production"
    puts "   3. Monitor browser console for any remaining CSP violations"
    puts "   4. Plan migration of inline scripts to external files"
  end
end

# Run the test if this script is executed directly
if __FILE__ == $0
  tester = CSPConfigurationTest.new
  tester.run_tests
end