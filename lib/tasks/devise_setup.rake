namespace :devise do
  desc "Create a confirmed admin user for development"
  task create_admin: :environment do
    email = "admin@example.com"
    password = "password123"
    
    user = User.find_or_create_by(email: email) do |u|
      u.password = password
      u.password_confirmation = password
      u.first_name = "Admin"
      u.last_name = "User"
      u.role = "admin"
      u.confirmed_at = Time.current
      u.active = true
    end
    
    if user.persisted?
      puts "✅ Admin user created successfully!"
      puts "Email: #{email}"
      puts "Password: #{password}"
      puts "You can now log in with these credentials."
    else
      puts "❌ Error creating admin user: #{user.errors.full_messages.join(', ')}"
    end
  end

  desc "Create a confirmed regular user for development"
  task create_user: :environment do
    email = "user@example.com"
    password = "password123"
    
    user = User.find_or_create_by(email: email) do |u|
      u.password = password
      u.password_confirmation = password
      u.first_name = "Test"
      u.last_name = "User"
      u.role = "user"
      u.confirmed_at = Time.current
      u.active = true
    end
    
    if user.persisted?
      puts "✅ Regular user created successfully!"
      puts "Email: #{email}"
      puts "Password: #{password}"
      puts "You can now log in with these credentials."
    else
      puts "❌ Error creating user: #{user.errors.full_messages.join(', ')}"
    end
  end

  desc "Confirm all existing users"
  task confirm_all: :environment do
    User.where(confirmed_at: nil).update_all(confirmed_at: Time.current)
    puts "✅ All users have been confirmed!"
  end
end