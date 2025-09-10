# frozen_string_literal: true

module Ai
  class ErrorTrackingService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :error_type, :string
    attribute :error_message, :string
    attribute :context, :string, default: {}
    attribute :user_id, :string
    attribute :workflow_id, :string
    attribute :task_name, :string
    attribute :retry_count, :integer, default: 0
    attribute :severity, :string, default: 'error'

    SEVERITY_LEVELS = %w[debug info warn error fatal].freeze
    ERROR_CATEGORIES = %w[
      validation_error
      llm_error
      document_processing_error
      database_error
      credit_limit_error
      business_rules_error
      network_error
      timeout_error
      authentication_error
      authorization_error
      rate_limit_error
      unknown_error
    ].freeze

    validates :error_type, presence: true, inclusion: { in: ERROR_CATEGORIES }
    validates :error_message, presence: true
    validates :severity, inclusion: { in: SEVERITY_LEVELS }

    def self.track_error(error_data)
      service = new(error_data)
      service.track_error
    end

    def track_error
      return false unless valid?

      # Log structured error
      log_structured_error

      # Track metrics
      track_error_metrics

      # Send to external monitoring if configured
      send_to_external_monitoring if should_send_to_external?

      # Store in database for analysis
      store_error_record

      true
    rescue StandardError => e
      Rails.logger.error "Failed to track error: #{e.message}"
      false
    end

    private

    def log_structured_error
      log_data = {
        timestamp: Time.current.iso8601,
        error_type: error_type,
        error_message: error_message,
        severity: severity,
        user_id: user_id,
        workflow_id: workflow_id,
        task_name: task_name,
        retry_count: retry_count,
        context: context,
        environment: Rails.env,
        request_id: Current.request_id,
        session_id: Current.session&.id
      }

      case severity
      when 'debug'
        Rails.logger.debug structured_log_message(log_data)
      when 'info'
        Rails.logger.info structured_log_message(log_data)
      when 'warn'
        Rails.logger.warn structured_log_message(log_data)
      when 'error'
        Rails.logger.error structured_log_message(log_data)
      when 'fatal'
        Rails.logger.fatal structured_log_message(log_data)
      end
    end

    def structured_log_message(data)
      "[AI_ERROR] #{data.to_json}"
    end

    def track_error_metrics
      # Track error counts by type
      Rails.cache.increment("ai_errors:#{error_type}:#{Date.current}", 1, expires_in: 7.days)
      
      # Track error counts by user
      if user_id.present?
        Rails.cache.increment("ai_errors:user:#{user_id}:#{Date.current}", 1, expires_in: 7.days)
      end

      # Track error counts by workflow task
      if task_name.present?
        Rails.cache.increment("ai_errors:task:#{task_name}:#{Date.current}", 1, expires_in: 7.days)
      end

      # Track retry patterns
      if retry_count > 0
        Rails.cache.increment("ai_errors:retries:#{error_type}:#{Date.current}", retry_count, expires_in: 7.days)
      end
    end

    def should_send_to_external?
      # Send to external monitoring for error and fatal levels
      %w[error fatal].include?(severity) && external_monitoring_configured?
    end

    def external_monitoring_configured?
      # Check if Sentry, Bugsnag, or other monitoring is configured
      defined?(Sentry) || defined?(Bugsnag) || Rails.application.config.respond_to?(:error_monitoring)
    end

    def send_to_external_monitoring
      error_data = {
        message: error_message,
        level: severity,
        tags: {
          error_type: error_type,
          workflow_id: workflow_id,
          task_name: task_name,
          user_id: user_id
        },
        extra: {
          context: context,
          retry_count: retry_count,
          timestamp: Time.current.iso8601
        }
      }

      if defined?(Sentry)
        Sentry.capture_message(error_message, level: severity.to_sym, tags: error_data[:tags], extra: error_data[:extra])
      elsif defined?(Bugsnag)
        Bugsnag.notify(error_message) do |report|
          report.severity = severity
          report.add_tab(:error_details, error_data)
        end
      end
    end

    def store_error_record
      # Store error in database for analysis and reporting
      # This could be a separate ErrorLog model if needed for detailed analysis
      Rails.cache.write(
        "ai_error_log:#{SecureRandom.uuid}",
        {
          error_type: error_type,
          error_message: error_message,
          severity: severity,
          user_id: user_id,
          workflow_id: workflow_id,
          task_name: task_name,
          retry_count: retry_count,
          context: context,
          created_at: Time.current.iso8601
        },
        expires_in: 30.days
      )
    end
  end
end