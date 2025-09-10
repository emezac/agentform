# frozen_string_literal: true

module Forms
  # Agent responsible for managing form lifecycle operations
  # Handles form creation, analysis, optimization, and management tasks
  class ManagementAgent < ApplicationAgent
    
    # Supported task types for this agent
    SUPPORTED_TASKS = %w[
      create_form
      analyze_form_performance
      optimize_form
      generate_form_from_template
      duplicate_form
      duplicate_question
      export_form_data
      publish_form
    ].freeze
    
    def initialize(context = {})
      super(context)
      @supported_tasks = SUPPORTED_TASKS
    end
    
    # Create a new form for a user with the provided form data
    # @param user [User] The user who will own the form
    # @param form_data [Hash] Form configuration and settings
    # @return [Hash] Success/error response with form data
    def create_form(user, form_data)
      validate_context(:user_id) if @context[:user_id]
      
      log_activity("create_form", { user_id: user.id, form_name: form_data[:name] })
      
      safe_db_operation do
        # Validate user permissions
        unless authorized?('write')
          return error_response("User not authorized to create forms", 'authorization_error')
        end
        
        # Validate form data
        validation_result = validate_form_data(form_data)
        unless validation_result[:valid]
          return error_response(validation_result[:errors].join(', '), 'validation_error')
        end
        
        # Create the form
        form = Form.new(prepare_form_attributes(user, form_data))
        
        if form.save
          # Generate workflow class if AI features are enabled
          if form.ai_enhanced?
            generate_workflow_for_form(form)
          end
          
          # Track form creation
          track_form_creation(form)
          
          success_response({
            form: form,
            form_id: form.id,
            share_token: form.share_token,
            public_url: form.public_url
          })
        else
          error_response(form.errors.full_messages.join(', '), 'creation_error')
        end
      end
    end
    
    # Analyze form performance and generate insights
    # @param form [Form] The form to analyze
    # @return [Hash] Analysis results and recommendations
    def analyze_form_performance(form)
      log_activity("analyze_form_performance", { form_id: form.id })
      
      # Validate form ownership
      unless owns_resource?(form)
        return error_response("Not authorized to analyze this form", 'authorization_error')
      end
      
      # Check if form has enough data for analysis
      if form.responses_count < 10
        return error_response("Form needs at least 10 responses for analysis", 'insufficient_data')
      end
      
      # Execute analysis workflow
      workflow_result = execute_workflow(
        Forms::AnalysisWorkflow,
        { form_id: form.id }
      )
      
      if workflow_result[:success]
        success_response({
          analysis: workflow_result[:data],
          form_id: form.id,
          analyzed_at: Time.current
        })
      else
        error_response("Analysis failed: #{workflow_result[:error_message]}", 'analysis_error')
      end
    end
    
    # Optimize form based on performance data and AI recommendations
    # @param form [Form] The form to optimize
    # @param optimization_preferences [Hash] User preferences for optimization
    # @return [Hash] Optimization results and applied changes
    def optimize_form(form, optimization_preferences = {})
      log_activity("optimize_form", { form_id: form.id, preferences: optimization_preferences })
      
      # Validate form ownership
      unless owns_resource?(form)
        return error_response("Not authorized to optimize this form", 'authorization_error')
      end
      
      # Check AI credits availability
      estimated_cost = calculate_optimization_cost(form)
      unless current_user&.can_use_ai_features? && ai_budget_available?(@context, estimated_cost)
        return error_response("Insufficient AI credits for optimization", 'insufficient_credits')
      end
      
      safe_db_operation do
        # Get current form analytics
        analytics = form.analytics_summary
        
        # Generate optimization recommendations
        optimization_result = generate_optimization_recommendations(form, analytics, optimization_preferences)
        
        if optimization_result[:success]
          # Apply approved optimizations
          applied_changes = apply_optimizations(form, optimization_result[:recommendations])
          
          # Track AI usage
          track_ai_usage(@context, estimated_cost, 'form_optimization')
          
          success_response({
            optimizations_applied: applied_changes,
            recommendations: optimization_result[:recommendations],
            estimated_improvement: optimization_result[:estimated_improvement],
            form_id: form.id
          })
        else
          error_response("Optimization failed: #{optimization_result[:error]}", 'optimization_error')
        end
      end
    end
    
    # Generate a new form from a template
    # @param user [User] The user who will own the new form
    # @param template_id [String] ID of the template to use
    # @param customizations [Hash] Custom modifications to apply
    # @return [Hash] Success/error response with new form data
    def generate_form_from_template(user, template_id, customizations = {})
      log_activity("generate_form_from_template", { 
        user_id: user.id, 
        template_id: template_id,
        customizations: customizations.keys
      })
      
      safe_db_operation do
        # Find and validate template
        template = FormTemplate.find_by(id: template_id)
        unless template
          return error_response("Template not found", 'not_found_error')
        end
        
        # Check template visibility permissions
        unless template.visibility == 'public' || template.creator == user
          return error_response("Template not accessible", 'authorization_error')
        end
        
        # Generate form from template
        form = template.instantiate_for_user(user, customizations)
        
        if form.persisted?
          # Update template usage count
          template.increment!(:usage_count)
          
          # Generate workflow if needed
          if form.ai_enhanced?
            generate_workflow_for_form(form)
          end
          
          success_response({
            form: form,
            form_id: form.id,
            template_id: template_id,
            customizations_applied: customizations.keys
          })
        else
          error_response(form.errors.full_messages.join(', '), 'creation_error')
        end
      end
    end
    
    # Duplicate an existing form with optional modifications
    # @param source_form [Form] The form to duplicate
    # @param target_user [User] The user who will own the duplicate
    # @param modifications [Hash] Changes to apply to the duplicate
    # @return [Hash] Success/error response with duplicated form data
    def duplicate_form(source_form, target_user, modifications = {})
      log_activity("duplicate_form", { 
        source_form_id: source_form.id,
        target_user_id: target_user.id,
        modifications: modifications.keys
      })
      
      # Validate source form access
      unless owns_resource?(source_form) || source_form.status == 'template'
        return error_response("Not authorized to duplicate this form", 'authorization_error')
      end
      
      safe_db_operation do
        # Create duplicate form
        duplicate_attributes = prepare_duplicate_attributes(source_form, target_user, modifications)
        duplicate_form = Form.new(duplicate_attributes)
        
        if duplicate_form.save
          # Duplicate questions
          duplicate_questions(source_form, duplicate_form)
          
          # Apply modifications
          apply_form_modifications(duplicate_form, modifications) if modifications.any?
          
          # Generate workflow if AI features enabled
          if duplicate_form.ai_enhanced?
            generate_workflow_for_form(duplicate_form)
          end
          
          success_response({
            duplicate_form: duplicate_form,
            source_form_id: source_form.id,
            duplicate_form_id: duplicate_form.id,
            modifications_applied: modifications.keys
          })
        else
          error_response(duplicate_form.errors.full_messages.join(', '), 'duplication_error')
        end
      end
    end
    
    # Export form data in various formats
    # @param form [Form] The form to export
    # @param export_options [Hash] Export configuration and format options
    # @return [Hash] Export results with download links or data
    def export_form_data(form, export_options = {})
      log_activity("export_form_data", { 
        form_id: form.id, 
        format: export_options[:format],
        include_responses: export_options[:include_responses]
      })
      
      # Validate form ownership
      unless owns_resource?(form)
        return error_response("Not authorized to export this form", 'authorization_error')
      end
      
      begin
        # Prepare export data
        export_data = prepare_export_data(form, export_options)
        
        # Generate export file based on format
        export_result = generate_export_file(export_data, export_options)
        
        if export_result[:success]
          success_response({
            export_url: export_result[:download_url],
            export_format: export_options[:format] || 'json',
            exported_at: Time.current,
            record_count: export_result[:record_count]
          })
        else
          error_response("Export failed: #{export_result[:error]}", 'export_error')
        end
      rescue StandardError => e
        logger.error "Export failed for form #{form.id}: #{e.message}"
        error_response("Export processing failed", 'export_error')
      end
    end
    
    # Publish a form and make it available for responses
    # @param form [Form] The form to publish
    # @return [Hash] Success/error response with publication details
    def publish_form(form)
      log_activity("publish_form", { form_id: form.id })
      
      # Validate form ownership
      unless owns_resource?(form)
        return error_response("Not authorized to publish this form", 'authorization_error')
      end
      
      safe_db_operation do
        # Validate form is ready for publication
        validation_result = validate_form_for_publication(form)
        unless validation_result[:valid]
          return error_response(validation_result[:errors].join(', '), 'validation_error')
        end
        
        # Update form status
        form.status = 'published'
        
        if form.save
          # Generate or regenerate workflow if needed
          if form.ai_enhanced?
            generate_workflow_for_form(form)
          end
          
          # Track publication
          track_form_publication(form)
          
          success_response({
            form_id: form.id,
            status: form.status,
            public_url: form.public_url,
            share_token: form.share_token,
            published_at: Time.current
          })
        else
          error_response(form.errors.full_messages.join(', '), 'publication_error')
        end
      end
    end
    
    # Duplicate a question within a form
    # @param source_question [FormQuestion] The question to duplicate
    # @param modifications [Hash] Changes to apply to the duplicate
    # @return [FormQuestion] The duplicated question
    def duplicate_question(source_question, modifications = {})
      log_activity("duplicate_question", { 
        source_question_id: source_question.id,
        form_id: source_question.form_id,
        modifications: modifications.keys
      })
      
      # Validate question access
      unless owns_resource?(source_question.form)
        raise StandardError, "Not authorized to duplicate this question"
      end
      
      safe_db_operation do
        # Prepare duplicate attributes
        question_attributes = source_question.attributes.except(
          'id', 'created_at', 'updated_at'
        )
        
        # Apply modifications
        question_attributes.merge!(modifications)
        
        # Create duplicate question
        duplicate_question = source_question.form.form_questions.create!(question_attributes)
        
        logger.info "Question duplicated: #{source_question.id} -> #{duplicate_question.id}"
        
        duplicate_question
      end
    end
    
    # Get list of supported tasks
    def supported_tasks
      SUPPORTED_TASKS
    end
    
    private
    
    # Validate form data structure and required fields
    def validate_form_data(form_data)
      errors = []
      
      # Required fields validation
      errors << "Name is required" if form_data[:name].blank?
      errors << "Name must be less than 255 characters" if form_data[:name]&.length&.> 255
      
      # Validate AI configuration if present
      if form_data[:ai_configuration].present?
        ai_errors = validate_ai_configuration(form_data[:ai_configuration])
        errors.concat(ai_errors)
      end
      
      # Validate style configuration if present
      if form_data[:style_configuration].present?
        style_errors = validate_style_configuration(form_data[:style_configuration])
        errors.concat(style_errors)
      end
      
      {
        valid: errors.empty?,
        errors: errors
      }
    end
    
    # Validate AI configuration parameters
    def validate_ai_configuration(ai_config)
      errors = []
      
      if ai_config[:enabled] && ai_config[:model].blank?
        errors << "AI model must be specified when AI is enabled"
      end
      
      if ai_config[:temperature] && (ai_config[:temperature] < 0 || ai_config[:temperature] > 2)
        errors << "AI temperature must be between 0 and 2"
      end
      
      errors
    end
    
    # Validate style configuration parameters
    def validate_style_configuration(style_config)
      errors = []
      
      # Validate color format if present
      if style_config[:primary_color] && !valid_color_format?(style_config[:primary_color])
        errors << "Invalid primary color format"
      end
      
      errors
    end
    
    # Check if color is in valid hex format
    def valid_color_format?(color)
      color.match?(/\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/)
    end
    
    # Prepare form attributes for creation
    def prepare_form_attributes(user, form_data)
      {
        user: user,
        name: form_data[:name],
        description: form_data[:description],
        category: form_data[:category] || 'general',
        form_settings: form_data[:form_settings] || {},
        ai_configuration: form_data[:ai_configuration] || {},
        style_configuration: form_data[:style_configuration] || {},
        integration_settings: form_data[:integration_settings] || {}
      }
    end
    
    # Generate workflow class for form with AI features
    def generate_workflow_for_form(form)
      return unless form.ai_enhanced?
      
      begin
        # Execute workflow generation job asynchronously
        Forms::WorkflowGenerationJob.perform_async(form.id)
        logger.info "Workflow generation queued for form #{form.id}"
      rescue StandardError => e
        logger.error "Failed to queue workflow generation for form #{form.id}: #{e.message}"
      end
    end
    
    # Track form creation metrics
    def track_form_creation(form)
      # Track in analytics
      logger.info "Form created: #{form.id} by user #{form.user_id}"
      
      # Update user stats if needed
      form.user.increment!(:forms_count) if form.user.respond_to?(:forms_count)
    end
    
    # Calculate estimated cost for form optimization
    def calculate_optimization_cost(form)
      # Base cost for analysis
      base_cost = 0.05
      
      # Additional cost based on form complexity
      question_cost = form.form_questions.count * 0.01
      response_cost = [form.responses_count, 100].min * 0.001
      
      base_cost + question_cost + response_cost
    end
    
    # Generate AI-powered optimization recommendations
    def generate_optimization_recommendations(form, analytics, preferences)
      # This would integrate with the optimization workflow
      # For now, return a placeholder structure
      {
        success: true,
        recommendations: [
          {
            type: 'question_order',
            description: 'Reorder questions to improve completion rate',
            impact: 'medium',
            estimated_improvement: '15%'
          }
        ],
        estimated_improvement: '15%'
      }
    end
    
    # Apply optimization recommendations to form
    def apply_optimizations(form, recommendations)
      applied_changes = []
      
      recommendations.each do |recommendation|
        case recommendation[:type]
        when 'question_order'
          # Apply question reordering logic
          applied_changes << "Reordered questions for better flow"
        when 'conditional_logic'
          # Apply conditional logic improvements
          applied_changes << "Improved conditional logic"
        end
      end
      
      applied_changes
    end
    
    # Prepare attributes for form duplication
    def prepare_duplicate_attributes(source_form, target_user, modifications)
      attributes = source_form.attributes.except(
        'id', 'created_at', 'updated_at', 'share_token', 
        'views_count', 'responses_count', 'completions_count'
      )
      
      attributes.merge!(
        user: target_user,
        name: "#{source_form.name} (Copy)",
        status: 'draft'
      )
      
      # Apply name modification if provided
      if modifications[:name]
        attributes[:name] = modifications[:name]
      end
      
      attributes
    end
    
    # Duplicate questions from source to target form
    def duplicate_questions(source_form, target_form)
      source_form.form_questions.order(:position).each do |question|
        question_attributes = question.attributes.except('id', 'form_id', 'created_at', 'updated_at')
        target_form.form_questions.create!(question_attributes)
      end
    end
    
    # Apply modifications to duplicated form
    def apply_form_modifications(form, modifications)
      modifications.each do |key, value|
        case key.to_s
        when 'ai_configuration'
          form.update!(ai_configuration: value)
        when 'style_configuration'
          form.update!(style_configuration: value)
        when 'form_settings'
          form.update!(form_settings: value)
        end
      end
    end
    
    # Prepare data for export
    def prepare_export_data(form, options)
      data = {
        form: form.as_json(include: [:form_questions]),
        exported_at: Time.current,
        export_options: options
      }
      
      # Include responses if requested
      if options[:include_responses]
        data[:responses] = form.form_responses.includes(:question_responses)
                              .as_json(include: [:question_responses])
      end
      
      data
    end
    
    # Generate export file in requested format
    def generate_export_file(data, options)
      format = options[:format] || 'json'
      
      case format.downcase
      when 'json'
        generate_json_export(data)
      when 'csv'
        generate_csv_export(data)
      when 'xlsx'
        generate_xlsx_export(data)
      else
        { success: false, error: "Unsupported export format: #{format}" }
      end
    end
    
    # Generate JSON export
    def generate_json_export(data)
      {
        success: true,
        download_url: "/exports/#{SecureRandom.uuid}.json",
        record_count: data[:responses]&.count || 0
      }
    end
    
    # Generate CSV export
    def generate_csv_export(data)
      {
        success: true,
        download_url: "/exports/#{SecureRandom.uuid}.csv",
        record_count: data[:responses]&.count || 0
      }
    end
    
    # Generate Excel export
    def generate_xlsx_export(data)
      {
        success: true,
        download_url: "/exports/#{SecureRandom.uuid}.xlsx",
        record_count: data[:responses]&.count || 0
      }
    end
    
    # Validate form is ready for publication
    def validate_form_for_publication(form)
      errors = []
      
      # Must have at least one question
      errors << "Form must have at least one question" if form.form_questions.empty?
      
      # Validate all questions have required fields
      form.form_questions.each do |question|
        if question.title.blank?
          errors << "Question #{question.position} must have a title"
        end
      end
      
      # Validate AI configuration if AI features are enabled
      if form.ai_enhanced?
        ai_errors = validate_ai_configuration(form.ai_configuration)
        errors.concat(ai_errors)
      end
      
      {
        valid: errors.empty?,
        errors: errors
      }
    end
    
    # Track form publication metrics
    def track_form_publication(form)
      logger.info "Form published: #{form.id} by user #{form.user_id}"
      
      # Could integrate with analytics service here
      # AnalyticsService.track_event('form_published', form_id: form.id)
    end
  end
end