# frozen_string_literal: true

module Ai
  class ErrorMessageService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :error_type, :string
    attribute :error_message, :string
    attribute :context, :string, default: {}
    attribute :user, :string
    attribute :retry_count, :integer, default: 0

    ERROR_MESSAGES = {
      # Credit and subscription errors
      'credit_limit_exceeded' => {
        title: 'Monthly AI Usage Limit Reached',
        message: 'You\'ve used all your AI credits for this month.',
        guidance: 'Upgrade your plan to continue using AI features or wait until next month for your credits to reset.',
        actions: [
          { label: 'Upgrade Plan', action: 'upgrade', primary: true },
          { label: 'View Usage', action: 'view_usage', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'insufficient_credits' => {
        title: 'Insufficient AI Credits',
        message: 'This operation requires more AI credits than you have remaining.',
        guidance: 'Try creating a simpler form or upgrade your plan for more credits.',
        actions: [
          { label: 'Upgrade Plan', action: 'upgrade', primary: true },
          { label: 'Simplify Request', action: 'retry', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'subscription_required' => {
        title: 'Premium Feature',
        message: 'AI form generation is available with premium plans.',
        guidance: 'Upgrade to access AI-powered form creation and advanced features.',
        actions: [
          { label: 'View Plans', action: 'upgrade', primary: true },
          { label: 'Create Manual Form', action: 'manual_form', primary: false }
        ],
        severity: 'info',
        recoverable: true
      },

      # Content validation errors
      'content_length_error' => {
        title: 'Content Length Issue',
        message: 'The content provided doesn\'t meet our requirements.',
        guidance: 'Please provide content between 10 and 5,000 words for optimal form generation.',
        actions: [
          { label: 'Edit Content', action: 'retry', primary: true },
          { label: 'Upload Document', action: 'switch_input', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'empty_prompt' => {
        title: 'Missing Content',
        message: 'Please provide a description of the form you want to create.',
        guidance: 'Describe your form\'s purpose, target audience, and what information you need to collect.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'See Examples', action: 'show_examples', primary: false }
        ],
        severity: 'info',
        recoverable: true
      },

      # Document processing errors
      'document_processing_error' => {
        title: 'Document Processing Failed',
        message: 'We couldn\'t process your uploaded document.',
        guidance: 'Try uploading a different file or use the text prompt option instead.',
        actions: [
          { label: 'Upload Different File', action: 'retry', primary: true },
          { label: 'Use Text Prompt', action: 'switch_input', primary: false }
        ],
        severity: 'error',
        recoverable: true
      },
      'invalid_file_type' => {
        title: 'Unsupported File Type',
        message: 'Please upload a PDF, Markdown (.md), or text (.txt) file.',
        guidance: 'Convert your document to a supported format or copy the text into the prompt field.',
        actions: [
          { label: 'Upload Supported File', action: 'retry', primary: true },
          { label: 'Use Text Prompt', action: 'switch_input', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'file_too_large' => {
        title: 'File Too Large',
        message: 'The uploaded file exceeds our 10MB size limit.',
        guidance: 'Try uploading a smaller file or extract the key content into a text prompt.',
        actions: [
          { label: 'Upload Smaller File', action: 'retry', primary: true },
          { label: 'Use Text Prompt', action: 'switch_input', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },

      # AI processing errors
      'llm_error' => {
        title: 'AI Processing Error',
        message: 'Our AI service encountered an issue while processing your request.',
        guidance: 'This is usually temporary. Please try again in a few moments.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'Contact Support', action: 'support', primary: false }
        ],
        severity: 'error',
        recoverable: true
      },
      'json_parse_error' => {
        title: 'AI Response Error',
        message: 'The AI generated an invalid response format.',
        guidance: 'This is a temporary issue. Please try again with the same or simplified content.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'Simplify Content', action: 'edit_content', primary: false }
        ],
        severity: 'error',
        recoverable: true
      },
      'analysis_validation_error' => {
        title: 'Content Analysis Failed',
        message: 'We couldn\'t properly analyze your content for form generation.',
        guidance: 'Try providing more specific details about your form\'s purpose and target audience.',
        actions: [
          { label: 'Add More Details', action: 'retry', primary: true },
          { label: 'Use Template', action: 'use_template', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'generation_validation_error' => {
        title: 'Form Generation Failed',
        message: 'The AI couldn\'t generate a valid form structure from your content.',
        guidance: 'Try being more specific about the questions you need or the form\'s purpose.',
        actions: [
          { label: 'Refine Content', action: 'retry', primary: true },
          { label: 'Manual Creation', action: 'manual_form', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },

      # Validation errors
      'structure_validation_error' => {
        title: 'Form Structure Invalid',
        message: 'The generated form structure doesn\'t meet our quality standards.',
        guidance: 'We\'ll try again with adjusted parameters. This usually resolves automatically.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'Manual Creation', action: 'manual_form', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'business_rules_error' => {
        title: 'Form Requirements Not Met',
        message: 'The generated form doesn\'t meet our platform requirements.',
        guidance: 'Try simplifying your requirements or being more specific about your needs.',
        actions: [
          { label: 'Simplify Request', action: 'retry', primary: true },
          { label: 'Contact Support', action: 'support', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },

      # Database errors
      'database_error' => {
        title: 'Save Error',
        message: 'We couldn\'t save your generated form due to a technical issue.',
        guidance: 'Your form was generated successfully but couldn\'t be saved. Please try again.',
        actions: [
          { label: 'Try Saving Again', action: 'retry', primary: true },
          { label: 'Contact Support', action: 'support', primary: false }
        ],
        severity: 'error',
        recoverable: true
      },

      # Network and timeout errors
      'timeout_error' => {
        title: 'Request Timeout',
        message: 'The AI processing took longer than expected.',
        guidance: 'Try again with simpler content or check your internet connection.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'Simplify Content', action: 'edit_content', primary: false }
        ],
        severity: 'warning',
        recoverable: true
      },
      'network_error' => {
        title: 'Connection Error',
        message: 'We couldn\'t connect to our AI services.',
        guidance: 'Check your internet connection and try again in a few moments.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'Check Status', action: 'status_page', primary: false }
        ],
        severity: 'error',
        recoverable: true
      },

      # Rate limiting
      'rate_limit_error' => {
        title: 'Too Many Requests',
        message: 'You\'re making requests too quickly.',
        guidance: 'Please wait a moment before trying again.',
        actions: [
          { label: 'Wait and Retry', action: 'retry_later', primary: true }
        ],
        severity: 'warning',
        recoverable: true
      },

      # Generic fallback
      'unknown_error' => {
        title: 'Unexpected Error',
        message: 'Something went wrong while processing your request.',
        guidance: 'Please try again or contact support if the problem persists.',
        actions: [
          { label: 'Try Again', action: 'retry', primary: true },
          { label: 'Contact Support', action: 'support', primary: false }
        ],
        severity: 'error',
        recoverable: true
      }
    }.freeze

    def self.get_user_friendly_error(error_type, context = {})
      service = new(error_type: error_type, context: context)
      service.get_user_friendly_error
    end

    def get_user_friendly_error
      error_config = ERROR_MESSAGES[error_type] || ERROR_MESSAGES['unknown_error']
      
      # Customize message based on context
      customized_config = customize_error_message(error_config)
      
      # Add retry information if applicable
      if retry_count > 0
        customized_config = add_retry_context(customized_config)
      end
      
      # Add escalation path for persistent failures
      if retry_count >= 3
        customized_config = add_escalation_path(customized_config)
      end
      
      customized_config
    end

    private

    def customize_error_message(base_config)
      config = base_config.deep_dup
      
      case error_type
      when 'content_length_error'
        word_count = context[:word_count] || 0
        if word_count < 10
          config[:message] = "Your content is too short (#{word_count} words). We need at least 10 words to generate a meaningful form."
          config[:guidance] = "Add more details about your form's purpose, target audience, and the information you want to collect."
        elsif word_count > 5000
          config[:message] = "Your content is too long (#{word_count} words). Please keep it under 5,000 words for optimal processing."
          config[:guidance] = "Focus on the essential information needed for your form. You can always add more questions manually later."
        end
        
      when 'credit_limit_exceeded'
        credits_used = context[:credits_used] || 0
        monthly_limit = context[:monthly_limit] || 10
        config[:message] = "You've used #{credits_used} of your #{monthly_limit} monthly AI credits."
        
      when 'insufficient_credits'
        required = context[:required_credits] || 0
        available = context[:available_credits] || 0
        config[:message] = "This operation requires #{required} credits, but you only have #{available} remaining."
        
      when 'file_too_large'
        file_size = context[:file_size]
        if file_size
          size_mb = (file_size / 1.megabyte).round(1)
          config[:message] = "Your file is #{size_mb}MB, but our limit is 10MB."
        end
        
      when 'document_processing_error'
        if context[:error_class] == 'PDF::Reader::MalformedPDFError'
          config[:message] = "The PDF file appears to be corrupted or invalid."
          config[:guidance] = "Try re-saving the PDF or converting it to a text file."
        elsif context[:error_class] == 'Encoding::InvalidByteSequenceError'
          config[:message] = "The text file has encoding issues that prevent processing."
          config[:guidance] = "Try saving the file with UTF-8 encoding or copy the text directly into the prompt field."
        end
      end
      
      config
    end

    def add_retry_context(config)
      config = config.deep_dup
      
      if retry_count == 1
        config[:message] += " (Attempt #{retry_count + 1})"
      elsif retry_count >= 2
        config[:message] += " (Multiple attempts failed)"
        config[:guidance] = "This error has occurred #{retry_count + 1} times. " + config[:guidance]
        
        # Add alternative suggestions for persistent failures
        case error_type
        when 'llm_error', 'json_parse_error'
          config[:guidance] += " Consider trying with simpler content or using a form template instead."
          config[:actions] << { label: 'Use Template', action: 'use_template', primary: false }
        when 'document_processing_error'
          config[:guidance] += " Consider copying the text content directly into the prompt field."
        end
      end
      
      config
    end

    def add_escalation_path(config)
      config = config.deep_dup
      
      config[:title] = "Persistent Issue: #{config[:title]}"
      config[:message] = "This error has occurred multiple times. #{config[:message]}"
      config[:guidance] = "Since this issue persists, we recommend contacting our support team for assistance. " + config[:guidance]
      config[:severity] = 'error'
      
      # Add support action as primary if not already present
      unless config[:actions].any? { |action| action[:action] == 'support' }
        config[:actions].unshift({ label: 'Contact Support', action: 'support', primary: true })
        # Make other actions secondary
        config[:actions][1..-1].each { |action| action[:primary] = false }
      end
      
      config
    end

    # Generate action URLs based on action type
    def self.get_action_url(action_type, context = {})
      case action_type
      when 'upgrade'
        '/subscriptions/upgrade'
      when 'view_usage'
        '/profile/usage'
      when 'manual_form'
        '/forms/new'
      when 'use_template'
        '/templates'
      when 'support'
        '/support'
      when 'status_page'
        'https://status.agentform.com'
      when 'show_examples'
        '/help/examples'
      when 'retry'
        context[:current_url] || '/forms/new_from_ai'
      when 'switch_input'
        '/forms/new_from_ai'
      when 'edit_content'
        context[:current_url] || '/forms/new_from_ai'
      when 'retry_later'
        context[:current_url] || '/forms/new_from_ai'
      else
        '/forms/new_from_ai'
      end
    end

    # Check if error is recoverable by user action
    def self.recoverable?(error_type)
      ERROR_MESSAGES[error_type]&.dig(:recoverable) || false
    end

    # Get error severity level
    def self.get_severity(error_type)
      ERROR_MESSAGES[error_type]&.dig(:severity) || 'error'
    end

    # Get suggested retry delay for rate limiting
    def self.get_retry_delay(error_type, retry_count = 0)
      case error_type
      when 'rate_limit_error'
        [30, 60, 120][retry_count] || 300 # 30s, 1m, 2m, then 5m
      when 'llm_error', 'network_error'
        [5, 15, 30][retry_count] || 60 # 5s, 15s, 30s, then 1m
      when 'timeout_error'
        [10, 30, 60][retry_count] || 120 # 10s, 30s, 1m, then 2m
      else
        0 # No delay for other errors
      end
    end
  end
end