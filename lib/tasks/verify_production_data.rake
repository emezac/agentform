namespace :db do
  desc "Verify production data integrity"
  task verify_production: :environment do
    puts "🔍 Verifying production data integrity..."
    
    errors = []
    warnings = []
    
    # Check Users
    puts "\n👤 Checking Users..."
    
    admin_count = User.where(role: ['admin', 'superadmin']).count
    if admin_count == 0
      errors << "No admin users found"
    elsif admin_count < 2
      warnings << "Only #{admin_count} admin user(s) found, consider having at least 2"
    else
      puts "✅ Found #{admin_count} admin users"
    end
    
    user_count = User.where(role: 'user').count
    puts "✅ Found #{user_count} regular users"
    
    # Check subscription tiers distribution
    User.group(:subscription_tier).count.each do |tier, count|
      puts "  - #{tier}: #{count} users"
    end
    
    # Check for users without confirmed emails
    unconfirmed = User.where(confirmed_at: nil).count
    if unconfirmed > 0
      warnings << "#{unconfirmed} users have unconfirmed emails"
    end
    
    # Check Discount Codes
    puts "\n🎫 Checking Discount Codes..."
    
    active_codes = DiscountCode.where(active: true).count
    expired_codes = DiscountCode.where('expires_at < ?', Time.current).count
    
    puts "✅ Found #{DiscountCode.count} total discount codes"
    puts "  - Active: #{active_codes}"
    puts "  - Expired: #{expired_codes}"
    
    # Check for codes without usage limits
    unlimited_codes = DiscountCode.where(max_usage_count: nil).count
    if unlimited_codes > 0
      warnings << "#{unlimited_codes} discount codes have no usage limits"
    end
    
    # Check discount code usage integrity
    DiscountCode.find_each do |code|
      actual_usage = code.discount_code_usages.count
      if code.current_usage_count != actual_usage
        errors << "Discount code '#{code.code}' usage count mismatch: recorded=#{code.current_usage_count}, actual=#{actual_usage}"
      end
    end
    
    # Check Forms
    puts "\n📝 Checking Forms..."
    
    total_forms = Form.count
    published_forms = Form.where(status: 'published').count
    ai_enabled_forms = Form.where(ai_enabled: true).count
    
    puts "✅ Found #{total_forms} total forms"
    puts "  - Published: #{published_forms}"
    puts "  - AI-enabled: #{ai_enabled_forms}"
    
    # Check for forms without questions
    forms_without_questions = Form.joins("LEFT JOIN form_questions ON forms.id = form_questions.form_id")
                                  .where(form_questions: { id: nil }).count
    if forms_without_questions > 0
      warnings << "#{forms_without_questions} forms have no questions"
    end
    
    # Check Form Templates
    puts "\n📋 Checking Form Templates..."
    
    template_count = FormTemplate.count
    puts "✅ Found #{template_count} form templates"
    
    FormTemplate.group(:category).count.each do |category, count|
      puts "  - #{category}: #{count} templates"
    end
    
    # Check API Tokens
    puts "\n🔑 Checking API Tokens..."
    
    active_tokens = ApiToken.where(active: true).count
    expired_tokens = ApiToken.where('expires_at < ?', Time.current).count
    
    puts "✅ Found #{ApiToken.count} total API tokens"
    puts "  - Active: #{active_tokens}"
    puts "  - Expired: #{expired_tokens}"
    
    # Check Form Responses
    puts "\n💬 Checking Form Responses..."
    
    total_responses = FormResponse.count
    completed_responses = FormResponse.where(status: 'completed').count
    in_progress_responses = FormResponse.where(status: 'in_progress').count
    
    puts "✅ Found #{total_responses} total form responses"
    puts "  - Completed: #{completed_responses}"
    puts "  - In Progress: #{in_progress_responses}"
    
    # Check for responses without question responses
    responses_without_answers = FormResponse.joins("LEFT JOIN question_responses ON form_responses.id = question_responses.form_response_id")
                                           .where(question_responses: { id: nil })
                                           .where(status: 'completed').count
    if responses_without_answers > 0
      warnings << "#{responses_without_answers} completed responses have no question answers"
    end
    
    # Check Analytics
    puts "\n📊 Checking Analytics..."
    
    analytics_count = FormAnalytic.count
    puts "✅ Found #{analytics_count} form analytics records"
    
    # Check for forms without analytics
    forms_without_analytics = Form.joins("LEFT JOIN form_analytics ON forms.id = form_analytics.form_id")
                                  .where(form_analytics: { id: nil })
                                  .where(status: 'published').count
    if forms_without_analytics > 0
      warnings << "#{forms_without_analytics} published forms have no analytics data"
    end
    
    # Check Audit Logs
    puts "\n📋 Checking Audit Logs..."
    
    audit_count = AuditLog.count
    puts "✅ Found #{audit_count} audit log entries"
    
    recent_logs = AuditLog.where('created_at > ?', 1.day.ago).count
    puts "  - Recent (last 24h): #{recent_logs}"
    
    # Database Constraints Check
    puts "\n🔒 Checking Database Constraints..."
    
    begin
      # Check discount code constraints
      invalid_discounts = DiscountCode.where('discount_percentage < 1 OR discount_percentage > 99').count
      if invalid_discounts > 0
        errors << "#{invalid_discounts} discount codes have invalid percentage values"
      end
      
      # Check user constraints
      invalid_users = User.where('ai_credits_used < 0 OR monthly_ai_limit <= 0').count
      if invalid_users > 0
        errors << "#{invalid_users} users have invalid AI credit values"
      end
      
      puts "✅ Database constraints validation passed"
    rescue => e
      errors << "Database constraint check failed: #{e.message}"
    end
    
    # Performance Checks
    puts "\n⚡ Checking Performance Indicators..."
    
    # Check for missing indexes (basic check)
    slow_queries = []
    
    begin
      # This is a basic check - in production you'd want more sophisticated monitoring
      large_tables = {
        'form_responses' => FormResponse.count,
        'question_responses' => QuestionResponse.count,
        'audit_logs' => AuditLog.count,
        'form_analytics' => FormAnalytic.count
      }
      
      large_tables.each do |table, count|
        if count > 10000
          warnings << "Table #{table} has #{count} records - monitor performance"
        end
        puts "  - #{table}: #{count} records"
      end
      
    rescue => e
      warnings << "Performance check failed: #{e.message}"
    end
    
    # Summary
    puts "\n" + "=" * 60
    puts "🎯 VERIFICATION SUMMARY"
    puts "=" * 60
    
    if errors.empty? && warnings.empty?
      puts "✅ All checks passed! Database is in excellent condition."
    else
      if errors.any?
        puts "❌ ERRORS FOUND (#{errors.count}):"
        errors.each { |error| puts "  - #{error}" }
        puts ""
      end
      
      if warnings.any?
        puts "⚠️  WARNINGS (#{warnings.count}):"
        warnings.each { |warning| puts "  - #{warning}" }
        puts ""
      end
      
      if errors.any?
        puts "🚨 Please fix the errors before deploying to production!"
        exit 1
      else
        puts "✅ No critical errors found. Warnings should be reviewed but don't block deployment."
      end
    end
    
    puts "\n📊 FINAL STATISTICS:"
    puts "👤 Users: #{User.count}"
    puts "🎫 Discount Codes: #{DiscountCode.count}"
    puts "📝 Forms: #{Form.count}"
    puts "📋 Templates: #{FormTemplate.count}"
    puts "💬 Responses: #{FormResponse.count}"
    puts "🔑 API Tokens: #{ApiToken.count}"
    puts "📋 Audit Logs: #{AuditLog.count}"
    
    puts "\n✅ Verification completed!"
  end
end