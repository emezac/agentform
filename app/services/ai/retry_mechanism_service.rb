# frozen_string_literal: true

module Ai
  class RetryMechanismService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :operation_type, :string
    attribute :error_type, :string
    attribute :retry_count, :integer, default: 0
    attribute :user_id, :string
    attribute :context, :string, default: {}

    MAX_RETRIES = {
      'llm_error' => 3,
      'json_parse_error' => 3,
      'analysis_validation_error' => 2,
      'generation_validation_error' => 2,
      'document_processing_error' => 2,
      'network_error' => 3,
      'timeout_error' => 2,
      'database_error' => 3,
      'structure_validation_error' => 2,
      'business_rules_error' => 1
    }.freeze

    RETRY_DELAYS = {
      'llm_error' => [2, 5, 10], # seconds
      'json_parse_error' => [1, 3, 5],
      'network_error' => [3, 10, 30],
      'timeout_error' => [5, 15, 30],
      'database_error' => [1, 2, 5],
      'rate_limit_error' => [30, 60, 120]
    }.freeze

    RETRY_STRATEGIES = {
      'llm_error' => 'exponential_backoff',
      'json_parse_error' => 'immediate_with_modification',
      'analysis_validation_error' => 'immediate_with_modification',
      'generation_validation_error' => 'immediate_with_modification',
      'document_processing_error' => 'alternative_approach',
      'network_error' => 'exponential_backoff',
      'timeout_error' => 'exponential_backoff',
      'database_error' => 'immediate',
      'rate_limit_error' => 'fixed_delay'
    }.freeze

    def self.should_retry?(error_type, retry_count)
      max_retries = MAX_RETRIES[error_type] || 0
      retry_count < max_retries
    end

    def self.get_retry_delay(error_type, retry_count)
      delays = RETRY_DELAYS[error_type] || [0]
      delays[retry_count] || delays.last || 0
    end

    def self.get_retry_strategy(error_type)
      RETRY_STRATEGIES[error_type] || 'immediate'
    end

    def self.create_retry_plan(error_type, retry_count, context = {})
      service = new(
        error_type: error_type,
        retry_count: retry_count,
        context: context
      )
      service.create_retry_plan
    end

    def create_retry_plan
      return nil unless self.class.should_retry?(error_type, retry_count)

      strategy = self.class.get_retry_strategy(error_type)
      delay = self.class.get_retry_delay(error_type, retry_count)

      plan = {
        can_retry: true,
        retry_count: retry_count + 1,
        delay_seconds: delay,
        strategy: strategy,
        modifications: get_retry_modifications,
        user_guidance: get_user_retry_guidance,
        automatic: should_auto_retry?,
        estimated_success_rate: estimate_success_rate
      }

      # Add strategy-specific details
      case strategy
      when 'exponential_backoff'
        plan[:next_delay] = calculate_exponential_backoff(delay, retry_count + 1)
      when 'alternative_approach'
        plan[:alternative_methods] = get_alternative_approaches
      when 'immediate_with_modification'
        plan[:required_modifications] = get_required_modifications
      end

      plan
    end

    private

    def get_retry_modifications
      modifications = {}

      case error_type
      when 'json_parse_error'
        modifications[:llm_temperature] = [0.1, 0.0, 0.0][retry_count] || 0.0
        modifications[:response_format] = 'strict_json'
        modifications[:max_tokens] = context[:max_tokens] ? context[:max_tokens] * 0.8 : nil
        
      when 'analysis_validation_error'
        modifications[:prompt_template] = 'simplified'
        modifications[:validation_strictness] = 'relaxed'
        
      when 'generation_validation_error'
        modifications[:question_count_limit] = [15, 10, 5][retry_count] || 5
        modifications[:complexity_level] = 'simple'
        modifications[:prompt_template] = 'basic'
        
      when 'llm_error'
        modifications[:model_fallback] = get_model_fallback
        modifications[:timeout_increase] = true
        
      when 'document_processing_error'
        modifications[:processing_method] = get_alternative_processing_method
        modifications[:content_extraction] = 'text_only'
        
      when 'timeout_error'
        modifications[:timeout_multiplier] = 2.0
        modifications[:content_chunking] = true
        
      when 'network_error'
        modifications[:connection_timeout] = 30
        modifications[:read_timeout] = 60
      end

      modifications
    end

    def get_user_retry_guidance
      case error_type
      when 'json_parse_error', 'analysis_validation_error'
        "We'll try again with adjusted AI parameters to improve response quality."
        
      when 'generation_validation_error'
        "We'll attempt to generate a simpler form structure that meets our quality standards."
        
      when 'llm_error'
        if retry_count == 0
          "We'll try again with our backup AI system."
        else
          "Attempting retry with extended timeout and error recovery."
        end
        
      when 'document_processing_error'
        "We'll try an alternative method to extract content from your document."
        
      when 'network_error', 'timeout_error'
        "We'll retry with improved connection settings and longer timeout."
        
      when 'database_error'
        "We'll attempt to save your form again with error recovery."
        
      else
        "We'll try again with optimized settings."
      end
    end

    def should_auto_retry?
      # Auto-retry for technical errors, but not for user input issues
      auto_retry_types = %w[
        llm_error
        json_parse_error
        network_error
        timeout_error
        database_error
        structure_validation_error
      ]
      
      auto_retry_types.include?(error_type) && retry_count < 2
    end

    def estimate_success_rate
      # Estimated success rates based on error type and retry count
      base_rates = {
        'llm_error' => [70, 85, 95],
        'json_parse_error' => [80, 90, 95],
        'analysis_validation_error' => [60, 75, 85],
        'generation_validation_error' => [65, 80, 90],
        'document_processing_error' => [50, 70, 80],
        'network_error' => [75, 85, 90],
        'timeout_error' => [70, 80, 85],
        'database_error' => [85, 95, 98],
        'structure_validation_error' => [60, 75, 85]
      }
      
      rates = base_rates[error_type] || [50, 60, 70]
      rates[retry_count] || rates.last || 50
    end

    def calculate_exponential_backoff(base_delay, attempt)
      # Exponential backoff with jitter
      delay = base_delay * (2 ** (attempt - 1))
      jitter = rand(0.1..0.3) * delay
      (delay + jitter).round(1)
    end

    def get_alternative_approaches
      approaches = []
      
      case error_type
      when 'document_processing_error'
        approaches << {
          method: 'text_extraction_only',
          description: 'Extract plain text without formatting'
        }
        approaches << {
          method: 'manual_input',
          description: 'Copy content manually into text prompt'
        }
        
      when 'llm_error'
        approaches << {
          method: 'template_based',
          description: 'Use a pre-built form template'
        }
        approaches << {
          method: 'manual_creation',
          description: 'Create form manually with guided assistance'
        }
        
      when 'analysis_validation_error'
        approaches << {
          method: 'simplified_analysis',
          description: 'Use basic content analysis'
        }
        approaches << {
          method: 'template_matching',
          description: 'Match content to existing templates'
        }
      end
      
      approaches
    end

    def get_required_modifications
      case error_type
      when 'analysis_validation_error'
        [
          'Simplify content analysis requirements',
          'Use more flexible validation rules',
          'Focus on core form elements only'
        ]
        
      when 'generation_validation_error'
        [
          'Reduce maximum question count',
          'Use simpler question types only',
          'Apply basic form structure template'
        ]
        
      when 'json_parse_error'
        [
          'Use stricter JSON formatting',
          'Reduce response complexity',
          'Apply response validation'
        ]
        
      else
        []
      end
    end

    def get_model_fallback
      case context[:current_model]
      when 'gpt-4o'
        'gpt-4o-mini'
      when 'gpt-4o-mini'
        'gpt-3.5-turbo'
      else
        'gpt-3.5-turbo'
      end
    end

    def get_alternative_processing_method
      case context[:current_method]
      when 'pdf_reader'
        'text_extraction'
      when 'full_processing'
        'simple_text_only'
      else
        'basic_extraction'
      end
    end

    # Class methods for workflow integration
    def self.execute_with_retry(operation_type, max_retries = 3, &block)
      retry_count = 0
      last_error = nil

      while retry_count <= max_retries
        begin
          result = yield(retry_count)
          
          # Track successful retry if this wasn't the first attempt
          if retry_count > 0
            track_retry_success(operation_type, retry_count, last_error&.class&.name)
          end
          
          return result
          
        rescue StandardError => e
          last_error = e
          error_type = classify_error(e)
          
          # Check if we should retry this error type
          unless should_retry?(error_type, retry_count)
            track_retry_failure(operation_type, retry_count, error_type, e.message)
            raise e
          end
          
          # Get retry delay and wait if necessary
          delay = get_retry_delay(error_type, retry_count)
          if delay > 0
            Rails.logger.info "Retrying #{operation_type} after #{delay}s delay (attempt #{retry_count + 1})"
            sleep(delay)
          end
          
          retry_count += 1
          
          # Track retry attempt
          track_retry_attempt(operation_type, retry_count, error_type, e.message)
        end
      end

      # If we get here, all retries failed
      track_retry_exhausted(operation_type, max_retries, last_error&.class&.name, last_error&.message)
      raise last_error
    end

    def self.classify_error(error)
      case error
      when JSON::ParserError
        'json_parse_error'
      when Net::TimeoutError, Timeout::Error
        'timeout_error'
      when Net::HTTPError, SocketError
        'network_error'
      when ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
        'database_error'
      when PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
        'document_processing_error'
      else
        if error.message.include?('LLM')
          'llm_error'
        elsif error.message.include?('validation')
          'validation_error'
        else
          'unknown_error'
        end
      end
    end

    def self.track_retry_attempt(operation_type, retry_count, error_type, error_message)
      Rails.logger.info "[RETRY_ATTEMPT] Operation: #{operation_type}, Attempt: #{retry_count}, Error: #{error_type}"
      
      # Track in cache for analytics
      key = "retry_attempts:#{operation_type}:#{Date.current}"
      Rails.cache.increment(key, 1, expires_in: 32.days)
    end

    def self.track_retry_success(operation_type, retry_count, error_type)
      Rails.logger.info "[RETRY_SUCCESS] Operation: #{operation_type}, Succeeded after #{retry_count} retries"
      
      # Track successful retries
      key = "retry_success:#{operation_type}:#{Date.current}"
      Rails.cache.increment(key, 1, expires_in: 32.days)
    end

    def self.track_retry_failure(operation_type, retry_count, error_type, error_message)
      Rails.logger.warn "[RETRY_FAILURE] Operation: #{operation_type}, Failed after #{retry_count} attempts, Error: #{error_type}"
      
      # Track failed retries
      key = "retry_failures:#{operation_type}:#{Date.current}"
      Rails.cache.increment(key, 1, expires_in: 32.days)
    end

    def self.track_retry_exhausted(operation_type, max_retries, error_type, error_message)
      Rails.logger.error "[RETRY_EXHAUSTED] Operation: #{operation_type}, All #{max_retries} retries failed, Final error: #{error_type}"
      
      # Track exhausted retries
      key = "retry_exhausted:#{operation_type}:#{Date.current}"
      Rails.cache.increment(key, 1, expires_in: 32.days)
    end
  end
end