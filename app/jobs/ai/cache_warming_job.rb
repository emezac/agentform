# frozen_string_literal: true

module Ai
  class CacheWarmingJob < ApplicationJob
    queue_as :ai_processing
    
    # Retry configuration for cache warming
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    
    def perform(cache_types = nil)
      Rails.logger.info "Starting AI cache warming job"
      
      cache_types ||= [:form_templates, :user_preferences]
      
      cache_types.each do |cache_type|
        case cache_type.to_sym
        when :form_templates
          warm_form_templates
        when :user_preferences
          warm_user_preferences
        when :content_analysis
          warm_content_analysis
        when :all
          Ai::CachingService.warm_cache
        else
          Rails.logger.warn "Unknown cache type for warming: #{cache_type}"
        end
      end
      
      Rails.logger.info "AI cache warming job completed"
    end
    
    private
    
    def warm_form_templates
      Rails.logger.info "Warming form templates cache"
      
      # Common form patterns to pre-cache
      common_patterns = [
        {
          'recommended_approach' => 'lead_capture',
          'complexity_level' => 'simple',
          'suggested_question_count' => 5,
          'form_category' => 'lead_generation'
        },
        {
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'suggested_question_count' => 8,
          'form_category' => 'customer_feedback'
        },
        {
          'recommended_approach' => 'survey',
          'complexity_level' => 'complex',
          'suggested_question_count' => 12,
          'form_category' => 'market_research'
        },
        {
          'recommended_approach' => 'registration',
          'complexity_level' => 'simple',
          'suggested_question_count' => 6,
          'form_category' => 'event_registration'
        },
        {
          'recommended_approach' => 'assessment',
          'complexity_level' => 'moderate',
          'suggested_question_count' => 10,
          'form_category' => 'job_application'
        }
      ]
      
      common_patterns.each do |pattern|
        template_key = Ai::CachingService.generate_template_key(pattern)
        
        # Only generate if not already cached
        unless Ai::CachingService.get_cached_form_template(template_key)
          template_structure = generate_template_structure(pattern)
          Ai::CachingService.cache_form_template(template_key, template_structure)
          
          Rails.logger.info "Warmed template cache for pattern: #{pattern['recommended_approach']}"
        end
      end
    end
    
    def warm_user_preferences
      Rails.logger.info "Warming user preferences cache"
      
      # Get recently active users who have used AI features
      active_users = User.joins(:forms)
                        .where(forms: { ai_enabled: true })
                        .where('users.updated_at > ?', 7.days.ago)
                        .distinct
                        .limit(50)
      
      active_users.find_each do |user|
        # Only warm if not already cached
        unless Ai::CachingService.get_cached_user_preferences(user.id)
          preferences = generate_user_preferences(user)
          Ai::CachingService.cache_user_preferences(user.id, preferences)
          
          Rails.logger.debug "Warmed preferences cache for user: #{user.id}"
        end
      end
    end
    
    def warm_content_analysis
      Rails.logger.info "Warming content analysis cache"
      
      # Common content patterns that might be analyzed
      common_content_samples = [
        "I need a contact form for my website to capture leads from potential customers.",
        "We want to collect customer feedback about our new product launch and user experience.",
        "Create a survey to understand market preferences and customer demographics.",
        "I need a registration form for our upcoming webinar event with payment processing.",
        "We need an assessment form for job applicants to evaluate their skills and experience."
      ]
      
      common_content_samples.each do |content|
        content_hash = Ai::CachingService.generate_content_hash(content)
        
        # Only analyze if not already cached
        unless Ai::CachingService.get_cached_content_analysis(content_hash)
          # This would normally trigger the AI analysis, but for warming we'll skip
          # actual LLM calls and just prepare the cache structure
          Rails.logger.debug "Content analysis cache prepared for sample content"
        end
      end
    end
    
    def generate_template_structure(pattern)
      {
        form_meta: {
          title: generate_title_for_pattern(pattern),
          description: generate_description_for_pattern(pattern),
          category: pattern['form_category'],
          instructions: "Please fill out this form completely."
        },
        questions: generate_questions_for_pattern(pattern),
        form_settings: {
          one_question_per_page: pattern['complexity_level'] == 'complex',
          show_progress_bar: pattern['suggested_question_count'] > 5,
          allow_multiple_submissions: false,
          thank_you_message: "Thank you for your response!",
          mobile_optimized: true,
          auto_save_enabled: true
        },
        metadata: {
          template_generated: true,
          pattern: pattern,
          generated_at: Time.current.iso8601
        }
      }
    end
    
    def generate_title_for_pattern(pattern)
      case pattern['recommended_approach']
      when 'lead_capture'
        "Contact Us"
      when 'feedback'
        "Your Feedback Matters"
      when 'survey'
        "Quick Survey"
      when 'registration'
        "Event Registration"
      when 'assessment'
        "Skills Assessment"
      else
        "#{pattern['form_category'].humanize} Form"
      end
    end
    
    def generate_description_for_pattern(pattern)
      case pattern['recommended_approach']
      when 'lead_capture'
        "Get in touch with us and we'll respond as soon as possible."
      when 'feedback'
        "Help us improve by sharing your thoughts and experiences."
      when 'survey'
        "Your responses help us understand our audience better."
      when 'registration'
        "Register for our upcoming event and secure your spot."
      when 'assessment'
        "Complete this assessment to help us understand your qualifications."
      else
        "Please complete this form with accurate information."
      end
    end
    
    def generate_questions_for_pattern(pattern)
      base_questions = []
      
      case pattern['recommended_approach']
      when 'lead_capture'
        base_questions = [
          {
            title: "What's your name?",
            question_type: "text_short",
            required: true,
            position: 1
          },
          {
            title: "Email address",
            question_type: "email",
            required: true,
            position: 2
          },
          {
            title: "Company name",
            question_type: "text_short",
            required: false,
            position: 3
          },
          {
            title: "Phone number",
            question_type: "phone",
            required: false,
            position: 4
          },
          {
            title: "How can we help you?",
            question_type: "text_long",
            required: true,
            position: 5
          }
        ]
      when 'feedback'
        base_questions = [
          {
            title: "How would you rate your overall experience?",
            question_type: "rating",
            required: true,
            position: 1,
            question_config: { scale: 5, labels: ["Poor", "Excellent"] }
          },
          {
            title: "What did you like most?",
            question_type: "text_long",
            required: false,
            position: 2
          },
          {
            title: "What could we improve?",
            question_type: "text_long",
            required: false,
            position: 3
          },
          {
            title: "Would you recommend us to others?",
            question_type: "yes_no",
            required: true,
            position: 4
          },
          {
            title: "Any additional comments?",
            question_type: "text_long",
            required: false,
            position: 5
          }
        ]
      when 'survey'
        base_questions = [
          {
            title: "What's your age range?",
            question_type: "multiple_choice",
            required: false,
            position: 1,
            question_config: {
              options: ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
            }
          },
          {
            title: "What's your location?",
            question_type: "text_short",
            required: false,
            position: 2
          },
          {
            title: "What's your primary interest?",
            question_type: "multiple_choice",
            required: true,
            position: 3,
            question_config: {
              options: ["Technology", "Business", "Education", "Healthcare", "Other"]
            }
          },
          {
            title: "How did you hear about us?",
            question_type: "multiple_choice",
            required: false,
            position: 4,
            question_config: {
              options: ["Social Media", "Search Engine", "Friend/Colleague", "Advertisement", "Other"]
            }
          }
        ]
      when 'registration'
        base_questions = [
          {
            title: "Full name",
            question_type: "text_short",
            required: true,
            position: 1
          },
          {
            title: "Email address",
            question_type: "email",
            required: true,
            position: 2
          },
          {
            title: "Phone number",
            question_type: "phone",
            required: true,
            position: 3
          },
          {
            title: "Organization/Company",
            question_type: "text_short",
            required: false,
            position: 4
          },
          {
            title: "Dietary restrictions or special requirements",
            question_type: "text_long",
            required: false,
            position: 5
          }
        ]
      when 'assessment'
        base_questions = [
          {
            title: "Full name",
            question_type: "text_short",
            required: true,
            position: 1
          },
          {
            title: "Email address",
            question_type: "email",
            required: true,
            position: 2
          },
          {
            title: "Years of experience",
            question_type: "number",
            required: true,
            position: 3
          },
          {
            title: "Relevant skills",
            question_type: "text_long",
            required: true,
            position: 4
          },
          {
            title: "Why are you interested in this position?",
            question_type: "text_long",
            required: true,
            position: 5
          }
        ]
      end
      
      # Limit to suggested question count
      base_questions.take(pattern['suggested_question_count'])
    end
    
    def generate_user_preferences(user)
      # Analyze user's form history to generate preferences
      user_forms = user.forms.where(ai_enabled: true).limit(10)
      
      # Default preferences
      preferences = {
        preferred_complexity: 'moderate',
        preferred_question_count: 8,
        common_categories: [],
        ai_features_usage: {
          sentiment_analysis: false,
          lead_scoring: false,
          dynamic_followup: false
        },
        form_patterns: [],
        last_updated: Time.current.iso8601
      }
      
      if user_forms.any?
        # Analyze patterns from user's forms
        categories = user_forms.pluck(:category).compact.uniq
        preferences[:common_categories] = categories.take(3)
        
        # Analyze AI configuration usage
        ai_configs = user_forms.where.not(ai_configuration: {}).pluck(:ai_configuration)
        if ai_configs.any?
          features_used = ai_configs.flat_map { |config| config['features'] || [] }.uniq
          preferences[:ai_features_usage] = {
            sentiment_analysis: features_used.include?('sentiment_analysis'),
            lead_scoring: features_used.include?('lead_scoring'),
            dynamic_followup: features_used.include?('dynamic_followup')
          }
        end
        
        # Calculate average question count preference
        question_counts = user_forms.joins(:form_questions).group('forms.id').count.values
        if question_counts.any?
          avg_questions = question_counts.sum / question_counts.length
          preferences[:preferred_question_count] = avg_questions.round
        end
      end
      
      preferences
    end
  end
end