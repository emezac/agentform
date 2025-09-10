# frozen_string_literal: true

module Ai
  class DocumentProcessor
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    # Supported file types
    SUPPORTED_CONTENT_TYPES = [
      'application/pdf',
      'text/markdown',
      'text/plain'
    ].freeze

    # Maximum file size (10 MB)
    MAX_FILE_SIZE = 10.megabytes

    # Content length constraints (10-5000 words)
    MIN_WORD_COUNT = 10
    MAX_WORD_COUNT = 5000

    attribute :file
    attribute :content_type, :string
    attribute :file_size, :integer

    validates :file, presence: { message: "File is required" }
    validates :content_type, inclusion: { 
      in: SUPPORTED_CONTENT_TYPES, 
      message: "Unsupported file type. Supported types: PDF, Markdown, Plain text" 
    }
    validates :file_size, numericality: { 
      less_than: MAX_FILE_SIZE, 
      message: "File size must be less than 10 MB" 
    }

    def initialize(attributes = {})
      super
      extract_file_attributes if file.present?
    end

    def process
      return validation_error_response unless valid?

      begin
        # Security validation first
        security_result = Ai::SecurityService.new(file: file).validate_file_upload
        return security_result unless security_result[:success]

        # Generate file hash for caching
        file_hash = generate_file_hash
        
        # Check cache first
        cached_result = Ai::CachingService.get_cached_document_processing(file_hash)
        if cached_result
          Rails.logger.info "Using cached document processing result for file: #{file&.original_filename}"
          return cached_result
        end
        
        # Process document if not cached
        content = extract_content
        
        # Sanitize extracted content
        sanitization_result = Ai::SecurityService.new(content: content).sanitize_content(content)
        return sanitization_result unless sanitization_result[:success]
        
        sanitized_content = sanitization_result[:content]
        word_count = count_words(sanitized_content)
        
        return word_count_error_response(word_count) unless valid_word_count?(word_count)

        result = success_response(sanitized_content, word_count)
        
        # Cache the successful result
        Ai::CachingService.cache_document_processing(file_hash, result)
        
        result
      rescue StandardError => e
        Rails.logger.error "Document processing failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Track the error for monitoring
        Ai::ErrorTrackingService.track_error({
          error_type: 'document_processing_error',
          error_message: "Document processing failed: #{e.message}",
          context: {
            file_size: file_size,
            content_type: content_type,
            file_name: file&.original_filename,
            error_class: e.class.name
          },
          severity: 'error'
        })
        
        error_response(['Failed to process document. Please try again.'])
      end
    end

    private

    def extract_file_attributes
      self.content_type = file.content_type
      self.file_size = file.size
    end

    def extract_content
      case content_type
      when 'application/pdf'
        extract_pdf_content
      when 'text/markdown', 'text/plain'
        extract_text_content
      else
        raise "Unsupported content type: #{content_type}"
      end
    end

    def extract_pdf_content
      require 'pdf-reader'
      
      content_parts = []
      page_count = 0
      
      PDF::Reader.open(file.tempfile) do |reader|
        reader.pages.each do |page|
          page_count += 1
          page_text = page.text.strip
          content_parts << page_text if page_text.present?
        end
      end

      content = content_parts.join("\n\n")
      
      # Store metadata for response
      @extraction_metadata = {
        page_count: page_count,
        pages_with_content: content_parts.size
      }

      content
    rescue PDF::Reader::MalformedPDFError => e
      Rails.logger.error "Malformed PDF: #{e.message}"
      raise "Invalid or corrupted PDF file"
    rescue PDF::Reader::UnsupportedFeatureError => e
      Rails.logger.error "Unsupported PDF feature: #{e.message}"
      raise "PDF contains unsupported features"
    end

    def extract_text_content
      content = file.read.force_encoding('UTF-8')
      
      # Handle encoding issues
      unless content.valid_encoding?
        content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      end

      # Store metadata for response
      line_count = content.lines.count
      @extraction_metadata = {
        line_count: line_count,
        encoding: content.encoding.name
      }

      content.strip
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      Rails.logger.error "Text encoding error: #{e.message}"
      raise "Unable to process file due to encoding issues"
    ensure
      file.rewind if file.respond_to?(:rewind)
    end

    def count_words(content)
      return 0 if content.blank?
      
      # Remove markdown formatting and count words
      clean_content = content.gsub(/[#*_`\[\](){}]/, ' ')
                            .gsub(/\s+/, ' ')
                            .strip
      
      clean_content.split.size
    end

    def valid_word_count?(word_count)
      word_count >= MIN_WORD_COUNT && word_count <= MAX_WORD_COUNT
    end

    def success_response(content, word_count)
      {
        success: true,
        content: content,
        metadata: base_metadata.merge(
          word_count: word_count,
          **(@extraction_metadata || {})
        ),
        source_type: determine_source_type
      }
    end

    def validation_error_response
      {
        success: false,
        errors: errors.full_messages
      }
    end

    def word_count_error_response(word_count)
      if word_count < MIN_WORD_COUNT
        error_message = "Content too short (#{word_count} words). Please provide more detailed information (minimum #{MIN_WORD_COUNT} words)."
      else
        error_message = "Content too long (#{word_count} words). Maximum #{MAX_WORD_COUNT} words allowed."
      end

      {
        success: false,
        errors: [error_message],
        metadata: { word_count: word_count }
      }
    end

    def error_response(errors)
      {
        success: false,
        errors: errors
      }
    end

    def base_metadata
      {
        file_name: file.original_filename,
        file_size: file_size,
        content_type: content_type,
        processed_at: Time.current.iso8601
      }
    end

    def determine_source_type
      case content_type
      when 'application/pdf'
        'pdf_document'
      when 'text/markdown'
        'markdown_document'
      when 'text/plain'
        'text_document'
      else
        'unknown'
      end
    end
    
    def generate_file_hash
      # Create a hash based on file content and metadata for caching
      hash_input = {
        file_size: file_size,
        content_type: content_type,
        file_name: file&.original_filename,
        # For small files, include content in hash; for large files, use metadata
        content_sample: file_size < 1.megabyte ? file.read.first(1000) : "#{file_size}_#{content_type}"
      }
      
      # Reset file position after reading
      file.rewind if file.respond_to?(:rewind)
      
      Digest::SHA256.hexdigest(hash_input.to_json)
    end
  end
end