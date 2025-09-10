# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'

module SuperAgent
  module A2A
    # Client for communicating with A2A-compatible agents
    class Client
      attr_reader :agent_url, :auth_token, :timeout, :retry_manager, :cache_manager

      def initialize(agent_url, auth_token: nil, timeout: 30, max_retries: 3, cache_ttl: 300)
        @agent_url = normalize_url(agent_url)
        @auth_token = auth_token
        @timeout = timeout
        @retry_manager = RetryManager.new(max_retries: max_retries)
        @cache_manager = CacheManager.new(ttl: cache_ttl)
        @http_client = build_http_client
      end

      # Fetch agent card with caching
      def fetch_agent_card(force_refresh: false)
        cache_key = "agent_card:#{@agent_url}"

        return @cache_manager.get(cache_key) if !force_refresh && @cache_manager.cached?(cache_key)

        @retry_manager.with_retry do
          response = http_get("#{@agent_url}/.well-known/agent.json")
          validate_response!(response, expected_content_type: 'application/json')

          card_data = JSON.parse(response.body)
          agent_card = AgentCard.from_hash(card_data)

          @cache_manager.set(cache_key, agent_card)

          log_info("Successfully fetched agent card for #{@agent_url}")
          agent_card
        end
      rescue StandardError => e
        error = ErrorHandler.wrap_network_error(e)
        log_error("Failed to fetch agent card: #{error.message}")
        raise error
      end

      # Invoke a skill on the remote agent
      def invoke_skill(skill_name, parameters, request_id: nil, stream: false, webhook_url: nil)
        request_id ||= SecureRandom.uuid

        # Validate skill exists
        agent_card = fetch_agent_card
        validate_skill_exists!(agent_card, skill_name)

        payload = build_invoke_payload(skill_name, parameters, request_id, stream, webhook_url)

        @retry_manager.with_retry do
          if stream
            invoke_skill_streaming(payload, request_id)
          else
            invoke_skill_blocking(payload)
          end
        end
      rescue StandardError => e
        error = ErrorHandler.wrap_network_error(e)
        log_error("Skill invocation failed: #{error.message}")
        raise error
      end

      # Health check for the remote agent
      def health_check
        @retry_manager.with_retry do
          response = http_get("#{@agent_url}/health")
          validate_response!(response)

          JSON.parse(response.body)
        end
      rescue StandardError => e
        log_error("Health check failed: #{e.message}")
        false
      end

      # List available capabilities
      def list_capabilities
        agent_card = fetch_agent_card
        agent_card.capabilities
      end

      # Check if agent supports a specific skill
      def supports_skill?(skill_name)
        agent_card = fetch_agent_card
        agent_card.capabilities.any? { |cap| cap.name == skill_name }
      end

      # Check if agent supports a specific modality
      def supports_modality?(modality)
        agent_card = fetch_agent_card
        agent_card.supported_modalities.include?(modality.to_s)
      end

      # Get agent information
      def agent_info
        {
          url: @agent_url,
          timeout: @timeout,
          cached_agent_card: @cache_manager.cached?("agent_card:#{@agent_url}"),
          cache_size: @cache_manager.size,
        }
      end

      # Clear all caches
      def clear_cache
        @cache_manager.clear
      end

      private

      def normalize_url(url)
        uri = URI.parse(url)
        uri.scheme ||= 'http'
        uri.to_s.chomp('/')
      end

      def build_http_client
        # Configure HTTP client with connection pooling
        uri = URI(@agent_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = @timeout
        http.open_timeout = @timeout / 2
        http.keep_alive_timeout = 30
        http
      end

      def http_get(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        add_common_headers(request)
        add_auth_headers(request)

        log_debug("GET #{url}")
        @http_client.request(request)
      end

      def http_post(url, payload)
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        add_common_headers(request)
        add_auth_headers(request)
        request.body = payload.to_json

        log_debug("POST #{url} with payload: #{payload}")
        @http_client.request(request)
      end

      def add_common_headers(request)
        request['User-Agent'] = user_agent
        request['Accept'] = 'application/json'
        request['X-Request-ID'] = SecureRandom.uuid
      end

      def add_auth_headers(request)
        return unless @auth_token

        case @auth_token
        when Hash
          handle_complex_auth(request, @auth_token)
        else
          request['Authorization'] = "Bearer #{@auth_token}"
        end
      end

      def handle_complex_auth(request, auth_config)
        case auth_config[:type]
        when :api_key
          request['X-API-Key'] = auth_config[:token]
        when :oauth2
          request['Authorization'] = "Bearer #{auth_config[:access_token]}"
        when :basic
          request.basic_auth(auth_config[:username], auth_config[:password])
        else
          request['Authorization'] = "Bearer #{auth_config[:token]}"
        end
      end

      def validate_response!(response, expected_content_type: nil)
        case response.code.to_i
        when 200..299
          if expected_content_type && !response['Content-Type']&.include?(expected_content_type)
            raise ProtocolError, "Expected #{expected_content_type}, got #{response['Content-Type']}"
          end
        when 401
          raise AuthenticationError, 'Authentication failed'
        when 404
          raise AgentCardError, 'Agent not found'
        when 408, 504
          raise TimeoutError, 'Request timeout'
        when 400..499
          raise InvocationError, "Client error: #{response.body}"
        when 500..599
          raise NetworkError, "Server error: #{response.body}"
        else
          raise Error, "Unexpected response: #{response.code}"
        end
      end

      def validate_skill_exists!(agent_card, skill_name)
        return if agent_card.capabilities.any? { |cap| cap.name == skill_name }

        available_skills = agent_card.capabilities.map(&:name).join(', ')
        raise SkillNotFoundError,
              "Skill '#{skill_name}' not found. Available skills: #{available_skills}"
      end

      def build_invoke_payload(skill_name, parameters, request_id, stream, webhook_url)
        {
          jsonrpc: '2.0',
          method: 'invoke',
          params: {
            task: {
              id: request_id,
              skill: skill_name,
              parameters: parameters,
              options: {
                stream: stream,
                webhookUrl: webhook_url,
              }.compact,
            },
          },
          id: request_id,
        }
      end

      def invoke_skill_blocking(payload)
        response = http_post("#{@agent_url}/invoke", payload)
        validate_response!(response, expected_content_type: 'application/json')

        result = JSON.parse(response.body)
        parse_jsonrpc_response(result)
      end

      def invoke_skill_streaming(payload, request_id)
        # For streaming, we'll use Server-Sent Events
        uri = URI("#{@agent_url}/invoke")
        request = Net::HTTP::Post.new(uri)
        request['Accept'] = 'text/event-stream'
        request['Cache-Control'] = 'no-cache'
        request['Content-Type'] = 'application/json'
        add_common_headers(request)
        add_auth_headers(request)
        request.body = payload.to_json

        results = []
        errors = []

        @http_client.request(request) do |response|
          validate_response!(response, expected_content_type: 'text/event-stream')

          response.read_body do |chunk|
            parse_sse_chunk(chunk) do |event|
              log_debug("Streaming event: #{event}")

              case event[:event]
              when 'task_complete', 'complete'
                results << event[:data]['result'] if event[:data] && event[:data]['result']
              when 'error'
                error_msg = event[:data]['error'] || 'Unknown streaming error'
                errors << error_msg
              end

              # Yield event to block if given
              yield event if block_given?
            end
          end
        end

        # Handle any errors that occurred during streaming
        raise InvocationError, "Streaming errors: #{errors.join(', ')}" if errors.any?

        # Combine streaming results
        combined_result = results.reduce({}) { |acc, result| acc.merge(result) }
        { 'result' => combined_result, 'status' => 'completed' }
      end

      def parse_jsonrpc_response(response)
        raise InvocationError, "Remote error: #{response['error']['message']}" if response['error']

        response['result']
      end

      def parse_sse_chunk(chunk)
        chunk.split('\\n\\n').each do |event_data|
          next if event_data.strip.empty?

          event = {}
          event_data.split('\\n').each do |line|
            if line.start_with?('data: ')
              begin
                event[:data] = JSON.parse(line[6..-1])
              rescue JSON::ParserError
                event[:data] = line[6..-1]
              end
            elsif line.start_with?('event: ')
              event[:event] = line[7..-1]
            elsif line.start_with?('id: ')
              event[:id] = line[4..-1]
            end
          end

          yield event if event.any?
        end
      end

      def user_agent
        SuperAgent.configuration.a2a_user_agent
      end

      def log_info(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.info(message)
      end

      def log_error(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.error(message)
      end

      def log_debug(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.debug(message)
      end
    end

    # Enhanced client with connection pooling and advanced features
    class PooledClient < Client
      def initialize(agent_url, **options)
        super
        @connection_pool = ConnectionPool.new
      end

      private

      def build_http_client
        @connection_pool.checkout do |http|
          super
        end
      end

      # Simple connection pool implementation
      class ConnectionPool
        def initialize(size: 5)
          @size = size
          @connections = []
          @mutex = Mutex.new
        end

        def checkout
          @mutex.synchronize do
            connection = @connections.pop || create_connection
            begin
              yield connection
            ensure
              @connections.push(connection) if @connections.size < @size
            end
          end
        end

        private

        def create_connection
          # Create new HTTP connection
          # This would be implemented based on specific requirements
          Net::HTTP.new
        end
      end
    end
  end
end
