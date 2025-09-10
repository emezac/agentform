# frozen_string_literal: true

module SuperAgent
  module A2A
    # Authentication middleware for A2A server
    class AuthMiddleware
      def initialize(app, auth_token: nil)
        @app = app
        @auth_token = auth_token
      end

      def call(env)
        # Skip auth for public endpoints
        return @app.call(env) if public_endpoint?(env['PATH_INFO'])

        return @app.call(env) unless @auth_token

        auth_header = env['HTTP_AUTHORIZATION']
        return unauthorized unless auth_header

        token = extract_token(auth_header)
        return unauthorized unless valid_token?(token)

        @app.call(env)
      end

      private

      def public_endpoint?(path)
        public_paths = [
          '/.well-known/agent.json',
          '/health',
          '/favicon.ico',
        ]

        public_paths.any? { |public_path| path == public_path }
      end

      def extract_token(auth_header)
        case auth_header
        when /\ABearer\s+(.+)\z/i
          Regexp.last_match(1)
        when /\ABasic\s+(.+)\z/i
          # Handle basic auth if needed
          nil
        else
          nil
        end
      end

      def valid_token?(token)
        case @auth_token
        when String
          token == @auth_token
        when Array
          @auth_token.include?(token)
        when Proc
          @auth_token.call(token)
        when Hash
          # Handle different auth configurations
          case @auth_token[:type]
          when :static
            token == @auth_token[:token]
          when :env
            token == ENV[@auth_token[:key]]
          else
            false
          end
        else
          false
        end
      rescue StandardError => e
        log_error("Token validation error: #{e.message}")
        false
      end

      def unauthorized
        [401,
         {
           'Content-Type' => 'application/json',
           'WWW-Authenticate' => 'Bearer realm="A2A Agent"',
         },
         [{ 'error' => 'Unauthorized', 'code' => 'auth_required' }.to_json],]
      end

      def log_error(message)
        return unless defined?(SuperAgent.logger)

        SuperAgent.logger.error("A2A Auth: #{message}")
      end
    end
  end
end
