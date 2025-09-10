# db/seeds_templates_expanded.rb

puts "Creating comprehensive form templates collection..."

# ============================================
# 1. MARKET RESEARCH SURVEYS
# ============================================

# 1.1 Deep Market Research Survey
FormTemplate.find_or_create_by!(name: "Comprehensive Market Research Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Discover key insights from your target market with demographic, psychographic, and behavioral questions. Perfect for understanding consumer preferences and market trends."
  template.template_data = {
    "form" => {
      "name" => "Market Research Survey",
      "category" => "survey",
      "ai_enabled" => true,
    },
    "questions" => [
      { "title" => "Age Range", "question_type" => "single_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"] } },
      { "title" => "Gender Identity", "question_type" => "single_choice", "position" => 2, "required" => false, "configuration" => { "options" => ["Male", "Female", "Non-binary", "Prefer not to say", "Other"] } },
      { "title" => "Annual Household Income", "question_type" => "single_choice", "position" => 3, "required" => false, "configuration" => { "options" => ["Under $25,000", "$25,000-$49,999", "$50,000-$74,999", "$75,000-$99,999", "$100,000-$149,999", "$150,000+"] } },
      { "title" => "Which social media platforms do you use weekly?", "question_type" => "multiple_choice", "position" => 4, "required" => true, "configuration" => { "options" => ["Facebook", "Instagram", "TikTok", "LinkedIn", "X (Twitter)", "YouTube", "Pinterest", "Snapchat", "Other"] } },
      { "title" => "On a scale of 1-10, how important is price when purchasing products like ours?", "question_type" => "scale", "position" => 5, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 10, "min_label" => "Not Important", "max_label" => "Extremely Important" } },
      { "title" => "Rank these factors by importance in your purchase decisions", "question_type" => "ranking", "position" => 6, "required" => true, "configuration" => { "items" => ["Price", "Quality", "Brand Reputation", "Customer Reviews", "Recommendations", "Environmental Impact"] } },
      { "title" => "What word best describes your experience with similar products?", "question_type" => "text_short", "position" => 7, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } },
      { "title" => "If you could change one thing about existing products in this market, what would it be?", "question_type" => "text_long", "position" => 8, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true, "theme_extraction" => true } }
    ]
  }
end

# 1.2 Customer Persona Research
FormTemplate.find_or_create_by!(name: "Customer Persona Development Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Build detailed customer personas with lifestyle, motivation, and behavior insights to better understand your target audience."
  template.template_data = {
    "form" => { "name" => "Customer Persona Research", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "What is your primary occupation?", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "What are your top 3 hobbies or interests?", "question_type" => "text_long", "position" => 2, "required" => true },
      { "title" => "How do you typically discover new products or services?", "question_type" => "multiple_choice", "position" => 3, "required" => true, "configuration" => { "options" => ["Social media", "Search engines", "Friends/family recommendations", "Online reviews", "TV/radio ads", "Email marketing", "Influencers", "In-store discovery"] } },
      { "title" => "What motivates you most when making purchases?", "question_type" => "single_choice", "position" => 4, "required" => true, "configuration" => { "options" => ["Solving a problem", "Status/prestige", "Convenience", "Value for money", "Supporting causes I care about", "Trying something new"] } },
      { "title" => "Rate your tech-savviness", "question_type" => "scale", "position" => 5, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "min_label" => "Not tech-savvy", "max_label" => "Very tech-savvy" } },
      { "title" => "Describe your biggest challenge or frustration in daily life", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true, "keyword_extraction" => true } }
    ]
  }
end

# 1.3 Competitive Analysis Survey
FormTemplate.find_or_create_by!(name: "Competitive Analysis Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Understand how customers perceive your competitors and identify market opportunities."
  template.template_data = {
    "form" => { "name" => "Competitive Analysis", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "Which brands in our industry are you familiar with?", "question_type" => "multiple_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Brand A", "Brand B", "Brand C", "Brand D", "Brand E", "Other (please specify)"] } },
      { "title" => "Rate each brand you're familiar with", "question_type" => "matrix", "position" => 2, "required" => true, "configuration" => { "rows" => ["Brand A", "Brand B", "Brand C", "Brand D"], "columns" => ["Poor", "Fair", "Good", "Very Good", "Excellent", "Not Familiar"] } },
      { "title" => "What do you like most about your preferred brand?", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } },
      { "title" => "What gaps do you see in the current market offerings?", "question_type" => "text_long", "position" => 4, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } }
    ]
  }
end

# ============================================
# 2. CUSTOMER SATISFACTION (CX) SURVEYS
# ============================================

# 2.1 Net Promoter Score (NPS) Survey
FormTemplate.find_or_create_by!(name: "Net Promoter Score (NPS) Survey") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Measure customer loyalty and identify promoters, passives, and detractors with the industry-standard NPS methodology."
  template.template_data = {
    "form" => { "name" => "NPS Survey", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "On a scale of 0-10, how likely are you to recommend our company to a friend or colleague?", "question_type" => "scale", "position" => 1, "required" => true, "configuration" => { "min_value" => 0, "max_value" => 10, "min_label" => "Not at all likely", "max_label" => "Extremely likely" } },
      { "title" => "What is the primary reason for your score?", "question_type" => "text_long", "position" => 2, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true, "keyword_extraction" => true } },
      { "title" => "How can we improve your experience?", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } }
    ]
  }
end

# 2.2 Customer Effort Score (CES)
FormTemplate.find_or_create_by!(name: "Customer Effort Score Survey") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Measure how easy it is for customers to get their issues resolved or complete their desired actions."
  template.template_data = {
    "form" => { "name" => "Customer Effort Survey", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "How easy was it to resolve your issue today?", "question_type" => "scale", "position" => 1, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 7, "min_label" => "Very Difficult", "max_label" => "Very Easy" } },
      { "title" => "Which channels did you use to resolve your issue?", "question_type" => "multiple_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Phone", "Email", "Live Chat", "Help Center/FAQ", "Social Media", "In-person", "Mobile App"] } },
      { "title" => "What made the process difficult? (if applicable)", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } }
    ]
  }
end

# 2.3 Customer Satisfaction (CSAT) Survey
FormTemplate.find_or_create_by!(name: "Customer Satisfaction Survey") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Comprehensive customer satisfaction survey covering product, service, and overall experience."
  template.template_data = {
    "form" => { "name" => "Customer Satisfaction Survey", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "Overall, how satisfied are you with our product/service?", "question_type" => "rating", "position" => 1, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "labels" => ["Very Unsatisfied", "Unsatisfied", "Neutral", "Satisfied", "Very Satisfied"] } },
      { "title" => "Rate the following aspects of our service:", "question_type" => "matrix", "position" => 2, "required" => true, "configuration" => { "rows" => ["Product Quality", "Customer Service", "Value for Money", "Delivery/Timeliness", "User Experience"], "columns" => ["Poor", "Fair", "Good", "Very Good", "Excellent"] } },
      { "title" => "What did we do well?", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } },
      { "title" => "What could we improve?", "question_type" => "text_long", "position" => 4, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } },
      { "title" => "Would you purchase from us again?", "question_type" => "single_choice", "position" => 5, "required" => true, "configuration" => { "options" => ["Definitely yes", "Probably yes", "Not sure", "Probably not", "Definitely not"] } }
    ]
  }
end

# ============================================
# 3. EMPLOYEE EXPERIENCE (EX) SURVEYS
# ============================================

# 3.1 Employee Net Promoter Score (eNPS)
FormTemplate.find_or_create_by!(name: "Employee Net Promoter Score Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Measure employee loyalty and their likelihood to recommend your organization as a great place to work."
  template.template_data = {
    "form" => { "name" => "eNPS Survey", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "On a scale of 0-10, how likely are you to recommend this company as a great place to work?", "question_type" => "scale", "position" => 1, "required" => true, "configuration" => { "min_value" => 0, "max_value" => 10, "min_label" => "Not at all likely", "max_label" => "Extremely likely" } },
      { "title" => "What is the main reason for your score?", "question_type" => "text_long", "position" => 2, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true, "keyword_extraction" => true } },
      { "title" => "What would make this a better place to work?", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } }
    ]
  }
end

# 3.2 Employee Engagement Survey
FormTemplate.find_or_create_by!(name: "Employee Engagement Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Comprehensive survey to measure employee engagement, satisfaction, and organizational commitment."
  template.template_data = {
    "form" => { "name" => "Employee Engagement Survey", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "Department", "question_type" => "single_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Sales", "Marketing", "Engineering", "HR", "Finance", "Operations", "Customer Service", "Other"] } },
      { "title" => "How long have you been with the company?", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Less than 6 months", "6 months - 1 year", "1-2 years", "2-5 years", "5+ years"] } },
      { "title" => "Rate your agreement with these statements:", "question_type" => "matrix", "position" => 3, "required" => true, "configuration" => { "rows" => ["I understand how my work contributes to company goals", "I have the resources needed to do my job well", "My manager provides clear direction", "I feel valued for my contributions", "I see opportunities for career growth"], "columns" => ["Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"] } },
      { "title" => "How satisfied are you with:", "question_type" => "matrix", "position" => 4, "required" => true, "configuration" => { "rows" => ["Work-life balance", "Compensation", "Benefits", "Professional development", "Recognition"], "columns" => ["Very Unsatisfied", "Unsatisfied", "Neutral", "Satisfied", "Very Satisfied"] } },
      { "title" => "What motivates you most at work?", "question_type" => "text_long", "position" => 5, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "What would you change to improve the workplace?", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } }
    ]
  }
end

# 3.3 360-Degree Feedback Survey
FormTemplate.find_or_create_by!(name: "360-Degree Feedback Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Multi-source feedback evaluation for leadership and professional development assessment."
  template.template_data = {
    "form" => { "name" => "360-Degree Feedback", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "Your relationship to the person being evaluated", "question_type" => "single_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Direct Manager", "Peer/Colleague", "Direct Report", "Internal Customer", "Self-Assessment"] } },
      { "title" => "Rate the following leadership competencies:", "question_type" => "matrix", "position" => 2, "required" => true, "configuration" => { "rows" => ["Communication Skills", "Team Leadership", "Strategic Thinking", "Problem Solving", "Adaptability", "Emotional Intelligence"], "columns" => ["Well Below Expected", "Below Expected", "Meets Expected", "Above Expected", "Role Model"] } },
      { "title" => "Rate these professional skills:", "question_type" => "matrix", "position" => 3, "required" => true, "configuration" => { "rows" => ["Technical Expertise", "Quality of Work", "Productivity", "Initiative", "Collaboration"], "columns" => ["Well Below Expected", "Below Expected", "Meets Expected", "Above Expected", "Role Model"] } },
      { "title" => "What are this person's greatest strengths?", "question_type" => "text_long", "position" => 4, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "What areas should this person focus on for development?", "question_type" => "text_long", "position" => 5, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } }
    ]
  }
end

# 3.4 Pulse Survey
FormTemplate.find_or_create_by!(name: "Weekly Pulse Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Quick weekly check-in to track employee mood, workload, and immediate concerns."
  template.template_data = {
    "form" => { "name" => "Weekly Pulse Check", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "How are you feeling about work this week?", "question_type" => "scale", "position" => 1, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "min_label" => "😞 Struggling", "max_label" => "😊 Thriving" } },
      { "title" => "How manageable is your current workload?", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Too light", "Just right", "A bit heavy", "Overwhelming", "Unmanageable"] } },
      { "title" => "Any immediate concerns or blockers?", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } }
    ]
  }
end

# ============================================
# 4. EVENT & REGISTRATION FORMS
# ============================================

# 4.1 Event Registration
FormTemplate.find_or_create_by!(name: "Event Registration Form") do |template|
  template.category = "event_registration"
  template.visibility = "template_public"
  template.description = "Comprehensive event registration form with attendee preferences, dietary requirements, and payment processing."
  template.template_data = {
    "form" => { "name" => "Event Registration", "category" => "event_registration", "ai_enabled" => false },
    "questions" => [
      { "title" => "Full Name", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "Email Address", "question_type" => "email", "position" => 2, "required" => true },
      { "title" => "Phone Number", "question_type" => "phone", "position" => 3, "required" => true },
      { "title" => "Company/Organization", "question_type" => "text_short", "position" => 4, "required" => false },
      { "title" => "Job Title", "question_type" => "text_short", "position" => 5, "required" => false },
      { "title" => "Which sessions interest you most?", "question_type" => "checkbox", "position" => 6, "required" => true, "configuration" => { "options" => ["Keynote Presentation", "Panel Discussion", "Networking Session", "Hands-on Workshops", "Product Demo", "Q&A Session"] } },
      { "title" => "Ticket Type", "question_type" => "single_choice", "position" => 7, "required" => true, "configuration" => { "options" => ["Early Bird - $99", "Regular - $149", "VIP - $299", "Student - $49", "Group Rate (5+) - $89 each"] } },
      { "title" => "Dietary Requirements", "question_type" => "multiple_choice", "position" => 8, "required" => false, "configuration" => { "options" => ["None", "Vegetarian", "Vegan", "Gluten-free", "Dairy-free", "Nut allergies", "Other (please specify)"] } },
      { "title" => "How did you hear about this event?", "question_type" => "single_choice", "position" => 9, "required" => false, "configuration" => { "options" => ["Social media", "Email marketing", "Colleague/friend", "Website", "Search engine", "Advertisement", "Previous event", "Other"] } },
      { "title" => "Payment", "question_type" => "payment", "position" => 10, "required" => true }
    ]
  }
end

# 4.2 Webinar Registration
FormTemplate.find_or_create_by!(name: "Webinar Registration Form") do |template|
  template.category = "event_registration"
  template.visibility = "template_public"
  template.description = "Simple webinar registration form with attendee interests and follow-up preferences."
  template.template_data = {
    "form" => { "name" => "Webinar Registration", "category" => "event_registration", "ai_enabled" => false },
    "questions" => [
      { "title" => "Full Name", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "Email Address", "question_type" => "email", "position" => 2, "required" => true },
      { "title" => "Company", "question_type" => "text_short", "position" => 3, "required" => false },
      { "title" => "Industry", "question_type" => "single_choice", "position" => 4, "required" => false, "configuration" => { "options" => ["Technology", "Healthcare", "Finance", "Education", "Retail", "Manufacturing", "Consulting", "Non-profit", "Government", "Other"] } },
      { "title" => "What do you hope to learn from this webinar?", "question_type" => "text_long", "position" => 5, "required" => false },
      { "title" => "Would you like to receive the recording?", "question_type" => "single_choice", "position" => 6, "required" => true, "configuration" => { "options" => ["Yes", "No"] } }
    ]
  }
end

# ============================================
# 5. HR & RECRUITMENT FORMS
# ============================================

# 5.1 Job Application Form
FormTemplate.find_or_create_by!(name: "Comprehensive Job Application Form") do |template|
  template.category = "job_application"
  template.visibility = "template_public"
  template.description = "Complete job application form with resume upload, experience assessment, and screening questions."
  template.template_data = {
    "form" => { "name" => "Job Application", "category" => "job_application", "ai_enabled" => true },
    "questions" => [
      { "title" => "Full Name", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "Email Address", "question_type" => "email", "position" => 2, "required" => true },
      { "title" => "Phone Number", "question_type" => "phone", "position" => 3, "required" => true },
      { "title" => "LinkedIn Profile URL", "question_type" => "url", "position" => 4, "required" => false },
      { "title" => "Resume/CV", "question_type" => "file_upload", "position" => 5, "required" => true, "configuration" => { "allowed_types" => ["pdf", "doc", "docx"], "max_size" => "10MB" } },
      { "title" => "Cover Letter", "question_type" => "file_upload", "position" => 6, "required" => false, "configuration" => { "allowed_types" => ["pdf", "doc", "docx"], "max_size" => "10MB" } },
      { "title" => "Years of Relevant Experience", "question_type" => "single_choice", "position" => 7, "required" => true, "configuration" => { "options" => ["Entry level (0-1 years)", "Junior (1-3 years)", "Mid-level (3-5 years)", "Senior (5-8 years)", "Expert (8+ years)"] } },
      { "title" => "Expected Salary Range", "question_type" => "single_choice", "position" => 8, "required" => false, "configuration" => { "options" => ["$40,000-$60,000", "$60,000-$80,000", "$80,000-$100,000", "$100,000-$120,000", "$120,000+", "Negotiable"] } },
      { "title" => "When could you start?", "question_type" => "single_choice", "position" => 9, "required" => true, "configuration" => { "options" => ["Immediately", "2 weeks notice", "1 month notice", "2+ months notice"] } },
      { "title" => "Are you authorized to work in this country?", "question_type" => "single_choice", "position" => 10, "required" => true, "configuration" => { "options" => ["Yes", "No", "Require sponsorship"] } },
      { "title" => "Why are you interested in this position?", "question_type" => "text_long", "position" => 11, "required" => true, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "Digital Signature", "question_type" => "signature", "position" => 12, "required" => true }
    ]
  }
end

# 5.2 Exit Interview Survey
FormTemplate.find_or_create_by!(name: "Exit Interview Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Comprehensive exit interview to understand reasons for departure and gather improvement insights."
  template.template_data = {
    "form" => { "name" => "Exit Interview", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "Department", "question_type" => "single_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Sales", "Marketing", "Engineering", "HR", "Finance", "Operations", "Customer Service", "Other"] } },
      { "title" => "Length of Employment", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Less than 6 months", "6 months - 1 year", "1-2 years", "2-5 years", "5+ years"] } },
      { "title" => "Primary reason for leaving", "question_type" => "single_choice", "position" => 3, "required" => true, "configuration" => { "options" => ["Better opportunity", "Compensation", "Work-life balance", "Management issues", "Company culture", "Career advancement", "Relocation", "Personal reasons", "Other"] } },
      { "title" => "Rate your satisfaction with:", "question_type" => "matrix", "position" => 4, "required" => true, "configuration" => { "rows" => ["Job responsibilities", "Management", "Team relationships", "Compensation", "Benefits", "Work environment"], "columns" => ["Very Unsatisfied", "Unsatisfied", "Neutral", "Satisfied", "Very Satisfied"] } },
      { "title" => "What could the company have done to retain you?", "question_type" => "text_long", "position" => 5, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } },
      { "title" => "What advice would you give to improve the organization?", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "Would you recommend this company as a place to work?", "question_type" => "single_choice", "position" => 7, "required" => true, "configuration" => { "options" => ["Definitely yes", "Probably yes", "Not sure", "Probably not", "Definitely not"] } }
    ]
  }
end

# ============================================
# 6. PRODUCT FEEDBACK FORMS
# ============================================

# 6.1 Product Feedback Survey
FormTemplate.find_or_create_by!(name: "Detailed Product Feedback Survey") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Comprehensive product feedback survey covering features, usability, and improvement suggestions."
  template.template_data = {
    "form" => { "name" => "Product Feedback", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "How long have you been using our product?", "question_type" => "single_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Less than 1 month", "1-3 months", "3-6 months", "6-12 months", "1+ years"] } },
      { "title" => "How frequently do you use our product?", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Daily", "Weekly", "Monthly", "Occasionally", "Rarely"] } },
      { "title" => "Overall satisfaction with the product", "question_type" => "rating", "position" => 3, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "labels" => ["Very Unsatisfied", "Unsatisfied", "Neutral", "Satisfied", "Very Satisfied"] } },
      { "title" => "Rate the following product aspects:", "question_type" => "matrix", "position" => 4, "required" => true, "configuration" => { "rows" => ["Ease of Use", "Features & Functionality", "Performance & Speed", "Design & Interface", "Value for Money", "Customer Support"], "columns" => ["Poor", "Fair", "Good", "Very Good", "Excellent"] } },
      { "title" => "Which feature do you find most valuable?", "question_type" => "text_short", "position" => 5, "required" => false },
      { "title" => "What features are missing that you would like to see?", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "Describe any issues or frustrations you've experienced", "question_type" => "text_long", "position" => 7, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } },
      { "title" => "How likely are you to continue using our product?", "question_type" => "scale", "position" => 8, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 10, "min_label" => "Very unlikely", "max_label" => "Very likely" } }
    ]
  }
end

# 6.2 Feature Request Survey
FormTemplate.find_or_create_by!(name: "Feature Request Survey") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Collect and prioritize feature requests from users to guide product development."
  template.template_data = {
    "form" => { "name" => "Feature Request", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "User Type", "question_type" => "single_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Free user", "Basic subscriber", "Premium subscriber", "Enterprise customer", "Trial user"] } },
      { "title" => "What feature would you like to see added?", "question_type" => "text_long", "position" => 2, "required" => true, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "What problem would this feature solve for you?", "question_type" => "text_long", "position" => 3, "required" => true, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } },
      { "title" => "How important is this feature to you?", "question_type" => "scale", "position" => 4, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "min_label" => "Nice to have", "max_label" => "Critical need" } },
      { "title" => "How do you currently work around this limitation?", "question_type" => "text_long", "position" => 5, "required" => false },
      { "title" => "Would you be willing to pay extra for this feature?", "question_type" => "single_choice", "position" => 6, "required" => false, "configuration" => { "options" => ["Yes, definitely", "Maybe", "No", "It should be included in current plan"] } }
    ]
  }
end

# 6.3 Beta Testing Feedback
FormTemplate.find_or_create_by!(name: "Beta Testing Feedback Form") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Collect detailed feedback from beta testers on new features or product versions."
  template.template_data = {
    "form" => { "name" => "Beta Testing Feedback", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "Which beta features did you test?", "question_type" => "multiple_choice", "position" => 1, "required" => true, "configuration" => { "options" => ["Feature A", "Feature B", "Feature C", "UI Updates", "Performance Improvements", "Bug Fixes"] } },
      { "title" => "Rate the overall beta experience", "question_type" => "rating", "position" => 2, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "labels" => ["Very Poor", "Poor", "Average", "Good", "Excellent"] } },
      { "title" => "What bugs or issues did you encounter?", "question_type" => "text_long", "position" => 3, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "How intuitive were the new features?", "question_type" => "scale", "position" => 4, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "min_label" => "Very confusing", "max_label" => "Very intuitive" } },
      { "title" => "What did you like most about the beta version?", "question_type" => "text_long", "position" => 5, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } },
      { "title" => "What needs improvement before public release?", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } },
      { "title" => "Screenshots of issues (optional)", "question_type" => "file_upload", "position" => 7, "required" => false, "configuration" => { "allowed_types" => ["jpg", "png", "gif"], "max_size" => "5MB", "multiple" => true } }
    ]
  }
end

# ============================================
# 7. LEAD GENERATION FORMS
# ============================================

# 7.1 Contact Form
FormTemplate.find_or_create_by!(name: "Contact Us Form") do |template|
  template.category = "contact_form"
  template.visibility = "template_public"
  template.description = "Professional contact form for inquiries, support requests, and business communications."
  template.template_data = {
    "form" => { "name" => "Contact Us", "category" => "contact_form", "ai_enabled" => true },
    "questions" => [
      { "title" => "Full Name", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "Email Address", "question_type" => "email", "position" => 2, "required" => true },
      { "title" => "Phone Number", "question_type" => "phone", "position" => 3, "required" => false },
      { "title" => "Company/Organization", "question_type" => "text_short", "position" => 4, "required" => false },
      { "title" => "Inquiry Type", "question_type" => "single_choice", "position" => 5, "required" => true, "configuration" => { "options" => ["General Inquiry", "Sales Question", "Technical Support", "Partnership", "Media/Press", "Feedback", "Other"] } },
      { "title" => "Subject", "question_type" => "text_short", "position" => 6, "required" => true },
      { "title" => "Message", "question_type" => "text_long", "position" => 7, "required" => true, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true, "keyword_extraction" => true } },
      { "title" => "How did you hear about us?", "question_type" => "single_choice", "position" => 8, "required" => false, "configuration" => { "options" => ["Search engine", "Social media", "Referral", "Advertisement", "News/Blog", "Event", "Other"] } }
    ]
  }
end

# 7.2 Newsletter Signup
FormTemplate.find_or_create_by!(name: "Newsletter Subscription Form") do |template|
  template.category = "general"
  template.visibility = "template_public"
  template.description = "Simple newsletter subscription form with interest preferences and frequency options."
  template.template_data = {
    "form" => { "name" => "Newsletter Signup", "category" => "general", "ai_enabled" => false },
    "questions" => [
      { "title" => "Email Address", "question_type" => "email", "position" => 1, "required" => true },
      { "title" => "First Name", "question_type" => "text_short", "position" => 2, "required" => false },
      { "title" => "What topics interest you?", "question_type" => "multiple_choice", "position" => 3, "required" => false, "configuration" => { "options" => ["Industry News", "Product Updates", "Tips & Tutorials", "Company News", "Special Offers", "Event Announcements"] } },
      { "title" => "Preferred email frequency", "question_type" => "single_choice", "position" => 4, "required" => false, "configuration" => { "options" => ["Daily", "Weekly", "Bi-weekly", "Monthly", "Quarterly"] } },
      { "title" => "Industry", "question_type" => "single_choice", "position" => 5, "required" => false, "configuration" => { "options" => ["Technology", "Healthcare", "Finance", "Education", "Retail", "Manufacturing", "Consulting", "Other"] } }
    ]
  }
end

# 7.3 Demo Request Form
FormTemplate.find_or_create_by!(name: "Product Demo Request Form") do |template|
  template.category = "lead_qualification"
  template.visibility = "template_public"
  template.description = "Qualification form for product demonstration requests with company and needs assessment."
  template.template_data = {
    "form" => { "name" => "Demo Request", "category" => "lead_qualification", "ai_enabled" => true },
    "questions" => [
      { "title" => "Full Name", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "Business Email", "question_type" => "email", "position" => 2, "required" => true },
      { "title" => "Phone Number", "question_type" => "phone", "position" => 3, "required" => true },
      { "title" => "Company Name", "question_type" => "text_short", "position" => 4, "required" => true },
      { "title" => "Job Title", "question_type" => "text_short", "position" => 5, "required" => true },
      { "title" => "Company Size", "question_type" => "single_choice", "position" => 6, "required" => true, "configuration" => { "options" => ["1-10 employees", "11-50 employees", "51-200 employees", "201-500 employees", "500+ employees"] } },
      { "title" => "Industry", "question_type" => "single_choice", "position" => 7, "required" => true, "configuration" => { "options" => ["Technology", "Healthcare", "Finance", "Education", "Retail", "Manufacturing", "Government", "Non-profit", "Other"] } },
      { "title" => "What's your primary use case?", "question_type" => "text_long", "position" => 8, "required" => true, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "What's your timeline for implementation?", "question_type" => "single_choice", "position" => 9, "required" => true, "configuration" => { "options" => ["Immediate (within 1 month)", "Short-term (1-3 months)", "Medium-term (3-6 months)", "Long-term (6+ months)", "Just exploring"] } },
      { "title" => "Preferred demo format", "question_type" => "single_choice", "position" => 10, "required" => false, "configuration" => { "options" => ["Online demo", "In-person demo", "Self-guided trial", "No preference"] } }
    ]
  }
end

# ============================================
# 8. EDUCATIONAL & RESEARCH FORMS
# ============================================

# 8.1 Course Feedback Survey
FormTemplate.find_or_create_by!(name: "Course Evaluation Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Comprehensive course evaluation form for educational institutions and training programs."
  template.template_data = {
    "form" => { "name" => "Course Evaluation", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "Course Name", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "Instructor Name", "question_type" => "text_short", "position" => 2, "required" => true },
      { "title" => "Overall course rating", "question_type" => "rating", "position" => 3, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "labels" => ["Poor", "Fair", "Good", "Very Good", "Excellent"] } },
      { "title" => "Rate the following aspects:", "question_type" => "matrix", "position" => 4, "required" => true, "configuration" => { "rows" => ["Course Content", "Instructor Knowledge", "Teaching Methods", "Course Materials", "Assignments/Exercises", "Course Organization"], "columns" => ["Poor", "Fair", "Good", "Very Good", "Excellent"] } },
      { "title" => "Did the course meet your expectations?", "question_type" => "single_choice", "position" => 5, "required" => true, "configuration" => { "options" => ["Exceeded expectations", "Met expectations", "Partially met expectations", "Did not meet expectations"] } },
      { "title" => "What did you find most valuable about this course?", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } },
      { "title" => "What could be improved?", "question_type" => "text_long", "position" => 7, "required" => false, "ai_enhanced" => true, "ai_config" => { "theme_extraction" => true } },
      { "title" => "Would you recommend this course to others?", "question_type" => "single_choice", "position" => 8, "required" => true, "configuration" => { "options" => ["Definitely yes", "Probably yes", "Not sure", "Probably not", "Definitely not"] } }
    ]
  }
end

# 8.2 Research Survey Template
FormTemplate.find_or_create_by!(name: "Academic Research Survey") do |template|
  template.category = "survey"
  template.visibility = "template_public"
  template.description = "Template for academic and professional research studies with consent and demographic sections."
  template.template_data = {
    "form" => { "name" => "Research Survey", "category" => "survey", "ai_enabled" => true },
    "questions" => [
      { "title" => "Informed Consent", "question_type" => "checkbox", "position" => 1, "required" => true, "configuration" => { "options" => ["I understand the purpose of this research", "I consent to participate voluntarily", "I understand I can withdraw at any time", "I agree to the use of my responses for research purposes"] } },
      { "title" => "Age Range", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"] } },
      { "title" => "Gender Identity", "question_type" => "single_choice", "position" => 3, "required" => false, "configuration" => { "options" => ["Male", "Female", "Non-binary", "Prefer not to say", "Other"] } },
      { "title" => "Education Level", "question_type" => "single_choice", "position" => 4, "required" => false, "configuration" => { "options" => ["High School", "Some College", "Bachelor's Degree", "Master's Degree", "Doctoral Degree", "Professional Degree"] } },
      { "title" => "Employment Status", "question_type" => "single_choice", "position" => 5, "required" => false, "configuration" => { "options" => ["Employed full-time", "Employed part-time", "Self-employed", "Unemployed", "Student", "Retired"] } },
      { "title" => "Research Question 1", "question_type" => "scale", "position" => 6, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 7, "min_label" => "Strongly Disagree", "max_label" => "Strongly Agree" } },
      { "title" => "Please explain your rating", "question_type" => "text_long", "position" => 7, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true } }
    ]
  }
end

# ============================================
# 9. CUSTOMER ONBOARDING FORMS
# ============================================

# 9.1 Customer Onboarding Survey
FormTemplate.find_or_create_by!(name: "Customer Onboarding Survey") do |template|
  template.category = "general"
  template.visibility = "template_public"
  template.description = "Welcome new customers and gather information to personalize their experience."
  template.template_data = {
    "form" => { "name" => "Welcome Survey", "category" => "general", "ai_enabled" => true },
    "questions" => [
      { "title" => "Welcome! What's your name?", "question_type" => "text_short", "position" => 1, "required" => true },
      { "title" => "What's your role?", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Business Owner", "Manager", "Individual Contributor", "Consultant", "Student", "Other"] } },
      { "title" => "Company Size", "question_type" => "single_choice", "position" => 3, "required" => false, "configuration" => { "options" => ["Just me", "2-10 people", "11-50 people", "51-200 people", "200+ people"] } },
      { "title" => "What's your primary goal with our product?", "question_type" => "single_choice", "position" => 4, "required" => true, "configuration" => { "options" => ["Increase productivity", "Save time", "Improve collaboration", "Better organization", "Cost reduction", "Other"] } },
      { "title" => "How did you hear about us?", "question_type" => "single_choice", "position" => 5, "required" => false, "configuration" => { "options" => ["Search engine", "Social media", "Friend/colleague", "Advertisement", "Blog/article", "Event", "Other"] } },
      { "title" => "What would success look like for you?", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "keyword_extraction" => true } }
    ]
  }
end

# ============================================
# 10. HEALTHCARE & WELLNESS FORMS
# ============================================

# 10.1 Patient Satisfaction Survey
FormTemplate.find_or_create_by!(name: "Patient Satisfaction Survey") do |template|
  template.category = "customer_feedback"
  template.visibility = "template_public"
  template.description = "Healthcare patient satisfaction survey covering care quality, staff, and facility experience."
  template.template_data = {
    "form" => { "name" => "Patient Satisfaction", "category" => "customer_feedback", "ai_enabled" => true },
    "questions" => [
      { "title" => "Date of Visit", "question_type" => "date", "position" => 1, "required" => true },
      { "title" => "Type of Visit", "question_type" => "single_choice", "position" => 2, "required" => true, "configuration" => { "options" => ["Routine Check-up", "Specialist Consultation", "Emergency Visit", "Follow-up Appointment", "Procedure/Surgery", "Other"] } },
      { "title" => "Overall satisfaction with your care", "question_type" => "rating", "position" => 3, "required" => true, "configuration" => { "min_value" => 1, "max_value" => 5, "labels" => ["Very Unsatisfied", "Unsatisfied", "Neutral", "Satisfied", "Very Satisfied"] } },
      { "title" => "Rate the following aspects:", "question_type" => "matrix", "position" => 4, "required" => true, "configuration" => { "rows" => ["Doctor's Communication", "Nursing Staff", "Wait Time", "Facility Cleanliness", "Appointment Scheduling", "Billing Process"], "columns" => ["Poor", "Fair", "Good", "Very Good", "Excellent"] } },
      { "title" => "Would you recommend us to family and friends?", "question_type" => "single_choice", "position" => 5, "required" => true, "configuration" => { "options" => ["Definitely yes", "Probably yes", "Not sure", "Probably not", "Definitely not"] } },
      { "title" => "Comments or suggestions for improvement", "question_type" => "text_long", "position" => 6, "required" => false, "ai_enhanced" => true, "ai_config" => { "sentiment_analysis" => true, "theme_extraction" => true } }
    ]
  }
end

puts "✅ #{FormTemplate.count} comprehensive form templates created successfully!"
puts "Categories included:"
puts "- Market Research Surveys (3 templates)"
puts "- Customer Satisfaction Surveys (6 templates)"  
puts "- Employee Experience Surveys (4 templates)"
puts "- Event Registration Forms (2 templates)"
puts "- HR & Recruitment Forms (2 templates)"
puts "- Product Feedback Forms (3 templates)"
puts "- Lead Qualification Forms (1 template)"
puts "- Contact Forms (1 template)"
puts "- Educational Forms (2 templates)"
puts "- General Forms (3 templates)"
puts "📊 Total: 25+ professional form templates ready for use!"
