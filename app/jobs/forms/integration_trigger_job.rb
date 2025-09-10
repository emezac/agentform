# frozen_string_literal: true
require 'net/http'
require 'openssl'

module Forms
  # Background job responsible for triggering external integrations when form events occur
  # This job is triggered when forms are completed, responses are submitted, or other integration events occur
  class IntegrationTriggerJob < ApplicationJob
    queue_as :integrations
    
    # Retry on specific errors that might be temporary (network issues, API rate limits)
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    retry_on Net::TimeoutError, wait: 5.seconds, attempts: 5
    retry_on Net::HTTPError, wait: 10.seconds, attempts: 3
    
    # Discard if records are not found or configuration is invalid
    discard_on ActiveRecord::RecordNotFound, ArgumentError
    
    def perform(form_response_id, trigger_event = 'form_completed', options = {})
      log_progress("Starting integration triggers for form_response #{form_response_id}, event: #{trigger_event}")
      
      # Find the form response and related records
      form_response = find_record(FormResponse, form_response_id)
      form = form_response.form
      
      # Validate prerequisites for integration processing
      validate_integration_prerequisites!(form_response, form, trigger_event)
      
      # Get enabled integrations for this form and trigger event
      enabled_integrations = get_enabled_integrations(form, trigger_event)
      
      if enabled_integrations.empty?
        log_progress("No integrations enabled for trigger event: #{trigger_event}")
        return { success: true, processed_count: 0, skipped: true }
      end
      
      # Process each enabled integration
      results = process_integrations(enabled_integrations, form_response, trigger_event, options)
      
      # Update integration tracking
      update_integration_tracking(form_response, results)
      
      # Log completion
      log_progress("Integration processing completed", {
        form_response_id: form_response.id,
        trigger_event: trigger_event,
        processed_count: results[:processed_count],
        success_count: results[:success_count],
        error_count: results[:error_count]
      })
      
      results
    rescue StandardError => e
      handle_integration_error(form_response_id, trigger_event, e)
    end
    
    private
    
    # Validate that integration processing is appropriate and allowed
    def validate_integration_prerequisites!(form_response, form, trigger_event)
      # Check if form has integrations enabled
      unless form.integrations_enabled?
        raise ArgumentError, "Form #{form.id} does not have integrations enabled"
      end
      
      # Check if user has integration capabilities
      user = form.user
      unless user.can_use_integrations?
        raise ArgumentError, "User #{user.id} does not have integration capabilities"
      end
      
      # Validate trigger event
      valid_events = %w[form_completed response_updated question_answered form_abandoned]
      unless valid_events.include?(trigger_event)
        raise ArgumentError, "Invalid trigger event: #{trigger_event}"
      end
      
      # Check if form response is in appropriate state for the trigger
      case trigger_event
      when 'form_completed'
        unless form_response.completed?
          raise ArgumentError, "Form response #{form_response.id} is not completed"
        end
      when 'form_abandoned'
        unless form_response.abandoned?
          raise ArgumentError, "Form response #{form_response.id} is not abandoned"
        end
      end
      
      log_progress("Integration prerequisites validated", {
        form_response_id: form_response.id,
        form_id: form.id,
        trigger_event: trigger_event,
        integrations_enabled: form.integrations_enabled?,
        user_can_integrate: user.can_use_integrations?
      })
    end
    
    # Get enabled integrations for the form and trigger event
    def get_enabled_integrations(form, trigger_event)
      integration_settings = form.integration_settings || {}
      enabled_integrations = {}
      
      integration_settings.each do |integration_name, config|
        next unless config.is_a?(Hash) && config['enabled']
        
        # Check if this integration should trigger for this event
        trigger_events = config['trigger_events'] || ['form_completed']
        next unless trigger_events.include?(trigger_event)
        
        enabled_integrations[integration_name] = config
      end
      
      log_progress("Found enabled integrations", {
        trigger_event: trigger_event,
        enabled_count: enabled_integrations.size,
        integration_names: enabled_integrations.keys
      })
      
      enabled_integrations
    end
    
    # Process all enabled integrations
    def process_integrations(enabled_integrations, form_response, trigger_event, options)
      results = {
        processed_count: 0,
        success_count: 0,
        error_count: 0,
        integration_results: {},
        errors: []
      }
      
      enabled_integrations.each do |integration_name, config|
        begin
          log_progress("Processing integration: #{integration_name}")
          
          integration_result = process_integration(integration_name, config, form_response, trigger_event, options)
          
          results[:processed_count] += 1
          results[:integration_results][integration_name] = integration_result
          
          if integration_result[:success]
            results[:success_count] += 1
            log_progress("Integration #{integration_name} completed successfully")
          else
            results[:error_count] += 1
            results[:errors] << {
              integration: integration_name,
              error: integration_result[:error],
              error_type: integration_result[:error_type]
            }
            log_progress("Integration #{integration_name} failed", {
              error: integration_result[:error]
            })
          end
          
        rescue StandardError => e
          results[:processed_count] += 1
          results[:error_count] += 1
          results[:errors] << {
            integration: integration_name,
            error: e.message,
            error_type: e.class.name
          }
          
          Rails.logger.error "Integration #{integration_name} processing failed: #{e.message}"
          
          # Continue processing other integrations even if one fails
          next
        end
      end
      
      results
    end
    
    # Process a single integration
    def process_integration(integration_name, config, form_response, trigger_event, options = {})
      log_progress("Processing #{integration_name} integration")
      
      case integration_name.to_s
      when 'webhook'
        process_webhook_integration(config, form_response, trigger_event, options)
      when 'slack'
        process_slack_integration(config, form_response, trigger_event, options)
      when 'email'
        process_email_integration(config, form_response, trigger_event, options)
      when 'salesforce', 'crm'
        process_crm_integration(config, form_response, trigger_event, options)
      when 'mailchimp'
        process_mailchimp_integration(config, form_response, trigger_event, options)
      when 'hubspot'
        process_hubspot_integration(config, form_response, trigger_event, options)
      when 'zapier'
        process_zapier_integration(config, form_response, trigger_event, options)
      else
        {
          success: false,
          error: "Unknown integration type: #{integration_name}",
          error_type: 'unknown_integration'
        }
      end
    end
    
    # Process webhook integration
    def process_webhook_integration(config, form_response, trigger_event, options = {})
      webhook_url = config['webhook_url'] || config['url']
      
      unless webhook_url.present?
        return {
          success: false,
          error: 'Webhook URL not configured',
          error_type: 'configuration_error'
        }
      end
      
      # Prepare webhook payload
      payload = build_webhook_payload(form_response, trigger_event, config)
      
      # Prepare headers
      headers = {
        'Content-Type' => 'application/json',
        'User-Agent' => 'AgentForm/1.0',
        'X-AgentForm-Event' => trigger_event,
        'X-AgentForm-Form-Id' => form_response.form.id,
        'X-AgentForm-Response-Id' => form_response.id
      }
      
      # Add custom headers if configured
      if config['headers'].is_a?(Hash)
        headers.merge!(config['headers'])
      end
      
      # Add webhook secret for verification
      if config['secret'].present?
        signature = generate_webhook_signature(payload.to_json, config['secret'])
        headers['X-AgentForm-Signature'] = signature
      end
      
      begin
        # Make HTTP request
        uri = URI(webhook_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = config['timeout'] || 30
        
        request = Net::HTTP::Post.new(uri.path, headers)
        request.body = payload.to_json
        
        response = http.request(request)
        
        if response.code.to_i.between?(200, 299)
          log_progress("Webhook delivered successfully", {
            url: webhook_url,
            status_code: response.code,
            response_body: response.body&.truncate(200)
          })
          
          {
            success: true,
            status_code: response.code.to_i,
            response_body: response.body,
            delivered_at: Time.current.iso8601
          }
        else
          {
            success: false,
            error: "HTTP #{response.code}: #{response.message}",
            error_type: 'http_error',
            status_code: response.code.to_i,
            response_body: response.body
          }
        end
        
      rescue Net::TimeoutError => e
        {
          success: false,
          error: "Webhook timeout: #{e.message}",
          error_type: 'timeout_error'
        }
      rescue StandardError => e
        {
          success: false,
          error: "Webhook delivery failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Process Slack integration
    def process_slack_integration(config, form_response, trigger_event, options = {})
      webhook_url = config['webhook_url']
      
      unless webhook_url.present?
        return {
          success: false,
          error: 'Slack webhook URL not configured',
          error_type: 'configuration_error'
        }
      end
      
      # Build Slack message payload
      slack_payload = build_slack_payload(form_response, trigger_event, config)
      
      begin
        uri = URI(webhook_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        
        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json'
        })
        request.body = slack_payload.to_json
        
        response = http.request(request)
        
        if response.code == '200'
          log_progress("Slack notification sent successfully")
          
          {
            success: true,
            status_code: 200,
            delivered_at: Time.current.iso8601
          }
        else
          {
            success: false,
            error: "Slack API error: #{response.code} #{response.message}",
            error_type: 'slack_api_error',
            status_code: response.code.to_i
          }
        end
        
      rescue StandardError => e
        {
          success: false,
          error: "Slack notification failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Process email integration
    def process_email_integration(config, form_response, trigger_event, options = {})
      email_type = config['type'] || 'notification'
      
      case email_type
      when 'notification'
        send_notification_email(config, form_response, trigger_event)
      when 'autoresponder'
        send_autoresponder_email(config, form_response, trigger_event)
      when 'admin_alert'
        send_admin_alert_email(config, form_response, trigger_event)
      else
        {
          success: false,
          error: "Unknown email type: #{email_type}",
          error_type: 'configuration_error'
        }
      end
    end
    
    # Process CRM integration (Salesforce, etc.)
    def process_crm_integration(config, form_response, trigger_event, options = {})
      crm_type = config['type'] || config['provider'] || 'salesforce'
      
      begin
        case crm_type.downcase
        when 'salesforce'
          service = Forms::Integrations::SalesforceService.new(config)
          result = service.sync_response(form_response)
        when 'hubspot'
          service = Forms::Integrations::HubspotService.new(config)
          result = service.sync_response(form_response)
        else
          return {
            success: false,
            error: "Unsupported CRM type: #{crm_type}",
            error_type: 'configuration_error'
          }
        end
        
        if result[:success]
          log_progress("CRM sync completed successfully", {
            crm_type: crm_type,
            record_id: result[:record_id]
          })
          
          {
            success: true,
            crm_type: crm_type,
            record_id: result[:record_id],
            synced_at: Time.current.iso8601
          }
        else
          {
            success: false,
            error: result[:error] || 'CRM sync failed',
            error_type: result[:error_type] || 'crm_error'
          }
        end
        
      rescue StandardError => e
        {
          success: false,
          error: "CRM integration failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Process Mailchimp integration
    def process_mailchimp_integration(config, form_response, trigger_event, options = {})
      begin
        service = Forms::Integrations::MailchimpService.new(config)
        result = service.sync_response(form_response)
        
        if result[:success]
          log_progress("Mailchimp sync completed successfully", {
            list_id: result[:list_id],
            subscriber_id: result[:subscriber_id]
          })
          
          {
            success: true,
            list_id: result[:list_id],
            subscriber_id: result[:subscriber_id],
            synced_at: Time.current.iso8601
          }
        else
          {
            success: false,
            error: result[:error] || 'Mailchimp sync failed',
            error_type: result[:error_type] || 'mailchimp_error'
          }
        end
        
      rescue StandardError => e
        {
          success: false,
          error: "Mailchimp integration failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Process HubSpot integration
    def process_hubspot_integration(config, form_response, trigger_event, options = {})
      begin
        service = Forms::Integrations::HubspotService.new(config)
        result = service.sync_response(form_response)
        
        if result[:success]
          log_progress("HubSpot sync completed successfully", {
            contact_id: result[:contact_id],
            deal_id: result[:deal_id]
          })
          
          {
            success: true,
            contact_id: result[:contact_id],
            deal_id: result[:deal_id],
            synced_at: Time.current.iso8601
          }
        else
          {
            success: false,
            error: result[:error] || 'HubSpot sync failed',
            error_type: result[:error_type] || 'hubspot_error'
          }
        end
        
      rescue StandardError => e
        {
          success: false,
          error: "HubSpot integration failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Process Zapier integration
    def process_zapier_integration(config, form_response, trigger_event, options = {})
      # Zapier integration is essentially a webhook with specific formatting
      zapier_config = config.merge({
        'webhook_url' => config['webhook_url'] || config['zapier_webhook_url']
      })
      
      process_webhook_integration(zapier_config, form_response, trigger_event, options)
    end
    
    # Build webhook payload
    def build_webhook_payload(form_response, trigger_event, config)
      form = form_response.form
      
      # Base payload structure
      payload = {
        event: trigger_event,
        timestamp: Time.current.iso8601,
        form: {
          id: form.id,
          name: form.name,
          description: form.description
        },
        response: {
          id: form_response.id,
          submitted_at: form_response.created_at.iso8601,
          completed_at: form_response.completed_at&.iso8601,
          status: form_response.status,
          progress_percentage: form_response.progress_percentage
        },
        answers: build_answers_payload(form_response),
        metadata: {
          user_agent: form_response.user_agent,
          ip_address: form_response.ip_address,
          referrer: form_response.referrer_url
        }
      }
      
      # Add AI analysis if available
      if form_response.ai_analysis_results.present?
        payload[:ai_analysis] = {
          overall_sentiment: form_response.ai_analysis_results['overall_sentiment'],
          overall_quality: form_response.ai_analysis_results['overall_quality'],
          key_insights: form_response.ai_analysis_results['key_insights']
        }
      end
      
      # Add custom fields if configured
      if config['include_custom_fields']
        payload[:custom_fields] = extract_custom_fields(form_response)
      end
      
      payload
    end
    
    # Build Slack message payload
    def build_slack_payload(form_response, trigger_event, config)
      form = form_response.form
      
      # Determine message color based on form response
      color = determine_slack_color(form_response)
      
      # Build main message
      text = case trigger_event
             when 'form_completed'
               "New form submission received for '#{form.name}'"
             when 'form_abandoned'
               "Form '#{form.name}' was abandoned"
             when 'response_updated'
               "Form response updated for '#{form.name}'"
             else
               "Form event '#{trigger_event}' for '#{form.name}'"
             end
      
      # Build fields for Slack attachment
      fields = build_slack_fields(form_response)
      
      payload = {
        text: text,
        attachments: [
          {
            color: color,
            fields: fields,
            footer: "AgentForm",
            ts: Time.current.to_i
          }
        ]
      }
      
      # Add channel if specified
      if config['channel'].present?
        payload[:channel] = config['channel']
      end
      
      # Add username if specified
      if config['username'].present?
        payload[:username] = config['username']
      end
      
      payload
    end
    
    # Determine Slack message color based on form response
    def determine_slack_color(form_response)
      return '#36a64f' if form_response.completed? # Green for completed
      return '#ff9900' if form_response.in_progress? # Orange for in progress
      return '#ff0000' if form_response.abandoned? # Red for abandoned
      
      '#439fe0' # Default blue
    end
    
    # Build Slack fields from form response
    def build_slack_fields(form_response)
      fields = []
      
      # Add basic info
      fields << {
        title: "Response ID",
        value: form_response.id,
        short: true
      }
      
      fields << {
        title: "Status",
        value: form_response.status.humanize,
        short: true
      }
      
      if form_response.completed_at
        fields << {
          title: "Completed At",
          value: form_response.completed_at.strftime("%Y-%m-%d %H:%M:%S"),
          short: true
        }
      end
      
      # Add key answers (limit to avoid message being too long)
      form_response.question_responses.includes(:form_question).limit(5).each do |qr|
        next unless qr.answer_data.present?
        
        fields << {
          title: qr.form_question.title,
          value: truncate_answer(qr.answer_data.to_s),
          short: false
        }
      end
      
      # Add AI insights if available
      if form_response.ai_analysis_results.present?
        sentiment = form_response.ai_analysis_results['overall_sentiment']
        if sentiment
          sentiment_label = case sentiment
                           when 0.0..0.3 then "Negative"
                           when 0.3..0.7 then "Neutral"
                           else "Positive"
                           end
          
          fields << {
            title: "AI Sentiment",
            value: sentiment_label,
            short: true
          }
        end
      end
      
      fields
    end
    
    # Truncate answer for display
    def truncate_answer(answer)
      return answer if answer.length <= 100
      
      "#{answer[0..97]}..."
    end
    
    # Build answers payload for webhooks
    def build_answers_payload(form_response)
      answers = {}
      
      form_response.question_responses.includes(:form_question).each do |qr|
        question = qr.form_question
        
        answers[question.id] = {
          question_id: question.id,
          question_title: question.title,
          question_type: question.question_type,
          answer: qr.answer_data,
          answered_at: qr.created_at.iso8601
        }
        
        # Add AI analysis for this specific answer if available
        if qr.ai_analysis_results.present?
          answers[question.id][:ai_analysis] = {
            sentiment: qr.ai_analysis_results['sentiment'],
            quality: qr.ai_analysis_results['quality'],
            confidence_score: qr.ai_confidence_score
          }
        end
      end
      
      answers
    end
    
    # Extract custom fields from form response
    def extract_custom_fields(form_response)
      custom_fields = {}
      
      # Add any custom metadata
      if form_response.metadata.present?
        custom_fields.merge!(form_response.metadata)
      end
      
      # Add form-specific custom fields
      form = form_response.form
      if form.form_settings.present? && form.form_settings['custom_fields']
        form.form_settings['custom_fields'].each do |field_name, field_config|
          # Extract custom field value based on configuration
          custom_fields[field_name] = extract_custom_field_value(form_response, field_config)
        end
      end
      
      custom_fields
    end
    
    # Extract custom field value
    def extract_custom_field_value(form_response, field_config)
      case field_config['type']
      when 'calculated'
        # Perform calculation based on answers
        calculate_field_value(form_response, field_config['formula'])
      when 'lookup'
        # Look up value from another source
        lookup_field_value(form_response, field_config['source'])
      else
        field_config['default_value']
      end
    end
    
    # Calculate field value based on formula
    def calculate_field_value(form_response, formula)
      # Simple calculation implementation
      # This could be expanded to support more complex formulas
      return 0 unless formula.present?
      
      # For now, just return a placeholder
      "calculated_value"
    end
    
    # Look up field value from external source
    def lookup_field_value(form_response, source_config)
      # Placeholder for lookup functionality
      "lookup_value"
    end
    
    # Send notification email
    def send_notification_email(config, form_response, trigger_event)
      begin
        # This would integrate with ActionMailer
        # For now, return success placeholder
        {
          success: true,
          email_type: 'notification',
          sent_at: Time.current.iso8601
        }
      rescue StandardError => e
        {
          success: false,
          error: "Email notification failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Send autoresponder email
    def send_autoresponder_email(config, form_response, trigger_event)
      begin
        # This would integrate with ActionMailer
        # For now, return success placeholder
        {
          success: true,
          email_type: 'autoresponder',
          sent_at: Time.current.iso8601
        }
      rescue StandardError => e
        {
          success: false,
          error: "Autoresponder email failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Send admin alert email
    def send_admin_alert_email(config, form_response, trigger_event)
      begin
        # This would integrate with ActionMailer
        # For now, return success placeholder
        {
          success: true,
          email_type: 'admin_alert',
          sent_at: Time.current.iso8601
        }
      rescue StandardError => e
        {
          success: false,
          error: "Admin alert email failed: #{e.message}",
          error_type: e.class.name
        }
      end
    end
    
    # Generate webhook signature for verification
    def generate_webhook_signature(payload, secret)
      OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
    end
    
    # Update integration tracking on the form response
    def update_integration_tracking(form_response, results)
      safe_db_operation do
        # Update integration metadata
        integration_metadata = form_response.integration_metadata || {}
        integration_metadata[:last_triggered_at] = Time.current.iso8601
        integration_metadata[:trigger_count] = (integration_metadata[:trigger_count] || 0) + 1
        integration_metadata[:last_results] = {
          processed_count: results[:processed_count],
          success_count: results[:success_count],
          error_count: results[:error_count],
          job_id: job_id
        }
        
        # Store individual integration results
        integration_metadata[:integration_history] ||= []
        integration_metadata[:integration_history] << {
          timestamp: Time.current.iso8601,
          results: results[:integration_results],
          job_id: job_id
        }
        
        # Keep only last 10 history entries
        integration_metadata[:integration_history] = integration_metadata[:integration_history].last(10)
        
        form_response.update!(integration_metadata: integration_metadata)
        
        log_progress("Integration tracking updated", {
          form_response_id: form_response.id,
          trigger_count: integration_metadata[:trigger_count]
        })
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update integration tracking: #{e.message}"
      # Don't re-raise as this is not critical
    end
    
    # Handle integration processing errors
    def handle_integration_error(form_response_id, trigger_event, error)
      error_context = {
        form_response_id: form_response_id,
        trigger_event: trigger_event,
        job_id: job_id,
        error_message: error.message,
        error_type: error.class.name
      }
      
      Rails.logger.error "Integration processing failed for form_response #{form_response_id}, event #{trigger_event}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Try to update form response with error information if possible
      begin
        form_response = FormResponse.find_by(id: form_response_id)
        if form_response
          integration_metadata = form_response.integration_metadata || {}
          integration_metadata[:errors] ||= []
          integration_metadata[:errors] << {
            error: error.message,
            error_type: error.class.name,
            trigger_event: trigger_event,
            failed_at: Time.current.iso8601,
            job_id: job_id
          }
          
          # Keep only last 5 errors
          integration_metadata[:errors] = integration_metadata[:errors].last(5)
          
          form_response.update!(integration_metadata: integration_metadata)
        end
      rescue StandardError => update_error
        Rails.logger.error "Failed to update form response with error information: #{update_error.message}"
      end
      
      # Track error in monitoring system
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: error_context)
      end
      
      # Re-raise to trigger retry logic
      raise error
    end
  end
end