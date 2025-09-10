# Production Seeds File
# This file contains all the essential data to bootstrap the production database
# Run with: rails db:seed:replant SEED_FILE=db/seeds_production.rb

puts "🚀 Starting production database seeding..."

# ============================================
# 1. ADMIN USERS
# ============================================

puts "👤 Creating admin users..."

admin_user = User.find_or_create_by!(email: "admin@agentform.com") do |user|
  user.first_name = "Admin"
  user.last_name = "User"
  user.role = "admin"
  user.subscription_tier = "premium"
  user.subscription_status = "active"
  user.password = "AdminPassword123!"
  user.password_confirmation = "AdminPassword123!"
  user.confirmed_at = Time.current
  user.active = true
  user.onboarding_completed = true
  user.monthly_ai_limit = 1000.0
  user.ai_credits_used = 0.0
  user.stripe_enabled = false
  user.discount_code_used = false
end

superadmin_user = User.find_or_create_by!(email: "superadmin@agentform.com") do |user|
  user.first_name = "Super"
  user.last_name = "Admin"
  user.role = "superadmin"
  user.subscription_tier = "premium"
  user.subscription_status = "active"
  user.password = "SuperAdminPassword123!"
  user.password_confirmation = "SuperAdminPassword123!"
  user.confirmed_at = Time.current
  user.active = true
  user.onboarding_completed = true
  user.monthly_ai_limit = 10000.0
  user.ai_credits_used = 0.0
  user.stripe_enabled = false
  user.discount_code_used = false
end

puts "✅ Created #{User.where(role: ['admin', 'superadmin']).count} admin users"

# ============================================
# 2. SAMPLE USERS (Different Tiers)
# ============================================

puts "👥 Creating sample users for different subscription tiers..."

# Basic Users
basic_users = [
  { email: "paul.creator@example.com", first_name: "Paul", last_name: "Creator" },
  { email: "sarah.student@example.com", first_name: "Sarah", last_name: "Student" },
  { email: "mike.freelancer@example.com", first_name: "Mike", last_name: "Freelancer" }
]

basic_users.each do |user_data|
  User.find_or_create_by!(email: user_data[:email]) do |user|
    user.first_name = user_data[:first_name]
    user.last_name = user_data[:last_name]
    user.role = "user"
    user.subscription_tier = "basic"
    user.subscription_status = "active"
    user.password = "Password123!"
    user.password_confirmation = "Password123!"
    user.confirmed_at = Time.current
    user.active = true
    user.onboarding_completed = true
    user.monthly_ai_limit = 10.0
    user.ai_credits_used = rand(0.0..5.0).round(2)
    user.discount_code_used = false
  end
end

# Basic Users
basic_users = [
  { email: "maria.marketing@company.com", first_name: "Maria", last_name: "Martinez" },
  { email: "john.manager@startup.com", first_name: "John", last_name: "Manager" }
]

basic_users.each do |user_data|
  User.find_or_create_by!(email: user_data[:email]) do |user|
    user.first_name = user_data[:first_name]
    user.last_name = user_data[:last_name]
    user.role = "user"
    user.subscription_tier = "basic"
    user.subscription_status = "active"
    user.password = "Password123!"
    user.password_confirmation = "Password123!"
    user.confirmed_at = Time.current
    user.active = true
    user.onboarding_completed = true
    user.monthly_ai_limit = 100.0
    user.ai_credits_used = rand(10.0..50.0).round(2)
    user.stripe_enabled = false
    user.discount_code_used = [true, false].sample
  end
end

# Premium Users (with Google Sheets integration ready)
premium_users = [
  { 
    email: "david.architect@enterprise.com", 
    first_name: "David", 
    last_name: "Solutions",
    time_zone: "America/New_York"
  },
  { 
    email: "lisa.director@bigcorp.com", 
    first_name: "Lisa", 
    last_name: "Director",
    time_zone: "Europe/London"
  },
  {
    email: "carlos.manager@techcorp.com",
    first_name: "Carlos",
    last_name: "Manager", 
    time_zone: "America/Los_Angeles"
  }
]

premium_users.each do |user_data|
  User.find_or_create_by!(email: user_data[:email]) do |user|
    user.first_name = user_data[:first_name]
    user.last_name = user_data[:last_name]
    user.role = "user"
    user.subscription_tier = "premium"
    user.subscription_status = "active"
    user.password = "Password123!"
    user.password_confirmation = "Password123!"
    user.confirmed_at = Time.current
    user.active = true
    user.onboarding_completed = true
    user.monthly_ai_limit = 500.0
    user.ai_credits_used = rand(50.0..200.0).round(2)
    user.stripe_enabled = false
    user.discount_code_used = true
    user.preferences = {
      time_zone: user_data[:time_zone],
      export_preferences: {
        include_metadata: true,
        include_timestamps: true,
        date_format: '%Y-%m-%d %H:%M:%S'
      }
    }
  end
end

puts "✅ Created #{User.where(role: 'user').count} sample users across all tiers"

# ============================================
# 3. DISCOUNT CODES
# ============================================

puts "🎫 Creating discount codes..."

discount_codes_data = [
  {
    code: "WELCOME25",
    discount_percentage: 25,
    max_usage_count: 1000,
    expires_at: 6.months.from_now,
    active: true
  },
  {
    code: "EARLYBIRD50",
    discount_percentage: 50,
    max_usage_count: 100,
    expires_at: 3.months.from_now,
    active: true
  },
  {
    code: "BLACKFRIDAY40",
    discount_percentage: 40,
    max_usage_count: 500,
    expires_at: 1.month.from_now,
    active: true
  },
  {
    code: "STUDENT30",
    discount_percentage: 30,
    max_usage_count: nil, # Unlimited
    expires_at: 1.year.from_now,
    active: true
  },
  {
    code: "EXPIRED20",
    discount_percentage: 20,
    max_usage_count: 50,
    expires_at: 1.month.ago,
    active: false
  },
  {
    code: "BETA15",
    discount_percentage: 15,
    max_usage_count: 200,
    expires_at: 2.months.from_now,
    active: true
  }
]

discount_codes_data.each do |code_data|
  DiscountCode.find_or_create_by!(code: code_data[:code]) do |discount_code|
    discount_code.discount_percentage = code_data[:discount_percentage]
    discount_code.max_usage_count = code_data[:max_usage_count]
    discount_code.current_usage_count = 0
    discount_code.expires_at = code_data[:expires_at]
    discount_code.active = code_data[:active]
    discount_code.created_by = admin_user
  end
end

# Create some usage records for discount codes
puts "📊 Creating discount code usage records..."

# Simulate some discount code usage
used_codes = DiscountCode.where(code: ['WELCOME25', 'EARLYBIRD50', 'STUDENT30'])
premium_and_basic_users = User.where(subscription_tier: ['basic', 'premium'], discount_code_used: true)

premium_and_basic_users.limit(5).each do |user|
  next if user.discount_code_usage.present? # Skip if user already has a usage record
  
  discount_code = used_codes.sample
  
  DiscountCodeUsage.find_or_create_by!(user: user) do |usage|
    original_amount = [2999, 4999, 9999].sample # $29.99, $49.99, $99.99 in cents
    discount_amount = (original_amount * discount_code.discount_percentage / 100.0).round
    
    usage.discount_code = discount_code
    usage.original_amount = original_amount
    usage.discount_amount = discount_amount
    usage.final_amount = original_amount - discount_amount
    usage.subscription_id = "sub_#{SecureRandom.hex(12)}"
    usage.used_at = rand(1.month.ago..Time.current)
  end
  
  # Update the discount code usage count
  discount_code.increment!(:current_usage_count)
end

puts "✅ Created #{DiscountCode.count} discount codes with #{DiscountCodeUsage.count} usage records"

# ============================================
# 4. FORM TEMPLATES
# ============================================

puts "📋 Creating form templates..."

# Load existing templates from the current seeds file
load Rails.root.join('db', 'seeds.rb')

puts "✅ Form templates loaded from existing seeds file"

# ============================================
# 5. SAMPLE FORMS
# ============================================

puts "📝 Creating sample forms..."

sample_forms_data = [
  {
    name: "Customer Feedback Survey",
    description: "Collect valuable feedback from our customers",
    category: "customer_feedback",
    status: "published",
    ai_enabled: true,
    user_email: "maria.marketing@company.com"
  },
  {
    name: "Job Application Form",
    description: "Application form for software developer position",
    category: "job_application", 
    status: "published",
    ai_enabled: true,
    user_email: "david.architect@enterprise.com"
  },
  {
    name: "Event Registration",
    description: "Register for our upcoming tech conference",
    category: "event_registration",
    status: "published", 
    ai_enabled: false,
    user_email: "lisa.director@bigcorp.com"
  },
  {
    name: "Market Research Survey",
    description: "Understanding market trends and customer preferences",
    category: "survey",
    status: "published",
    ai_enabled: true,
    user_email: "carlos.manager@techcorp.com"
  },
  {
    name: "Lead Qualification Form",
    description: "BANT qualification for enterprise prospects",
    category: "lead_qualification",
    status: "published",
    ai_enabled: true,
    user_email: "david.architect@enterprise.com"
  },
  {
    name: "Product Demo Request",
    description: "Request a personalized product demonstration",
    category: "lead_qualification",
    status: "published",
    ai_enabled: true,
    user_email: "lisa.director@bigcorp.com"
  }
]

sample_forms_data.each do |form_data|
  user = User.find_by(email: form_data[:user_email])
  next unless user
  
  form = Form.find_or_create_by!(
    name: form_data[:name],
    user: user
  ) do |f|
    f.description = form_data[:description]
    f.category = form_data[:category]
    f.status = form_data[:status]
    f.ai_enabled = form_data[:ai_enabled]
    f.share_token = SecureRandom.urlsafe_base64(32)
    f.public = form_data[:status] == "published"
    f.accepts_responses = true
    f.published_at = form_data[:status] == "published" ? Time.current : nil
    f.views_count = rand(10..500)
    f.responses_count = rand(5..50)
    f.completion_count = rand(3..40)
    f.completion_rate = f.responses_count > 0 ? (f.completion_count.to_f / f.responses_count * 100).round(2) : 0.0
  end
  
  # Add some sample questions to each form
  if form.form_questions.empty?
    case form.category
    when "customer_feedback"
      questions = [
        { title: "How satisfied are you with our service?", question_type: "rating", position: 1, required: true, question_config: { min_value: 1, max_value: 5 } },
        { title: "What could we improve?", question_type: "text_long", position: 2, required: false, ai_enhanced: true },
        { title: "Would you recommend us to others?", question_type: "scale", position: 3, required: true, question_config: { min_value: 1, max_value: 10 } }
      ]
    when "job_application"
      questions = [
        { title: "Full Name", question_type: "text_short", position: 1, required: true },
        { title: "Email Address", question_type: "email", position: 2, required: true },
        { title: "Years of Experience", question_type: "single_choice", position: 3, required: true, question_config: { options: ["0-1 years", "2-5 years", "5+ years"] } },
        { title: "Why do you want this position?", question_type: "text_long", position: 4, required: true, ai_enhanced: true }
      ]
    when "event_registration"
      questions = [
        { title: "Full Name", question_type: "text_short", position: 1, required: true },
        { title: "Email Address", question_type: "email", position: 2, required: true },
        { title: "Company", question_type: "text_short", position: 3, required: false },
        { title: "Dietary Requirements", question_type: "multiple_choice", position: 4, required: false, question_config: { options: ["None", "Vegetarian", "Vegan", "Gluten-free"] } }
      ]
    when "survey", "lead_qualification"
      questions = [
        { title: "Age Range", question_type: "single_choice", position: 1, required: true, question_config: { options: ["18-25", "26-35", "36-45", "46+"] } },
        { title: "Industry", question_type: "single_choice", position: 2, required: true, question_config: { options: ["Technology", "Healthcare", "Finance", "Other"] } },
        { title: "What challenges do you face?", question_type: "text_long", position: 3, required: false, ai_enhanced: true }
      ]
    end
    
    questions.each do |q_data|
      form.form_questions.create!(
        title: q_data[:title],
        question_type: q_data[:question_type],
        position: q_data[:position],
        required: q_data[:required],
        ai_enhanced: q_data[:ai_enhanced] || false,
        question_config: q_data[:question_config] || {},
        validation_rules: {},
        display_options: {},
        ai_config: q_data[:ai_enhanced] ? { sentiment_analysis: true } : {}
      )
    end
  end
end

puts "✅ Created #{Form.count} sample forms with questions"

# ============================================
# 6. API TOKENS
# ============================================

puts "🔑 Creating API tokens..."

api_users = User.where(subscription_tier: ['basic', 'premium']).limit(3)

api_users.each do |user|
  ApiToken.find_or_create_by!(
    user: user,
    name: "Production API Token"
  ) do |token|
    token.token = SecureRandom.hex(32)
    token.permissions = { 
      forms: ['read', 'write'], 
      responses: ['read'], 
      analytics: ['read'] 
    }
    token.active = true
    token.expires_at = 1.year.from_now
    token.usage_count = rand(0..100)
    token.last_used_at = rand(1.week.ago..Time.current)
  end
end

puts "✅ Created #{ApiToken.count} API tokens"

# ============================================
# 7. AUDIT LOGS
# ============================================

puts "📋 Creating audit logs..."

audit_events = [
  'user_login', 'user_logout', 'form_created', 'form_published', 
  'discount_code_created', 'discount_code_used', 'user_registered',
  'admin_login', 'settings_updated', 'api_token_created'
]

50.times do
  AuditLog.create!(
    event_type: audit_events.sample,
    user: User.all.sample,
    ip_address: "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
    details: {
      user_agent: "Mozilla/5.0 (compatible; AgentForm/1.0)",
      timestamp: rand(1.month.ago..Time.current),
      success: [true, false].sample
    },
    created_at: rand(1.month.ago..Time.current)
  )
end

puts "✅ Created #{AuditLog.count} audit log entries"

# ============================================
# 8. FORM ANALYTICS
# ============================================

puts "📊 Creating form analytics..."

Form.published.each do |form|
  # Create daily analytics for the last 30 days
  30.times do |i|
    date = i.days.ago.to_date
    
    FormAnalytic.find_or_create_by!(
      form: form,
      date: date,
      period_type: "daily"
    ) do |analytic|
      views = rand(5..100)
      started = rand(1..views)
      completed = rand(1..started)
      
      analytic.views_count = views
      analytic.unique_views_count = (views * 0.8).round
      analytic.started_responses_count = started
      analytic.completed_responses_count = completed
      analytic.abandoned_responses_count = started - completed
      analytic.conversion_rate = started > 0 ? (completed.to_f / started * 100).round(2) : 0.0
      analytic.completion_rate = views > 0 ? (completed.to_f / views * 100).round(2) : 0.0
      analytic.abandonment_rate = started > 0 ? ((started - completed).to_f / started * 100).round(2) : 0.0
      analytic.avg_completion_time = rand(60..600) # seconds
      analytic.median_completion_time = rand(45..400)
      analytic.avg_time_per_question = rand(10..60)
      analytic.validation_errors_count = rand(0..10)
      analytic.skip_count = rand(0..5)
      
      if form.ai_enabled?
        analytic.ai_analyses_count = rand(0..completed)
        analytic.avg_ai_confidence = rand(0.6..0.95).round(2)
        analytic.qualified_leads_count = rand(0..completed)
        analytic.lead_qualification_rate = completed > 0 ? (analytic.qualified_leads_count.to_f / completed * 100).round(2) : 0.0
      end
      
      analytic.traffic_sources = {
        "direct" => rand(20..40),
        "social" => rand(10..30), 
        "search" => rand(15..35),
        "email" => rand(5..20)
      }
      
      analytic.device_breakdown = {
        "desktop" => rand(40..70),
        "mobile" => rand(25..50),
        "tablet" => rand(5..15)
      }
      
      analytic.country_breakdown = {
        "US" => rand(40..60),
        "CA" => rand(10..20),
        "UK" => rand(8..15),
        "AU" => rand(5..12)
      }
    end
  end
end

puts "✅ Created form analytics for #{Form.published.count} forms"

# ============================================
# 9. SAMPLE FORM RESPONSES
# ============================================

puts "💬 Creating sample form responses..."

Form.published.limit(3).each do |form|
  # Create some completed responses
  rand(5..15).times do
    response = FormResponse.create!(
      form: form,
      user_id: [nil, User.where(role: 'user').sample&.id].sample, # Some anonymous, some logged in
      session_id: SecureRandom.hex(16),
      fingerprint: SecureRandom.hex(8),
      ip_address: "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
      status: "completed",
      progress_percentage: 100.0,
      started_at: rand(1.month.ago..1.day.ago),
      completed_at: rand(1.day.ago..Time.current),
      time_spent_seconds: rand(120..1800),
      qualified_lead: [true, false].sample,
      gdpr_consent: true,
      country: ["US", "CA", "UK", "AU"].sample,
      region: ["California", "Ontario", "London", "Sydney"].sample
    )
    
    # Add AI analysis for AI-enabled forms
    if form.ai_enabled?
      response.update!(
        ai_analysis: {
          sentiment: ["positive", "neutral", "negative"].sample,
          keywords: ["quality", "service", "price", "support"].sample(2),
          confidence: rand(0.7..0.95).round(2)
        },
        ai_score: rand(0.6..0.95).round(2),
        ai_classification: ["high_value", "medium_value", "low_value"].sample,
        ai_summary: "AI-generated summary of the response content and insights."
      )
    end
    
    # Create question responses
    form.form_questions.each do |question|
      answer_data = case question.question_type
      when "text_short"
        { text: "Sample short answer" }
      when "text_long" 
        { text: "This is a longer sample answer with more detailed information about the topic." }
      when "email"
        { text: "user@example.com" }
      when "rating"
        { rating: rand(1..5) }
      when "scale"
        { scale: rand(1..10) }
      when "single_choice"
        { choice: "Option #{rand(1..3)}" }
      when "multiple_choice"
        { choices: ["Option 1", "Option 2"].sample(rand(1..2)) }
      else
        { text: "Sample answer" }
      end
      
      QuestionResponse.create!(
        form_response: response,
        form_question: question,
        answer_text: answer_data[:text],
        answer_data: answer_data,
        time_spent_seconds: rand(10..120),
        answer_valid: true,
        quality_score: rand(0.7..1.0).round(2),
        ai_confidence: question.ai_enhanced? ? rand(0.6..0.95).round(2) : nil,
        ai_analysis: question.ai_enhanced? ? { sentiment: "positive", confidence: 0.85 } : {}
      )
    end
  end
  
  # Create some in-progress responses
  rand(2..5).times do
    FormResponse.create!(
      form: form,
      session_id: SecureRandom.hex(16),
      fingerprint: SecureRandom.hex(8),
      ip_address: "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
      status: "in_progress",
      current_question_position: rand(1..form.form_questions.count),
      progress_percentage: rand(10.0..80.0).round(2),
      started_at: rand(1.week.ago..Time.current),
      time_spent_seconds: rand(30..300),
      last_activity_at: rand(1.hour.ago..Time.current)
    )
  end
end

puts "✅ Created sample form responses with question answers"

# ============================================
# 10. GOOGLE SHEETS INTEGRATION DATA
# ============================================

puts "📊 Creating Google Sheets integration sample data..."

# Note: In production, these would be created through OAuth flow
# This is just for demonstration and testing purposes
premium_users_for_google = User.where(subscription_tier: 'premium').limit(2)

premium_users_for_google.each_with_index do |user, index|
  # Create sample Google integration (normally created via OAuth)
  # In real production, this would be created through the OAuth callback
  puts "  - Setting up Google integration sample data for #{user.email}"
  
  # Create sample export jobs to show history
  user.forms.published.limit(2).each do |form|
    next if form.form_responses.empty?
    
    # Create a completed export job
    ExportJob.find_or_create_by!(
      user: user,
      form: form,
      job_id: SecureRandom.uuid,
      export_type: 'google_sheets'
    ) do |job|
      job.status = 'completed'
      job.configuration = {
        include_metadata: true,
        include_timestamps: true,
        include_dynamic_questions: true,
        date_format: '%Y-%m-%d %H:%M:%S'
      }
      job.spreadsheet_id = "1#{SecureRandom.hex(21)}" # Fake Google Sheets ID format
      job.spreadsheet_url = "https://docs.google.com/spreadsheets/d/#{job.spreadsheet_id}/edit"
      job.records_exported = form.form_responses.count
      job.started_at = rand(1.week.ago..2.days.ago)
      job.completed_at = job.started_at + rand(30..300).seconds
    end
    
    # Create a recent pending export job
    ExportJob.find_or_create_by!(
      user: user,
      form: form,
      job_id: SecureRandom.uuid,
      export_type: 'google_sheets'
    ) do |job|
      job.status = 'pending'
      job.configuration = {
        include_metadata: true,
        include_timestamps: true,
        include_dynamic_questions: false,
        date_format: '%Y-%m-%d %H:%M:%S'
      }
      job.started_at = rand(1.hour.ago..Time.current)
    end
  end
end

puts "✅ Created Google Sheets integration sample data"

# ============================================
# 11. FINAL STATISTICS
# ============================================

puts "\n🎉 Production database seeding completed!"
puts "=" * 50

puts "📊 FINAL STATISTICS:"
puts "👤 Users: #{User.count} (#{User.where(role: 'admin').count} admins, #{User.where(role: 'user').count} regular users)"
puts "🎫 Discount Codes: #{DiscountCode.count} (#{DiscountCode.where(active: true).count} active)"
puts "💳 Discount Code Usages: #{DiscountCodeUsage.count}"
puts "📋 Form Templates: #{FormTemplate.count}"
puts "📝 Forms: #{Form.count} (#{Form.where(status: 'published').count} published)"
puts "❓ Form Questions: #{FormQuestion.count}"
puts "💬 Form Responses: #{FormResponse.count} (#{FormResponse.where(status: 'completed').count} completed)"
puts "🔑 API Tokens: #{ApiToken.count}"
puts "📋 Audit Logs: #{AuditLog.count}"
puts "📊 Form Analytics: #{FormAnalytic.count}"
puts "📤 Export Jobs: #{ExportJob.count} (Google Sheets integration ready)"
puts "🔗 Google Integrations: #{GoogleIntegration.count} (OAuth connections)"

puts "\n🔐 ADMIN CREDENTIALS:"
puts "Admin: admin@agentform.com / AdminPassword123!"
puts "Super Admin: superadmin@agentform.com / SuperAdminPassword123!"

puts "\n✅ Database is ready for production deployment!"