# frozen_string_literal: true

module SuperAgent
  module A2A
    module Middleware
      # CORS middleware for A2A server
      class CorsMiddleware
      def initialize(app, options = {})
        @app = app
        @options = {
          allow_origin: '*',
          allow_methods: 'GET, POST, OPTIONS',
          allow_headers: 'Content-Type, Authorization, X-Request-ID, Accept',
          expose_headers: 'X-Request-ID, X-Response-Time',
          max_age: 86_400,
          allow_credentials: false,
        }.merge(options)
      end

      def call(env)
        if env['REQUEST_METHOD'] == 'OPTIONS'
          handle_preflight_request(env)
        else
          handle_actual_request(env)
        end
      end

      private

      def handle_preflight_request(env)
        origin = env['HTTP_ORIGIN']

        if origin_allowed?(origin)
          headers = cors_headers(origin)
          headers['Access-Control-Allow-Methods'] = requested_methods(env) || @options[:allow_methods]
          headers['Access-Control-Allow-Headers'] = requested_headers(env) || @options[:allow_headers]
          [200, headers, ['']]
        else
          [403, { 'Content-Type' => 'text/plain' }, ['CORS request denied']]
        end
      end

      def handle_actual_request(env)
        origin = env['HTTP_ORIGIN']
        status, headers, body = @app.call(env)

        headers.merge!(cors_headers(origin)) if origin_allowed?(origin)

        [status, headers, body]
      end

      def cors_headers(origin = nil)
        headers = {}

        if @options[:allow_origin] == '*' && !@options[:allow_credentials]
          headers['Access-Control-Allow-Origin'] = '*'
        elsif origin && origin_allowed?(origin)
          headers['Access-Control-Allow-Origin'] = origin
        end

        headers['Access-Control-Allow-Credentials'] = 'true' if @options[:allow_credentials]

        headers['Access-Control-Expose-Headers'] = @options[:expose_headers] if @options[:expose_headers]

        headers['Access-Control-Max-Age'] = @options[:max_age].to_s if @options[:max_age]

        headers
      end

      def origin_allowed?(origin)
        return true if @options[:allow_origin] == '*'
        return false unless origin

        allowed_origins = Array(@options[:allow_origin])
        allowed_origins.any? do |allowed|
          case allowed
          when String
            origin == allowed
          when Regexp
            origin.match?(allowed)
          when Proc
            allowed.call(origin)
          else
            false
          end
        end
      end

      def requested_methods(env)
        env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']
      end

      def requested_headers(env)
        env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
      end
      end
    end
  end
end
