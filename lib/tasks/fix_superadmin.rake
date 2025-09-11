# frozen_string_literal: true

namespace :users do
  desc "Diagnose superadmin login issues"
  task diagnose_superadmin: :environment do
    puts "🔍 Running superadmin login diagnostics..."
    
    # Load and run the diagnostic script
    diagnostic_script = Rails.root.join('script', 'diagnose_superadmin_login.rb')
    
    if File.exist?(diagnostic_script)
      load diagnostic_script
      
      diagnostic = SuperadminLoginDiagnostic.new
      diagnostic.run_diagnosis
    else
      puts "❌ Diagnostic script not found at: #{diagnostic_script}"
      exit 1
    end
  end

  desc "Fix superadmin login issues"
  task fix_superadmin: :environment do
    email = ENV['EMAIL']
    password = ENV['PASSWORD']
    
    if email.nil?
      puts "❌ EMAIL environment variable is required"
      puts "Usage: EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:fix_superadmin"
      exit 1
    end
    
    if password.nil?
      puts "❌ PASSWORD environment variable is required"
      puts "Usage: EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:fix_superadmin"
      exit 1
    end
    
    puts "🔧 Fixing superadmin login issues..."
    
    # Load and run the fix script
    fix_script = Rails.root.join('script', 'fix_superadmin_login.rb')
    
    if File.exist?(fix_script)
      load fix_script
      
      fixer = SuperadminLoginFix.new(email, password)
      fixer.run_fix
    else
      puts "❌ Fix script not found at: #{fix_script}"
      exit 1
    end
  end

  desc "Quick superadmin confirmation fix"
  task confirm_superadmin: :environment do
    puts "📧 Confirming all superadmin users..."
    
    superadmin_users = User.where(role: 'superadmin')
    
    if superadmin_users.empty?
      puts "❌ No superadmin users found"
      puts "Run: rake users:create_superadmin first"
      exit 1
    end
    
    confirmed_count = 0
    superadmin_users.each do |user|
      unless user.confirmed?
        user.confirmed_at = Time.current
        user.confirmation_token = nil
        
        if user.save(validate: false)
          puts "✅ Confirmed: #{user.email}"
          confirmed_count += 1
        else
          puts "❌ Failed to confirm: #{user.email} - #{user.errors.full_messages.join(', ')}"
        end
      else
        puts "✅ Already confirmed: #{user.email}"
      end
    end
    
    puts "\n📊 Summary:"
    puts "  Total superadmin users: #{superadmin_users.count}"
    puts "  Newly confirmed: #{confirmed_count}"
    puts "  All confirmed: #{superadmin_users.reload.all?(&:confirmed?)}"
  end

  desc "Activate all superadmin users"
  task activate_superadmin: :environment do
    puts "🔓 Activating all superadmin users..."
    
    superadmin_users = User.where(role: 'superadmin')
    
    if superadmin_users.empty?
      puts "❌ No superadmin users found"
      puts "Run: rake users:create_superadmin first"
      exit 1
    end
    
    activated_count = 0
    superadmin_users.each do |user|
      unless user.active?
        user.active = true
        
        if user.save
          puts "✅ Activated: #{user.email}"
          activated_count += 1
        else
          puts "❌ Failed to activate: #{user.email} - #{user.errors.full_messages.join(', ')}"
        end
      else
        puts "✅ Already active: #{user.email}"
      end
      
      # Also reactivate if suspended
      if user.suspended?
        user.reactivate!
        puts "✅ Reactivated (was suspended): #{user.email}"
      end
    end
    
    puts "\n📊 Summary:"
    puts "  Total superadmin users: #{superadmin_users.count}"
    puts "  Newly activated: #{activated_count}"
    puts "  All active: #{superadmin_users.reload.all?(&:active?)}"
  end

  desc "Reset superadmin password"
  task reset_superadmin_password: :environment do
    email = ENV['EMAIL']
    password = ENV['PASSWORD']
    
    if email.nil?
      puts "❌ EMAIL environment variable is required"
      puts "Usage: EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:reset_superadmin_password"
      exit 1
    end
    
    if password.nil?
      puts "❌ PASSWORD environment variable is required"
      puts "Usage: EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:reset_superadmin_password"
      exit 1
    end
    
    puts "🔐 Resetting superadmin password..."
    
    user = User.find_by(email: email)
    
    if user.nil?
      puts "❌ User not found: #{email}"
      exit 1
    end
    
    unless user.superadmin?
      puts "❌ User is not a superadmin: #{email}"
      puts "Current role: #{user.role}"
      exit 1
    end
    
    user.password = password
    user.password_confirmation = password
    
    if user.save
      puts "✅ Password reset successfully for: #{email}"
      puts "New password: #{password}"
      
      # Test the password
      if user.valid_password?(password)
        puts "✅ Password validation confirmed"
      else
        puts "❌ Password validation failed - there may be an issue"
      end
    else
      puts "❌ Failed to reset password: #{user.errors.full_messages.join(', ')}"
      exit 1
    end
  end

  desc "Show superadmin credentials"
  task show_superadmin_credentials: :environment do
    puts "🔑 SUPERADMIN CREDENTIALS"
    puts "=" * 50
    puts "Environment: #{Rails.env}"
    puts "App Domain: #{ENV['APP_DOMAIN'] || 'localhost'}"
    puts "Timestamp: #{Time.current}"
    puts

    superadmin_users = User.where(role: 'superadmin')

    if superadmin_users.empty?
      puts "❌ No superadmin users found!"
      puts "Run: rake users:create_superadmin to create one"
      return
    end

    superadmin_users.each_with_index do |user, index|
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
        app_domain = ENV['APP_DOMAIN'] || 'mydialogform.com'
        login_url = "https://#{app_domain}/users/sign_in"
      else
        login_url = "http://localhost:3000/users/sign_in"
      end

      puts "🌐 Login URL: #{login_url}"
      puts
    end

    puts "🔐 PASSWORD INFORMATION"
    puts "-" * 30
    puts "The password was last reset using the script."
    puts "If you used the reset script, the password should be:"
    puts "  MyPassword123!"
    puts
    puts "If you're not sure about the password, you can reset it:"
    puts "  heroku run EMAIL=superadmin@mydialogform.com PASSWORD=NewPassword123! rake users:reset_superadmin_password --app mydialogform"
    puts

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

  desc "Complete superadmin setup and verification"
  task setup_superadmin: :environment do
    email = ENV['EMAIL'] || 'superadmin@agentform.com'
    password = ENV['PASSWORD'] || 'SuperSecret123!'
    
    puts "🚀 Complete Superadmin Setup"
    puts "=" * 40
    puts "Email: #{email}"
    puts "Password: #{password}"
    puts "Environment: #{Rails.env}"
    puts
    
    # Step 1: Create or find user
    puts "Step 1: Creating/Finding superadmin user..."
    user = User.find_or_initialize_by(email: email)
    
    user.assign_attributes(
      first_name: 'Super',
      last_name: 'Admin',
      role: 'superadmin',
      subscription_tier: 'premium',
      active: true,
      password: password,
      password_confirmation: password
    )
    
    if user.save
      puts "✅ User created/updated successfully"
    else
      puts "❌ Failed to create/update user: #{user.errors.full_messages.join(', ')}"
      exit 1
    end
    
    # Step 2: Confirm email
    puts "\nStep 2: Confirming email..."
    unless user.confirmed?
      user.confirmed_at = Time.current
      user.confirmation_token = nil
      user.save(validate: false)
      puts "✅ Email confirmed"
    else
      puts "✅ Email already confirmed"
    end
    
    # Step 3: Activate user
    puts "\nStep 3: Activating user..."
    unless user.active?
      user.update!(active: true)
      puts "✅ User activated"
    else
      puts "✅ User already active"
    end
    
    # Step 4: Remove suspension if any
    puts "\nStep 4: Checking suspension status..."
    if user.suspended?
      user.reactivate!
      puts "✅ User reactivated (was suspended)"
    else
      puts "✅ User not suspended"
    end
    
    # Step 5: Verify login
    puts "\nStep 5: Verifying login credentials..."
    user.reload
    
    if user.valid_password?(password)
      puts "✅ Password validation successful"
    else
      puts "❌ Password validation failed"
      exit 1
    end
    
    # Step 6: Test Devise authentication
    puts "\nStep 6: Testing Devise authentication..."
    authenticated_user = User.find_for_database_authentication(email: email)
    if authenticated_user && authenticated_user.valid_password?(password)
      puts "✅ Devise authentication successful"
    else
      puts "❌ Devise authentication failed"
      exit 1
    end
    
    puts "\n🎉 SUPERADMIN SETUP COMPLETE!"
    puts "=" * 40
    puts "✅ User created and configured"
    puts "✅ Email confirmed"
    puts "✅ User activated"
    puts "✅ Password validated"
    puts "✅ Authentication tested"
    puts
    puts "Login credentials:"
    puts "  Email: #{email}"
    puts "  Password: #{password}"
    puts "  Role: #{user.role}"
    puts "  Subscription: #{user.subscription_tier}"
    puts
    puts "You can now log in to the application!"
  end
end