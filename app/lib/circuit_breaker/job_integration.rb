# frozen_string_literal: true

module CircuitBreaker
    class OpenError < StandardError; end
    
    module JobIntegration
      extend ActiveSupport::Concern
      
      included do
        class_attribute :circuit_breaker_config
      end
      
      class_methods do
        def circuit_breaker_options(options = {})
          self.circuit_breaker_config = {
            failure_threshold: options[:failure_threshold] || 5,
            recovery_timeout: options[:recovery_timeout] || 60,
            expected_errors: options[:expected_errors] || []
          }.freeze
        end
      end
      
      private
      
      def with_circuit_breaker(&block)
        circuit_breaker = get_or_create_circuit_breaker
        
        if circuit_breaker.open?
          if circuit_breaker.should_attempt_reset?
            circuit_breaker.attempt_reset
          else
            raise CircuitBreaker::OpenError, "Circuit breaker is open"
          end
        end
        
        begin
          result = block.call
          circuit_breaker.record_success
          result
        rescue => error
          if expected_error?(error)
            circuit_breaker.record_failure
            if circuit_breaker.should_trip?
              circuit_breaker.trip!
            end
          end
          raise error
        end
      end
      
      def get_or_create_circuit_breaker
        @circuit_breaker ||= CircuitBreakerState.new(
          job_class: self.class.name,
          config: self.class.circuit_breaker_config || {}
        )
      end
      
      def expected_error?(error)
        expected_errors = self.class.circuit_breaker_config&.dig(:expected_errors) || []
        expected_errors.any? { |error_class| error.is_a?(error_class) }
      end
    end
    
    class CircuitBreakerState
      attr_reader :job_class, :config, :failure_count, :last_failure_time, :state
      
      def initialize(job_class:, config:)
        @job_class = job_class
        @config = config
        @failure_count = get_failure_count
        @last_failure_time = get_last_failure_time
        @state = determine_state
      end
      
      def open?
        @state == :open
      end
      
      def closed?
        @state == :closed
      end
      
      def half_open?
        @state == :half_open
      end
      
      def should_attempt_reset?
        open? && time_since_last_failure > recovery_timeout
      end
      
      def should_trip?
        @failure_count >= failure_threshold
      end
      
      def record_success
        reset_circuit_breaker
      end
      
      def record_failure
        increment_failure_count
        update_last_failure_time
        @failure_count = get_failure_count
      end
      
      def trip!
        @state = :open
        Rails.logger.warn "Circuit breaker tripped for #{@job_class}"
      end
      
      def attempt_reset
        @state = :half_open
        Rails.logger.info "Circuit breaker attempting reset for #{@job_class}"
      end
      
      private
      
      def failure_threshold
        @config[:failure_threshold] || 5
      end
      
      def recovery_timeout
        @config[:recovery_timeout] || 60
      end
      
      def cache_key_prefix
        "circuit_breaker:#{@job_class}"
      end
      
      def failure_count_key
        "#{cache_key_prefix}:failures"
      end
      
      def last_failure_key
        "#{cache_key_prefix}:last_failure"
      end
      
      def get_failure_count
        Rails.cache.read(failure_count_key) || 0
      end
      
      def get_last_failure_time
        Rails.cache.read(last_failure_key)
      end
      
      def increment_failure_count
        Rails.cache.write(failure_count_key, get_failure_count + 1, expires_in: 1.hour)
      end
      
      def update_last_failure_time
        Rails.cache.write(last_failure_key, Time.current, expires_in: 1.hour)
      end
      
      def reset_circuit_breaker
        Rails.cache.delete(failure_count_key)
        Rails.cache.delete(last_failure_key)
        @failure_count = 0
        @last_failure_time = nil
        @state = :closed
        Rails.logger.info "Circuit breaker reset for #{@job_class}"
      end
      
      def time_since_last_failure
        return Float::INFINITY unless @last_failure_time
        Time.current - @last_failure_time
      end
      
      def determine_state
        if @failure_count >= failure_threshold
          if @last_failure_time && time_since_last_failure > recovery_timeout
            :half_open
          else
            :open
          end
        else
          :closed
        end
      end
    end
  end