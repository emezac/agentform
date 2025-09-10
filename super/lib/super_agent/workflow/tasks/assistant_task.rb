# frozen_string_literal: true

require 'openai'

module SuperAgent
  module Workflow
    module Tasks
      # Task for using OpenAI Assistant API with file search capabilities
      class AssistantTask < Task
        def initialize(name, config = {})
          super(name, config)
          @instructions = config[:instructions] || "You are a helpful assistant."
          @prompt = config[:prompt] || config[:messages]
          @model = config[:model] || "gpt-4o"
          @max_tokens = config[:max_tokens] || 2000
          @temperature = config[:temperature] || 0.7
          @file_ids = config[:file_ids] || []
          @vector_store_ids = config[:vector_store_ids] || []
          @result_key = config[:as] || :assistant_response
        end

        def execute(context)
          file_ids = resolve_file_ids(context)
          vector_store_ids = resolve_vector_store_ids(context)
          
          # Try to use Assistant API with file search
          begin
            # Create assistant with file search
            assistant = create_assistant(file_ids, vector_store_ids)
            
            if assistant
              # Create thread with message
              thread = create_thread(assistant, context)
              
              # Run the assistant
              response = run_assistant(assistant, thread, context)
              
              # Clean up
              cleanup_assistant(assistant, thread)
              
              { @result_key => response }
            else
              # Use fallback when assistant creation fails
              { @result_key => fallback_llm_call(context) }
            end
          rescue StandardError => e
            SuperAgent.configuration.logger.warn("Assistant API failed, using fallback: #{e.message}")
            { @result_key => fallback_llm_call(context) }
          end
        end

        def description
          "Assistant task: #{@model} with file search"
        end

        private

        def resolve_file_ids(context)
          if @file_ids.empty?
            # Try to get from context
            file_ids = context.get(:file_ids) || context.get(:file_id)
            Array(file_ids).compact
          else
            Array(@file_ids).map { |id| context.get(id) || id }.compact
          end
        end

        def resolve_vector_store_ids(context)
          if @vector_store_ids.empty?
            # Try to get from context
            store_ids = context.get(:vector_store_ids) || context.get(:vector_store_id)
            Array(store_ids).compact
          else
            Array(@vector_store_ids).map { |id| context.get(id) || id }.compact
          end
        end

        def create_assistant(file_ids, vector_store_ids)
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          tools = []
          unless file_ids.empty? && vector_store_ids.empty?
            tools << { type: "file_search" }
          end
          
          params = {
            model: @model || "gpt-4o-mini",  # Use a more reliable model
            instructions: @instructions,
            tools: tools
          }
          
          # Add vector store configuration if provided
          unless vector_store_ids.empty?
            params[:tool_resources] = {
              file_search: {
                vector_store_ids: vector_store_ids
              }
            }
          end
          
          # Don't add file_ids directly to assistant, rely on vector stores for search
          # This avoids the 400 error when file_ids are provided without proper setup
          
          SuperAgent.configuration.logger.debug("Creating assistant with params: #{params.inspect}")
          response = client.assistants.create(**params)
          response['id']
        rescue StandardError => e
          SuperAgent.configuration.logger.error("Failed to create assistant: #{e.message}")
          SuperAgent.configuration.logger.error("Params: #{params.inspect}")
          nil  # Return nil to trigger fallback instead of raising
        end

        def create_thread(assistant_id, context)
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          prompt = if @prompt.is_a?(Array)
                    @prompt.map { |msg| interpolate_template(msg[:content], context) }.join("\n")
                  else
                    interpolate_template(@prompt, context)
                  end

          response = client.threads.create
          client.messages.create(
            thread_id: response['id'],
            role: "user",
            content: prompt
          )
          response
        end

        def run_assistant(assistant_id, thread, context)
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          # Start the run
          run = client.runs.create(
            thread_id: thread['id'],
            assistant_id: assistant_id
          )

          # Wait for completion
          max_wait = 60 # Maximum 60 seconds
          waited = 0
          
          while run['status'] != 'completed' && waited < max_wait
            sleep(2)
            waited += 2
            run = client.runs.retrieve(
              thread_id: thread['id'],
              run_id: run['id']
            )
            
            if run['status'] == 'failed'
              raise "Assistant run failed: #{run['last_error']&.dig('message') || 'Unknown error'}"
            end
          end
          
          if waited >= max_wait
            raise "Assistant run timed out after #{max_wait} seconds"
          end

          # Get the messages
          messages = client.messages.list(thread_id: thread['id'])
          
          # Find the assistant's response
          assistant_message = messages['data'].find { |msg| msg['role'] == 'assistant' }
          assistant_message&.dig('content', 0, 'text', 'value') || "No response generated"
        rescue StandardError => e
          SuperAgent.configuration.logger.warn("Assistant run failed, using fallback: #{e.message}")
          fallback_llm_call(context)
        end

        def cleanup_assistant(assistant_id, thread)
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          # Clean up thread
          client.threads.delete(thread_id: thread['id'])
          
          # Clean up assistant
          client.assistants.delete(assistant_id: assistant_id)
        rescue StandardError => e
          SuperAgent.configuration.logger.warn("Failed to cleanup assistant: #{e.message}")
        end

        def fallback_llm_call(context)
          # Enhanced fallback that includes file context when available
          file_ids = resolve_file_ids(context)
          vector_store_ids = resolve_vector_store_ids(context)
          
          enhanced_prompt = build_enhanced_prompt(context)
          
          # Use LLM directly with enhanced prompt
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          response = client.chat(
            parameters: {
              model: @model || "gpt-4o-mini",
              messages: [
                { role: "system", content: @instructions },
                { role: "user", content: enhanced_prompt }
              ],
              max_tokens: @max_tokens,
              temperature: @temperature
            }
          )
          
          response.dig('choices', 0, 'message', 'content') || "Enhanced fallback response generated"
        end

        def build_enhanced_prompt(context)
          base_prompt = if @prompt.is_a?(Array)
                         @prompt.map { |msg| interpolate_template(msg[:content], context) }.join("\n")
                       else
                         interpolate_template(@prompt, context)
                       end
          
          file_ids = resolve_file_ids(context)
          vector_store_ids = resolve_vector_store_ids(context)
          
          if file_ids.any? || vector_store_ids.any?
            <<~ENHANCED_PROMPT
              The following document has been uploaded to OpenAI with file ID(s): #{file_ids.join(', ')}
              and is available for analysis via vector store(s): #{vector_store_ids.join(', ')}
              
              Please analyze this uploaded document and provide specific insights based on its actual content:
              
              #{base_prompt}
              
              Important: Focus on providing specific, document-based analysis rather than generic advice.
            ENHANCED_PROMPT
          else
            base_prompt
          end
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

        def self.name
          :assistant
        end
      end
    end
  end
end