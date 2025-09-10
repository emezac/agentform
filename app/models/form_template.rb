# frozen_string_literal: true

class FormTemplate < ApplicationRecord
  # Associations
  belongs_to :creator, class_name: 'User', optional: true
  has_many :form_instances, class_name: 'Form', foreign_key: 'template_id'

  # Explicit attribute declarations for enums
  attribute :category, :string, default: 'general'
  attribute :visibility, :string, default: 'public'

  # Enums
  enum :category, { 
    general: 'general',
    lead_qualification: 'lead_qualification',
    customer_feedback: 'customer_feedback',
    job_application: 'job_application',
    event_registration: 'event_registration',
    survey: 'survey',
    contact_form: 'contact_form'
  }, prefix: true
  enum :visibility, { 
    template_private: 'private', 
    template_public: 'public', 
    featured: 'featured' 
  }, prefix: true

  # Validations
  validates :name, presence: true
  validates :template_data, presence: true

  # Scopes will be added after database migration
  # scope :public_templates, -> { where(visibility: 'template_public') }
  # scope :featured, -> { where(visibility: 'featured') }

  # Scopes
  scope :public_templates, -> { where(visibility: :template_public) }
  scope :featured, -> { where(visibility: :featured) }
  scope :by_category, ->(category) { where(category: category) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_save :calculate_estimated_time, :extract_features

  # Core Methods
  def questions_config
    template_data&.dig('questions') || []
  end

  def form_settings_template
    template_data&.dig('settings') || {}
  end

  def ai_configuration_template
    template_data&.dig('ai_configuration') || {}
  end

  def instantiate_for_user(user, customizations = {})
    # Validate premium access for AI templates
    if ai_enhanced? && !user.can_use_ai_features?
      raise Pundit::NotAuthorizedError, "AI templates require a premium subscription."
    end

    form_attributes = {
      name: customizations[:name] || name,
      description: customizations[:description] || description,
      category: customizations[:category] || category,
      user: user,
      template_id: id,
      ai_enabled: ai_enhanced?,
      form_settings: merge_settings(form_settings_template, customizations[:settings] || {}),
      ai_configuration: merge_ai_config(ai_configuration_template, customizations[:ai_configuration] || {})
    }

    form = Form.create!(form_attributes)

    # Create questions from template
    questions_config.each_with_index do |question_config, index|
      question_attributes = {
        form: form,
        title: question_config['title'],
        description: question_config['description'],
        question_type: question_config['question_type'],
        required: question_config['required'] || false,
        position: index + 1,
        question_config: question_config['configuration'] || {},
        ai_enhanced: question_config['ai_enhanced'] || false,
        ai_config: question_config['ai_config'] || {},
        conditional_enabled: question_config['conditional_enabled'] || false,
        conditional_logic: question_config['conditional_logic'] || {}
      }

      # Apply customizations to specific questions if provided
      if customizations[:questions] && customizations[:questions][index]
        question_customizations = customizations[:questions][index]
        question_attributes.merge!(question_customizations)
      end

      FormQuestion.create!(question_attributes)
    end

    # Increment usage count
    increment!(:usage_count)

    form
  end

  def preview_data
    {
      id: id,
      name: name,
      description: description,
      category: category,
      visibility: visibility,
      estimated_time: estimated_time_minutes,
      features: features_list,
      questions_count: questions_config.length,
      ai_enhanced: ai_enhanced?,
      usage_count: usage_count,
      creator: creator&.full_name,
      created_at: created_at,
      sample_questions: sample_questions_preview
    }
  end

  def ai_enhanced?
    ai_configuration_template.present? && ai_configuration_template.any?
  end

  def features_list
    return [] if features.blank?
    
    case features
    when String
      begin
        JSON.parse(features)
      rescue JSON::ParserError
        []
      end
    when Array
      features
    else
      []
    end
  end

  def sample_questions_preview(limit = 3)
    questions_config.first(limit).map do |question|
      {
        title: question['title'],
        type: question['question_type'],
        required: question['required'] || false,
        ai_enhanced: question['ai_enhanced'] || false
      }
    end
  end

  def complexity_score
    # Calculate template complexity based on various factors
    base_score = questions_config.length * 2

    # Add complexity for different question types
    complex_types = %w[matrix ranking drag_drop payment signature]
    complex_questions = questions_config.count { |q| complex_types.include?(q['question_type']) }
    base_score += complex_questions * 5

    # Add complexity for AI features
    ai_questions = questions_config.count { |q| q['ai_enhanced'] }
    base_score += ai_questions * 3

    # Add complexity for conditional logic
    conditional_questions = questions_config.count { |q| q['conditional_enabled'] }
    base_score += conditional_questions * 4

    # Add complexity for integrations
    integrations_count = form_settings_template.dig('integrations')&.length || 0
    base_score += integrations_count * 3

    base_score
  end

  def duplicate_for_user(user, new_name = nil)
    new_template = self.dup
    new_template.name = new_name || "#{name} (Copy)"
    new_template.creator = user
    new_template.visibility = :private
    new_template.usage_count = 0
    new_template.save!

    new_template
  end

  def export_data
    {
      template: {
        name: name,
        description: description,
        category: category,
        estimated_time: estimated_time_minutes,
        features: features_list,
        template_data: template_data
      },
      metadata: {
        version: '1.0',
        exported_at: Time.current.iso8601,
        creator: creator&.email,
        usage_count: usage_count
      }
    }
  end

  def self.import_from_data(import_data, user)
    template_data = import_data['template']
    
    create!(
      name: template_data['name'],
      description: template_data['description'],
      category: template_data['category'],
      template_data: template_data['template_data'],
      creator: user,
      visibility: :private,
      estimated_time_minutes: template_data['estimated_time'],
      features: template_data['features'].is_a?(Array) ? template_data['features'].to_json : template_data['features']
    )
  end

  def self.popular_templates(limit = 10)
    public_templates.popular.limit(limit)
  end

  def self.featured_templates
    featured.order(:created_at)
  end

  def self.search(query)
    return all if query.blank?
    
    where(
      'name ILIKE ? OR description ILIKE ? OR features @> ?',
      "%#{query}%",
      "%#{query}%",
      [query].to_json
    )
  end

  # Payment validation methods
  def payment_requirements
    @payment_requirements ||= TemplateAnalysisService.call(template: self).result
  end

  def has_payment_questions?
    payment_requirements[:has_payment_questions] || false
  end

  def required_features
    payment_requirements[:required_features] || []
  end

  def setup_complexity
    payment_requirements[:setup_complexity] || 'none'
  end

  private

  def calculate_estimated_time
    return if questions_config.blank?

    # Base time per question type (in seconds)
    time_estimates = {
      'text_short' => 15,
      'text_long' => 45,
      'email' => 10,
      'phone' => 15,
      'number' => 10,
      'multiple_choice' => 8,
      'single_choice' => 6,
      'checkbox' => 12,
      'rating' => 5,
      'scale' => 8,
      'yes_no' => 3,
      'date' => 10,
      'datetime' => 15,
      'file_upload' => 30,
      'image_upload' => 25,
      'signature' => 20,
      'payment' => 60,
      'matrix' => 45,
      'ranking' => 30,
      'drag_drop' => 25,
      'nps_score' => 8
    }

    total_seconds = questions_config.sum do |question|
      base_time = time_estimates[question['question_type']] || 20
      
      # Add time for AI processing
      base_time += 5 if question['ai_enhanced']
      
      # Add time for conditional logic complexity
      base_time += 3 if question['conditional_enabled']
      
      base_time
    end

    # Add buffer time (20% extra)
    total_seconds = (total_seconds * 1.2).round

    # Convert to minutes and round up
    self.estimated_time_minutes = (total_seconds / 60.0).ceil
  end

  def extract_features
    features_set = Set.new

    questions_config.each do |question|
      # Add question type features
      features_set << question['question_type']
      
      # Add AI features
      if question['ai_enhanced']
        features_set << 'ai_enhanced'
        
        ai_config = question['ai_config'] || {}
        ai_config.keys.each { |feature| features_set << "ai_#{feature}" }
      end
      
      # Add conditional logic
      features_set << 'conditional_logic' if question['conditional_enabled']
      
      # Add validation features
      if question['configuration']&.dig('validation')
        features_set << 'validation'
      end
    end

    # Add form-level features
    settings = form_settings_template
    features_set << 'multi_step' if settings['multi_step']
    features_set << 'progress_bar' if settings['show_progress']
    features_set << 'save_progress' if settings['allow_save_progress']
    
    # Add integration features
    if settings['integrations']
      settings['integrations'].each do |integration|
        features_set << "integration_#{integration['type']}"
      end
    end

    self.features = features_set.to_a.to_json
  end

  def merge_settings(template_settings, custom_settings)
    template_settings.deep_merge(custom_settings)
  end

  def merge_ai_config(template_ai_config, custom_ai_config)
    template_ai_config.deep_merge(custom_ai_config)
  end
end