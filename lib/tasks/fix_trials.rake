namespace :users do
  desc "Fix trial status for existing users"
  task fix_trials: :environment do
    puts "Fixing trial status for users..."
    
    # Users without trial setup
    users_without_trial = User.where(trial_expires_at: nil)
    puts "Found #{users_without_trial.count} users without trial setup"
    
    users_without_trial.find_each do |user|
      # Set trial to 14 days from now for existing users
      user.update_column(:trial_expires_at, 14.days.from_now)
      puts "Updated trial for user #{user.email}"
    end
    
    puts "Done!"
  end
end