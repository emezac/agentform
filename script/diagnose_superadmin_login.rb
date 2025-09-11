#!/usr/bin/env ruby
# frozen_string_literal: true

# Superadmin Login Diagnostic Script
# This script helps diagnose why superadmin login is failing

require_relative '../config/environment'

class SuperadminLoginDiagnostic
  def initialize
    @issues = []
    @warnings = []
  end

  def run_diagnosis
    puts "🔍 Superadmin Login Diagnostic"
    puts "=" * 40
    puts "Environment: #{Rails.env}"
    puts "Timestamp: #{Time.current}"
    puts

    check_superadmin_users
    check_devise_configuration
    check_confirmation_status
    check_password_validation
    check_database_connection
    check_environment_variables

    print_summary
    suggest_solutions
  end

  private

  def check_superadmin_users
    puts "👤 Checking Superadmin Users"
    puts "-" * 30

    superadmin_users = User.where(role: 'superadmin')
    
    if superadmin_users.empty?
      error("No superadmin users found in database")
      puts "  Run: rake users:create_superadmin"
      return
    end

    superadmin_users.each do |user|
      puts "Found superadmin: #{user.email}"
      puts "  ID: #{user.id}"
      puts "  Role: #{user.role}"
      puts "  Active: #{user.active?}"
      puts "  Confirmed: #{user.confirmed?}"
      puts "  Confirmation token: #{user.confirmation_token.present? ? 'Present' : 'None'}"
      puts "  Confirmed at: #{user.confirmed_at || 'Not confirmed'}"
      puts "  Created at: #{user.created_at}"
      puts "  Updated at: #{user.updated_at}"
      
      # Check password
      if user.encrypted_password.present?
        success("Password is set")
      else
        error("Password is not set")
      end

      # Check confirmation status
      if user.confirmed?
        success("User is confirmed")
      else
        error("User is not confirmed")
        @issues << {
          type: :confirmation,
          user: user,
          message: "User #{user.email} is not confirmed"
        }
      end

      # Check if user is active
      if user.active?
        success("User is active")
      else
        error("User is inactive")
        @issues << {
          type: :inactive,
          user: user,
          message: "User #{user.email} is inactive"
        }
      end

      puts
    end
  end

  def check_devise_configuration
    puts "⚙️ Checking Devise Configuration"
    puts "-" * 30

    # Check if confirmable is enabled
    if User.devise_modules.include?(:confirmable)
      warning("Devise confirmable is enabled - users must confirm email")
      puts "  This requires email confirmation before login"
    else
      success("Devise confirmable is disabled")
    end

    # Check other devise modules
    puts "Enabled Devise modules:"
    User.devise_modules.each do |module_name|
      puts "  - #{module_name}"
    end

    puts
  end

  def check_confirmation_status
    puts "📧 Checking Email Confirmation"
    puts "-" * 30

    superadmin_users = User.where(role: 'superadmin')
    
    superadmin_users.each do |user|
      puts "User: #{user.email}"
      
      if user.confirmed?
        success("Email confirmed at #{user.confirmed_at}")
      else
        error("Email not confirmed")
        
        if user.confirmation_token.present?
          puts "  Confirmation token exists: #{user.confirmation_token[0..10]}..."
          puts "  Confirmation sent at: #{user.confirmation_sent_at}"
        else
          puts "  No confirmation token"
        end
        
        # Try to confirm the user
        puts "  Attempting to confirm user..."
        begin
          user.confirm
          if user.confirmed?
            success("User confirmed successfully")
          else
            error("Failed to confirm user: #{user.errors.full_messages.join(', ')}")
          end
        rescue => e
          error("Error confirming user: #{e.message}")
        end
      end
      puts
    end
  end

  def check_password_validation
    puts "🔐 Checking Password Validation"
    puts "-" * 30

    # Test password validation with a sample
    test_email = "test_validation_#{Time.current.to_i}@example.com"
    test_user = User.new(
      email: test_email,
      password: 'SuperSecret123!',
      password_confirmation: 'SuperSecret123!',
      first_name: 'Test',
      last_name: 'User',
      role: 'superadmin'
    )

    if test_user.valid?
      success("Password validation works correctly")
    else
      error("Password validation failed: #{test_user.errors.full_messages.join(', ')}")
    end

    # Test authentication
    superadmin = User.where(role: 'superadmin').first
    if superadmin
      puts "Testing authentication for: #{superadmin.email}"
      
      # Try with a known password (this won't work in production, but helps diagnose)
      test_passwords = ['SuperSecret123!', 'superadmin123', 'password123']
      
      test_passwords.each do |password|
        if superadmin.valid_password?(password)
          success("Password '#{password}' works for #{superadmin.email}")
          break
        else
          puts "  Password '#{password}' does not work"
        end
      end
    end

    puts
  end

  def check_database_connection
    puts "🗄️ Checking Database Connection"
    puts "-" * 30

    begin
      User.connection.execute("SELECT 1")
      success("Database connection is working")
      
      user_count = User.count
      puts "  Total users in database: #{user_count}"
      
      superadmin_count = User.where(role: 'superadmin').count
      puts "  Superadmin users: #{superadmin_count}"
      
    rescue => e
      error("Database connection failed: #{e.message}")
    end

    puts
  end

  def check_environment_variables
    puts "🌍 Checking Environment Variables"
    puts "-" * 30

    important_vars = [
      'DATABASE_URL',
      'RAILS_ENV',
      'SECRET_KEY_BASE',
      'APP_DOMAIN'
    ]

    important_vars.each do |var|
      value = ENV[var]
      if value.present?
        # Mask sensitive values
        display_value = var.include?('SECRET') || var.include?('KEY') ? 
                       "#{value[0..10]}..." : value
        success("#{var}: #{display_value}")
      else
        warning("#{var}: Not set")
      end
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
    @issues << { type: :error, message: message }
  end

  def print_summary
    puts "📊 DIAGNOSTIC SUMMARY"
    puts "=" * 30

    puts "Issues found: #{@issues.size}"
    puts "Warnings: #{@warnings.size}"

    if @issues.any?
      puts "\n🚨 ISSUES:"
      @issues.each_with_index do |issue, index|
        puts "  #{index + 1}. #{issue[:message] || issue}"
      end
    end

    if @warnings.any?
      puts "\n⚠️  WARNINGS:"
      @warnings.each_with_index do |warning, index|
        puts "  #{index + 1}. #{warning}"
      end
    end

    puts
  end

  def suggest_solutions
    puts "💡 SUGGESTED SOLUTIONS"
    puts "=" * 30

    if @issues.any? { |i| i[:type] == :confirmation }
      puts "🔧 Email Confirmation Issues:"
      puts "  1. Confirm superadmin users manually:"
      puts "     rails console"
      puts "     User.where(role: 'superadmin').each(&:confirm)"
      puts
    end

    if @issues.any? { |i| i[:type] == :inactive }
      puts "🔧 Inactive User Issues:"
      puts "  1. Activate superadmin users:"
      puts "     rails console"
      puts "     User.where(role: 'superadmin').update_all(active: true)"
      puts
    end

    if @issues.any? { |i| i[:type] == :error && i[:message].include?('Password') }
      puts "🔧 Password Issues:"
      puts "  1. Reset superadmin password:"
      puts "     rails console"
      puts "     user = User.find_by(role: 'superadmin')"
      puts "     user.password = 'NewPassword123!'"
      puts "     user.password_confirmation = 'NewPassword123!'"
      puts "     user.save!"
      puts
    end

    puts "🔧 General Solutions:"
    puts "  1. Recreate superadmin user:"
    puts "     EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:create_superadmin"
    puts
    puts "  2. Check application logs:"
    puts "     heroku logs --tail --app your-app-name"
    puts
    puts "  3. Test login in Rails console:"
    puts "     rails console"
    puts "     user = User.find_by(email: 'your-email@example.com')"
    puts "     user.valid_password?('your-password')"
    puts
  end
end

# Run the diagnostic if this script is executed directly
if __FILE__ == $0
  diagnostic = SuperadminLoginDiagnostic.new
  diagnostic.run_diagnosis
end