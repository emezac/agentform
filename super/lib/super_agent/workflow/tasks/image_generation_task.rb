# frozen_string_literal: true

require 'openai'

module SuperAgent
  module Workflow
    module Tasks
      # Task for generating images using OpenAI's DALL-E
      class ImageGenerationTask < Task
        def validate!
          unless config[:prompt]
            raise SuperAgent::ConfigurationError, "ImageGenerationTask requires :prompt configuration"
          end
          super
        end

        def execute(context)
          validate!

          prompt = interpolate_template(config[:prompt], context)
          
          SuperAgent.configuration.logger.info(
            "Generating image: #{name}, prompt: #{prompt[0..100]}#{prompt.length > 100 ? '...' : ''}"
          )

          image_url = generate_image(prompt)
          
          SuperAgent.configuration.logger.info(
            "Image generation completed: #{name}, url: #{image_url}"
          )

          {
            url: image_url,
            revised_prompt: prompt
          }
        end

        def description
          "Image generation: #{config[:size] || '1024x1024'}"
        end

        private

        def generate_image(prompt)
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          params = {
            model: config[:model] || "dall-e-3",
            prompt: prompt,
            size: config[:size] || "1024x1024",
            quality: config[:quality] || "standard",
            response_format: config[:response_format] || "url"
          }
          
          response = client.images.generate(parameters: params)
          
          if config[:response_format] == "b64_json"
            response.dig("data", 0, "b64_json")
          else
            response.dig("data", 0, "url")
          end
        rescue StandardError => e
          raise TaskError, "Image generation API error: #{e.message}"
        end

        def interpolate_template(template, context)
          return template unless template.is_a?(String)
          
          template.gsub(/\{\{(.+?)\}\}/) do |match|
            key = $1.strip
            value = context.get(key)
            
            if value.nil?
              SuperAgent.configuration.logger.warn("Missing context variable: #{key}")
              "[MISSING: #{key}]"
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end