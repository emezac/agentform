# frozen_string_literal: true

module SuperAgent
  module A2A
    module Handlers
      # Handler for serving Agent Card (/.well-known/agent.json)
      class AgentCardHandler
      def initialize(workflow_registry)
        @workflow_registry = workflow_registry
      end

      def call(env)
        agent_card = generate_agent_card

        log_info("Serving agent card with #{agent_card.capabilities.size} capabilities")

        response_headers = {
          'Content-Type' => 'application/json',
          'Cache-Control' => 'public, max-age=300',
          'ETag' => generate_etag(agent_card),
          'Last-Modified' => agent_card.updated_at,
        }

        # Handle conditional requests
        return [304, response_headers, []] if handle_conditional_request(env, response_headers)

        [200, response_headers, [agent_card.to_json]]
      rescue StandardError => e
        log_error("Failed to generate agent card: #{e.message}")
        error_response(500, 'Failed to generate agent card', e)
      end

      private

      def generate_agent_card
        if @workflow_registry.size == 1
          # Single workflow mode
          workflow_class = @workflow_registry.values.first
          AgentCard.from_workflow(workflow_class)
        else
          # Gateway mode - multiple workflows
          AgentCard.from_workflow_registry(@workflow_registry)
        end
      end

      def generate_etag(agent_card)
        content_hash = Digest::MD5.hexdigest(agent_card.to_json)
        "\"#{content_hash}\""
      end

      def handle_conditional_request(env, response_headers)
        # Handle If-None-Match (ETag)
        if env['HTTP_IF_NONE_MATCH']
          client_etags = env['HTTP_IF_NONE_MATCH'].split(',').map(&:strip)
          return true if client_etags.include?(response_headers['ETag'])
        end

        # Handle If-Modified-Since
        if env['HTTP_IF_MODIFIED_SINCE']
          begin
            client_time = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE'])
            server_time = Time.parse(response_headers['Last-Modified'])
            return true if server_time <= client_time
          rescue ArgumentError
            # Invalid date format, ignore
          end
        end

        false
      end

      def error_response(status, message, error = nil)
        error_data = {
          error: message,
          timestamp: Time.current.iso8601,
        }

        if error && defined?(Rails) && Rails.env.development?
          error_data[:details] = {
            class: error.class.name,
            message: error.message,
            backtrace: error.backtrace&.first(5),
          }
        end

        [status,
         { 'Content-Type' => 'application/json' },
         [error_data.to_json],]
      end

      def log_info(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.info("AgentCardHandler: #{message}")
      end

      def log_error(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.error("AgentCardHandler: #{message}")
      end
      end
    end
  end
end
