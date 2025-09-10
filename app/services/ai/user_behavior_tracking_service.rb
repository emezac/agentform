# frozen_string_literal: true

module Ai
  class UserBehaviorTrackingService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :user_id, :string
    attribute :session_id, :string
    attribute :event_type, :string
    attribute :event_data, :string, default: {}
    attribute :page_url, :string
    attribute :user_agent, :string
    attribute :ip_address, :string
    attribute :timestamp, :datetime, default: -> { Time.current }

    EVENT_TYPES = %w[
      form_generation_started
      form_generation_completed
      form_generation_failed
      document_uploaded
      prompt_entered
      preview_viewed
      form_edited
      ai_feature_used
      error_encountered
      retry_attempted
      session_started
      session_ended
      page_viewed
      button_clicked
      input_focused
      input_changed
      form_submitted
      navigation_event
    ].freeze

    validates :user_id, presence: true
    validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

    def self.track_event(event_data)
      service = new(event_data)
      service.track_event
    end

    def track_event
      return false unless valid?

      # Track user journey patterns
      track_user_journey

      # Track feature usage patterns
      track_feature_usage

      # Track conversion funnel
      track_conversion_funnel

      # Track user engagement
      track_user_engagement

      # Store detailed event for analysis
      store_event_record

      true
    rescue StandardError => e
      Rails.logger.error "Failed to track user behavior: #{e.message}"
      false
    end

    private

    def track_user_journey
      # Track user session flow
      session_key = "user_journey:#{session_id}"
      current_journey = Rails.cache.read(session_key) || []
      
      journey_event = {
        event_type: event_type,
        timestamp: timestamp.iso8601,
        page_url: page_url,
        event_data: event_data
      }
      
      current_journey << journey_event
      # Keep last 50 events per session
      current_journey = current_journey.last(50)
      Rails.cache.write(session_key, current_journey, expires_in: 4.hours)

      # Track common user paths
      if current_journey.length >= 2
        previous_event = current_journey[-2]
        path_key = "user_paths:#{previous_event[:event_type]}:#{event_type}:#{Date.current}"
        Rails.cache.increment(path_key, 1, expires_in: 32.days)
      end
    end

    def track_feature_usage
      # Track AI feature adoption
      if event_type.include?('ai_') || event_type.include?('form_generation')
        feature_key = "feature_usage:#{event_type}:#{Date.current}"
        Rails.cache.increment(feature_key, 1, expires_in: 32.days)

        # Track feature usage by user
        user_feature_key = "user_features:#{user_id}:#{event_type}:#{Date.current}"
        Rails.cache.increment(user_feature_key, 1, expires_in: 32.days)
      end

      # Track document vs prompt preference
      if event_type == 'document_uploaded'
        Rails.cache.increment("input_preference:document:#{Date.current}", 1, expires_in: 32.days)
      elsif event_type == 'prompt_entered'
        Rails.cache.increment("input_preference:prompt:#{Date.current}", 1, expires_in: 32.days)
      end

      # Track error recovery patterns
      if event_type == 'retry_attempted'
        retry_context = event_data[:error_type] || 'unknown'
        retry_key = "retry_patterns:#{retry_context}:#{Date.current}"
        Rails.cache.increment(retry_key, 1, expires_in: 32.days)
      end
    end

    def track_conversion_funnel
      # Define conversion funnel stages
      funnel_stages = {
        'form_generation_started' => 'started',
        'document_uploaded' => 'input_provided',
        'prompt_entered' => 'input_provided',
        'preview_viewed' => 'preview_viewed',
        'form_generation_completed' => 'completed',
        'form_edited' => 'engaged'
      }

      stage = funnel_stages[event_type]
      return unless stage

      # Track funnel progression
      funnel_key = "conversion_funnel:#{stage}:#{Date.current}"
      Rails.cache.increment(funnel_key, 1, expires_in: 32.days)

      # Track user-specific funnel progression
      user_funnel_key = "user_funnel:#{user_id}"
      user_stages = Rails.cache.read(user_funnel_key) || []
      
      unless user_stages.include?(stage)
        user_stages << stage
        Rails.cache.write(user_funnel_key, user_stages, expires_in: 1.day)
        
        # Track unique users reaching each stage
        unique_funnel_key = "unique_funnel:#{stage}:#{Date.current}"
        Rails.cache.increment(unique_funnel_key, 1, expires_in: 32.days)
      end
    end

    def track_user_engagement
      # Track session duration indicators
      if event_type == 'session_started'
        session_start_key = "session_start:#{session_id}"
        Rails.cache.write(session_start_key, timestamp.to_f, expires_in: 4.hours)
      elsif event_type == 'session_ended'
        session_start_key = "session_start:#{session_id}"
        start_time = Rails.cache.read(session_start_key)
        
        if start_time
          duration = timestamp.to_f - start_time
          duration_key = "session_durations:#{Date.current}"
          current_durations = Rails.cache.read(duration_key) || []
          current_durations << duration
          current_durations = current_durations.last(1000) # Keep recent sessions
          Rails.cache.write(duration_key, current_durations, expires_in: 32.days)
        end
      end

      # Track page engagement time
      if event_type == 'page_viewed' && page_url.present?
        page_view_key = "page_views:#{normalize_page_url(page_url)}:#{Date.current}"
        Rails.cache.increment(page_view_key, 1, expires_in: 32.days)
      end

      # Track interaction frequency
      interaction_events = %w[button_clicked input_focused input_changed form_submitted]
      if interaction_events.include?(event_type)
        interaction_key = "user_interactions:#{user_id}:#{Date.current}"
        Rails.cache.increment(interaction_key, 1, expires_in: 32.days)
      end
    end

    def store_event_record
      # Store detailed event record for analysis
      event_record = {
        user_id: user_id,
        session_id: session_id,
        event_type: event_type,
        event_data: event_data,
        page_url: page_url,
        user_agent: user_agent,
        ip_address: ip_address,
        timestamp: timestamp.iso8601,
        date: timestamp.to_date.to_s,
        hour: timestamp.hour,
        day_of_week: timestamp.wday
      }

      # Store with unique key for detailed analysis
      record_key = "behavior_event:#{SecureRandom.uuid}"
      Rails.cache.write(record_key, event_record, expires_in: 90.days)

      # Log structured event data
      Rails.logger.info "[USER_BEHAVIOR] #{event_record.to_json}"
    end

    def normalize_page_url(url)
      # Extract meaningful page identifier from URL
      uri = URI.parse(url)
      path = uri.path
      
      # Normalize dynamic segments
      path = path.gsub(/\/\d+/, '/:id') # Replace numeric IDs
      path = path.gsub(/\/[a-f0-9-]{36}/, '/:uuid') # Replace UUIDs
      
      path
    rescue URI::InvalidURIError
      'unknown'
    end

    # Class methods for retrieving behavior analytics
    def self.get_conversion_funnel_data(date = Date.current)
      stages = %w[started input_provided preview_viewed completed engaged]
      funnel_data = {}
      
      stages.each do |stage|
        key = "conversion_funnel:#{stage}:#{date}"
        funnel_data[stage] = Rails.cache.read(key) || 0
      end
      
      funnel_data
    end

    def self.get_feature_usage_stats(date = Date.current)
      feature_stats = {}
      
      EVENT_TYPES.each do |event_type|
        next unless event_type.include?('ai_') || event_type.include?('form_generation')
        
        key = "feature_usage:#{event_type}:#{date}"
        feature_stats[event_type] = Rails.cache.read(key) || 0
      end
      
      feature_stats
    end

    def self.get_input_preference_stats(date = Date.current)
      document_key = "input_preference:document:#{date}"
      prompt_key = "input_preference:prompt:#{date}"
      
      {
        document: Rails.cache.read(document_key) || 0,
        prompt: Rails.cache.read(prompt_key) || 0
      }
    end

    def self.get_user_journey(session_id)
      key = "user_journey:#{session_id}"
      Rails.cache.read(key) || []
    end

    def self.get_average_session_duration(date = Date.current)
      key = "session_durations:#{date}"
      durations = Rails.cache.read(key) || []
      
      return 0 if durations.empty?
      (durations.sum / durations.length).round(0)
    end

    def self.get_popular_user_paths(date = Date.current, limit = 10)
      # This would need a more sophisticated implementation to aggregate paths
      # For now, return empty array
      []
    end

    def self.get_retry_patterns(date = Date.current)
      # Get all retry pattern keys for the date
      pattern_keys = Rails.cache.instance_variable_get(:@data).keys.select do |key|
        key.to_s.start_with?("retry_patterns:") && key.to_s.end_with?(":#{date}")
      end
      
      patterns = {}
      pattern_keys.each do |key|
        error_type = key.to_s.split(':')[1]
        patterns[error_type] = Rails.cache.read(key) || 0
      end
      
      patterns
    end
  end
end