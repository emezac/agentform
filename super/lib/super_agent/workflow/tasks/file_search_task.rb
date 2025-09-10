module SuperAgent
  module Workflow
    module Tasks
      # Task for searching files in OpenAI Vector Stores (RAG functionality)
      #
      # @example Usage in workflow
      #   step :search_documents, uses: :file_search, with: {
      #     query: "What are the key points about IP law?",
      #     vector_store_ids: [:vector_store_id],
      #     max_results: 5
      #   }
      #
      class FileSearchTask < Task
        def initialize(name, config = {})
          super(name, config)
          @query_key = config[:query] || :query
          @vector_store_ids_key = config[:vector_store_ids] || :vector_store_ids
          @max_results = config[:max_results] || 5
          @result_key = config[:as] || :search_results
        end

        def execute(context)
          query = resolve_query(context.get(@query_key))
          vector_store_ids = resolve_vector_store_ids(context.get(@vector_store_ids_key))

          raise ArgumentError, "Query is required" unless query
          raise ArgumentError, "Vector store IDs are required" unless vector_store_ids.any?

          response = perform_file_search(query, vector_store_ids)

          {
            @result_key => {
              query: query,
              results: extract_results(response),
              citations: extract_citations(response),
              vector_store_ids: vector_store_ids
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

        def resolve_vector_store_ids(store_ids_param)
          case store_ids_param
          when Array
            store_ids_param
          when String
            [store_ids_param]
          else
            Array(store_ids_param)
          end.compact
        end

        def perform_file_search(query, vector_store_ids)
          llm = SuperAgent::LLMInterface.new
          
          messages = [{
            role: "user",
            content: query
          }]

          llm.complete(
            prompt: messages,
            model: SuperAgent.configuration.default_llm_model,
            tools: [{
              type: "file_search",
              vector_store_ids: vector_store_ids,
              max_num_results: @max_results
            }]
          )
        end

        def extract_results(response)
          # Parse the response to extract relevant information
          if response.include?("[File search results]")
            extract_search_content(response)
          else
            response
          end
        end

        def extract_search_content(response)
          # Extract search content and format it
          lines = response.split("\n")
          results = []
          
          lines.each do |line|
            if line.match?(/^\d+\./) || line.match?(/^\[\d+\]/)
              results << line.strip
            end
          end
          
          results.empty? ? response : results.join("\n")
        end

        def extract_citations(response)
          citations = []
          
          # Extract citations from file search results
          response.scan(/\[Source: ([^\]]+)\]/) do |source|
            citations << source.first
          end
          
          response.scan(/\[\d+\]\s+([^\n]+)/) do |citation|
            citations << citation.first.strip
          end
          
          citations.uniq
        end

        def self.name
          :file_search
        end
      end
    end
  end
end