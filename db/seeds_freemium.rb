# Create a basic test user
basic_user = User.create!(
  email: "basic@example.com",
  password: "password123",
  password_confirmation: "password123",
  first_name: "Basic",
  last_name: "User",
  role: "user",
  subscription_tier: "basic",
  active: true
)

puts "✅ Basic user created:"
puts "  Email: #{basic_user.email}"
puts "  Password: password123"
puts "  Tier: #{basic_user.subscription_tier}"
puts "  AI Credits: #{basic_user.ai_credits_remaining}"
puts ""

# Create a premium user for comparison
premium_user = User.create!(
  email: "premium@example.com",
  password: "password123",
  password_confirmation: "password123",
  first_name: "Premium",
  last_name: "User",
  role: "user",
  subscription_tier: "premium",
  active: true
)

puts "✅ Premium user created:"
puts "  Email: #{premium_user.email}"
puts "  Password: password123"
puts "  Tier: #{premium_user.subscription_tier}"
puts "  AI Credits: #{premium_user.ai_credits_remaining}"
puts ""

puts "🎯 Test account details:"
puts "  Basic: basic@example.com / password123"
puts "  Premium: premium@example.com / password123"