namespace :db do
  namespace :seed do
    desc "Load production seed data"
    task production: :environment do
      puts "🚀 Loading production seed data..."
      
      # Check if we're in production environment
      if Rails.env.production?
        print "⚠️  You are about to seed the PRODUCTION database. Are you sure? (yes/no): "
        confirmation = STDIN.gets.chomp
        
        unless confirmation.downcase == 'yes'
          puts "❌ Seeding cancelled."
          exit
        end
      end
      
      # Load the production seeds
      load Rails.root.join('db', 'seeds_production.rb')
      
      puts "✅ Production seeding completed successfully!"
    end
    
    desc "Reset and load production seed data (DESTRUCTIVE)"
    task reset_production: :environment do
      puts "🔥 This will DESTROY all existing data and reload production seeds!"
      
      if Rails.env.production?
        print "⚠️  You are about to RESET the PRODUCTION database. Type 'RESET PRODUCTION' to confirm: "
        confirmation = STDIN.gets.chomp
        
        unless confirmation == 'RESET PRODUCTION'
          puts "❌ Reset cancelled."
          exit
        end
      else
        print "Are you sure you want to reset the database? (yes/no): "
        confirmation = STDIN.gets.chomp
        
        unless confirmation.downcase == 'yes'
          puts "❌ Reset cancelled."
          exit
        end
      end
      
      # Reset the database
      Rake::Task['db:reset'].invoke
      
      # Load production seeds
      load Rails.root.join('db', 'seeds_production.rb')
      
      puts "✅ Database reset and production seeding completed!"
    end
  end
  
  desc "Export current database state to production seeds"
  task export_to_production_seeds: :environment do
    puts "📤 Exporting current database state to production seeds..."
    
    seed_content = []
    seed_content << "# Auto-generated production seeds from current database state"
    seed_content << "# Generated at: #{Time.current}"
    seed_content << ""
    
    # Export Users
    seed_content << "# ============================================"
    seed_content << "# USERS"
    seed_content << "# ============================================"
    seed_content << ""
    
    User.find_each do |user|
      seed_content << "User.find_or_create_by!(email: '#{user.email}') do |u|"
      seed_content << "  u.first_name = '#{user.first_name}'"
      seed_content << "  u.last_name = '#{user.last_name}'"
      seed_content << "  u.role = '#{user.role}'"
      seed_content << "  u.subscription_tier = '#{user.subscription_tier}'"
      seed_content << "  u.subscription_status = '#{user.subscription_status}'"
      seed_content << "  u.confirmed_at = Time.current"
      seed_content << "  u.active = #{user.active}"
      seed_content << "  u.onboarding_completed = #{user.onboarding_completed}"
      seed_content << "  u.monthly_ai_limit = #{user.monthly_ai_limit}"
      seed_content << "  u.ai_credits_used = #{user.ai_credits_used}"
      seed_content << "  u.stripe_enabled = #{user.stripe_enabled}"
      seed_content << "  u.discount_code_used = #{user.discount_code_used}"
      seed_content << "  # Password will need to be set manually"
      seed_content << "end"
      seed_content << ""
    end
    
    # Export Discount Codes
    seed_content << "# ============================================"
    seed_content << "# DISCOUNT CODES"
    seed_content << "# ============================================"
    seed_content << ""
    
    DiscountCode.find_each do |code|
      seed_content << "DiscountCode.find_or_create_by!(code: '#{code.code}') do |dc|"
      seed_content << "  dc.discount_percentage = #{code.discount_percentage}"
      seed_content << "  dc.max_usage_count = #{code.max_usage_count}"
      seed_content << "  dc.current_usage_count = #{code.current_usage_count}"
      seed_content << "  dc.expires_at = #{code.expires_at ? "'#{code.expires_at.iso8601}'" : 'nil'}"
      seed_content << "  dc.active = #{code.active}"
      seed_content << "  dc.created_by = User.find_by(email: '#{code.created_by.email}')"
      seed_content << "end"
      seed_content << ""
    end
    
    # Write to file
    File.write(Rails.root.join('db', 'seeds_exported.rb'), seed_content.join("\n"))
    
    puts "✅ Database state exported to db/seeds_exported.rb"
    puts "📊 Exported #{User.count} users and #{DiscountCode.count} discount codes"
  end
end