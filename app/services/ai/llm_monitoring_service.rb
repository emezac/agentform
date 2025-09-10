# frozen_string_literal: true

module Ai
  class LlmMonitoringService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :model_name, :string
    attribute :operation_type, :string
    attribute :request_tokens, :integer
    attribute :response_tokens, :integer
    attribute :response_time_ms, :integer
    attribute :success, :boolean, default: true
    attribute :error_type, :string
    attribute :error_message, :string
    attribute :retry_count, :integer, default: 0
    attribute :temperature, :float
    attribute :max_tokens, :integer
    attribute :user_id, :string

    MODELS = %w[gpt-4o gpt-4o-mini gpt-3.5-turbo claude-3-sonnet claude-3-haiku].freeze
    OPERATION_TYPES = %w[content_analysis form_generation question_enhancement validation].freeze

    validates :model_name, presence: true, inclusion: { in: MODELS }
    validates :operation_type, presence: true, inclusion: { in: OPERATION_TYPES }

    def self.monitor_request(request_data)
      service = new(request_data)
      service.monitor_request
    end

    def monitor_request
      return false unless valid?

      # Track model performance
      track_model_performance

      # Track API reliability
      track_api_reliability

      # Monitor cost efficiency
      monitor_cost_efficiency

      # Track quality metrics
      track_quality_metrics

      # Alert on anomalies
      check_for_anomalies

      true
    rescue StandardError => e
      Rails.logger.error "Failed to monitor LLM request: #{e.message}"
      false
    end

    private

    def track_model_performance
      # Track response times by model
      response_time_key = "llm_performance:#{model_name}:response_times"
      current_times = Rails.cache.read(response_time_key) || []
      current_times << response_time_ms if response_time_ms.present?
      current_times = current_times.last(100) # Keep rolling window
      Rails.cache.write(response_time_key, current_times, expires_in: 1.day)

      # Track token usage efficiency
      if request_tokens.present? && response_tokens.present?
        total_tokens = request_tokens + response_tokens
        token_key = "llm_performance:#{model_name}:tokens:#{Date.current}"
        Rails.cache.increment(token_key, total_tokens, expires_in: 32.days)

        # Track token efficiency by operation
        operation_token_key = "llm_performance:#{operation_type}:tokens:#{Date.current}"
        Rails.cache.increment(operation_token_key, total_tokens, expires_in: 32.days)
      end

      # Track request volume by model
      volume_key = "llm_performance:#{model_name}:requests:#{Date.current}"
      Rails.cache.increment(volume_key, 1, expires_in: 32.days)
    end

    def track_api_reliability
      # Track success rates by model
      success_key = "llm_reliability:#{model_name}:success:#{Date.current}"
      total_key = "llm_reliability:#{model_name}:total:#{Date.current}"
      
      Rails.cache.increment(total_key, 1, expires_in: 32.days)
      if success
        Rails.cache.increment(success_key, 1, expires_in: 32.days)
      end

      # Track error patterns
      if !success && error_type.present?
        error_key = "llm_reliability:#{model_name}:errors:#{error_type}:#{Date.current}"
        Rails.cache.increment(error_key, 1, expires_in: 32.days)
      end

      # Track retry patterns
      if retry_count > 0
        retry_key = "llm_reliability:#{model_name}:retries:#{Date.current}"
        Rails.cache.increment(retry_key, retry_count, expires_in: 32.days)
      end
    end

    def monitor_cost_efficiency
      return unless request_tokens.present? && response_tokens.present?

      # Calculate estimated cost based on model pricing
      estimated_cost = calculate_estimated_cost
      
      # Track cost per operation type
      cost_key = "llm_cost:#{operation_type}:#{Date.current}"
      Rails.cache.increment_float(cost_key, estimated_cost, expires_in: 32.days)

      # Track cost per model
      model_cost_key = "llm_cost:#{model_name}:#{Date.current}"
      Rails.cache.increment_float(model_cost_key, estimated_cost, expires_in: 32.days)

      # Track cost efficiency (cost per successful operation)
      if success
        efficiency_key = "llm_efficiency:#{operation_type}:cost_per_success:#{Date.current}"
        current_costs = Rails.cache.read(efficiency_key) || []
        current_costs << estimated_cost
        current_costs = current_costs.last(100)
        Rails.cache.write(efficiency_key, current_costs, expires_in: 32.days)
      end
    end

    def track_quality_metrics
      # Track temperature usage patterns
      if temperature.present?
        temp_key = "llm_quality:#{operation_type}:temperature:#{Date.current}"
        current_temps = Rails.cache.read(temp_key) || []
        current_temps << temperature
        current_temps = current_temps.last(100)
        Rails.cache.write(temp_key, current_temps, expires_in: 32.days)
      end

      # Track max_tokens usage
      if max_tokens.present?
        max_tokens_key = "llm_quality:#{operation_type}:max_tokens:#{Date.current}"
        current_max_tokens = Rails.cache.read(max_tokens_key) || []
        current_max_tokens << max_tokens
        current_max_tokens = current_max_tokens.last(100)
        Rails.cache.write(max_tokens_key, current_max_tokens, expires_in: 32.days)
      end

      # Track response quality indicators
      if success && response_tokens.present?
        # Track response length patterns
        response_length_key = "llm_quality:#{operation_type}:response_length:#{Date.current}"
        current_lengths = Rails.cache.read(response_length_key) || []
        current_lengths << response_tokens
        current_lengths = current_lengths.last(100)
        Rails.cache.write(response_length_key, current_lengths, expires_in: 32.days)
      end
    end

    def check_for_anomalies
      # Check for response time anomalies
      check_response_time_anomalies

      # Check for error rate spikes
      check_error_rate_anomalies

      # Check for cost anomalies
      check_cost_anomalies
    end

    def check_response_time_anomalies
      return unless response_time_ms.present?

      # Get recent response times for this model
      response_time_key = "llm_performance:#{model_name}:response_times"
      recent_times = Rails.cache.read(response_time_key) || []
      
      return if recent_times.length < 10 # Need enough data

      # Calculate average and threshold
      avg_time = recent_times.sum.to_f / recent_times.length
      threshold = avg_time * 2.5 # Alert if 2.5x slower than average

      if response_time_ms > threshold
        alert_data = {
          alert_type: 'response_time_anomaly',
          model_name: model_name,
          operation_type: operation_type,
          current_time: response_time_ms,
          average_time: avg_time.round(0),
          threshold: threshold.round(0),
          severity: 'warning'
        }

        send_anomaly_alert(alert_data)
      end
    end

    def check_error_rate_anomalies
      # Get current error rate for this model
      success_key = "llm_reliability:#{model_name}:success:#{Date.current}"
      total_key = "llm_reliability:#{model_name}:total:#{Date.current}"
      
      successes = Rails.cache.read(success_key) || 0
      total = Rails.cache.read(total_key) || 0
      
      return if total < 10 # Need enough data

      error_rate = ((total - successes).to_f / total * 100).round(2)
      
      # Alert if error rate exceeds 20%
      if error_rate > 20.0
        alert_data = {
          alert_type: 'error_rate_spike',
          model_name: model_name,
          error_rate: error_rate,
          total_requests: total,
          failed_requests: total - successes,
          severity: 'error'
        }

        send_anomaly_alert(alert_data)
      end
    end

    def check_cost_anomalies
      return unless request_tokens.present? && response_tokens.present?

      estimated_cost = calculate_estimated_cost
      
      # Get recent costs for this operation type
      efficiency_key = "llm_efficiency:#{operation_type}:cost_per_success:#{Date.current}"
      recent_costs = Rails.cache.read(efficiency_key) || []
      
      return if recent_costs.length < 10

      avg_cost = recent_costs.sum / recent_costs.length
      threshold = avg_cost * 3.0 # Alert if 3x more expensive than average

      if estimated_cost > threshold
        alert_data = {
          alert_type: 'cost_anomaly',
          operation_type: operation_type,
          model_name: model_name,
          current_cost: estimated_cost,
          average_cost: avg_cost.round(4),
          threshold: threshold.round(4),
          severity: 'warning'
        }

        send_anomaly_alert(alert_data)
      end
    end

    def send_anomaly_alert(alert_data)
      # Log the anomaly
      Rails.logger.warn "[LLM_ANOMALY] #{alert_data.to_json}"

      # Store alert for dashboard
      alert_key = "llm_alerts:#{SecureRandom.uuid}"
      alert_record = alert_data.merge({
        timestamp: Time.current.iso8601,
        user_id: user_id
      })
      Rails.cache.write(alert_key, alert_record, expires_in: 7.days)

      # Send to external monitoring if configured
      if defined?(Sentry)
        Sentry.capture_message(
          "LLM Anomaly: #{alert_data[:alert_type]}",
          level: alert_data[:severity].to_sym,
          tags: {
            model: model_name,
            operation: operation_type,
            alert_type: alert_data[:alert_type]
          },
          extra: alert_data
        )
      end
    end

    def calculate_estimated_cost
      return 0.0 unless request_tokens.present? && response_tokens.present?

      # Pricing per 1K tokens (approximate as of 2024)
      pricing = {
        'gpt-4o' => { input: 0.005, output: 0.015 },
        'gpt-4o-mini' => { input: 0.00015, output: 0.0006 },
        'gpt-3.5-turbo' => { input: 0.001, output: 0.002 },
        'claude-3-sonnet' => { input: 0.003, output: 0.015 },
        'claude-3-haiku' => { input: 0.00025, output: 0.00125 }
      }

      model_pricing = pricing[model_name] || { input: 0.001, output: 0.002 }
      
      input_cost = (request_tokens / 1000.0) * model_pricing[:input]
      output_cost = (response_tokens / 1000.0) * model_pricing[:output]
      
      (input_cost + output_cost).round(6)
    end

    # Class methods for retrieving monitoring data
    def self.get_model_success_rate(model_name, date = Date.current)
      success_key = "llm_reliability:#{model_name}:success:#{date}"
      total_key = "llm_reliability:#{model_name}:total:#{date}"
      
      successes = Rails.cache.read(success_key) || 0
      total = Rails.cache.read(total_key) || 0
      
      return 0.0 if total.zero?
      (successes.to_f / total * 100).round(2)
    end

    def self.get_average_response_time(model_name)
      key = "llm_performance:#{model_name}:response_times"
      times = Rails.cache.read(key) || []
      
      return 0 if times.empty?
      (times.sum.to_f / times.length).round(0)
    end

    def self.get_daily_token_usage(model_name, date = Date.current)
      key = "llm_performance:#{model_name}:tokens:#{date}"
      Rails.cache.read(key) || 0
    end

    def self.get_recent_alerts(limit = 10)
      # This would need a more sophisticated implementation in production
      # For now, return empty array as alerts are logged
      []
    end
  end
end