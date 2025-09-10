namespace :users do
  desc "Create a superadmin user with no billing restrictions"
  task create_superadmin: :environment do
    email = ENV['EMAIL'] || 'superadmin@agentform.com'
    password = ENV['PASSWORD'] || 'SuperSecret123!'
    
    puts "Creating superadmin user..."
    
    user = User.find_or_initialize_by(email: email)
    user.assign_attributes(
      first_name: 'Super',
      last_name: 'Admin',
      role: 'superadmin',
      subscription_tier: 'premium', # Set to premium to bypass all restrictions
      password: password,
      password_confirmation: password,
      active: true
    )
    
    if user.save
      puts "Superadmin user created successfully!"
      puts "Email: #{email}"
      puts "Password: #{password}"
      puts "Role: superadmin (bypasses all billing/trial restrictions)"
    else
      puts "Failed to create superadmin: #{user.errors.full_messages.join(', ')}"
    end
  end
end