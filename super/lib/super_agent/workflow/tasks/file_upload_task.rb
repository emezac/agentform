module SuperAgent
  module Workflow
    module Tasks
      # Task for uploading files to OpenAI for use with assistants
      #
      # @example Usage in workflow
      #   step :upload_document, uses: :file_upload, with: {
      #     file_path: "path/to/document.pdf",
      #     purpose: "assistants"
      #   }
      #
      class FileUploadTask < Task
        def initialize(name, config = {})
          super(name, config)
          @file_path_key = config[:file_path] || :file_path
          @purpose = config[:purpose] || "assistants"
          @result_key = config[:as] || :file_id
          @check_existing = config[:check_existing] != false # Default to true
        end

        def execute(context)
          file_path = resolve_file_path(context.get(@file_path_key))
          
          SuperAgent.configuration.logger.debug("FileUploadTask: Looking for file at path: #{file_path.inspect}")
          SuperAgent.configuration.logger.debug("FileUploadTask: Context has keys: #{context.keys.inspect}")
          
          raise ArgumentError, "File path is required" unless file_path
          raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

          # Check for existing file if enabled
          if @check_existing
            existing_file = find_existing_file(file_path)
            if existing_file
              SuperAgent.configuration.logger.info("Using existing file: #{existing_file['filename']} (ID: #{existing_file['id']})")
              return {
                @result_key => existing_file['id'],
                filename: existing_file['filename'],
                size: existing_file['bytes'],
                uploaded_at: Time.at(existing_file['created_at']),
                existing: true
              }
            end
          end

          file_id = upload_to_openai(file_path)
          
          {
            @result_key => file_id,
            filename: File.basename(file_path),
            size: File.size(file_path),
            uploaded_at: Time.now,
            existing: false
          }
        end

        private

        def find_existing_file(file_path)
          client = OpenAI::Client.new(access_token: SuperAgent.configuration.api_key)
          
          begin
            # List all files for the specified purpose
            response = client.files.list(parameters: { purpose: @purpose })
            files = response['data'] || []
            
            filename = File.basename(file_path)
            file_size = File.size(file_path)
            
            # Find file with matching filename and size
            existing_file = files.find do |file|
              file['filename'] == filename && file['bytes'] == file_size
            end
            
            existing_file
          rescue StandardError => e
            SuperAgent.configuration.logger.warn("Failed to check existing files: #{e.message}")
            nil
          end
        end

        def resolve_file_path(path_param)
          case path_param
          when String
            path_param
          when Hash
            path_param[:file_path] || path_param[:path]
          when Symbol
            path_param.to_s
          else
            path_param.to_s
          end
        end

        def upload_to_openai(file_path)
          uri = URI.parse("https://api.openai.com/v1/files")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.request_uri)
          request['Authorization'] = "Bearer #{SuperAgent.configuration.api_key}"

          # Multipart form data
          boundary = "----#{SecureRandom.hex(16)}"
          request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"

          form_data = build_multipart_body(file_path, boundary)
          request.body = form_data

          response = http.request(request)
          
          if response.code == '200'
            result = JSON.parse(response.body)
            result['id']
          else
            raise "OpenAI API Error: #{response.code} - #{response.body}"
          end
        end

        def build_multipart_body(file_path, boundary)
          filename = File.basename(file_path)
          file_content = File.read(file_path)

          body = []
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"purpose\"\r\n\r\n"
          body << "#{@purpose}\r\n"
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
          body << "Content-Type: #{determine_content_type(filename)}\r\n\r\n"
          body << file_content
          body << "\r\n--#{boundary}--\r\n"

          body.join
        end

        def determine_content_type(filename)
          extension = File.extname(filename).downcase
          case extension
          when '.pdf'
            'application/pdf'
          when '.txt'
            'text/plain'
          when '.json'
            'application/json'
          when '.csv'
            'text/csv'
          when '.md', '.markdown'
            'text/markdown'
          else
            'application/octet-stream'
          end
        end

        def self.name
          :file_upload
        end
      end
    end
  end
end