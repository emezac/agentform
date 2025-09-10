# frozen_string_literal: true

module SuperAgent
  module A2A
    # Retry manager with exponential backoff for A2A operations
    class RetryManager
      def initialize(max_retries: 3, base_delay: 1.0, max_delay: 32.0, backoff_factor: 2.0)
        @max_retries = max_retries
        @base_delay = base_delay
        @max_delay = max_delay
        @backoff_factor = backoff_factor
      end

      def with_retry(&block)
        attempt = 0
        begin
          attempt += 1
          yield
        rescue StandardError => e
          raise e unless should_retry?(e, attempt)

          delay = calculate_delay(attempt)
          log_retry_attempt(attempt, delay, e)
          sleep(delay)
          retry
        end
      end

      private

      def should_retry?(error, attempt)
        return false if attempt >= @max_retries

        retryable_errors = [
          Net::TimeoutError,
          Net::HTTPServiceUnavailable,
          Net::HTTPRequestTimeout,
          Net::HTTPTooManyRequests,
          SocketError,
          Errno::ECONNREFUSED,
          Errno::ECONNRESET,
          Errno::ETIMEDOUT,
          Timeout::Error,
        ]

        retryable_errors.any? { |klass| error.is_a?(klass) }
      end

      def calculate_delay(attempt)
        delay = @base_delay * (@backoff_factor**(attempt - 1))
        [delay, @max_delay].min
      end

      def log_retry_attempt(attempt, delay, error)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.warn(
          "A2A retry attempt #{attempt}/#{@max_retries} after #{delay}s delay: #{error.message}"
        )
      end
    end
  end
end
