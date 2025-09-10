namespace :trial do
  desc "Update existing user with correct trial end date"
  task update_existing_user: :environment do
    email = 'emezac@gmail.com'
    
    # Find or create the user
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User #{email} not found. Creating user..."
      user = User.create!(
        email: email,
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'Eduardo',
        last_name: 'Mezac',
        subscription_tier: 'basic',
        subscription_status: 'trialing',
        created_at: 30.days.ago # Simulate user created 30 days ago
      )
      puts "Created user: #{user.email}"
    end
    
    # Update trial_ends_at based on created_at date
    if user.subscription_status == 'trialing'
      original_trial_end = user.trial_ends_at
      new_trial_end = TrialConfig.trial_end_date(user.created_at)
      
      user.update!(trial_ends_at: new_trial_end)
      
      puts "Updated trial end date for #{user.email}:"
      puts "  Created at: #{user.created_at}"
      puts "  Original trial_ends_at: #{original_trial_end}"
      puts "  New trial_ends_at: #{user.trial_ends_at}"
      puts "  Trial period days: #{TrialConfig.trial_period_days}"
      puts "  Days remaining: #{user.trial_days_remaining}"
      puts "  Trial status: #{user.trial_status_message}"
      
      # Verify calculations work correctly
      puts "\nVerifying trial calculations:"
      puts "  trial_expired?: #{user.trial_expired?}"
      puts "  trial_expires_soon?: #{user.trial_expires_soon?}"
      puts "  trial_expires_today?: #{user.trial_expires_today?}"
      
    else
      puts "User #{user.email} is not in trialing status (current: #{user.subscription_status})"
    end
  end
  
  desc "Test trial calculations for existing user"
  task test_calculations: :environment do
    email = 'emezac@gmail.com'
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User #{email} not found. Run 'rails trial:update_existing_user' first."
      exit 1
    end
    
    puts "Testing trial calculations for #{user.email}:"
    puts "  Created at: #{user.created_at}"
    puts "  Trial ends at: #{user.trial_ends_at}"
    puts "  Current time: #{Time.current}"
    puts "  Subscription status: #{user.subscription_status}"
    puts ""
    puts "Trial methods:"
    puts "  trial_days_remaining: #{user.trial_days_remaining}"
    puts "  trial_expired?: #{user.trial_expired?}"
    puts "  trial_expires_soon?: #{user.trial_expires_soon?}"
    puts "  trial_expires_today?: #{user.trial_expires_today?}"
    puts "  trial_status_message: #{user.trial_status_message}"
    puts ""
    puts "Configuration:"
    puts "  TrialConfig.trial_period_days: #{TrialConfig.trial_period_days}"
    puts "  TrialConfig.trial_enabled?: #{TrialConfig.trial_enabled?}"
  end
end