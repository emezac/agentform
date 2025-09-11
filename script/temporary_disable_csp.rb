#!/usr/bin/env ruby
# frozen_string_literal: true

# Temporary CSP Disable Script
# This script creates a temporary configuration to disable CSP for debugging

puts "🔧 Creating temporary CSP-disabled configuration..."

# Create a temporary initializer to disable CSP
csp_disable_content = <<~RUBY
  # Temporary CSP disable for debugging domain issues
  # This file should be removed after fixing the login issues
  
  Rails.application.configure do
    # Completely disable CSP temporarily
    config.content_security_policy = nil
    config.content_security_policy_report_only = false
    config.content_security_policy_nonce_generator = nil
    
    Rails.logger.info "⚠️  CSP temporarily disabled for debugging"
  end
RUBY

File.write('config/initializers/temporary_disable_csp.rb', csp_disable_content)

puts "✅ Created config/initializers/temporary_disable_csp.rb"
puts "⚠️  Remember to remove this file after fixing the issue!"
puts ""
puts "To deploy this change:"
puts "  git add config/initializers/temporary_disable_csp.rb"
puts "  git commit -m 'Temporarily disable CSP for debugging'"
puts "  git push heroku main"
puts ""
puts "To remove after fixing:"
puts "  rm config/initializers/temporary_disable_csp.rb"
puts "  git add -A && git commit -m 'Remove temporary CSP disable'"
puts "  git push heroku main"