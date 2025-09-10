# frozen_string_literal: true

module SuperAgent
  module A2A
    module Handlers
      # Handler for health check endpoint (/health)
      class HealthHandler
      def initialize(workflow_registry, start_time: Time.current)
        @workflow_registry = workflow_registry
        @start_time = start_time
      end

      def call(env)
        health_data = generate_health_data

        # Determine status based on health checks
        status_code = health_data[:status] == 'healthy' ? 200 : 503

        response_headers = {
          'Content-Type' => 'application/json',
          'Cache-Control' => 'no-cache, no-store, must-revalidate',
        }

        [status_code, response_headers, [health_data.to_json]]
      rescue StandardError => e
        log_error("Health check failed: #{e.message}")
        error_response(503, 'Health check failed', e)
      end

      private

      def generate_health_data
        {
          status: overall_status,
          timestamp: Time.current.iso8601,
          uptime_seconds: uptime_seconds,
          uptime_human: human_uptime,
          version: {
            superagent: superagent_version,
            ruby: RUBY_VERSION,
            a2a_protocol: '1.0',
          },
          server: {
            registered_workflows: @workflow_registry.size,
            workflow_names: @workflow_registry.keys,
            memory_usage: memory_usage,
            thread_count: Thread.list.size,
          },
          capabilities: {
            total_capabilities: total_capabilities,
            authentication: authentication_enabled?,
            ssl: ssl_enabled?,
            streaming: true,
            webhooks: true,
          },
          checks: perform_health_checks,
        }
      end

      def overall_status
        checks = perform_health_checks
        failed_checks = checks.select { |_, result| result[:status] != 'ok' }

        if failed_checks.empty?
          'healthy'
        elsif failed_checks.size < checks.size / 2
          'degraded'
        else
          'unhealthy'
        end
      end

      def perform_health_checks
        checks = {}

        # Check workflow registry
        checks[:workflow_registry] = {
          status: @workflow_registry.any? ? 'ok' : 'warning',
          message: "#{@workflow_registry.size} workflows registered",
          details: {
            count: @workflow_registry.size,
            workflows: @workflow_registry.keys,
          },
        }

        # Check memory usage
        memory_mb = memory_usage
        checks[:memory] = {
          status: memory_mb < 1000 ? 'ok' : 'warning',
          message: "#{memory_mb}MB memory usage",
          details: { usage_mb: memory_mb },
        }

        # Check configuration
        checks[:configuration] = {
          status: configuration_valid? ? 'ok' : 'error',
          message: configuration_valid? ? 'Configuration valid' : 'Configuration issues',
          details: configuration_details,
        }

        # Check external dependencies if any
        checks[:dependencies] = check_dependencies

        checks
      end

      def uptime_seconds
        (Time.current - @start_time).to_i
      end

      def human_uptime
        seconds = uptime_seconds
        days = seconds / 86_400
        hours = (seconds % 86_400) / 3600
        minutes = (seconds % 3600) / 60
        seconds %= 60

        parts = []
        parts << "#{days}d" if days > 0
        parts << "#{hours}h" if hours > 0
        parts << "#{minutes}m" if minutes > 0
        parts << "#{seconds}s"

        parts.join(' ')
      end

      def memory_usage
        # Get memory usage in MB
        if File.exist?('/proc/self/status')
          # Linux
          status = File.read('/proc/self/status')
          if match = status.match(/VmRSS:\\s+(\\d+)\\s+kB/)
            match[1].to_i / 1024
          else
            0
          end
        else
          # Fallback for other systems
          begin
            `ps -o rss= -p #{Process.pid}`.strip.to_i / 1024
          rescue StandardError
            0
          end
        end
      end

      def superagent_version
        defined?(SuperAgent::VERSION) ? SuperAgent::VERSION : 'unknown'
      end

      def total_capabilities
        @workflow_registry.values.sum do |workflow_class|
          workflow_class.workflow_definition.tasks.size
        end
      end

      def authentication_enabled?
        SuperAgent.configuration.a2a_auth_token.present?
      end

      def ssl_enabled?
        SuperAgent.configuration.a2a_server_ssl_enabled?
      end

      def configuration_valid?
        SuperAgent.configuration.a2a_server_port.is_a?(Integer) &&
          SuperAgent.configuration.a2a_server_host.present?
      end

      def configuration_details
        {
          port: SuperAgent.configuration.a2a_server_port,
          host: SuperAgent.configuration.a2a_server_host,
          authentication: authentication_enabled?,
          ssl: ssl_enabled?,
          base_url: SuperAgent.configuration.a2a_base_url,
        }
      end

      def check_dependencies
        # Check if required dependencies are available
        dependencies = {
          'json' => check_json_support,
          'http' => check_http_support,
          'ssl' => check_ssl_support,
        }

        all_ok = dependencies.values.all? { |dep| dep[:status] == 'ok' }

        {
          status: all_ok ? 'ok' : 'warning',
          message: all_ok ? 'All dependencies available' : 'Some dependencies unavailable',
          details: dependencies,
        }
      end

      def check_json_support
        JSON.parse('{"test": true}')
        { status: 'ok', message: 'JSON support available' }
      rescue StandardError
        { status: 'error', message: 'JSON support unavailable' }
      end

      def check_http_support
        require 'net/http'
        { status: 'ok', message: 'HTTP support available' }
      rescue LoadError
        { status: 'error', message: 'HTTP support unavailable' }
      end

      def check_ssl_support
        require 'openssl'
        { status: 'ok', message: 'SSL support available' }
      rescue LoadError
        { status: 'warning', message: 'SSL support unavailable' }
      end

      def error_response(status, message, error = nil)
        error_data = {
          status: 'error',
          error: message,
          timestamp: Time.current.iso8601,
        }

        if error && defined?(Rails) && Rails.env.development?
          error_data[:details] = {
            class: error.class.name,
            message: error.message,
          }
        end

        [status,
         { 'Content-Type' => 'application/json' },
         [error_data.to_json],]
      end

      def log_error(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.error("HealthHandler: #{message}")
      end
    end
  end
end
