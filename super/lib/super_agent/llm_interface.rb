# frozen_string_literal: true
# lib/super_agent/llm_interface.rb

require 'net/http'
require 'json'
require 'uri'
require 'openai'

module SuperAgent
  class LlmInterface
    attr_reader :provider, :client

    def initialize(provider: nil)
      @provider = provider || SuperAgent.configuration.llm_provider
      @client = create_client
    end

    # Unified interface for text completion
    def complete(prompt:, model: nil, temperature: 0.7, max_tokens: nil, **options)
      model ||= SuperAgent.configuration.default_llm_model
      messages = normalize_messages(prompt)

      case @provider
      when :openai
        complete_openai(messages, model, temperature, max_tokens, **options)
      when :open_router
        complete_open_router(messages, model, temperature, max_tokens, **options)
      when :anthropic
        complete_anthropic(messages, model, temperature, max_tokens, **options)
      else
        raise ConfigurationError, "Unsupported LLM provider: #{@provider}"
      end
    rescue => e
      raise TaskError, "LLM API Error with provider #{@provider}: #{e.message}"
    end

    # Unified interface for image generation
    def generate_image(prompt:, model: nil, **options)
      case @provider
      when :openai
        generate_image_openai(prompt, model, **options)
      when :open_router
        generate_image_open_router(prompt, model, **options)
      else
        raise ConfigurationError, "Image generation not supported for provider: #{@provider}"
      end
    rescue => e
      raise TaskError, "Image generation error with provider #{@provider}: #{e.message}"
    end

    # Get available models for the current provider
    def available_models
      case @provider
      when :openai
        @client.models.list.dig('data')&.map { |m| m['id'] } || []
      when :open_router
        # OpenRouter models method might return different structure
        models = @client.models rescue []
        if models.respond_to?(:map)
          models.map { |m| m.is_a?(Hash) ? m['id'] : m.to_s }
        else
          []
        end
      when :anthropic
        # Anthropic doesn't have a models endpoint, return known models
        %w[claude-3-5-sonnet-20241022 claude-3-haiku-20240307 claude-3-opus-20240229]
      else
        []
      end
    rescue => e
      SuperAgent.configuration.logger.warn("Failed to fetch models for #{@provider}: #{e.message}")
      []
    end

    private

    def create_client
      case @provider
      when :openai
        OpenAI::Client.new(access_token: SuperAgent.configuration.openai_api_key)
      when :open_router
        create_open_router_client
      when :anthropic
        create_anthropic_client
      else
        raise ConfigurationError, "Unsupported LLM provider: #{@provider}"
      end
    end

    def create_open_router_client
      require 'open_router'
      
      # Configure OpenRouter
      OpenRouter.configure do |config|
        config.access_token = SuperAgent.configuration.open_router_api_key
        config.site_name = SuperAgent.configuration.open_router_site_name if SuperAgent.configuration.open_router_site_name
        config.site_url = SuperAgent.configuration.open_router_site_url if SuperAgent.configuration.open_router_site_url
      end
      
      OpenRouter::Client.new(access_token: SuperAgent.configuration.open_router_api_key)
    rescue LoadError
      raise ConfigurationError, "open_router gem not found. Add 'gem \"open_router\"' to your Gemfile"
    end

    def create_anthropic_client
      require 'anthropic'
      
      Anthropic::Client.new(access_token: SuperAgent.configuration.anthropic_api_key)
    rescue LoadError
      raise ConfigurationError, "anthropic gem not found. Add 'gem \"anthropic\"' to your Gemfile"
    end

    def normalize_messages(prompt)
      case prompt
      when String
        [{ role: 'user', content: prompt }]
      when Array
        prompt
      when Hash
        [prompt]
      else
        [{ role: 'user', content: prompt.to_s }]
      end
    end

    # OpenAI completion
    def complete_openai(messages, model, temperature, max_tokens, **options)
      params = {
        model: model,
        messages: messages,
        temperature: temperature
      }
      params[:max_tokens] = max_tokens if max_tokens
      params.merge!(options)

      response = @client.chat(parameters: params)
      response.dig('choices', 0, 'message', 'content')
    end

    # OpenRouter completion - FIXED
    def complete_open_router(messages, model, temperature, max_tokens, **options)
      # OpenRouter espera parámetros diferentes
      params = {
        model: model,
        messages: messages,
        temperature: temperature
      }
      
      # OpenRouter usa 'max_tokens' no 'max_completion_tokens'
      params[:max_tokens] = max_tokens if max_tokens
      
      # Merge additional options
      params.merge!(options)

      # OpenRouter client expects different method signature
      # Usar el método correcto según la gem open_router
      response = @client.chat(
        parameters: params
      )
      
      response.dig('choices', 0, 'message', 'content')
    rescue => e
      # Si el método chat no funciona, intentar con complete
      begin
        response = @client.complete(messages, **params.except(:messages))
        response.dig('choices', 0, 'message', 'content')
      rescue => e2
        # Si tampoco funciona complete, usar API directa
        complete_open_router_direct(messages, model, temperature, max_tokens, **options)
      end
    end

    # Método directo para OpenRouter si la gem no funciona
    def complete_open_router_direct(messages, model, temperature, max_tokens, **options)
      uri = URI('https://openrouter.ai/api/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{SuperAgent.configuration.open_router_api_key}"
      request['Content-Type'] = 'application/json'
      request['HTTP-Referer'] = SuperAgent.configuration.open_router_site_url if SuperAgent.configuration.open_router_site_url
      request['X-Title'] = SuperAgent.configuration.open_router_site_name if SuperAgent.configuration.open_router_site_name

      body = {
        model: model,
        messages: messages,
        temperature: temperature
      }
      body[:max_tokens] = max_tokens if max_tokens
      body.merge!(options)

      request.body = JSON.generate(body)

      response = http.request(request)
      
      if response.code == '200'
        result = JSON.parse(response.body)
        result.dig('choices', 0, 'message', 'content')
      else
        raise "OpenRouter API Error: #{response.code} - #{response.body}"
      end
    end

    # Anthropic completion
    def complete_anthropic(messages, model, temperature, max_tokens, **options)
      # Convert messages to Anthropic format
      system_message = messages.find { |m| m[:role] == 'system' }&.dig(:content) || ""
      user_messages = messages.reject { |m| m[:role] == 'system' }
      
      params = {
        model: model,
        max_tokens: max_tokens || 1000,
        temperature: temperature,
        system: system_message,
        messages: user_messages
      }
      params.merge!(options)

      response = @client.messages(parameters: params)
      response.dig('content', 0, 'text')
    end

    # OpenAI image generation
    def generate_image_openai(prompt, model, **options)
      params = {
        model: model || "dall-e-3",
        prompt: prompt,
        size: options[:size] || "1024x1024",
        quality: options[:quality] || "standard",
        response_format: options[:response_format] || "url"
      }

      response = @client.images.generate(parameters: params)
      response.dig("data", 0)
    end

    # OpenRouter image generation
    def generate_image_open_router(prompt, model, **options)
      # Some models on OpenRouter support image generation
      params = {
        model: model || "dall-e-3",
        prompt: prompt
      }.merge(options)

      response = @client.images.generate(**params)
      response.dig("data", 0)
    end
  end
end
