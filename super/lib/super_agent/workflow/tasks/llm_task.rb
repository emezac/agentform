# frozen_string_literal: true
# lib/super_agent/workflow/tasks/llm_task.rb

module SuperAgent
  module Workflow
    module Tasks
      # Task for executing LLM operations with prompt templating and multi-provider support
      class LlmTask < Task
        def validate!
          # CORRECCIÓN: Mejorar la validación para manejar la nueva sintaxis DSL
          unless config[:prompt] || config[:messages] || config[:system_prompt]
            raise SuperAgent::ConfigurationError, "LlmTask requires :prompt, :messages, or :system_prompt configuration. Got: #{config.keys.inspect}"
          end
          super
        end

        def execute(context)
          validate!

          prompt = build_prompt(context)
          provider = config[:provider] || SuperAgent.configuration.llm_provider
          
          log_execution_start(prompt)

          response = make_llm_call(prompt, provider, context)
          
          log_execution_complete(response)

          parse_response(response)
        end

        def description
          provider = config[:provider] || SuperAgent.configuration.llm_provider
          model = config[:model] || SuperAgent.configuration.default_llm_model
          "LLM task: #{model} via #{provider}"
        end

        private

        def build_prompt(context)
          # CORRECCIÓN: Mejorar la lógica de construcción del prompt
          if config[:prompt]
            template = config[:prompt]
            interpolate_template(template, context)
          elsif config[:messages]
            config[:messages].map do |message|
              {
                role: message[:role],
                content: interpolate_template(message[:content], context)
              }
            end
          elsif config[:system_prompt] && config[:template]
            [
              { role: 'system', content: interpolate_template(config[:system_prompt], context) },
              { role: 'user', content: interpolate_template(config[:template], context) }
            ]
          elsif config[:system_prompt]
            # Si solo hay system_prompt, crear un mensaje simple
            [
              { role: 'user', content: interpolate_template(config[:system_prompt], context) }
            ]
          else
            raise ConfigurationError, "No prompt configuration found. Available keys: #{config.keys.inspect}"
          end
        end

        def interpolate_template(template, context)
          return template unless template.is_a?(String)
          
          template.gsub(/\{\{(.+?)\}\}/) do |match|
            key_path = $1.strip
            value = resolve_template_value(key_path, context)
            
            if value.nil?
              SuperAgent.configuration.logger.warn("Missing context variable: #{key_path}")
              "[MISSING: #{key_path}]"
            else
              value.to_s
            end
          end
        end

        def resolve_template_value(key_path, context)
          # Support nested access like "user.name" or "analysis.confidence_score"
          keys = key_path.split('.')
          
          if keys.size == 1
            context.get(keys.first)
          else
            # Nested access
            result = context.get(keys.first)
            keys[1..-1].each do |key|
              break unless result.respond_to?(:[]) || result.respond_to?(key.to_sym)
              
              result = if result.respond_to?(:[])
                         result[key] || result[key.to_sym]
                       else
                         result.send(key.to_sym)
                       end
            end
            result
          end
        rescue
          nil
        end

        def make_llm_call(prompt, provider, context)
          llm_interface = SuperAgent::LlmInterface.new(provider: provider)
          
          params = {
            prompt: prompt,
            model: config[:model] || SuperAgent.configuration.default_llm_model,
            temperature: config[:temperature] || 0.7,
            max_tokens: config[:max_tokens]
          }.compact

          # Add any additional parameters
          extra_params = config.except(:prompt, :messages, :system_prompt, :template, 
                                       :model, :temperature, :max_tokens, :provider,
                                       :uses, :with, :inputs, :outputs, :meta, :if)
          params.merge!(extra_params)

          llm_interface.complete(**params)
        rescue StandardError => e
          raise TaskError, "LLM API error: #{e.message}"
        end

        def parse_response(response)
          format_type = config[:format] || config[:response_format]
          
          case format_type
          when :json
            parse_json_response(response)
          when :integer
            response.to_s.scan(/\d+/).first&.to_i || 0
          when :float
            response.to_s.scan(/[\d.]+/).first&.to_f || 0.0
          when :boolean
            response.to_s.downcase.match?(/\b(true|yes|1|success|ok)\b/)
          when :array
            parse_array_response(response)
          when :hash
            parse_json_response(response)
          else
            response
          end
        end

        def parse_json_response(response)
          # Try to extract JSON from the response
          json_match = response.match(/\{.*\}/m) || response.match(/\[.*\]/m)
          json_string = json_match ? json_match[0] : response
          
          JSON.parse(json_string)
        rescue JSON::ParserError => e
          SuperAgent.configuration.logger.warn("Failed to parse JSON response: #{e.message}")
          SuperAgent.configuration.logger.debug("Response was: #{response}")
          
          # Fallback: try to extract structured data
          extract_structured_data(response)
        end

        def parse_array_response(response)
          # Try to parse as JSON array first
          if response.match(/\[.*\]/m)
            parse_json_response(response)
          else
            # Split by common delimiters
            response.split(/[,\n]/).map(&:strip).reject(&:empty?)
          end
        end

        def extract_structured_data(response)
          # Try to extract key-value pairs or structured info
          data = {}
          
          # Look for key: value patterns
          response.scan(/(\w+):\s*([^\n,]+)/) do |key, value|
            data[key.downcase] = value.strip
          end
          
          # If no structured data found, return the original response
          data.empty? ? response : data
        end

        def log_execution_start(prompt)
          log_prompt = if prompt.is_a?(Array)
                        prompt.map { |m| m[:content] }.join(" ")
                      else
                        prompt.to_s
                      end

          truncated = log_prompt[0..500] + (log_prompt.length > 500 ? "..." : "")
          
          SuperAgent.configuration.logger.info(
            "Executing LLM task: #{name}, prompt: #{truncated}"
          )
        end

        def log_execution_complete(response)
          truncated = response.to_s[0..500] + (response.to_s.length > 500 ? "..." : "")
          
          SuperAgent.configuration.logger.info(
            "LLM task completed: #{name}, response: #{truncated}"
          )
        end
      end
    end
  end
end
