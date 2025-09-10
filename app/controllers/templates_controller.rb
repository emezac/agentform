class TemplatesController < ApplicationController
  include Pundit
  before_action :authenticate_user!
  before_action :set_template, only: [:show, :instantiate]

  # GET /templates
  def index
    @templates = policy_scope(FormTemplate).public_templates
    
    # Apply filters
    @templates = apply_filters(@templates)
    
    # Apply sorting
    @templates = apply_sorting(@templates)
    
    # Set filter state for UI
    @filter_params = filter_params
    @has_payment_filter = params[:payment_features].present?
    @category_filter = params[:category]
    @sort_by = params[:sort_by] || 'name'
  end

  # GET /templates/:id
  def show
    authorize @template
  end

  # POST /templates/:id/instantiate
  def instantiate
    authorize @template
    
    begin
      # Check if user skipped payment setup
      skip_setup = params[:skip_setup] == 'true'
      
      # Validate payment requirements if not skipping setup
      if @template.has_payment_questions? && !skip_setup
        # Check if PaymentSetupValidationService exists, otherwise skip validation for now
        if defined?(PaymentSetupValidationService)
          validation_result = PaymentSetupValidationService.call(
            user: current_user,
            required_features: @template.required_features
          )
          
          unless validation_result.success?
            # Redirect to payment setup with template context
            redirect_to payment_setup_path(template_id: @template.id, return_to: templates_path),
                        alert: "Payment setup required for this template. Please complete the setup to continue."
            return
          end
        end
      end
      
      new_form = @template.instantiate_for_user(current_user)
      
      # Set payment setup reminder if user skipped setup
      if skip_setup && @template.has_payment_questions?
        flash[:notice] = "Form created from template '#{@template.name}'. Remember to complete payment setup before publishing."
      else
        flash[:notice] = "Form created from template '#{@template.name}'."
      end
      
      redirect_to edit_form_path(new_form)
      
    rescue Pundit::NotAuthorizedError => e
      redirect_to templates_path, alert: "AI templates require a premium subscription. Please upgrade to access this template."
    rescue => e
      Rails.logger.error "Error instantiating template #{@template.id}: #{e.message}"
      redirect_to templates_path, alert: "Error creating form: #{e.message}"
    end
  end

  private

  def set_template
    @template = FormTemplate.find(params[:id])
  end

  private

  def apply_filters(templates)
    # Filter by category
    if params[:category].present? && params[:category] != 'all'
      templates = templates.by_category(params[:category])
    end
    
    # Search filter (apply before converting to array)
    if params[:search].present?
      templates = templates.where(
        'name ILIKE ? OR description ILIKE ?',
        "%#{params[:search]}%",
        "%#{params[:search]}%"
      )
    end
    
    # Convert to array for payment filtering
    templates_array = templates.to_a
    
    # Filter by payment features
    case params[:payment_features]
    when 'with_payments'
      templates_array = templates_array.select { |t| t.has_payment_questions? }
    when 'without_payments'
      templates_array = templates_array.reject { |t| t.has_payment_questions? }
    end
    
    # Filter by features
    if params[:features].present?
      features_array = params[:features].split(',')
      templates_array = templates_array.select do |template|
        features_array.any? { |feature| template.features&.include?(feature) }
      end
    end
    
    templates_array
  end
  
  def apply_sorting(templates)
    # If templates is an array (after payment filtering), sort manually
    if templates.is_a?(Array)
      case params[:sort_by]
      when 'popular'
        templates.sort_by { |t| -t.usage_count }
      when 'recent'
        templates.sort_by { |t| -t.created_at.to_i }
      when 'usage'
        templates.sort_by { |t| -t.usage_count }
      when 'time'
        templates.sort_by { |t| t.estimated_time_minutes || 0 }
      else
        templates.sort_by { |t| t.name }
      end
    else
      # If templates is still an ActiveRecord relation, use database sorting
      case params[:sort_by]
      when 'popular'
        templates.popular
      when 'recent'
        templates.recent
      when 'usage'
        templates.order(usage_count: :desc)
      when 'time'
        templates.order(:estimated_time_minutes)
      else
        templates.order(:name)
      end
    end
  end
  
  def filter_params
    params.permit(:category, :payment_features, :features, :search, :sort_by)
  end

  def template_params
    params.require(:template).permit(:name, :description, :category, :visibility)
  end
end