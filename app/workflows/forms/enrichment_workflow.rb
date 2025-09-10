# frozen_string_literal: true

module Forms
  # Workflow for enriching form response data with external company information
  # Uses email domain to fetch company data and enhance lead profiles
  class EnrichmentWorkflow < ApplicationWorkflow
    
    workflow do
      # Validate that the form belongs to a premium user
      validate :check_premium_access do
        input :form_response_id
        process do |id|
          form_response = FormResponse.find(id)
          form = form_response.form
          
          # Check if user has premium access for AI features
          unless FormPolicy.new(form.user, form).ai_features?
            raise Pundit::NotAuthorizedError, "AI enrichment requires premium subscription"
          end
          
          email = form_response.get_answer('email')
          domain = email&.split('@')&.last
          
          unless domain.present?
            raise ArgumentError, "Invalid email address provided"
          end
          
          { domain: domain, form_response_id: id }
        end
      end

      # Fetch company information from external API
      task :fetch_company_info do
        input :domain
        output :company_data
        process do |domain|
          begin
            company_info = fetch_company_data(domain)
            company_info || {}
          rescue StandardError => e
            Rails.logger.error "Failed to fetch company data for #{domain}: #{e.message}"
            {} # Return empty hash on failure
          end
        end
      end

      # Process and structure the company data
      task :process_company_data do
        input :company_data, :form_response_id
        output :processed_data
        process do |company_data, form_response_id|
          next {} if company_data.empty?
          
          processed = {
            company_name: company_data['name'],
            industry: company_data['industry'],
            company_size: company_data['employees'],
            location: company_data['location'],
            website: company_data['domain'],
            description: company_data['description'],
            founded_year: company_data['founded'],
            technologies: company_data['tech'] || [],
            social_profiles: company_data['social_profiles'] || {}
          }
          
          # Filter out nil/empty values
          processed.compact.reject { |_, v| v.blank? }
        end
      end

      # Update form response with enrichment data
      task :update_response_with_enrichment do
        input :processed_data, :form_response_id
        process do |processed_data, form_response_id|
          next if processed_data.empty?
          
          form_response = FormResponse.find(form_response_id)
          
          # Store enrichment data
          form_response.update!(
            enrichment_data: processed_data,
            enriched_at: Time.current
          )
          
          # Also store as metadata for easy access
          current_metadata = form_response.metadata || {}
          current_metadata[:company_enrichment] = processed_data
          form_response.update!(metadata: current_metadata)
          
          { success: true, enrichment_data: processed_data }
        end
      end

      # Update UI with enrichment results via Turbo Streams
      stream :update_ui_with_enrichment do
        target { |ctx| "enrichment_#{ctx.get(:form_response_id)}" }
        partial "responses/enrichment_data"
        locals { |ctx| 
          { 
            company_data: ctx.get(:processed_data),
            form_response_id: ctx.get(:form_response_id)
          } 
        }
      end
    end

    private

    # Fetch company data from external enrichment service
    # In a real implementation, this would call Clearbit, FullContact, or similar service
    def fetch_company_data(domain)
      # Mock implementation - replace with actual API call
      Rails.logger.info "Fetching company data for domain: #{domain}"
      
      # This is a placeholder - in production, integrate with:
      # - Clearbit Enrichment API
      # - FullContact Company API
      # - Hunter.io Company API
      # - Or similar service
      
      mock_data = {
        'name' => domain.split('.').first.capitalize + ' Inc.',
        'industry' => 'Technology',
        'employees' => '51-200',
        'location' => 'San Francisco, CA',
        'domain' => domain,
        'description' => "A leading technology company in the #{domain.split('.').first} space.",
        'founded' => 2015,
        'tech' => ['JavaScript', 'Ruby', 'AWS'],
        'social_profiles' => {
          'linkedin' => "https://linkedin.com/company/#{domain.split('.').first}",
          'twitter' => "https://twitter.com/#{domain.split('.').first}"
        }
      }
      
      # Return mock data for development
      mock_data
    end
  end
end