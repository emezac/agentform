module SuperAgent
  module Workflow
    module Tasks
      # Task for performing web searches using OpenAI's web search capability
      #
      # @example Usage in workflow
      #   step :search_news, uses: :web_search, with: {
      #     query: "latest AI developments 2024",
      #     search_context_size: "high"
      #   }
      #
      class WebSearchTask < Task
        def initialize(name, config = {})
          super(name, config)
          @query_key = config[:query] || :query
          @context_size = config[:search_context_size] || "medium"
          @user_location = config[:user_location]
          @result_key = config[:as] || :search_results
        end

        def execute(context)
          query = resolve_query(context.get(@query_key))
          
          raise ArgumentError, "Query is required" unless query

          response = perform_web_search(query)
          
          {
            @result_key => {
              query: query,
              results: format_results(response),
              citations: extract_citations(response)
            }
          }
        end

        private

        def resolve_query(query_param)
          case query_param
          when String
            query_param
          when Hash
            query_param[:query] || query_param[:search]
          else
            query_param.to_s
          end
        end

        def perform_web_search(query)
          llm = SuperAgent::LLMInterface.new
          
          messages = [{
            role: "user",
            content: query
          }]

          # Use OpenAI's web search capability via LLMInterface
          llm.complete(
            prompt: messages,
            model: SuperAgent.configuration.default_llm_model,
            tools: [{
              type: "web_search_preview",
              search_context_size: @context_size,
              user_location: @user_location
            }]
          )
        end

        def format_results(response)
          # Parse and format the search results
          if response.include?("[Search results]")
            extract_search_content(response)
          else
            response
          end
        end

        def extract_search_content(response)
          # Extract the actual search content from OpenAI response
          search_start = response.index("[Search results]")
          return response unless search_start

          response[search_start..-1]
        end

        def extract_citations(response)
          # Extract citations from the response
          citations = []
          response.scan(/\[\d+\]\(([^)]+)\)/) do |url|
            citations << url.first
          end
          citations.uniq
        end

        def self.name
          :web_search
        end
      end
    end
  end
end