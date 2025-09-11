# frozen_string_literal: true

# RedisErrorLogger - Centralized Redis error logging service
# Provides comprehensive error logging for all Redis operations across the application
# Includes context information, masked connection details, and Sentry integration
class RedisErrorLogger
  include ActiveSupport::Configurable
  
  # Error severity levels
  SEVERITY_LEVELS = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
    fatal: 4
  }.freeze
  
  # Redis error types for categorization
  REDIS_ERROR_TYPES = {
    connection: [
      'Redis::CannotConnectError',
      'Redis::ConnectionError',
      'Redis::TimeoutError',
      'Redis::ReadOnlyError'
    ].freeze,
    command: [
      'Redis::CommandError',
      'Redis::WrongTypeError',
      'Redis::OutOfMemoryError'
    ].freeze,
    protocol: [
      'Redis::ProtocolError',
      'Redis::ParserError'
    ].freeze,
    client: [
      'Redis::ClientError',
      'Redis::InheritedError'
    ].freeze
  }.freeze
  
  class << self
    # Main entry point for logging Redis errors
    # @param exception [Exception] The Redis-related exception
    # @param context [Hash] Additional context information
    # @param severity [Symbol] Log severity level (:debug, :info, :warn, :error, :fatal)
    def log_redis_error(exception, context = {}, severity: :error)
      return unless should_log?(exception, severity)
      
      error_data = build_error_data(exception, context)
      log_to_rails_logger(error_data, severity)
      send_to_sentry(exception, error_data) if should_send_to_sentry?(severity)
      track_error_metrics(error_data)
      
      error_data
    end
    
    # Log Redis connection errors specifically
    def log_connection_error(exception, context = {})
      enhanced_context = context.merge({
        error_category: 'connection',
        redis_url_masked: mask_redis_url(current_redis_url),
        ssl_enabled: ssl_enabled?,
        environment: Rails.env,
        timestamp: Time.current.iso8601
      })
      
      log_redis_error(exception, enhanced_context, severity: :error)
    end
    
    # Log Redis command errors
    def log_command_error(exception, context = {})
      enhanced_context = context.merge({
        error_category: 'command',
        redis_url_masked: mask_redis_url(current_redis_url),
        timestamp: Time.current.iso8601
      })
      
      log_redis_error(exception, enhanced_context, severity: :warn)
    end
    
    # Log Redis operation warnings (non-critical issues)
    def log_redis_warning(message, context = {})
      warning_data = {
        message: message,
        context: context,
        redis_url_masked: mask_redis_url(current_redis_url),
        ssl_enabled: ssl_enabled?,
        environment: Rails.env,
        timestamp: Time.current.iso8601,
        severity: 'warning'
      }
      
      Rails.logger.warn format_log_message(warning_data)
      track_warning_metrics(warning_data)
    end
    
    # Log Redis operation info (successful operations, monitoring)
    def log_redis_info(message, context = {})
      info_data = {
        message: message,
        context: context,
        redis_url_masked: mask_redis_url(current_redis_url),
        timestamp: Time.current.iso8601,
        severity: 'info'
      }
      
      Rails.logger.info format_log_message(info_data)
    end
    
    # Log Redis connection recovery
    def log_connection_recovery(context = {})
      recovery_data = {
        message: 'Redis connection recovered successfully',
        context: context,
        redis_url_masked: mask_redis_url(current_redis_url),
        ssl_enabled: ssl_enabled?,
        environment: Rails.env,
        timestamp: Time.current.iso8601,
        event_type: 'connection_recovery'
      }
      
      Rails.logger.info format_log_message(recovery_data)
      
      if defined?(Sentry)
        Sentry.capture_message(
          'Redis connection recovered',
          level: :info,
          extra: recovery_data
        )
      end
    end
    
    # Test Redis connection and log results
    def test_and_log_connection(component: 'unknown')
      start_time = Time.current

      begin
        # Test basic Redis connectivity using proper SSL configuration
        case component
        when 'sidekiq'
          if defined?(Sidekiq)
            Sidekiq.redis(&:ping)
          else
            Redis.new(RedisConfig.sidekiq_config).ping
          end
        when 'cache'
          if Rails.cache.respond_to?(:redis)
            Rails.cache.redis.ping
          else
            raise "Rails.cache no responde a :redis. No se puede probar la conexión."
          end
        when 'actioncable'
          if defined?(ActionCable) && ActionCable.server.pubsub.respond_to?(:redis_connection)
            ActionCable.server.pubsub.redis_connection.ping
          else
            raise "Action Cable no parece estar configurado con un adaptador de Redis."
          end
        else
          Redis.new(RedisConfig.connection_config).ping
        end
        
        duration = Time.current - start_time
        
        log_redis_info("Redis connection test successful for #{component}", {
          component: component,
          duration_ms: (duration * 1000).round(2),
          test_type: 'connectivity'
        })
        
        true
      rescue => e
        duration = Time.current - start_time
        
        log_connection_error(e, {
          component: component,
          duration_ms: (duration * 1000).round(2),
          test_type: 'connectivity',
          operation: 'connection_test'
        })
        
        false
      end
    
    # Get Redis connection diagnostics
    def get_connection_diagnostics
      diagnostics = {
        redis_url_masked: mask_redis_url(current_redis_url),
        ssl_enabled: ssl_enabled?,
        environment: Rails.env,
        timestamp: Time.current.iso8601
      }
      
      begin
        # Try to get Redis info
        redis_info = get_redis_info
        diagnostics.merge!(redis_info)
      rescue => e
        diagnostics[:connection_error] = e.message
        diagnostics[:connection_status] = 'failed'
      end
      
      diagnostics
    end
    
    private
    
    # Build comprehensive error data structure
    def build_error_data(exception, context)
      {
        error_class: exception.class.name,
        error_message: exception.message,
        error_category: categorize_error(exception),
        context: context,
        redis_url_masked: mask_redis_url(current_redis_url),
        ssl_enabled: ssl_enabled?,
        environment: Rails.env,
        timestamp: Time.current.iso8601,
        backtrace: format_backtrace(exception),
        redis_diagnostics: get_safe_redis_diagnostics
      }
    end
    
    # Determine if error should be logged based on severity and configuration
    def should_log?(exception, severity)
      # In test environment, check if Redis error logging is explicitly enabled
      if Rails.env.test?
        return false unless Rails.application.config.respond_to?(:log_redis_errors_in_test) &&
                           Rails.application.config.log_redis_errors_in_test
      end
      
      # Always log errors and fatal
      return true if [:error, :fatal].include?(severity)
      
      # Log warnings in production and development, or in test when enabled
      return true if severity == :warn && (
        !Rails.env.test? || 
        (Rails.application.config.respond_to?(:log_redis_errors_in_test) && 
         Rails.application.config.log_redis_errors_in_test)
      )
      
      # Log info and debug only in development or when explicitly enabled
      [:info, :debug].include?(severity) && 
        (Rails.env.development? || 
         (Rails.application.config.respond_to?(:verbose_redis_logging) && 
          Rails.application.config.verbose_redis_logging))
    end
    
    # Determine if error should be sent to Sentry
    def should_send_to_sentry?(severity)
      defined?(Sentry) && [:error, :fatal].include?(severity)
    end
    
    # Categorize Redis errors by type
    def categorize_error(exception)
      error_class = exception.class.name
      
      REDIS_ERROR_TYPES.each do |category, error_classes|
        return category.to_s if error_classes.include?(error_class)
      end
      
      'unknown'
    end
    
    # Format error message for Rails logger
    def format_log_message(data)
      severity_text = case data[:severity]
                     when 'info'
                       'INFO'
                     when 'warning'
                       'WARNING'
                     when 'debug'
                       'DEBUG'
                     when 'fatal'
                       'FATAL'
                     else
                       'ERROR'
                     end
      
      message_parts = [
        "Redis #{severity_text}:",
        data[:error_message] || data[:message]
      ]
      
      if data[:context] && !data[:context].empty?
        message_parts << "Context: #{data[:context].inspect}"
      end
      
      if data[:redis_url_masked]
        message_parts << "Redis URL: #{data[:redis_url_masked]}"
      end
      
      if data[:error_category]
        message_parts << "Category: #{data[:error_category]}"
      end
      
      message_parts.join(' | ')
    end
    
    # Log to Rails logger with appropriate severity
    def log_to_rails_logger(error_data, severity)
      formatted_message = format_log_message(error_data)
      
      case severity
      when :debug
        Rails.logger.debug formatted_message
      when :info
        Rails.logger.info formatted_message
      when :warn
        Rails.logger.warn formatted_message
      when :error
        Rails.logger.error formatted_message
      when :fatal
        Rails.logger.fatal formatted_message
      end
      
      # Log additional context in debug mode
      if Rails.env.development? || Rails.logger.level <= Logger::DEBUG
        Rails.logger.debug "Redis Error Details: #{error_data.except(:backtrace).to_json}"
        
        if error_data[:backtrace]
          Rails.logger.debug "Redis Error Backtrace:\n#{error_data[:backtrace]}"
        end
      end
    end
    
    # Send error to Sentry with enhanced context
    def send_to_sentry(exception, error_data)
      Sentry.capture_exception(exception, extra: error_data.except(:backtrace))
    end
    
    # Track error metrics for monitoring
    def track_error_metrics(error_data)
      # This could be extended to send metrics to monitoring services
      # For now, we'll just increment Rails cache-based counters
      
      begin
        cache_key = "redis_errors:#{Date.current}:#{error_data[:error_category]}"
        current_count = Rails.cache.read(cache_key) || 0
        Rails.cache.write(cache_key, current_count + 1, expires_in: 7.days)
        
        total_cache_key = "redis_errors:#{Date.current}:total"
        total_count = Rails.cache.read(total_cache_key) || 0
        Rails.cache.write(total_cache_key, total_count + 1, expires_in: 7.days)
      rescue
        # Ignore cache errors when tracking Redis errors to avoid recursion
      end
    end
    
    # Track warning metrics
    def track_warning_metrics(warning_data)
      begin
        cache_key = "redis_warnings:#{Date.current}"
        current_count = Rails.cache.read(cache_key) || 0
        Rails.cache.write(cache_key, current_count + 1, expires_in: 7.days)
      rescue
        # Ignore cache errors
      end
    end
    
    # Get current Redis URL from configuration
    def current_redis_url
      ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    end
    
    # Check if SSL is enabled
    def ssl_enabled?
      current_redis_url.start_with?('rediss://')
    end
    
    # Mask sensitive information in Redis URL
    def mask_redis_url(url)
      return url unless url&.include?('@')
      
      # Replace password with asterisks
      url.gsub(/:[^:@]*@/, ':***@')
    end
    
    # Format exception backtrace for logging
    def format_backtrace(exception)
      return nil unless exception.backtrace
      
      # Limit backtrace to first 10 lines to avoid log spam
      exception.backtrace.first(10).join("\n")
    end
    
    # Get Redis server information safely
    def get_redis_info
      info = {}
      
      begin
        # Try different Redis connection methods
        redis_client = if defined?(Sidekiq)
          Sidekiq.redis { |conn| conn }
        elsif Rails.cache.respond_to?(:redis)
          Rails.cache.redis
        else
          Redis.new(url: current_redis_url)
        end
        
        server_info = redis_client.info
        
        info.merge!({
          redis_version: server_info['redis_version'],
          connected_clients: server_info['connected_clients'],
          used_memory_human: server_info['used_memory_human'],
          uptime_in_seconds: server_info['uptime_in_seconds'],
          connection_status: 'connected'
        })
      rescue => e
        info.merge!({
          connection_status: 'failed',
          connection_error: e.message
        })
      end
      
      info
    end
    
    # Get Redis diagnostics safely (won't raise exceptions)
    def get_safe_redis_diagnostics
      begin
        get_redis_info
      rescue
        {
          connection_status: 'unknown',
          diagnostic_error: 'Unable to retrieve Redis diagnostics'
        }
      end
    end
  end
end