# frozen_string_literal: true

module Ai
  class SecurityService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    # File upload security constants
    ALLOWED_MIME_TYPES = [
      'application/pdf',
      'text/plain',
      'text/markdown',
      'text/x-markdown'
    ].freeze

    ALLOWED_FILE_EXTENSIONS = %w[.pdf .txt .md .markdown].freeze
    MAX_FILE_SIZE = 10.megabytes
    MAX_CONTENT_LENGTH = 50_000 # characters
    MIN_CONTENT_LENGTH = 10 # characters

    # Content security patterns
    SUSPICIOUS_PATTERNS = [
      # Prompt injection attempts
      /ignore\s+previous\s+instructions/i,
      /forget\s+everything\s+above/i,
      /system\s*:\s*you\s+are\s+now/i,
      /act\s+as\s+if\s+you\s+are/i,
      /pretend\s+to\s+be/i,
      /roleplay\s+as/i,
      # Code injection attempts
      /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi,
      /javascript\s*:/i,
      /on\w+\s*=/i,
      # SQL injection patterns
      /union\s+select/i,
      /drop\s+table/i,
      /delete\s+from/i,
      # Command injection
      /\|\s*[a-z]/i,
      /&&\s*[a-z]/i,
      /;\s*[a-z]/i
    ].freeze

    # Inappropriate content patterns
    INAPPROPRIATE_PATTERNS = [
      # Hate speech indicators
      /\b(hate|kill|murder|terrorist)\b.*\b(people|group|race|religion)\b/i,
      # Adult content indicators
      /\b(porn|sex|nude|naked)\b/i,
      # Violence indicators
      /\b(bomb|weapon|gun|knife)\b.*\b(make|build|create)\b/i,
      # More specific inappropriate patterns
      /how\s+to\s+make.*\b(bomb|weapon|explosive)\b/i
    ].freeze

    attribute :file
    attribute :content, :string
    attribute :user_id
    attribute :ip_address, :string

    def validate_file_upload
      return { success: false, errors: ['No file provided'] } unless file

      errors = []
      
      # Validate file size
      if file.size > MAX_FILE_SIZE
        errors << "File size exceeds maximum allowed size of #{MAX_FILE_SIZE / 1.megabyte}MB"
      end

      # Validate MIME type
      unless ALLOWED_MIME_TYPES.include?(file.content_type)
        errors << "File type '#{file.content_type}' is not allowed. Allowed types: #{ALLOWED_MIME_TYPES.join(', ')}"
      end

      # Validate file extension
      file_extension = File.extname(file.original_filename).downcase
      unless ALLOWED_FILE_EXTENSIONS.include?(file_extension)
        errors << "File extension '#{file_extension}' is not allowed. Allowed extensions: #{ALLOWED_FILE_EXTENSIONS.join(', ')}"
      end

      # Additional security checks
      errors.concat(perform_file_security_scan)

      if errors.any?
        log_security_event('file_validation_failed', { errors: errors })
        { success: false, errors: errors }
      else
        { success: true }
      end
    end

    def sanitize_content(raw_content)
      return { success: false, errors: ['No content provided'] } if raw_content.blank?

      sanitized_content = raw_content.dup
      security_issues = []

      # Length validation
      if sanitized_content.length > MAX_CONTENT_LENGTH
        security_issues << "Content exceeds maximum length of #{MAX_CONTENT_LENGTH} characters"
      elsif sanitized_content.length < MIN_CONTENT_LENGTH
        security_issues << "Content is too short (minimum #{MIN_CONTENT_LENGTH} characters)"
      end

      # Check for suspicious patterns
      SUSPICIOUS_PATTERNS.each do |pattern|
        if sanitized_content.match?(pattern)
          security_issues << "Content contains potentially malicious patterns"
          log_security_event('suspicious_content_detected', { 
            pattern: pattern.source,
            content_preview: sanitized_content[0..100] 
          })
          break # Don't reveal specific patterns to potential attackers
        end
      end

      # Check for inappropriate content
      INAPPROPRIATE_PATTERNS.each do |pattern|
        if sanitized_content.match?(pattern)
          security_issues << "Content contains inappropriate material"
          log_security_event('inappropriate_content_detected', { 
            content_preview: sanitized_content[0..100] 
          })
          break
        end
      end

      # Basic HTML/script sanitization
      sanitized_content = sanitize_html_content(sanitized_content)

      # Remove potential command injection characters
      sanitized_content = sanitize_command_injection(sanitized_content)

      if security_issues.any?
        { success: false, errors: security_issues }
      else
        { success: true, content: sanitized_content }
      end
    end

    def check_rate_limit
      return { success: false, errors: ['User ID required for rate limiting'] } unless user_id

      cache_key = "ai_generation_rate_limit:#{user_id}"
      current_count = Rails.cache.read(cache_key) || 0
      
      # Allow 10 requests per hour for AI generation
      rate_limit = 10
      time_window = 1.hour

      if current_count >= rate_limit
        log_security_event('rate_limit_exceeded', { 
          user_id: user_id,
          current_count: current_count,
          limit: rate_limit 
        })
        return { success: false, errors: ['Rate limit exceeded. Please try again later.'] }
      else
        Rails.cache.write(cache_key, current_count + 1, expires_in: time_window)
        return { success: true, remaining_requests: rate_limit - current_count - 1 }
      end
    end

    private

    def perform_file_security_scan
      errors = []
      
      # Check file header/magic bytes
      if file.respond_to?(:read)
        file.rewind
        header = file.read(1024)
        file.rewind

        # Basic magic byte validation for PDF
        if file.content_type == 'application/pdf' && !header.start_with?('%PDF-')
          errors << 'File appears to be corrupted or not a valid PDF'
        end

        # Check for embedded scripts in text files
        if file.content_type.start_with?('text/') && header.match?(/<script|javascript:/i)
          errors << 'File contains potentially malicious script content'
        end
      end

      errors
    end

    def sanitize_html_content(content)
      # Remove HTML tags and decode entities
      content = ActionController::Base.helpers.strip_tags(content)
      content = CGI.unescapeHTML(content)
      content
    end

    def sanitize_command_injection(content)
      # Remove or escape potentially dangerous characters
      dangerous_chars = ['|', '&', ';', '`', '$', '(', ')', '{', '}']
      dangerous_chars.each do |char|
        content = content.gsub(char, '')
      end
      content
    end

    def log_security_event(event_type, details = {})
      Rails.logger.warn "[SECURITY] #{event_type}: #{details.to_json}"
      
      # Store in audit log
      begin
        AuditLog.create!(
          event_type: event_type,
          user_id: user_id,
          ip_address: ip_address,
          details: details,
          created_at: Time.current
        )
      rescue => e
        Rails.logger.error "Failed to log security event: #{e.message}"
      end
    end
  end
end