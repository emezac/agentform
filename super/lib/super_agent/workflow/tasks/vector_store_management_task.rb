module SuperAgent
  module Workflow
    module Tasks
      # Task for managing OpenAI Vector Stores (RAG functionality)
      #
      # @example Create a vector store
      #   step :create_knowledge_base, uses: :vector_store_management, with: {
      #     operation: :create,
      #     name: "Legal Documents",
      #     file_ids: [:uploaded_file_id1, :uploaded_file_id2]
      #   }
      #
      # @example Add files to existing store
      #   step :add_files, uses: :vector_store_management, with: {
      #     operation: :add_file,
      #     vector_store_id: :existing_store_id,
      #     file_ids: [:new_file_id]
      #   }
      #
      class VectorStoreManagementTask < Task
        VALID_OPERATIONS = [:create, :add_file, :delete, :list].freeze

        def initialize(name, config = {})
          super(name, config)
          @operation = config[:operation]&.to_sym || :create
          @name = config[:name]
          @file_ids_key = config[:file_ids] || :file_ids
          @vector_store_id_key = config[:vector_store_id] || :vector_store_id
          @result_key = config[:as] || :vector_store_result
        end

        def execute(context)
          validate_operation!

          case @operation
          when :create
            create_vector_store(context)
          when :add_file
            add_files_to_store(context)
          when :delete
            delete_vector_store(context)
          when :list
            list_vector_stores
          end
        end

        private

        def validate_operation!
          unless VALID_OPERATIONS.include?(@operation)
            raise ArgumentError, "Invalid operation: #{@operation}. Must be one of: #{VALID_OPERATIONS.join(', ')}"
          end
        end

        def create_vector_store(context)
          name = context.get(:name) || @name
          file_ids = resolve_file_ids(context.get(@file_ids_key))

          SuperAgent.configuration.logger.debug("VectorStoreManagementTask: Creating store with name=#{name}, file_ids=#{file_ids.inspect}, key=#{@file_ids_key}")
          SuperAgent.configuration.logger.debug("VectorStoreManagementTask: Context has keys: #{context.keys.inspect}")

          raise ArgumentError, "Name is required for create operation" unless name

          response = api_call(:post, '/v1/vector_stores', {
            name: name,
            file_ids: file_ids
          })

          {
            @result_key => {
              operation: :create,
              vector_store_id: response['id'],
              name: response['name'],
              file_count: response['file_counts']['total'],
              created_at: response['created_at']
            }
          }
        end

        def add_files_to_store(context)
          vector_store_id = context.get(@vector_store_id_key)
          file_ids = resolve_file_ids(context.get(@file_ids_key))

          raise ArgumentError, "Vector store ID is required" unless vector_store_id
          raise ArgumentError, "File IDs are required" unless file_ids.any?

          response = api_call(:post, "/v1/vector_stores/#{vector_store_id}/files", {
            file_ids: file_ids
          })

          {
            @result_key => {
              operation: :add_file,
              vector_store_id: vector_store_id,
              added_files: file_ids.count,
              batch_id: response['id']
            }
          }
        end

        def delete_vector_store(context)
          vector_store_id = context.get(@vector_store_id_key)
          raise ArgumentError, "Vector store ID is required" unless vector_store_id

          api_call(:delete, "/v1/vector_stores/#{vector_store_id}")

          {
            @result_key => {
              operation: :delete,
              vector_store_id: vector_store_id,
              deleted: true
            }
          }
        end

        def list_vector_stores
          response = api_call(:get, '/v1/vector_stores')

          {
            @result_key => {
              operation: :list,
              vector_stores: response['data'] || [],
              total: response['object'] == 'list' ? response['data'].size : 0
            }
          }
        end

        def resolve_file_ids(file_ids_param)
          case file_ids_param
          when Array
            file_ids_param
          when String
            [file_ids_param]
          when Symbol
            Array(file_ids_param.to_s)
          else
            Array(file_ids_param)
          end.compact
        end

        def api_call(method, endpoint, payload = {})
          uri = URI.parse("https://api.openai.com#{endpoint}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = case method
                    when :post
                      req = Net::HTTP::Post.new(uri.request_uri)
                      req['Content-Type'] = 'application/json'
                      req.body = payload.to_json unless payload.empty?
                      req
                    when :delete
                      Net::HTTP::Delete.new(uri.request_uri)
                    when :get
                      Net::HTTP::Get.new(uri.request_uri)
                    end

          request['Authorization'] = "Bearer #{SuperAgent.configuration.api_key}"

          response = http.request(request)
          
          if response.code.start_with?('2')
            JSON.parse(response.body)
          else
            raise "OpenAI API Error: #{response.code} - #{response.body}"
          end
        end

        def self.name
          :vector_store_management
        end
      end
    end
  end
end