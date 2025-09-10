# frozen_string_literal: true

require 'securerandom'

module SuperAgent
  module A2A
    module Middleware
      # Logging middleware for A2A server with structured logging
      class LoggingMiddleware
        def initialize(app, logger: nil)
          @app = app
          @logger = logger || default_logger
        end

        def call(env)
          start_time = Time.current
          request_id = extract_request_id(env)

          log_request(env, request_id)

          status, headers, body = @app.call(env)

          duration = Time.current - start_time
          log_response(status, duration, request_id, headers)

          # Add request ID to response headers
          headers['X-Request-ID'] = request_id
          headers['X-Response-Time'] = "#{(duration * 1000).round(2)}ms"

          [status, headers, body]
        rescue StandardError => e
          duration = Time.current - start_time
          log_error(e, duration, request_id)

          # Return error response
          error_response = {
            error: 'Internal server error',
            request_id: request_id,
            timestamp: Time.current.iso8601
          }

          [
            500,
            {
              'Content-Type' => 'application/json',
              'X-Request-ID' => request_id
            },
            [error_response.to_json]
          ]
        end

        private

        def extract_request_id(env)
          env['HTTP_X_REQUEST_ID'] ||
            env['HTTP_X_CORRELATION_ID'] ||
            SecureRandom.uuid
        end

        def log_request(env, request_id)
          request_data = {
            event: 'a2a_request',
            request_id: request_id,
            method: env['REQUEST_METHOD'],
            path: env['PATH_INFO'],
            query_string: env['QUERY_STRING'],
            user_agent: env['HTTP_USER_AGENT'],
            remote_addr: extract_client_ip(env),
            content_type: env['CONTENT_TYPE'],
            content_length: env['CONTENT_LENGTH'],
            host: env['HTTP_HOST'],
            referer: env['HTTP_REFERER'],
            accept: env['HTTP_ACCEPT'],
            timestamp: Time.current.iso8601
          }.compact

          @logger.info(request_data)
        end

        def log_response(status, duration, request_id, headers = {})
          level = determine_log_level(status)

          response_data = {
            event: 'a2a_response',
            request_id: request_id,
            status: status,
            duration_ms: (duration * 1000).round(2),
            content_type: headers['Content-Type'],
            content_length: headers['Content-Length'],
            timestamp: Time.current.iso8601
          }.compact

          @logger.public_send(level, response_data)
        end

        def log_error(error, duration, request_id)
          error_data = {
            event: 'a2a_error',
            request_id: request_id,
            error_class: error.class.name,
            error_message: error.message,
            error_backtrace: error.backtrace&.first(10),
            duration_ms: (duration * 1000).round(2),
            timestamp: Time.current.iso8601
          }

          @logger.error(error_data)
        end

        def extract_client_ip(env)
          # Check for forwarded IP addresses
          forwarded_for = env['HTTP_X_FORWARDED_FOR']
          if forwarded_for
            # Take the first IP from the list
            forwarded_for.split(',').first.strip
          else
            env['HTTP_X_REAL_IP'] || env['REMOTE_ADDR']
          end
        end

        def determine_log_level(status)
          case status
          when 200..299
            :info
          when 300..399
            :info
          when 400..499
            :warn
          when 500..599
            :error
          else
            :info
          end
        end

        def default_logger
          if defined?(SuperAgent.logger)
            SuperAgent.logger
          else
            require 'logger'
            logger = Logger.new(STDOUT)
            logger.level = Logger::INFO
            logger.formatter = proc do |severity, datetime, progname, msg|
              data = msg.is_a?(Hash) ? msg : { message: msg }
              "#{datetime.iso8601} [#{severity}] A2A: #{data.to_json}\n"
            end
            logger
          end
        end
      end
    end
  end
end