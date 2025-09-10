module SuperAgent
  module Workflow
    module Tasks
      # Task for processing Markdown text using LLM operations
      #
      # @example Usage in workflow
      #   step :summarize_report, uses: :markdown, with: {
      #     content: :report_content,
      #     operation: :summarize,
      #     max_length: 500
      #   }
      #
      class MarkdownTask < Task
        VALID_OPERATIONS = [:summarize, :expand, :change_tone, :format_table, :extract_key_points, :translate].freeze
        VALID_TONES = [:formal, :casual, :technical, :business, :friendly].freeze

        def initialize(name, config = {})
          super(name, config)
          @content_key = config[:content] || :content
          @operation = (config[:operation] || :summarize).to_sym
          @target_tone = config[:tone]&.to_sym || :formal
          @max_length = config[:max_length] || 1000
          @result_key = config[:as] || :processed_content
        end

        def execute(context)
          content = resolve_content(context.get(@content_key))
          
          raise ArgumentError, "Content is required" unless content
          raise ArgumentError, "Invalid operation: #{@operation}" unless VALID_OPERATIONS.include?(@operation)

          processed_content = process_markdown(content)

          {
            @result_key => processed_content,
            operation: @operation,
            original_length: content.length,
            processed_length: processed_content.length
          }
        end

        private

        def resolve_content(content_param)
          case content_param
          when String
            content_param
          when Hash
            content_param[:content] || content_param[:text]
          else
            content_param.to_s
          end
        end

        def process_markdown(content)
          case @operation
          when :summarize
            summarize_content(content)
          when :expand
            expand_content(content)
          when :change_tone
            change_tone(content)
          when :format_table
            format_as_table(content)
          when :extract_key_points
            extract_key_points(content)
          when :translate
            translate_content(content)
          else
            content
          end
        end

        def summarize_content(content)
          prompt = build_prompt(
            "Summarize the following markdown content concisely.",
            content,
            "Provide a clear summary in markdown format, highlighting key points."
          )
          
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          response = client.chat(
            parameters: {
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: prompt }],
              max_tokens: [@max_length, 500].min
            }
          )
          response.dig("choices", 0, "message", "content") || content
        end

        def expand_content(content)
          prompt = build_prompt(
            "Expand on the following markdown content.",
            content,
            "Provide detailed explanations and additional context while maintaining markdown format."
          )

          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          response = client.chat(
            parameters: {
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: prompt }],
              max_tokens: @max_length
            }
          )
          response.dig("choices", 0, "message", "content") || content
        end

        def change_tone(content)
          raise ArgumentError, "Invalid tone: #{@target_tone}" unless VALID_TONES.include?(@target_tone)

          prompt = build_prompt(
            "Change the tone of the following markdown content to be #{@target_tone}.",
            content,
            "Maintain the markdown structure and key information while adjusting the tone."
          )

          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          response = client.chat(
            parameters: {
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: prompt }],
              max_tokens: @max_length
            }
          )
          response.dig("choices", 0, "message", "content") || content
        end

        def format_as_table(content)
          prompt = build_prompt(
            "Convert the following markdown content into a well-formatted table.",
            content,
            "Create a clear markdown table that presents the information effectively."
          )

          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          response = client.chat(
            parameters: {
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: prompt }],
              max_tokens: @max_length
            }
          )
          response.dig("choices", 0, "message", "content") || content
        end

        def extract_key_points(content)
          prompt = build_prompt(
            "Extract the key points from the following markdown content.",
            content,
            "Return the main points as a bulleted markdown list."
          )

          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          response = client.chat(
            parameters: {
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: prompt }],
              max_tokens: [@max_length, 300].min
            }
          )
          response.dig("choices", 0, "message", "content") || content
        end

        def translate_content(content)
          target_language = "Spanish" # Default, could be made configurable
          
          prompt = build_prompt(
            "Translate the following markdown content to #{target_language}.",
            content,
            "Maintain markdown formatting and structure in the translation."
          )

          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          response = client.chat(
            parameters: {
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: prompt }],
              max_tokens: @max_length
            }
          )
          response.dig("choices", 0, "message", "content") || content
        end

        def build_prompt(instruction, content, additional_guidance)
          <<~PROMPT
            #{instruction}

            Content:
            ```markdown
            #{content}
            ```

            #{additional_guidance}

            Respond with processed markdown content only.
          PROMPT
        end

        def self.name
          :markdown
        end
      end
    end
  end
end