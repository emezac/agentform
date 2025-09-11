#!/usr/bin/env ruby
# frozen_string_literal: true

# Superadmin Credentials Display Script
# This script shows the current superadmin credentials

require_relative '../config/environment'

class SuperadminCredentialsDisplay
  def initialize
    @superadmin_users = User.where(role: 'superadmin')
  end

  def show_credentials
    puts "🔑 SUPERADMIN CREDENTIALS"
    puts "=" * 50
    puts "Environment: #{Rails.env}"
    puts "App Domain: #{ENV['APP_DOMAIN'] || 'localhost'}"
    puts "Timestamp: #{Time.current}"
    puts

    if @superadmin_users.empty?
      puts "❌ No superadmin users found!"
      puts "Run: rake users:create_superadmin to create one"
      return
    end

    @superadmin_users.each_with_index do |user, index|
      puts "👤 Superadmin User ##{index + 1}"
      puts "-" * 30
      puts "Email: #{user.email}"
      puts "ID: #{user.id}"
      puts "Role: #{user.role}"
      puts "Active: #{user.active? ? '✅ Yes' : '❌ No'}"
      puts "Confirmed: #{user.confirmed? ? '✅ Yes' : '❌ No'}"
      puts "Suspended: #{user.suspended? ? '❌ Yes' : '✅ No'}"
      puts "Subscription: #{user.subscription_tier}"
      puts "Created: #{user.created_at}"
      puts "Last Updated: #{user.updated_at}"
      puts

      # Show login URL
      if Rails.env.production?
        app_domain = ENV['APP_DOMAIN'] || 'mydialogform-b93454ae9225.herokuapp.com'
        login_url = "https://#{app_domain}/users/sign_in"
      else
        login_url = "http://localhost:3000/users/sign_in"
      end

      puts "🌐 Login URL: #{login_url}"
      puts
    end

    show_password_info
    show_usage_instructions
  end

  private

  def show_password_info
    puts "🔐 PASSWORD INFORMATION"
    puts "-" * 30
    puts "The password was last reset using the script."
    puts "If you used the reset script, the password should be:"
    puts "  MyPassword123!"
    puts
    puts "If you're not sure about the password, you can reset it:"
    puts "  heroku run EMAIL=superadmin@mydialogform.com PASSWORD=NewPassword123! rake users:reset_superadmin_password --app mydialogform"
    puts
  end

  def show_usage_instructions
    puts "📋 USAGE INSTRUCTIONS"
    puts "-" * 30
    puts "1. Go to the login URL above"
    puts "2. Use the email and password shown"
    puts "3. You should be logged in as superadmin"
    puts
    puts "🔧 If login fails:"
    puts "1. Run diagnostics:"
    puts "   heroku run rake users:diagnose_superadmin --app mydialogform"
    puts
    puts "2. Reset password:"
    puts "   heroku run EMAIL=superadmin@mydialogform.com PASSWORD=YourNewPassword123! rake users:reset_superadmin_password --app mydialogform"
    puts
    puts "3. Complete setup (fixes all issues):"
    puts "   heroku run EMAIL=superadmin@mydialogform.com PASSWORD=YourNewPassword123! rake users:setup_superadmin --app mydialogform"
    puts
  end
end

# Run if executed directly
if __FILE__ == $0
  display = SuperadminCredentialsDisplay.new
  display.show_credentials
end