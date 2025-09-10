# frozen_string_literal: true

module Ai
  class UsageAnalyticsService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :user_id, :string
    attribute :operation_type, :string
    attribute :cost, :decimal
    attribute :model_used, :string
    attribute :tokens_used, :integer
    attribute :response_time_ms, :integer
    attribute :success, :boolean, default: true
    attribute :metadata, :string, default: {}

    OPERATION_TYPES = %w[
      content_analysis
      form_generation
      document_processing
      question_enhancement
      validation
      optimization
    ].freeze

    validates :user_id, presence: true
    validates :operation_type, presence: true, inclusion: { in: OPERATION_TYPES }
    validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }

    def self.track_usage(usage_data)
      service = new(usage_data)
      service.track_usage
    end

    def track_usage
      return false unless valid?

      # Track cost metrics
      track_cost_metrics

      # Track performance metrics
      track_performance_metrics

      # Track usage patterns
      track_usage_patterns

      # Store detailed usage record
      store_usage_record

      true
    rescue StandardError => e
      Rails.logger.error "Failed to track AI usage: #{e.message}"
      false
    end

    private

    def track_cost_metrics
      # Daily cost tracking by user
      daily_key = "ai_cost:user:#{user_id}:#{Date.current}"
      Rails.cache.increment_float(daily_key, cost.to_f, expires_in: 32.days)

      # Monthly cost tracking by user
      monthly_key = "ai_cost:user:#{user_id}:#{Date.current.beginning_of_month}"
      Rails.cache.increment_float(monthly_key, cost.to_f, expires_in: 32.days)

      # Daily cost tracking by operation type
      operation_daily_key = "ai_cost:operation:#{operation_type}:#{Date.current}"
      Rails.cache.increment_float(operation_daily_key, cost.to_f, expires_in: 32.days)

      # Total platform cost tracking
      platform_daily_key = "ai_cost:platform:#{Date.current}"
      Rails.cache.increment_float(platform_daily_key, cost.to_f, expires_in: 32.days)

      # Track cost by model
      if model_used.present?
        model_daily_key = "ai_cost:model:#{model_used}:#{Date.current}"
        Rails.cache.increment_float(model_daily_key, cost.to_f, expires_in: 32.days)
      end
    end

    def track_performance_metrics
      return unless response_time_ms.present?

      # Track average response times by operation
      response_key = "ai_performance:#{operation_type}:response_times"
      current_times = Rails.cache.read(response_key) || []
      current_times << response_time_ms
      # Keep only last 100 measurements for rolling average
      current_times = current_times.last(100)
      Rails.cache.write(response_key, current_times, expires_in: 1.day)

      # Track success rates
      success_key = "ai_performance:#{operation_type}:success_rate:#{Date.current}"
      total_key = "ai_performance:#{operation_type}:total:#{Date.current}"
      
      Rails.cache.increment(total_key, 1, expires_in: 32.days)
      if success
        Rails.cache.increment(success_key, 1, expires_in: 32.days)
      end

      # Track token usage if available
      if tokens_used.present?
        token_key = "ai_tokens:#{operation_type}:#{Date.current}"
        Rails.cache.increment(token_key, tokens_used, expires_in: 32.days)
      end
    end

    def track_usage_patterns
      # Track hourly usage patterns
      hour = Time.current.hour
      hourly_key = "ai_usage:hour:#{hour}:#{Date.current}"
      Rails.cache.increment(hourly_key, 1, expires_in: 32.days)

      # Track daily usage by operation
      daily_operation_key = "ai_usage:operation:#{operation_type}:#{Date.current}"
      Rails.cache.increment(daily_operation_key, 1, expires_in: 32.days)

      # Track user activity patterns
      user_activity_key = "ai_usage:user:#{user_id}:#{Date.current}"
      Rails.cache.increment(user_activity_key, 1, expires_in: 32.days)

      # Track weekly trends
      week_key = "ai_usage:week:#{Date.current.beginning_of_week}"
      Rails.cache.increment(week_key, 1, expires_in: 8.weeks)
    end

    def store_usage_record
      # Store detailed usage record for analysis
      usage_record = {
        user_id: user_id,
        operation_type: operation_type,
        cost: cost.to_f,
        model_used: model_used,
        tokens_used: tokens_used,
        response_time_ms: response_time_ms,
        success: success,
        metadata: metadata,
        timestamp: Time.current.iso8601,
        date: Date.current.to_s,
        hour: Time.current.hour
      }

      # Store with unique key for detailed analysis
      record_key = "ai_usage_record:#{SecureRandom.uuid}"
      Rails.cache.write(record_key, usage_record, expires_in: 90.days)

      # Log structured usage data
      Rails.logger.info "[AI_USAGE] #{usage_record.to_json}"
    end

    # Class methods for retrieving analytics
    def self.get_user_daily_cost(user_id, date = Date.current)
      key = "ai_cost:user:#{user_id}:#{date}"
      Rails.cache.read(key) || 0.0
    end

    def self.get_user_monthly_cost(user_id, month = Date.current.beginning_of_month)
      key = "ai_cost:user:#{user_id}:#{month}"
      Rails.cache.read(key) || 0.0
    end

    def self.get_operation_success_rate(operation_type, date = Date.current)
      success_key = "ai_performance:#{operation_type}:success_rate:#{date}"
      total_key = "ai_performance:#{operation_type}:total:#{date}"
      
      successes = Rails.cache.read(success_key) || 0
      total = Rails.cache.read(total_key) || 0
      
      return 0.0 if total.zero?
      (successes.to_f / total * 100).round(2)
    end

    def self.get_average_response_time(operation_type)
      key = "ai_performance:#{operation_type}:response_times"
      times = Rails.cache.read(key) || []
      
      return 0 if times.empty?
      (times.sum.to_f / times.length).round(0)
    end

    def self.get_platform_daily_cost(date = Date.current)
      key = "ai_cost:platform:#{date}"
      Rails.cache.read(key) || 0.0
    end

    def self.get_hourly_usage_pattern(date = Date.current)
      pattern = {}
      (0..23).each do |hour|
        key = "ai_usage:hour:#{hour}:#{date}"
        pattern[hour] = Rails.cache.read(key) || 0
      end
      pattern
    end
  end
end