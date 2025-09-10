# frozen_string_literal: true

require 'rack'
require 'webrick'
require 'json'
require 'openssl'

module SuperAgent
  module A2A
    # A2A Protocol Server for SuperAgent
    class Server
      attr_reader :port, :host, :auth_token, :workflow_registry, :ssl_config, :server

      def initialize(port: 8080, host: '0.0.0.0', auth_token: nil, ssl_config: nil)
        @port = port
        @host = host
        @auth_token = auth_token
        @ssl_config = ssl_config
        @workflow_registry = {}
        @server = nil
        @start_time = Time.current
      end

      # Register a single workflow
      def register_workflow(workflow_class, path = nil)
        path ||= "/agents/#{workflow_class.name.underscore}"
        @workflow_registry[path] = workflow_class
        log_info("Registered workflow #{workflow_class.name} at #{path}")
      end

      # Register all available workflows
      def register_all_workflows
        if defined?(SuperAgent::WorkflowRegistry)
          SuperAgent::WorkflowRegistry.all.each do |workflow_class|
            register_workflow(workflow_class)
          end
        else
          log_warn('SuperAgent::WorkflowRegistry not found, no workflows auto-registered')
        end
      end

      # Start the server
      def start
        log_info("Starting A2A server on #{@host}:#{@port}")
        log_info('SSL enabled') if @ssl_config
        log_info('Authentication enabled') if @auth_token
        log_info("Registered workflows: #{@workflow_registry.keys.join(', ')}")

        app = build_rack_app

        server_options = {
          Host: @host,
          Port: @port,
          Logger: server_logger,
          AccessLog: [],
        }

        if @ssl_config
          server_options.merge!(
            SSLEnable: true,
            SSLCertificate: load_ssl_certificate,
            SSLPrivateKey: load_ssl_private_key
          )
        end

        @server = WEBrick::HTTPServer.new(server_options)
        @server.mount '/', Rack::Handler::WEBrick, app

        setup_signal_handlers

        log_info('A2A server started successfully')
        log_info("Agent Card available at: #{base_url}/.well-known/agent.json")
        log_info("Health check available at: #{base_url}/health")
        log_info("Invoke endpoint available at: #{base_url}/invoke")

        @server.start
      end

      # Stop the server
      def stop
        log_info('Stopping A2A server...')
        @server&.shutdown
        log_info('A2A server stopped')
      end

      # Get server health information
      def health
        {
          status: 'healthy',
          uptime: uptime,
          uptime_human: human_uptime,
          registered_workflows: @workflow_registry.size,
          version: superagent_version,
          timestamp: Time.current.iso8601,
          server_info: {
            host: @host,
            port: @port,
            ssl: @ssl_config ? true : false,
            authentication: @auth_token ? true : false,
          },
        }
      end

      # Get server statistics
      def stats
        {
          workflows: @workflow_registry.size,
          total_capabilities: total_capabilities,
          endpoints: endpoint_list,
          uptime: uptime,
          memory_usage: memory_usage,
        }
      end

      private

      def build_rack_app
        registry = @workflow_registry
        auth_token = @auth_token
        server_instance = self

        Rack::Builder.new do
          # Add middleware stack
          use SuperAgent::A2A::LoggingMiddleware
          use SuperAgent::A2A::CorsMiddleware
          use SuperAgent::A2A::AuthMiddleware, auth_token: auth_token

          # Agent Card Discovery
          map '/.well-known/agent.json' do
            run SuperAgent::A2A::AgentCardHandler.new(registry)
          end

          # Health Check
          map '/health' do
            run SuperAgent::A2A::HealthHandler.new(registry,
                                                   start_time: server_instance.instance_variable_get(:@start_time))
          end

          # Main Invoke Endpoint
          map '/invoke' do
            run SuperAgent::A2A::InvokeHandler.new(registry)
          end

          # Individual workflow endpoints
          registry.each do |path, workflow_class|
            map path do
              run SuperAgent::A2A::WorkflowHandler.new(workflow_class)
            end
          end

          # Root endpoint with server info
          map '/' do
            run lambda { |env|
              info = {
                name: 'SuperAgent A2A Server',
                version: server_instance.superagent_version,
                status: 'running',
                endpoints: {
                  agent_card: '/.well-known/agent.json',
                  health: '/health',
                  invoke: '/invoke',
                  workflows: registry.keys,
                },
                documentation: 'https://github.com/superagent-ai/superagent',
              }
              [200, { 'Content-Type' => 'application/json' }, [info.to_json]]
            }
          end

          # Default 404 handler
          run lambda { |env|
            error_response = {
              error: 'Endpoint not found',
              path: env['PATH_INFO'],
              available_endpoints: [
                '/.well-known/agent.json',
                '/health',
                '/invoke',
              ] + registry.keys,
              timestamp: Time.current.iso8601,
            }
            [404, { 'Content-Type' => 'application/json' }, [error_response.to_json]]
          }
        end
      end

      def setup_signal_handlers
        trap('INT') { graceful_shutdown }
        trap('TERM') { graceful_shutdown }

        return unless Signal.list.key?('USR1')

        trap('USR1') do
          log_info('Received USR1 signal - logging current status')
          log_info("Health: #{health}")
          log_info("Stats: #{stats}")
        end
      end

      def graceful_shutdown
        log_info('Received shutdown signal, stopping server gracefully...')
        stop
      end

      def load_ssl_certificate
        OpenSSL::X509::Certificate.new(File.read(@ssl_config[:cert_path]))
      rescue StandardError => e
        raise ConfigurationError, "Failed to load SSL certificate: #{e.message}"
      end

      def load_ssl_private_key
        OpenSSL::PKey::RSA.new(File.read(@ssl_config[:key_path]))
      rescue StandardError => e
        raise ConfigurationError, "Failed to load SSL private key: #{e.message}"
      end

      def base_url
        protocol = @ssl_config ? 'https' : 'http'
        "#{protocol}://#{@host}:#{@port}"
      end

      def uptime
        Time.current - @start_time
      end

      def human_uptime
        seconds = uptime.to_i
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

      def superagent_version
        defined?(SuperAgent::VERSION) ? SuperAgent::VERSION : 'unknown'
      end

      def total_capabilities
        @workflow_registry.values.sum do |workflow_class|
          if workflow_class.respond_to?(:workflow_definition)
            workflow_class.workflow_definition.tasks.size
          else
            1 # Fallback
          end
        end
      end

      def endpoint_list
        endpoints = [
          '/.well-known/agent.json',
          '/health',
          '/invoke',
        ]
        endpoints.concat(@workflow_registry.keys)
        endpoints
      end

      def memory_usage
        # Get memory usage in MB

        if File.exist?('/proc/self/status')
          # Linux
          status = File.read('/proc/self/status')
          if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
            match[1].to_i / 1024
          else
            0
          end
        else
          # Fallback for other systems
          `ps -o rss= -p #{Process.pid}`.strip.to_i / 1024
        end
      rescue StandardError
        0
      end

      def server_logger
        if defined?(SuperAgent.logger)
          # Create a WEBrick-compatible logger wrapper
          Class.new do
            def initialize(logger)
              @logger = logger
            end

            def info(message)
              @logger.info("WEBrick: #{message}")
            end

            def warn(message)
              @logger.warn("WEBrick: #{message}")
            end

            def error(message)
              @logger.error("WEBrick: #{message}")
            end

            def debug(message)
              @logger.debug("WEBrick: #{message}")
            end

            def fatal(message)
              @logger.error("WEBrick FATAL: #{message}")
            end

            def unknown(message)
              @logger.info("WEBrick: #{message}")
            end
          end.new(SuperAgent.logger)
        else
          require 'logger'
          Logger.new(STDOUT)
        end
      end

      def log_info(message)
        if defined?(SuperAgent.logger)
          SuperAgent.logger.info("A2A Server: #{message}")
        else
          puts "[INFO] A2A Server: #{message}"
        end
      end

      def log_warn(message)
        if defined?(SuperAgent.logger)
          SuperAgent.logger.warn("A2A Server: #{message}")
        else
          puts "[WARN] A2A Server: #{message}"
        end
      end

      def log_error(message)
        if defined?(SuperAgent.logger)
          SuperAgent.logger.error("A2A Server: #{message}")
        else
          puts "[ERROR] A2A Server: #{message}"
        end
      end
    end

    # Individual workflow handler for direct workflow endpoints
    class WorkflowHandler
      def initialize(workflow_class)
        @workflow_class = workflow_class
      end

      def call(env)
        request = Rack::Request.new(env)

        case request.request_method
        when 'GET'
          # Return workflow information
          workflow_info = {
            name: @workflow_class.name,
            description: extract_description,
            capabilities: extract_capabilities,
            endpoint: env['PATH_INFO'],
          }
          [200, { 'Content-Type' => 'application/json' }, [workflow_info.to_json]]
        when 'POST'
          # Execute workflow directly
          invoke_handler = InvokeHandler.new({ env['PATH_INFO'] => @workflow_class })
          invoke_handler.call(env)
        else
          [405, { 'Content-Type' => 'application/json' }, [{ 'error' => 'Method not allowed' }.to_json]]
        end
      end

      private

      def extract_description
        if @workflow_class.respond_to?(:description)
          @workflow_class.description
        else
          "SuperAgent workflow: #{@workflow_class.name}"
        end
      end

      def extract_capabilities
        if @workflow_class.respond_to?(:workflow_definition)
          @workflow_class.workflow_definition.tasks.map(&:name)
        else
          [@workflow_class.name.underscore]
        end
      end
    end

    # Configuration error for server setup issues
    class ConfigurationError < Error; end
  end
end
