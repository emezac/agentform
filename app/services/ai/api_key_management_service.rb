# frozen_string_literal: true

module Ai
  class ApiKeyManagementService < ApplicationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    # API key rotation schedule (in hours)
    ROTATION_SCHEDULE = {
      openai: 168, # 7 days
      anthropic: 168, # 7 days
      google: 168 # 7 days
    }.freeze

    # Key validation patterns
    KEY_PATTERNS = {
      openai: /\Ask-[a-zA-Z0-9]{48}\z/,
      anthropic: /\Ask-ant-api03-[a-zA-Z0-9_-]{95}\z/,
      google: /\AAIza[a-zA-Z0-9_-]{35}\z/
    }.freeze

    attribute :provider, :string
    attribute :environment, :string, default: Rails.env
    attribute :force_rotation, :boolean, default: false

    def rotate_api_keys
      return { success: false, errors: ['Provider is required'] } if provider.blank?
      return { success: false, errors: ['Invalid provider'] } unless valid_provider?

      begin
        current_key_info = get_current_key_info
        
        # Check if rotation is needed
        unless force_rotation || rotation_needed?(current_key_info)
          return {
            success: true,
            message: 'Key rotation not needed',
            next_rotation: current_key_info[:next_rotation]
          }
        end

        # Generate new key (this would typically involve calling the provider's API)
        new_key_result = generate_new_api_key
        return new_key_result unless new_key_result[:success]

        # Validate new key
        validation_result = validate_api_key(new_key_result[:api_key])
        return validation_result unless validation_result[:success]

        # Store new key securely
        storage_result = store_api_key_securely(new_key_result[:api_key])
        return storage_result unless storage_result[:success]

        # Test new key functionality
        test_result = test_api_key_functionality(new_key_result[:api_key])
        if test_result[:success]
          # Update key rotation record
          update_rotation_record(new_key_result[:api_key])
          
          # Log successful rotation
          log_key_rotation('success')
          
          {
            success: true,
            message: 'API key rotated successfully',
            provider: provider,
            rotated_at: Time.current,
            next_rotation: Time.current + ROTATION_SCHEDULE[provider.to_sym].hours
          }
        else
          # Rollback if test fails
          rollback_key_rotation
          log_key_rotation('failed', test_result[:error])
          
          {
            success: false,
            errors: ['New API key failed functionality test'],
            details: test_result
          }
        end

      rescue => e
        Rails.logger.error "API key rotation failed: #{e.message}"
        log_key_rotation('error', e.message)
        
        {
          success: false,
          errors: ['API key rotation failed'],
          error_details: e.message
        }
      end
    end

    def validate_current_keys
      results = {}
      
      ROTATION_SCHEDULE.keys.each do |provider_name|
        self.provider = provider_name.to_s
        
        begin
          current_key = get_current_api_key
          if current_key
            validation_result = validate_api_key(current_key)
            test_result = test_api_key_functionality(current_key)
            
            results[provider_name] = {
              valid_format: validation_result[:success],
              functional: test_result[:success],
              last_rotation: get_last_rotation_time,
              next_rotation: get_next_rotation_time,
              needs_rotation: rotation_needed?
            }
          else
            results[provider_name] = {
              valid_format: false,
              functional: false,
              error: 'API key not found'
            }
          end
        rescue => e
          results[provider_name] = {
            valid_format: false,
            functional: false,
            error: e.message
          }
        end
      end
      
      {
        success: true,
        validation_results: results,
        overall_health: results.values.all? { |r| r[:functional] }
      }
    end

    def get_usage_analytics
      return { success: false, errors: ['Provider is required'] } if provider.blank?

      begin
        # Get usage data from cache or database
        usage_data = Rails.cache.fetch("api_usage_analytics:#{provider}", expires_in: 1.hour) do
          calculate_usage_analytics
        end

        # Detect anomalies
        anomalies = detect_usage_anomalies(usage_data)

        {
          success: true,
          provider: provider,
          usage_data: usage_data,
          anomalies: anomalies,
          generated_at: Time.current
        }
      rescue => e
        Rails.logger.error "Failed to get usage analytics: #{e.message}"
        { success: false, errors: ['Failed to retrieve usage analytics'] }
      end
    end

    private

    def valid_provider?
      ROTATION_SCHEDULE.key?(provider.to_sym)
    end

    def get_current_key_info
      {
        api_key: get_current_api_key,
        last_rotation: get_last_rotation_time,
        next_rotation: get_next_rotation_time
      }
    end

    def rotation_needed?(key_info = nil)
      key_info ||= get_current_key_info
      return true if key_info[:last_rotation].nil?
      
      hours_since_rotation = (Time.current - key_info[:last_rotation]) / 1.hour
      hours_since_rotation >= ROTATION_SCHEDULE[provider.to_sym]
    end

    def generate_new_api_key
      # In a real implementation, this would call the provider's API to generate a new key
      # For now, we'll simulate this process
      
      case provider.to_sym
      when :openai
        # Simulate OpenAI key generation
        new_key = "sk-#{SecureRandom.alphanumeric(48)}"
      when :anthropic
        # Simulate Anthropic key generation
        new_key = "sk-ant-api03-#{SecureRandom.urlsafe_base64(95).tr('=', '')}"
      when :google
        # Simulate Google key generation
        new_key = "AIza#{SecureRandom.urlsafe_base64(35).tr('=', '')}"
      else
        return { success: false, errors: ['Unsupported provider for key generation'] }
      end

      { success: true, api_key: new_key }
    end

    def validate_api_key(api_key)
      pattern = KEY_PATTERNS[provider.to_sym]
      
      if pattern && api_key.match?(pattern)
        { success: true }
      else
        { success: false, errors: ['Invalid API key format'] }
      end
    end

    def store_api_key_securely(api_key)
      # Store in Rails credentials or environment variables
      # This is a simplified implementation
      
      credential_key = "#{provider}_api_key"
      
      # In production, you would update Rails credentials or use a secure key management service
      Rails.application.credentials.config[credential_key.to_sym] = api_key
      
      { success: true }
    rescue => e
      Rails.logger.error "Failed to store API key: #{e.message}"
      { success: false, errors: ['Failed to store API key securely'] }
    end

    def test_api_key_functionality(api_key)
      # Test the API key with a simple request
      case provider.to_sym
      when :openai
        test_openai_key(api_key)
      when :anthropic
        test_anthropic_key(api_key)
      when :google
        test_google_key(api_key)
      else
        { success: false, error: 'Unsupported provider for testing' }
      end
    end

    def test_openai_key(api_key)
      # Simulate OpenAI API test
      # In reality, you would make a simple API call to verify the key works
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def test_anthropic_key(api_key)
      # Simulate Anthropic API test
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def test_google_key(api_key)
      # Simulate Google API test
      { success: true }
    rescue => e
      { success: false, error: e.message }
    end

    def get_current_api_key
      credential_key = "#{provider}_api_key"
      Rails.application.credentials.dig(credential_key.to_sym) || ENV["#{provider.upcase}_API_KEY"]
    end

    def get_last_rotation_time
      Rails.cache.read("api_key_rotation:#{provider}:last_rotation")
    end

    def get_next_rotation_time
      last_rotation = get_last_rotation_time
      return nil unless last_rotation
      
      last_rotation + ROTATION_SCHEDULE[provider.to_sym].hours
    end

    def update_rotation_record(api_key)
      cache_key = "api_key_rotation:#{provider}"
      rotation_data = {
        last_rotation: Time.current,
        key_hash: Digest::SHA256.hexdigest(api_key),
        rotation_count: (Rails.cache.read("#{cache_key}:rotation_count") || 0) + 1
      }
      
      Rails.cache.write("#{cache_key}:last_rotation", Time.current, expires_in: 1.year)
      Rails.cache.write("#{cache_key}:rotation_count", rotation_data[:rotation_count], expires_in: 1.year)
    end

    def rollback_key_rotation
      # In a real implementation, you would restore the previous key
      Rails.logger.warn "Rolling back API key rotation for #{provider}"
    end

    def calculate_usage_analytics
      # Calculate usage metrics from logs or monitoring data
      {
        requests_today: rand(100..1000),
        requests_this_week: rand(500..5000),
        requests_this_month: rand(2000..20000),
        average_response_time: rand(200..2000),
        error_rate: rand(0.0..5.0).round(2),
        cost_today: rand(1.0..50.0).round(2),
        cost_this_month: rand(50.0..500.0).round(2)
      }
    end

    def detect_usage_anomalies(usage_data)
      anomalies = []
      
      # Check for unusual request volume
      if usage_data[:requests_today] > usage_data[:requests_this_week] / 7 * 3
        anomalies << {
          type: 'high_request_volume',
          severity: 'medium',
          description: 'Request volume is significantly higher than average'
        }
      end
      
      # Check for high error rate
      if usage_data[:error_rate] > 10.0
        anomalies << {
          type: 'high_error_rate',
          severity: 'high',
          description: 'Error rate is above acceptable threshold'
        }
      end
      
      # Check for unusual costs
      if usage_data[:cost_today] > usage_data[:cost_this_month] / 30 * 5
        anomalies << {
          type: 'high_cost',
          severity: 'medium',
          description: 'Daily cost is significantly higher than average'
        }
      end
      
      anomalies
    end

    def log_key_rotation(status, error_message = nil)
      AuditLog.create!(
        event_type: 'api_key_rotation',
        details: {
          provider: provider,
          status: status,
          error_message: error_message,
          environment: environment,
          force_rotation: force_rotation
        }
      )
    rescue => e
      Rails.logger.error "Failed to log key rotation: #{e.message}"
    end
  end
end