# frozen_string_literal: true

class Form < ApplicationRecord
  include Cacheable

  # Associations
  belongs_to :user
  has_many :form_questions, -> { order(:position) }, dependent: :destroy
  has_many :form_responses, dependent: :destroy
  has_many :form_analytics, dependent: :destroy
  has_many :dynamic_questions, through: :form_responses
  belongs_to :template, class_name: 'FormTemplate', optional: true
  has_one :google_sheets_integration, dependent: :destroy

  # Enums
  enum :status, { draft: 'draft', published: 'published', archived: 'archived', template: 'template' }
  enum :category, { 
    general: 'general',
    lead_qualification: 'lead_qualification',
    customer_feedback: 'customer_feedback',
    job_application: 'job_application',
    event_registration: 'event_registration',
    survey: 'survey',
    contact_form: 'contact_form'
  }

  # Aliases for database fields
  alias_attribute :workflow_class_name, :workflow_class

  # Validations
  validates :name, presence: true
  validates :share_token, uniqueness: true, allow_blank: true
  validates :category, inclusion: { in: categories.keys }
  validates :status, inclusion: { in: statuses.keys }

  # Callbacks
  before_create :generate_share_token
  before_save :set_workflow_class_name, :update_form_cache

  # Core Methods
  def workflow_class
    return nil unless workflow_class_name.present?
    
    workflow_class_name.constantize
  rescue NameError
    nil
  end

  def create_workflow_class!
    # Generate dynamic workflow class based on form configuration
    # This will be implemented when SuperAgent workflows are created
    # For now, return a placeholder
    "Forms::Form#{id.to_s.gsub('-', '').first(8).capitalize}Workflow"
  end

  def regenerate_workflow!
    self.workflow_class_name = create_workflow_class!
    save!
  end

  def ai_enhanced?
    ai_enabled? && ai_configuration.present?
  end

  def ai_features_enabled
    return [] unless ai_enhanced?
    
    ai_configuration.fetch('features', [])
  end

  def generated_by_ai?
    metadata.present? && metadata['generated_by_ai'] == true
  end

  def generation_timestamp
    metadata&.dig('generation_timestamp')
  end

  def ai_generation_cost
    metadata&.dig('ai_cost')
  end

  def estimated_ai_cost_per_response
    return 0.0 unless ai_enhanced?
    
    # Base cost calculation - will be refined based on actual usage
    base_cost = 0.01 # $0.01 per response
    feature_multiplier = ai_features_enabled.length * 0.005
    
    base_cost + feature_multiplier
  end

  def completion_rate
    return 0.0 if responses_count.zero?
    
    (completion_count.to_f / responses_count * 100).round(2)
  end

  def questions_ordered
    form_questions.order(:position)
  end

  def next_question_position
    (form_questions.maximum(:position) || 0) + 1
  end

  def public_url
    begin
      Rails.application.routes.url_helpers.public_form_url(share_token)
    rescue ActionController::UrlGenerationError
      # Fallback to path if host is not configured
      Rails.application.routes.url_helpers.public_form_path(share_token)
    end
  end

  def embed_code(options = {})
    width = options[:width] || '100%'
    height = options[:height] || '600px'
    
    <<~HTML
      <iframe 
        src="#{public_url}" 
        width="#{width}" 
        height="#{height}" 
        frameborder="0" 
        style="border: none;">
      </iframe>
    HTML
  end

  def analytics_summary(period: 30.days)
    start_date = period.ago.to_date
    
    {
      period: period,
      views: views_count,
      responses: form_responses.where(created_at: start_date..).count,
      completions: form_responses.where(completed_at: start_date..).count,
      completion_rate: cached_completion_rate,
      avg_time: form_responses.where(completed_at: start_date..).average(:time_spent_seconds)&.to_i || 0
    }
  end

  def cached_analytics_summary(period: 30.days)
    Rails.cache.fetch("form/#{id}/analytics/#{period.to_i}", expires_in: 1.hour) do
      analytics_summary(period: period)
    end
  end

  def cached_completion_rate
    Rails.cache.fetch("form/#{id}/completion_rate", expires_in: 30.minutes) do
      completion_rate
    end
  end

  def questions_count
    form_questions.count
  end

  def cached_questions_count
    Rails.cache.fetch("form/#{id}/questions_count", expires_in: 1.hour) do
      questions_count
    end
  end

  def ai_enabled?
    # Check the ai_enabled column first, then fall back to configuration
    return read_attribute(:ai_enabled) if has_attribute?(:ai_enabled) && !read_attribute(:ai_enabled).nil?
    
    ai_configuration.present? && ai_configuration['enabled'] == true
  end

  def ai_model
    ai_configuration&.dig('model') || 'gpt-4o-mini'
  end

  def lead_scoring_enabled?
    ai_enabled? && ai_configuration&.dig('lead_scoring') == "1"
  end

  def lead_qualification_framework
    ai_configuration&.dig('qualification_framework') || 'bant'
  end

  def hot_lead_threshold
    ai_configuration&.dig('hot_lead_threshold')&.to_i || 80
  end

  def warm_lead_threshold
    ai_configuration&.dig('warm_lead_threshold')&.to_i || 60
  end

  def cold_lead_threshold
    ai_configuration&.dig('cold_lead_threshold')&.to_i || 40
  end

  def integrations_enabled?
    integration_settings&.dig('enabled') == true
  end

  def ai_feature_enabled?(feature_name)
    ai_enhanced? && ai_configuration.dig('enabled_features')&.include?(feature_name)
  end

  def ai_config_cached
    Rails.cache.fetch("form_ai_config/#{id}/#{updated_at.to_i}", expires_in: 1.hour) do
      ai_configuration
    end
  end

  def ai_usage_stats(period = 30.days)
    form_responses.joins(:dynamic_questions)
                  .where(dynamic_questions: { created_at: period.ago.. })
                  .group('date(dynamic_questions.created_at)')
                  .count
  end

  def ai_enhanced?
    ai_enabled? && ai_configuration.present?
  end

  def has_payment_questions?
    form_questions.where(question_type: 'payment').exists?
  end

  def payment_questions
    form_questions.where(question_type: 'payment')
  end

  def requires_premium_features?
    has_payment_questions?
  end

  # Payment setup validation methods
  def payment_setup_complete?
    return true unless has_payment_questions?
    
    user.stripe_configured? && user.premium?
  end

  def payment_setup_requirements
    return [] unless has_payment_questions?
    
    requirements = []
    requirements << 'stripe_configuration' unless user.stripe_configured?
    requirements << 'premium_subscription' unless user.premium?
    requirements
  end

  def can_publish_with_payments?
    !has_payment_questions? || payment_setup_complete?
  end

  validate :validate_ai_configuration, if: :ai_enhanced?
  validate :validate_premium_features

  private

  def generate_share_token
    return if share_token.present?
    
    loop do
      self.share_token = SecureRandom.urlsafe_base64(12)
      break unless self.class.exists?(share_token: share_token)
    end
  end

  def set_workflow_class_name
    return unless ai_enabled? && workflow_class_name.blank?
    
    self.workflow_class_name = create_workflow_class!
  end

  def update_form_cache
    # Bust related caches when form is updated
    Rails.cache.delete_matched("form/#{id}/*") if persisted?
  end

  def validate_ai_configuration
    return unless ai_enhanced?
    return unless ai_configuration.present?

    # Ensure the validator class is loaded
    begin
      require_relative '../../lib/ai_configuration_validator'
    rescue LoadError
      # Fallback for development/testing
      return true
    end
    
    validator = AIConfigurationValidator.new(ai_configuration)
    unless validator.validate
      errors.add(:ai_configuration, "Invalid configuration: #{validator.errors.join(', ')}")
    end
  end

  def validate_premium_features
    return unless requires_premium_features?
    
    unless user&.premium?
      errors.add(:base, 'Payment questions require a Premium subscription')
    end
    
    # Additional validation for published forms with payment questions
    if status == 'published' && has_payment_questions? && !user&.can_accept_payments?
      errors.add(:base, 'To publish forms with payment questions, you must configure Stripe in your settings')
    end
  end
end