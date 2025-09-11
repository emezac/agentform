# frozen_string_literal: true

module Ai
  class CachingService
    include ActiveModel::Model
    
    # Cache TTL configurations (in seconds)
    CACHE_TTLS = {
      content_analysis: 24.hours.to_i,      # Content analysis results
      form_templates: 7.days.to_i,          # Common form patterns
      document_processing: 1.hour.to_i,     # Document extraction results
      llm_responses: 12.hours.to_i,         # LLM response caching
      user_preferences: 30.days.to_i        # User form preferences
    }.freeze
    
    # Cache key prefixes for organization
    CACHE_PREFIXES = {
      content_analysis: 'ai:content_analysis',
      form_templates: 'ai:form_templates',
      document_processing: 'ai:document_processing',
      llm_responses: 'ai:llm_responses',
      user_preferences: 'ai:user_preferences'
    }.freeze
    
    class << self
      # Cache content analysis results based on content hash
      def cache_content_analysis(content_hash, analysis_result)
        cache_key = build_cache_key(:content_analysis, content_hash)
        
        cache_data = {
          analysis_result: analysis_result,
          cached_at: Time.current.iso8601,
          cache_version: '1.0'
        }
        
        begin
          Rails.cache.write(cache_key, cache_data, expires_in: CACHE_TTLS[:content_analysis])
          
          Rails.logger.info "Cached content analysis for hash: #{content_hash[0..8]}..."
          cache_data
        rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
          RedisErrorLogger.log_connection_error(e, {
            component: 'ai_caching_service',
            operation: 'cache_content_analysis',
            cache_key: cache_key,
            content_hash: content_hash[0..8]
          })
          
          # Return the data even if caching failed
          cache_data
        end
      end
      
      # Retrieve cached content analysis
      def get_cached_content_analysis(content_hash)
        cache_key = build_cache_key(:content_analysis, content_hash)
        
        begin
          cached_data = Rails.cache.read(cache_key)
          
          if cached_data
            Rails.logger.info "Cache hit for content analysis: #{content_hash[0..8]}..."
            
            # Track cache hit for analytics
            track_cache_hit(:content_analysis, content_hash)
            
            cached_data[:analysis_result]
          else
            Rails.logger.debug "Cache miss for content analysis: #{content_hash[0..8]}..."
            
            # Track cache miss for analytics
            track_cache_miss(:content_analysis, content_hash)
            
            nil
          end
        rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
          RedisErrorLogger.log_connection_error(e, {
            component: 'ai_caching_service',
            operation: 'get_cached_content_analysis',
            cache_key: cache_key,
            content_hash: content_hash[0..8]
          })
          
          # Return nil when cache is unavailable
          nil
        end
      end
      
      # Cache form templates for common patterns
      def cache_form_template(template_key, form_structure)
        cache_key = build_cache_key(:form_templates, template_key)
        
        cache_data = {
          form_structure: form_structure,
          usage_count: 1,
          cached_at: Time.current.iso8601,
          cache_version: '1.0'
        }
        
        # Try to increment usage count if template already exists
        existing_data = Rails.cache.read(cache_key)
        if existing_data
          cache_data[:usage_count] = existing_data[:usage_count] + 1
        end
        
        Rails.cache.write(cache_key, cache_data, expires_in: CACHE_TTLS[:form_templates])
        
        Rails.logger.info "Cached form template: #{template_key}"
        cache_data
      end
      
      # Retrieve cached form template
      def get_cached_form_template(template_key)
        cache_key = build_cache_key(:form_templates, template_key)
        cached_data = Rails.cache.read(cache_key)
        
        if cached_data
          Rails.logger.info "Cache hit for form template: #{template_key}"
          
          # Update usage count
          cached_data[:usage_count] += 1
          Rails.cache.write(cache_key, cached_data, expires_in: CACHE_TTLS[:form_templates])
          
          track_cache_hit(:form_templates, template_key)
          cached_data[:form_structure]
        else
          Rails.logger.debug "Cache miss for form template: #{template_key}"
          track_cache_miss(:form_templates, template_key)
          nil
        end
      end
      
      # Cache document processing results
      def cache_document_processing(file_hash, processing_result)
        cache_key = build_cache_key(:document_processing, file_hash)
        
        cache_data = {
          processing_result: processing_result,
          cached_at: Time.current.iso8601,
          cache_version: '1.0'
        }
        
        Rails.cache.write(cache_key, cache_data, expires_in: CACHE_TTLS[:document_processing])
        
        Rails.logger.info "Cached document processing for hash: #{file_hash[0..8]}..."
        cache_data
      end
      
      # Retrieve cached document processing result
      def get_cached_document_processing(file_hash)
        cache_key = build_cache_key(:document_processing, file_hash)
        cached_data = Rails.cache.read(cache_key)
        
        if cached_data
          Rails.logger.info "Cache hit for document processing: #{file_hash[0..8]}..."
          track_cache_hit(:document_processing, file_hash)
          cached_data[:processing_result]
        else
          Rails.logger.debug "Cache miss for document processing: #{file_hash[0..8]}..."
          track_cache_miss(:document_processing, file_hash)
          nil
        end
      end
      
      # Cache LLM responses for similar prompts
      def cache_llm_response(prompt_hash, model, temperature, response)
        cache_key = build_cache_key(:llm_responses, "#{prompt_hash}_#{model}_#{temperature}")
        
        cache_data = {
          response: response,
          model: model,
          temperature: temperature,
          cached_at: Time.current.iso8601,
          cache_version: '1.0'
        }
        
        Rails.cache.write(cache_key, cache_data, expires_in: CACHE_TTLS[:llm_responses])
        
        Rails.logger.info "Cached LLM response for model #{model}: #{prompt_hash[0..8]}..."
        cache_data
      end
      
      # Retrieve cached LLM response
      def get_cached_llm_response(prompt_hash, model, temperature)
        cache_key = build_cache_key(:llm_responses, "#{prompt_hash}_#{model}_#{temperature}")
        cached_data = Rails.cache.read(cache_key)
        
        if cached_data
          Rails.logger.info "Cache hit for LLM response (#{model}): #{prompt_hash[0..8]}..."
          track_cache_hit(:llm_responses, prompt_hash)
          cached_data[:response]
        else
          Rails.logger.debug "Cache miss for LLM response (#{model}): #{prompt_hash[0..8]}..."
          track_cache_miss(:llm_responses, prompt_hash)
          nil
        end
      end
      
      # Cache user form preferences
      def cache_user_preferences(user_id, preferences)
        cache_key = build_cache_key(:user_preferences, user_id)
        
        cache_data = {
          preferences: preferences,
          cached_at: Time.current.iso8601,
          cache_version: '1.0'
        }
        
        Rails.cache.write(cache_key, cache_data, expires_in: CACHE_TTLS[:user_preferences])
        
        Rails.logger.info "Cached user preferences for user: #{user_id}"
        cache_data
      end
      
      # Retrieve cached user preferences
      def get_cached_user_preferences(user_id)
        cache_key = build_cache_key(:user_preferences, user_id)
        cached_data = Rails.cache.read(cache_key)
        
        if cached_data
          Rails.logger.info "Cache hit for user preferences: #{user_id}"
          track_cache_hit(:user_preferences, user_id)
          cached_data[:preferences]
        else
          Rails.logger.debug "Cache miss for user preferences: #{user_id}"
          track_cache_miss(:user_preferences, user_id)
          nil
        end
      end
      
      # Invalidate cache entries
      def invalidate_cache(cache_type, identifier = nil)
        if identifier
          cache_key = build_cache_key(cache_type, identifier)
          Rails.cache.delete(cache_key)
          Rails.logger.info "Invalidated cache: #{cache_key}"
        else
          # Invalidate all entries of this type (pattern-based deletion)
          pattern = "#{CACHE_PREFIXES[cache_type]}:*"
          invalidate_cache_pattern(pattern)
          Rails.logger.info "Invalidated all cache entries for type: #{cache_type}"
        end
      end
      
      # Warm cache with common patterns
      def warm_cache
        Rails.logger.info "Starting cache warming process..."
        
        # Warm form templates cache with common patterns
        warm_form_templates_cache
        
        # Warm user preferences for active users
        warm_user_preferences_cache
        
        Rails.logger.info "Cache warming completed"
      end
      
      # Get cache statistics
      def cache_statistics
        stats = {}
        
        CACHE_PREFIXES.each do |type, prefix|
          pattern = "#{prefix}:*"
          keys = get_cache_keys_by_pattern(pattern)
          
          stats[type] = {
            total_entries: keys.length,
            cache_size_estimate: estimate_cache_size(keys),
            oldest_entry: find_oldest_cache_entry(keys),
            newest_entry: find_newest_cache_entry(keys)
          }
        end
        
        stats
      end
      
      # Generate content hash for caching
      def generate_content_hash(content, additional_params = {})
        hash_input = {
          content: content.to_s.strip,
          params: additional_params.sort.to_h
        }.to_json
        
        Digest::SHA256.hexdigest(hash_input)
      end
      
      # Generate template key for form patterns
      def generate_template_key(analysis_result)
        key_components = [
          analysis_result['recommended_approach'],
          analysis_result['complexity_level'],
          analysis_result['suggested_question_count'],
          analysis_result['form_category']
        ].compact
        
        Digest::SHA256.hexdigest(key_components.join('_'))
      end
      
      private
      
      # Build standardized cache keys
      def build_cache_key(cache_type, identifier)
        prefix = CACHE_PREFIXES[cache_type]
        "#{prefix}:#{identifier}"
      end
      
      # Track cache hits for analytics
      def track_cache_hit(cache_type, identifier)
        Ai::UsageAnalyticsService.track_event({
          event_type: 'cache_hit',
          cache_type: cache_type.to_s,
          identifier: identifier.to_s[0..16], # Truncate for privacy
          timestamp: Time.current.iso8601
        })
      end
      
      # Track cache misses for analytics
      def track_cache_miss(cache_type, identifier)
        Ai::UsageAnalyticsService.track_event({
          event_type: 'cache_miss',
          cache_type: cache_type.to_s,
          identifier: identifier.to_s[0..16], # Truncate for privacy
          timestamp: Time.current.iso8601
        })
      end
      
      # Invalidate cache entries by pattern
      def invalidate_cache_pattern(pattern)
        # This implementation depends on the cache store
        # For Redis-based cache stores, we can use pattern matching
        if Rails.cache.respond_to?(:delete_matched)
          Rails.cache.delete_matched(pattern)
        else
          # Fallback for other cache stores
          Rails.logger.warn "Pattern-based cache invalidation not supported by current cache store"
        end
      end
      
      # Warm form templates cache with common patterns
      def warm_form_templates_cache
        common_patterns = [
          {
            recommended_approach: 'lead_capture',
            complexity_level: 'simple',
            suggested_question_count: 5,
            form_category: 'lead_generation'
          },
          {
            recommended_approach: 'feedback',
            complexity_level: 'moderate',
            suggested_question_count: 8,
            form_category: 'customer_feedback'
          },
          {
            recommended_approach: 'survey',
            complexity_level: 'complex',
            suggested_question_count: 12,
            form_category: 'market_research'
          }
        ]
        
        common_patterns.each do |pattern|
          template_key = generate_template_key(pattern)
          
          # Only warm if not already cached
          unless get_cached_form_template(template_key)
            # Generate a basic template structure for this pattern
            template_structure = generate_basic_template(pattern)
            cache_form_template(template_key, template_structure)
          end
        end
      end
      
      # Warm user preferences cache for active users
      def warm_user_preferences_cache
        # Get recently active users (last 7 days)
        active_users = User.where('updated_at > ?', 7.days.ago)
                          .where.not(ai_credits_used: 0)
                          .limit(100)
        
        active_users.find_each do |user|
          # Generate basic preferences based on user's form history
          preferences = generate_user_preferences(user)
          cache_user_preferences(user.id, preferences)
        end
      end
      
      # Generate basic template structure for warming
      def generate_basic_template(pattern)
        {
          form_meta: {
            title: "#{pattern[:recommended_approach].humanize} Form",
            description: "Generated template for #{pattern[:form_category]}",
            category: pattern[:form_category],
            instructions: "Please fill out this form completely."
          },
          questions: generate_template_questions(pattern),
          form_settings: {
            one_question_per_page: pattern[:complexity_level] == 'complex',
            show_progress_bar: pattern[:suggested_question_count] > 5,
            allow_multiple_submissions: false,
            thank_you_message: "Thank you for your response!"
          }
        }
      end
      
      # Generate template questions based on pattern
      def generate_template_questions(pattern)
        base_questions = []
        
        case pattern[:recommended_approach]
        when 'lead_capture'
          base_questions = [
            { title: "What's your name?", question_type: "text_short", required: true },
            { title: "Email address", question_type: "email", required: true },
            { title: "Company name", question_type: "text_short", required: false },
            { title: "Phone number", question_type: "phone", required: false },
            { title: "How can we help you?", question_type: "text_long", required: true }
          ]
        when 'feedback'
          base_questions = [
            { title: "How would you rate your experience?", question_type: "rating", required: true },
            { title: "What did you like most?", question_type: "text_long", required: false },
            { title: "What could we improve?", question_type: "text_long", required: false },
            { title: "Would you recommend us?", question_type: "yes_no", required: true }
          ]
        when 'survey'
          base_questions = [
            { title: "Age range", question_type: "multiple_choice", required: false },
            { title: "Location", question_type: "text_short", required: false },
            { title: "Primary interest", question_type: "multiple_choice", required: true },
            { title: "Additional comments", question_type: "text_long", required: false }
          ]
        end
        
        # Limit to suggested question count
        base_questions.take(pattern[:suggested_question_count])
      end
      
      # Generate user preferences based on history
      def generate_user_preferences(user)
        {
          preferred_complexity: 'moderate',
          preferred_question_count: 8,
          common_categories: ['lead_generation', 'customer_feedback'],
          ai_features_usage: {
            sentiment_analysis: true,
            lead_scoring: true,
            dynamic_followup: false
          },
          last_updated: Time.current.iso8601
        }
      end
      
      # Get cache keys by pattern (Redis-specific)
      def get_cache_keys_by_pattern(pattern)
        if Rails.cache.respond_to?(:redis)
          begin
            Rails.cache.redis.keys(pattern)
          rescue Redis::CannotConnectError, Redis::ConnectionError, Redis::TimeoutError => e
            RedisErrorLogger.log_connection_error(e, {
              component: 'ai_caching_service',
              operation: 'get_cache_keys_by_pattern',
              pattern: pattern
            })
            
            # Return empty array when Redis is unavailable
            []
          end
        else
          []
        end
      end
      
      # Estimate cache size for keys
      def estimate_cache_size(keys)
        return 0 if keys.empty?
        
        sample_size = [keys.length, 10].min
        sample_keys = keys.sample(sample_size)
        
        total_size = sample_keys.sum do |key|
          data = Rails.cache.read(key)
          data ? data.to_json.bytesize : 0
        end
        
        # Extrapolate to all keys
        (total_size * keys.length / sample_size).round
      end
      
      # Find oldest cache entry
      def find_oldest_cache_entry(keys)
        return nil if keys.empty?
        
        oldest_time = nil
        keys.each do |key|
          data = Rails.cache.read(key)
          if data && data[:cached_at]
            cached_time = Time.parse(data[:cached_at])
            oldest_time = cached_time if oldest_time.nil? || cached_time < oldest_time
          end
        end
        
        oldest_time&.iso8601
      end
      
      # Find newest cache entry
      def find_newest_cache_entry(keys)
        return nil if keys.empty?
        
        newest_time = nil
        keys.each do |key|
          data = Rails.cache.read(key)
          if data && data[:cached_at]
            cached_time = Time.parse(data[:cached_at])
            newest_time = cached_time if newest_time.nil? || cached_time > newest_time
          end
        end
        
        newest_time&.iso8601
      end
    end
  end
end