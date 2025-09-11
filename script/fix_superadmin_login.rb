#!/usr/bin/env ruby
# frozen_string_literal: true

# Superadmin Login Fix Script
# This script fixes common superadmin login issues

require_relative '../config/environment'

class SuperadminLoginFix
  def initialize(email = nil, password = nil)
    @email = email || ENV['EMAIL'] || 'superadmin@agentform.com'
    @password = password || ENV['PASSWORD'] || 'SuperSecret123!'
  end

  def run_fix
    puts "🔧 Superadmin Login Fix"
    puts "=" * 30
    puts "Email: #{@email}"
    puts "Environment: #{Rails.env}"
    puts "Timestamp: #{Time.current}"
    puts

    find_or_create_superadmin
    fix_confirmation_issues
    fix_activation_issues
    verify_login
    
    puts "\n✅ Superadmin login fix completed!"
    puts "Try logging in with:"
    puts "  Email: #{@email}"
    puts "  Password: #{@password}"
  end

  private

  def find_or_create_superadmin
    puts "👤 Finding or Creating Superadmin"
    puts "-" * 30

    @user = User.find_by(email: @email)
    
    if @user
      puts "✅ Found existing user: #{@user.email}"
      puts "  Current role: #{@user.role}"
      
      # Update to superadmin if not already
      if @user.role != 'superadmin'
        @user.update!(role: 'superadmin')
        puts "✅ Updated role to superadmin"
      end
    else
      puts "Creating new superadmin user..."
      
      @user = User.new(
        email: @email,
        password: @password,
        password_confirmation: @password,
        first_name: 'Super',
        last_name: 'Admin',
        role: 'superadmin',
        subscription_tier: 'premium',
        active: true
      )
      
      if @user.save
        puts "✅ Created new superadmin user"
      else
        puts "❌ Failed to create user: #{@user.errors.full_messages.join(', ')}"
        return
      end
    end

    # Update password if provided
    if @password.present?
      @user.password = @password
      @user.password_confirmation = @password
      if @user.save
        puts "✅ Password updated"
      else
        puts "❌ Failed to update password: #{@user.errors.full_messages.join(', ')}"
      end
    end

    puts
  end

  def fix_confirmation_issues
    puts "📧 Fixing Email Confirmation Issues"
    puts "-" * 30

    if @user.confirmed?
      puts "✅ User is already confirmed"
    else
      puts "Confirming user email..."
      
      # Force confirmation
      @user.confirmed_at = Time.current
      @user.confirmation_token = nil
      
      if @user.save(validate: false)
        puts "✅ User email confirmed"
      else
        puts "❌ Failed to confirm email: #{@user.errors.full_messages.join(', ')}"
      end
    end

    puts
  end

  def fix_activation_issues
    puts "🔓 Fixing User Activation Issues"
    puts "-" * 30

    if @user.active?
      puts "✅ User is already active"
    else
      puts "Activating user..."
      
      @user.active = true
      
      if @user.save
        puts "✅ User activated"
      else
        puts "❌ Failed to activate user: #{@user.errors.full_messages.join(', ')}"
      end
    end

    # Check for suspension
    if @user.suspended?
      puts "User is suspended, reactivating..."
      @user.reactivate!
      puts "✅ User reactivated"
    end

    puts
  end

  def verify_login
    puts "🔐 Verifying Login Credentials"
    puts "-" * 30

    # Reload user to get latest data
    @user.reload

    puts "User details:"
    puts "  Email: #{@user.email}"
    puts "  Role: #{@user.role}"
    puts "  Active: #{@user.active?}"
    puts "  Confirmed: #{@user.confirmed?}"
    puts "  Suspended: #{@user.suspended?}"
    puts "  Subscription tier: #{@user.subscription_tier}"

    # Test password validation
    if @user.valid_password?(@password)
      puts "✅ Password validation successful"
    else
      puts "❌ Password validation failed"
      
      # Try to fix password
      puts "Attempting to fix password..."
      @user.password = @password
      @user.password_confirmation = @password
      
      if @user.save
        puts "✅ Password fixed and saved"
        
        # Test again
        @user.reload
        if @user.valid_password?(@password)
          puts "✅ Password validation now works"
        else
          puts "❌ Password validation still failing"
        end
      else
        puts "❌ Failed to save new password: #{@user.errors.full_messages.join(', ')}"
      end
    end

    # Check if user can authenticate with Devise
    authenticated_user = User.find_for_database_authentication(email: @email)
    if authenticated_user && authenticated_user.valid_password?(@password)
      puts "✅ Devise authentication successful"
    else
      puts "❌ Devise authentication failed"
    end

    puts
  end
end

# Command line interface
if __FILE__ == $0
  email = ARGV[0]
  password = ARGV[1]
  
  if email.nil? && ENV['EMAIL'].nil?
    puts "Usage: ruby script/fix_superadmin_login.rb [email] [password]"
    puts "Or set EMAIL and PASSWORD environment variables"
    puts
    puts "Example:"
    puts "  ruby script/fix_superadmin_login.rb admin@example.com MyPassword123!"
    puts "  EMAIL=admin@example.com PASSWORD=MyPassword123! ruby script/fix_superadmin_login.rb"
    exit 1
  end
  
  fixer = SuperadminLoginFix.new(email, password)
  fixer.run_fix
end