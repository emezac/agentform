# AgentForm Complete Implementation Blueprint

## Project Architecture Overview

**Tech Stack:**
- Rails 7.1+ with PostgreSQL
- SuperAgent workflow framework
- Tailwind CSS for styling
- Turbo Streams for real-time updates
- Sidekiq for background processing
- Redis for caching and sessions

**Core Architecture Pattern:**
```
Controllers → Agents → Workflows → Tasks (LLM/DB/Stream) → Services
```

## Phase 1: Foundation Setup (Days 1-7)

### Day 1: Project Initialization

#### 1.1 Rails Application Setup
```bash
rails new agent_form --database=postgresql --css=tailwind --javascript=importmap
cd agent_form

# Core gems
bundle add super_agent redis sidekiq pundit
bundle add turbo-rails stimulus-rails
bundle add ruby-openai anthropic open_router
bundle add image_processing aws-sdk-s3
bundle add --group development,test rspec-rails factory_bot_rails faker
bundle add --group development debug pry-rails
bundle add --group production puma
```

#### 1.2 Environment Configuration
```ruby
# config/application.rb
module AgentForm
  class Application < Rails::Application
    config.load_defaults 7.1
    config.generators.system_tests = nil
    config.active_job.queue_adapter = :sidekiq
    config.time_zone = 'UTC'
    
    # SuperAgent configuration
    config.autoload_paths += %W(#{config.root}/app/workflows)
    config.autoload_paths += %W(#{config.root}/app/agents)
    config.autoload_paths += %W(#{config.root}/app/services)
  end
end

# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']
  config.default_llm_model = "gpt-4o-mini"
  config.logger = Rails.logger
  config.enable_instrumentation = true
  config.workflow_timeout = 300
  config.max_retries = 3
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
  config.a2a_auth_token = ENV['SUPER_AGENT_A2A_TOKEN']
end
```

### Day 2: Database Schema Design

#### 2.1 Core Models Migration
```ruby
# db/migrate/001_enable_uuid_extension.rb
class EnableUuidExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
  end
end

# db/migrate/002_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :encrypted_password, null: false
      t.string :first_name
      t.string :last_name
      t.string :role, default: 'user'
      t.json :preferences, default: {}
      t.json :ai_settings, default: {}
      t.datetime :last_seen_at
      
      t.timestamps
    end
  end
end

# db/migrate/003_create_forms.rb
class CreateForms < ActiveRecord::Migration[7.1]
  def change
    create_table :forms, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'draft'
      t.string :category
      t.string :share_token, null: false, index: { unique: true }
      t.references :user, null: false, foreign_key: true, type: :uuid
      
      # Configuration fields
      t.json :form_settings, default: {}
      t.json :ai_configuration, default: {}
      t.json :style_configuration, default: {}
      t.json :integration_settings, default: {}
      t.json :notification_settings, default: {}
      
      # Workflow fields
      t.string :workflow_class_name
      t.json :workflow_state, default: {}
      
      # Analytics
      t.integer :views_count, default: 0
      t.integer :responses_count, default: 0
      t.integer :completions_count, default: 0
      t.datetime :last_response_at
      
      t.timestamps
    end
    
    add_index :forms, :status
    add_index :forms, :category
    add_index :forms, :workflow_class_name
    add_index :forms, :created_at
  end
end

# db/migrate/004_create_form_questions.rb
class CreateFormQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :form_questions, id: :uuid do |t|
      t.references :form, null: false, foreign_key: true, type: :uuid
      t.string :question_type, null: false
      t.string :title, null: false
      t.text :description
      t.text :help_text
      t.integer :position, null: false
      t.boolean :required, default: false
      
      # Configuration
      t.json :field_configuration, default: {}
      t.json :validation_rules, default: {}
      t.json :conditional_logic, default: {}
      t.json :ai_enhancement, default: {}
      t.json :style_overrides, default: {}
      
      # Analytics
      t.integer :responses_count, default: 0
      t.decimal :avg_response_time, precision: 8, scale: 2
      t.json :drop_off_data, default: {}
      
      t.timestamps
    end
    
    add_index :form_questions, [:form_id, :position], unique: true
    add_index :form_questions, :question_type
  end
end

# db/migrate/005_create_form_responses.rb
class CreateFormResponses < ActiveRecord::Migration[7.1]
  def change
    create_table :form_responses, id: :uuid do |t|
      t.references :form, null: false, foreign_key: true, type: :uuid
      t.string :session_id, null: false, index: true
      t.string :status, default: 'in_progress'
      
      # Context and tracking
      t.json :context_data, default: {}
      t.json :ai_analysis, default: {}
      t.json :metadata, default: {}
      
      # Workflow tracking
      t.string :workflow_execution_id
      t.json :workflow_state, default: {}
      
      # User tracking
      t.text :user_agent
      t.string :ip_address
      t.string :referrer
      t.json :utm_parameters, default: {}
      
      # Timing
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :last_activity_at
      
      # Scoring
      t.decimal :completion_score, precision: 5, scale: 2
      t.decimal :quality_score, precision: 5, scale: 2
      t.decimal :sentiment_score, precision: 5, scale: 2
      
      t.timestamps
    end
    
    add_index :form_responses, :workflow_execution_id
    add_index :form_responses, :status
    add_index :form_responses, :started_at
    add_index :form_responses, [:form_id, :status]
  end
end

# db/migrate/006_create_question_responses.rb
class CreateQuestionResponses < ActiveRecord::Migration[7.1]
  def change
    create_table :question_responses, id: :uuid do |t|
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      t.references :form_question, null: false, foreign_key: true, type: :uuid
      
      # Response data
      t.json :answer_data, null: false
      t.json :raw_input, default: {}
      t.json :processed_data, default: {}
      
      # AI analysis
      t.json :ai_analysis, default: {}
      t.json :enrichment_data, default: {}
      t.json :validation_results, default: {}
      
      # Timing and behavior
      t.integer :response_time_ms
      t.integer :revision_count, default: 0
      t.json :interaction_events, default: []
      
      # Quality metrics
      t.decimal :confidence_score, precision: 5, scale: 2
      t.decimal :completeness_score, precision: 5, scale: 2
      
      t.timestamps
    end
    
    add_index :question_responses, [:form_response_id, :form_question_id], 
              unique: true, name: 'index_question_responses_unique'
  end
end

# db/migrate/007_create_form_analytics.rb
class CreateFormAnalytics < ActiveRecord::Migration[7.1]
  def change
    create_table :form_analytics, id: :uuid do |t|
      t.references :form, null: false, foreign_key: true, type: :uuid
      t.date :date, null: false
      t.string :metric_type, null: false
      
      # Basic metrics
      t.integer :views_count, default: 0
      t.integer :starts_count, default: 0
      t.integer :completions_count, default: 0
      t.integer :abandons_count, default: 0
      
      # Time metrics
      t.decimal :avg_completion_time, precision: 8, scale: 2
      t.decimal :avg_response_time, precision: 8, scale: 2
      t.json :time_distribution, default: {}
      
      # Quality metrics
      t.decimal :avg_quality_score, precision: 5, scale: 2
      t.decimal :avg_sentiment_score, precision: 5, scale: 2
      t.json :quality_distribution, default: {}
      
      # AI insights
      t.json :ai_insights, default: {}
      t.json :optimization_suggestions, default: {}
      t.json :behavioral_patterns, default: {}
      
      t.timestamps
    end
    
    add_index :form_analytics, [:form_id, :date, :metric_type], unique: true
  end
end

# db/migrate/008_create_dynamic_questions.rb
class CreateDynamicQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :dynamic_questions, id: :uuid do |t|
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      t.references :generated_from_question, null: true, foreign_key: { to_table: :form_questions }, type: :uuid
      
      t.string :question_type, null: false
      t.text :title, null: false
      t.text :description
      t.json :configuration, default: {}
      
      # Generation context
      t.json :generation_context, default: {}
      t.text :generation_prompt
      t.string :generation_model
      
      # Response tracking
      t.json :answer_data
      t.decimal :response_time_ms
      t.decimal :ai_confidence, precision: 5, scale: 2
      
      t.timestamps
    end
    
    add_index :dynamic_questions, :form_response_id
    add_index :dynamic_questions, :question_type
  end
end
```

### Day 3: Core Model Implementation

#### 3.1 User Model
```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  
  has_many :forms, dependent: :destroy
  has_many :form_responses, through: :forms
  
  enum :role, { user: 'user', admin: 'admin', premium: 'premium' }
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  
  before_create :set_default_preferences
  before_save :update_last_seen
  
  scope :active, -> { where('last_seen_at > ?', 30.days.ago) }
  scope :premium_users, -> { where(role: 'premium') }
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def ai_credits_remaining
    preferences.dig('ai', 'credits_remaining') || default_ai_credits
  end
  
  def can_use_ai_features?
    premium? || ai_credits_remaining > 0
  end
  
  def consume_ai_credit(cost = 1)
    current_credits = ai_credits_remaining
    new_credits = [current_credits - cost, 0].max
    
    preferences['ai'] ||= {}
    preferences['ai']['credits_remaining'] = new_credits
    save!
    
    new_credits
  end
  
  def form_usage_stats
    {
      total_forms: forms.count,
      published_forms: forms.published.count,
      total_responses: form_responses.count,
      avg_completion_rate: forms.average(:completions_count) || 0
    }
  end
  
  private
  
  def set_default_preferences
    self.preferences = {
      'theme' => 'light',
      'notifications' => {
        'email' => true,
        'browser' => false
      },
      'ai' => {
        'credits_remaining' => default_ai_credits,
        'model_preference' => 'gpt-4o-mini'
      }
    }
  end
  
  def default_ai_credits
    premium? ? 10000 : 100
  end
  
  def update_last_seen
    self.last_seen_at = Time.current if persisted?
  end
end
```

#### 3.2 Form Model (Enhanced)
```ruby
# app/models/form.rb
class Form < ApplicationRecord
  belongs_to :user
  has_many :form_questions, -> { order(:position) }, dependent: :destroy
  has_many :form_responses, dependent: :destroy
  has_many :form_analytics, dependent: :destroy
  has_many :dynamic_questions, through: :form_responses
  
  enum :status, { 
    draft: 'draft', 
    published: 'published', 
    archived: 'archived',
    template: 'template' 
  }
  
  enum :category, {
    general: 'general',
    lead_qualification: 'lead_qualification',
    customer_feedback: 'customer_feedback',
    job_application: 'job_application',
    event_registration: 'event_registration',
    survey: 'survey',
    contact_form: 'contact_form'
  }
  
  before_create :generate_share_token
  before_save :set_workflow_class_name, :update_form_cache
  after_update :invalidate_cache, if: :saved_change_to_form_settings?
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :share_token, presence: true, uniqueness: true
  validates :category, inclusion: { in: categories.keys }
  
  scope :published, -> { where(status: 'published') }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_category, ->(category) { where(category: category) }
  scope :popular, -> { order(responses_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Core workflow methods
  def workflow_class
    return nil unless workflow_class_name.present?
    workflow_class_name.safe_constantize
  end
  
  def create_workflow_class!
    Forms::WorkflowGeneratorService.new(self).generate_class
  end
  
  def regenerate_workflow!
    Forms::WorkflowGeneratorService.new(self).regenerate_class
    update!(workflow_state: {})
  end
  
  # AI enhancement
  def ai_enhanced?
    ai_configuration.dig('enabled') == true
  end
  
  def ai_features_enabled
    ai_configuration.dig('features') || []
  end
  
  def ai_model
    ai_configuration.dig('model') || user.preferences.dig('ai', 'model_preference') || 'gpt-4o-mini'
  end
  
  def estimated_ai_cost_per_response
    base_cost = questions_ordered.count * 0.001 # Base per question
    ai_multiplier = ai_features_enabled.size * 0.005 # Per AI feature
    base_cost + ai_multiplier
  end
  
  # Analytics and metrics
  def completion_rate
    return 0 if responses_count.zero?
    (completions_count.to_f / responses_count * 100).round(2)
  end
  
  def abandonment_rate
    100 - completion_rate
  end
  
  def average_completion_time_minutes
    completed_responses = form_responses.completed.where.not(completed_at: nil)
    return 0 if completed_responses.empty?
    
    total_seconds = completed_responses.sum do |response|
      (response.completed_at - response.started_at).to_i
    end
    
    (total_seconds / completed_responses.count / 60.0).round(2)
  end
  
  def questions_ordered
    form_questions.includes(:question_responses).order(:position)
  end
  
  def next_question_position
    (form_questions.maximum(:position) || 0) + 1
  end
  
  # Form configuration helpers
  def progress_bar_enabled?
    form_settings.dig('ui', 'progress_bar') != false
  end
  
  def one_question_per_page?
    form_settings.dig('ui', 'one_question_per_page') != false
  end
  
  def auto_save_enabled?
    form_settings.dig('behavior', 'auto_save') != false
  end
  
  def allow_back_navigation?
    form_settings.dig('behavior', 'allow_back') != false
  end
  
  # Form sharing and embedding
  def public_url
    Rails.application.routes.url_helpers.response_url(share_token)
  end
  
  def embed_code(options = {})
    Forms::EmbedCodeGeneratorService.new(self, options).generate
  end
  
  def can_be_embedded?
    published? && form_settings.dig('sharing', 'allow_embedding') != false
  end
  
  # Analytics aggregation
  def analytics_summary(period: 30.days)
    Forms::AnalyticsAggregatorService.new(self, period: period).summary
  end
  
  def performance_insights
    Forms::PerformanceAnalysisService.new(self).generate_insights
  end
  
  private
  
  def generate_share_token
    self.share_token = SecureRandom.urlsafe_base64(16)
  end
  
  def set_workflow_class_name
    return unless name.present?
    self.workflow_class_name = "Forms::#{name.classify}Workflow"
  end
  
  def update_form_cache
    # Update cache key for form configuration changes
    Rails.cache.delete("form_config_#{id}")
  end
  
  def invalidate_cache
    Rails.cache.delete_matched("form_#{id}_*")
  end
end
```

#### 3.3 FormQuestion Model (Enhanced)
```ruby
# app/models/form_question.rb
class FormQuestion < ApplicationRecord
  belongs_to :form
  has_many :question_responses, dependent: :destroy
  has_many :dynamic_questions, foreign_key: 'generated_from_question_id', dependent: :destroy
  
  QUESTION_TYPES = %w[
    text_short text_long email phone url number
    multiple_choice single_choice checkbox
    rating scale slider
    yes_no boolean
    date datetime time
    file_upload image_upload
    address location
    payment signature
    nps_score matrix
    ranking drag_drop
  ].freeze
  
  enum :question_type, QUESTION_TYPES.index_with(&:itself)
  
  validates :title, presence: true, length: { maximum: 500 }
  validates :question_type, inclusion: { in: QUESTION_TYPES }
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :form, presence: true
  
  validate :validate_field_configuration
  validate :validate_conditional_logic
  
  scope :required, -> { where(required: true) }
  scope :by_position, -> { order(:position) }
  scope :with_ai_enhancement, -> { where("ai_enhancement ->> 'enabled' = 'true'") }
  
  before_save :clean_field_configuration
  after_create :increment_form_cache
  after_destroy :reorder_positions
  
  # Question type helpers
  def question_type_handler
    @question_type_handler ||= "QuestionTypes::#{question_type.classify}".constantize.new(self)
  end
  
  def render_component
    question_type_handler.render_component
  end
  
  def validate_answer(answer)
    question_type_handler.validate_answer(answer)
  end
  
  def process_answer(raw_answer)
    question_type_handler.process_answer(raw_answer)
  end
  
  def default_value
    question_type_handler.default_value
  end
  
  # AI enhancement
  def ai_enhanced?
    ai_enhancement.dig('enabled') == true
  end
  
  def ai_features
    ai_enhancement.dig('features') || []
  end
  
  def generates_followups?
    ai_features.include?('dynamic_followups')
  end
  
  def has_smart_validation?
    ai_features.include?('smart_validation')
  end
  
  def has_response_analysis?
    ai_features.include?('response_analysis')
  end
  
  # Conditional logic
  def has_conditional_logic?
    conditional_logic.present? && conditional_logic['rules'].present?
  end
  
  def conditional_rules
    @conditional_rules ||= Forms::ConditionalLogicParser.new(conditional_logic).parse
  end
  
  def should_show_for_response?(form_response)
    return true unless has_conditional_logic?
    Forms::ConditionalLogicEvaluator.new(self, form_response).should_show?
  end
  
  # Configuration helpers based on question type
  def choice_options
    field_configuration['options'] || []
  end
  
  def has_other_option?
    field_configuration['allow_other'] == true
  end
  
  def rating_config
    {
      min: field_configuration['scale_min'] || 1,
      max: field_configuration['scale_max'] || 10,
      labels: field_configuration['scale_labels'] || {},
      show_numbers: field_configuration['show_numbers'] != false
    }
  end
  
  def file_upload_config
    {
      max_size: field_configuration['max_file_size'] || 10.megabytes,
      allowed_types: field_configuration['allowed_file_types'] || ['pdf', 'doc', 'docx'],
      multiple: field_configuration['allow_multiple'] == true,
      max_files: field_configuration['max_files'] || 1
    }
  end
  
  def text_config
    {
      min_length: field_configuration['min_length'],
      max_length: field_configuration['max_length'] || 1000,
      placeholder: field_configuration['placeholder'],
      multiline: question_type == 'text_long'
    }
  end
  
  # Analytics
  def average_response_time_seconds
    return 0 if question_responses.empty?
    question_responses.average(:response_time_ms) / 1000.0
  end
  
  def completion_rate
    total_attempts = form.form_responses.where('started_at <= ?', created_at + 1.hour).count
    return 0 if total_attempts.zero?
    
    completed = question_responses.count
    (completed.to_f / total_attempts * 100).round(2)
  end
  
  def generates_ai_insights?
    response_data_sufficient? && ai_enhanced?
  end
  
  private
  
  def validate_field_configuration
    return unless field_configuration.present?
    
    validator = "FormQuestions::#{question_type.classify}ConfigValidator".safe_constantize
    return unless validator
    
    result = validator.new(field_configuration).validate
    errors.add(:field_configuration, result.error_message) if result.invalid?
  end
  
  def validate_conditional_logic
    return unless conditional_logic.present?
    
    parser = Forms::ConditionalLogicParser.new(conditional_logic)
    unless parser.valid?
      errors.add(:conditional_logic, parser.error_message)
    end
  end
  
  def clean_field_configuration
    self.field_configuration = field_configuration.deep_symbolize_keys.compact
  end
  
  def increment_form_cache
    Rails.cache.increment("form_#{form_id}_questions_count")
  end
  
  def response_data_sufficient?
    question_responses.count >= 10
  end
  
  def reorder_positions
    return unless form
    
    form.form_questions.order(:position).each_with_index do |question, index|
      question.update_column(:position, index + 1)
    end
  end
end
```

#### 3.4 FormResponse Model (Enhanced)
```ruby
# app/models/form_response.rb
class FormResponse < ApplicationRecord
  belongs_to :form
  has_many :question_responses, dependent: :destroy
  has_many :dynamic_questions, dependent: :destroy
  
  enum :status, { 
    in_progress: 'in_progress', 
    completed: 'completed', 
    abandoned: 'abandoned',
    paused: 'paused'
  }
  
  validates :session_id, presence: true
  validates :form, presence: true
  
  before_create :set_started_at
  before_save :update_last_activity
  
  scope :completed, -> { where(status: 'completed') }
  scope :recent, ->(days = 7) { where('created_at > ?', days.days.ago) }
  scope :with_quality_above, ->(score) { where('quality_score >= ?', score) }
  scope :by_completion_time, -> { order(:completed_at) }
  
  # Progress and completion
  def progress_percentage
    total_questions = form.form_questions.count
    answered_questions = question_responses.count
    return 0 if total_questions.zero?
    
    (answered_questions.to_f / total_questions * 100).round
  end
  
  def duration_minutes
    return 0 unless completed_at && started_at
    ((completed_at - started_at) / 60).round(2)
  end
  
  def time_since_last_activity
    return 0 unless last_activity_at
    Time.current - last_activity_at
  end
  
  def is_stale?
    time_since_last_activity > 1.hour
  end
  
  # Response data management
  def answers_hash
    @answers_hash ||= question_responses.includes(:form_question).each_with_object({}) do |response, hash|
      question_key = response.form_question.title.parameterize(separator: '_')
      hash[question_key] = response.processed_answer_data
    end
  end
  
  def get_answer(question_title_or_id)
    if question_title_or_id.is_a?(String)
      question = form.form_questions.find_by(title: question_title_or_id)
    else
      question = form.form_questions.find(question_title_or_id)
    end
    
    return nil unless question
    
    question_response = question_responses.find_by(form_question: question)
    question_response&.processed_answer_data
  end
  
  def set_answer(question, answer_data)
    question = find_question(question) if question.is_a?(String)
    return false unless question
    
    question_response = question_responses.find_or_initialize_by(form_question: question)
    question_response.answer_data = answer_data
    question_response.save
  end
  
  # AI analysis methods
  def trigger_ai_analysis!
    return unless form.ai_enhanced?
    Forms::ResponseAnalysisWorkflow.perform_later(id)
  end
  
  def ai_sentiment
    ai_analysis.dig('sentiment', 'label') || 'neutral'
  end
  
  def ai_confidence
    ai_analysis.dig('confidence', 'overall') || 0.5
  end
  
  def ai_risk_indicators
    ai_analysis.dig('risk', 'indicators') || []
  end
  
  def needs_human_review?
    ai_risk_indicators.any? || quality_score < 0.5
  end
  
  # Response quality scoring
  def calculate_quality_score!
    calculator = Forms::QualityScoreCalculator.new(self)
    update!(quality_score: calculator.calculate)
  end
  
  def calculate_sentiment_score!
    return unless form.ai_enhanced?
    
    analyzer = Forms::SentimentAnalysisService.new(self)
    update!(sentiment_score: analyzer.calculate)
  end
  
  # Status management
  def mark_completed!(completion_data = {})
    transaction do
      update!(
        status: 'completed',
        completed_at: Time.current,
        metadata: metadata.merge(completion_data)
      )
      
      # Update form counters
      form.increment!(:completions_count)
      
      # Trigger completion workflow
      Forms::CompletionWorkflow.perform_later(id)
    end
  end
  
  def mark_abandoned!(reason = nil)
    return if completed?
    
    update!(
      status: 'abandoned',
      metadata: metadata.merge(abandon_reason: reason, abandoned_at: Time.current)
    )
    
    Forms::AbandonmentAnalysisService.perform_later(id)
  end
  
  def pause!(context = {})
    update!(
      status: 'paused',
      metadata: metadata.merge(pause_context: context, paused_at: Time.current)
    )
  end
  
  def resume!
    return unless paused?
    
    update!(
      status: 'in_progress',
      last_activity_at: Time.current
    )
  end
  
  # Workflow integration
  def workflow_context
    {
      form_id: form_id,
      response_id: id,
      session_id: session_id,
      user_context: context_data,
      answers: answers_hash,
      metadata: metadata,
      ai_analysis: ai_analysis,
      current_position: current_question_position
    }
  end
  
  def current_question_position
    question_responses.maximum('form_questions.position') || 1
  end
  
  private
  
  def set_started_at
    self.started_at = Time.current unless started_at
  end
  
  def update_last_activity
    self.last_activity_at = Time.current
  end
  
  def find_question(identifier)
    if identifier.is_a?(String)
      form.form_questions.find_by(title: identifier)
    else
      form.form_questions.find(identifier)
    end
  end
end
```

#### 3.5 QuestionResponse Model
```ruby
# app/models/question_response.rb
class QuestionResponse < ApplicationRecord
  belongs_to :form_response
  belongs_to :form_question
  
  validates :answer_data, presence: true
  validates :form_response, presence: true
  validates :form_question, presence: true
  
  before_save :process_answer_data, :calculate_response_time
  after_create :trigger_ai_analysis, :update_question_analytics
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_question_type, ->(type) { joins(:form_question).where(form_questions: { question_type: type }) }
  scope :with_high_confidence, -> { where('confidence_score >= ?', 0.8) }
  
  # Answer processing
  def processed_answer_data
    @processed_answer_data ||= form_question.process_answer(answer_data)
  end
  
  def raw_answer
    answer_data
  end
  
  def formatted_answer
    Forms::AnswerFormatterService.new(self).format
  end
  
  def answer_text
    case form_question.question_type
    when 'text_short', 'text_long', 'email', 'phone', 'url'
      answer_data.to_s
    when 'multiple_choice', 'checkbox'
      Array(answer_data).join(', ')
    when 'single_choice', 'yes_no'
      answer_data.to_s
    when 'rating', 'scale', 'nps_score'
      "#{answer_data}/#{form_question.rating_config[:max]}"
    when 'date', 'datetime'
      Time.parse(answer_data.to_s).strftime('%B %d, %Y')
    when 'file_upload'
      answer_data.is_a?(Array) ? "#{answer_data.size} files" : "1 file"
    else
      answer_data.to_s
    end
  rescue
    answer_data.to_s
  end
  
  # AI analysis
  def trigger_ai_analysis!
    return unless form_question.has_response_analysis?
    Forms::ResponseAnalysisWorkflow.perform_later(id)
  end
  
  def ai_sentiment
    ai_analysis.dig('sentiment', 'label') || 'neutral'
  end
  
  def ai_confidence_score
    ai_analysis.dig('confidence') || confidence_score
  end
  
  def ai_insights
    ai_analysis.dig('insights') || []
  end
  
  def needs_followup?
    ai_analysis.dig('flags', 'needs_followup') == true
  end
  
  # Validation and quality
  def is_valid?
    validation_errors.empty?
  end
  
  def validation_errors
    @validation_errors ||= form_question.validate_answer(answer_data)
  end
  
  def quality_indicators
    {
      completeness: calculate_completeness_score,
      relevance: ai_analysis.dig('quality', 'relevance') || 0.5,
      confidence: confidence_score || 0.5,
      response_time: response_time_category
    }
  end
  
  # Response timing
  def response_time_category
    return 'unknown' unless response_time_ms
    
    case response_time_ms
    when 0..5000 then 'fast'
    when 5001..15000 then 'normal'
    when 15001..45000 then 'slow'
    else 'very_slow'
    end
  end
  
  def unusually_fast?
    response_time_ms && response_time_ms < 1000
  end
  
  def unusually_slow?
    response_time_ms && response_time_ms > 120000 # 2 minutes
  end
  
  private
  
  def process_answer_data
    self.processed_data = form_question.process_answer(answer_data)
  end
  
  def calculate_response_time
    return unless response_time_ms
    
    # Validate response time is reasonable
    if response_time_ms < 100 || response_time_ms > 600000 # 10 minutes
      Rails.logger.warn "Unusual response time: #{response_time_ms}ms for question #{form_question.title}"
    end
  end
  
  def trigger_ai_analysis
    trigger_ai_analysis! if should_trigger_ai_analysis?
  end
  
  def should_trigger_ai_analysis?
    form_question.ai_enhanced? && 
    answer_data.present? && 
    form_response.form.user.can_use_ai_features?
  end
  
  def update_question_analytics
    form_question.increment!(:responses_count)
    
    # Update running average of response time
    if response_time_ms
      current_avg = form_question.avg_response_time || 0
      count = form_question.responses_count
      new_avg = ((current_avg * (count - 1)) + response_time_ms) / count
      form_question.update_column(:avg_response_time, new_avg)
    end
  end
  
  def calculate_completeness_score
    return 1.0 if answer_data.blank?
    
    case form_question.question_type
    when 'text_short', 'text_long'
      text_length = answer_data.to_s.length
      expected_length = form_question.text_config[:min_length] || 10
      [text_length.to_f / expected_length, 1.0].min
    when 'multiple_choice', 'checkbox'
      selected_count = Array(answer_data).size
      total_options = form_question.choice_options.size
      return 1.0 if total_options.zero?
      [selected_count.to_f / total_options, 1.0].min
    else
      answer_data.present? ? 1.0 : 0.0
    end
  end
end
```

### Day 4: Question Type System Implementation

#### 4.1 Question Type Base Classes
```ruby
# app/models/concerns/question_types/base.rb
module QuestionTypes
  class Base
    attr_reader :question, :configuration
    
    def initialize(question)
      @question = question
      @configuration = question.field_configuration
    end
    
    def render_component
      "question_types/#{component_name}"
    end
    
    def validate_answer(answer)
      errors = []
      
      # Required validation
      if question.required? && answer_blank?(answer)
        errors << I18n.t('form_questions.errors.required')
      end
      
      # Type-specific validation
      errors.concat(type_specific_validation(answer)) unless answer_blank?(answer)
      
      errors
    end
    
    def process_answer(raw_answer)
      return nil if answer_blank?(raw_answer)
      base_processing(raw_answer)
    end
    
    def default_value
      configuration['default_value']
    end
    
    def placeholder_text
      configuration['placeholder'] || default_placeholder
    end
    
    def help_text
      question.help_text
    end
    
    protected
    
    def component_name
      self.class.name.demodulize.underscore
    end
    
    def answer_blank?(answer)
      answer.nil? || answer == '' || (answer.is_a?(Array) && answer.empty?)
    end
    
    def base_processing(answer)
      answer
    end
    
    def type_specific_validation(answer)
      []
    end
    
    def default_placeholder
      "Enter your #{question.title.downcase}"
    end
  end
end

# app/models/concerns/question_types/text_short.rb
module QuestionTypes
  class TextShort < Base
    protected
    
    def base_processing(answer)
      answer.to_s.strip
    end
    
    def type_specific_validation(answer)
      errors = []
      text = answer.to_s
      
      if min_length && text.length < min_length
        errors << I18n.t('form_questions.errors.min_length', count: min_length)
      end
      
      if max_length && text.length > max_length
        errors << I18n.t('form_questions.errors.max_length', count: max_length)
      end
      
      if pattern && !text.match?(Regexp.new(pattern))
        errors << (pattern_error_message || I18n.t('form_questions.errors.invalid_format'))
      end
      
      errors
    end
    
    def default_placeholder
      if min_length && max_length
        "Enter #{min_length}-#{max_length} characters"
      elsif max_length
        "Enter up to #{max_length} characters"
      else
        "Enter text"
      end
    end
    
    private
    
    def min_length
      configuration['min_length']
    end
    
    def max_length
      configuration['max_length'] || 255
    end
    
    def pattern
      configuration['pattern']
    end
    
    def pattern_error_message
      configuration['pattern_error_message']
    end
  end
end

# app/models/concerns/question_types/email.rb
module QuestionTypes
  class Email < Base
    EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    
    protected
    
    def base_processing(answer)
      answer.to_s.downcase.strip
    end
    
    def type_specific_validation(answer)
      errors = []
      
      unless answer.match?(EMAIL_REGEX)
        errors << I18n.t('form_questions.errors.invalid_email')
      end
      
      if block_disposable? && disposable_email?(answer)
        errors << I18n.t('form_questions.errors.disposable_email')
      end
      
      errors
    end
    
    def default_placeholder
      "your.email@example.com"
    end
    
    private
    
    def block_disposable?
      configuration['block_disposable'] == true
    end
    
    def disposable_email?(email)
      Forms::DisposableEmailDetectorService.new(email).disposable?
    end
  end
end

# app/models/concerns/question_types/multiple_choice.rb
module QuestionTypes
  class MultipleChoice < Base
    def choice_options
      configuration['options'] || []
    end
    
    def allows_multiple?
      configuration['allow_multiple'] == true
    end
    
    def has_other_option?
      configuration['allow_other'] == true
    end
    
    def randomize_options?
      configuration['randomize_options'] == true
    end
    
    def display_options(seed = nil)
      options = choice_options.dup
      return options unless randomize_options?
      
      # Use deterministic randomization based on session
      rng = Random.new(seed || question.id.hash)
      options.shuffle(random: rng)
    end
    
    protected
    
    def base_processing(answer)
      if allows_multiple?
        Array(answer).compact.uniq
      else
        answer.to_s
      end
    end
    
    def type_specific_validation(answer)
      errors = []
      
      valid_values = choice_options.map { |opt| opt['value'] }
      valid_values << 'other' if has_other_option?
      
      selected_values = allows_multiple? ? Array(answer) : [answer]
      invalid_selections = selected_values - valid_values
      
      if invalid_selections.any?
        errors << I18n.t('form_questions.errors.invalid_selection', selections: invalid_selections.join(', '))
      end
      
      if allows_multiple?
        errors.concat(validate_multiple_selection_limits(selected_values))
      end
      
      errors
    end
    
    private
    
    def validate_multiple_selection_limits(selected_values)
      errors = []
      
      min_selections = configuration['min_selections']
      max_selections = configuration['max_selections']
      
      if min_selections && selected_values.size < min_selections
        errors << I18n.t('form_questions.errors.min_selections', count: min_selections)
      end
      
      if max_selections && selected_values.size > max_selections
        errors << I18n.t('form_questions.errors.max_selections', count: max_selections)
      end
      
      errors
    end
  end
end

# app/models/concerns/question_types/rating.rb
module QuestionTypes
  class Rating < Base
    def scale_min
      configuration['scale_min'] || 1
    end
    
    def scale_max
      configuration['scale_max'] || 10
    end
    
    def scale_labels
      configuration['scale_labels'] || {}
    end
    
    def show_numbers?
      configuration['show_numbers'] != false
    end
    
    def scale_steps
      configuration['scale_steps'] || 1
    end
    
    protected
    
    def base_processing(answer)
      answer.to_f
    end
    
    def type_specific_validation(answer)
      errors = []
      numeric_value = answer.to_f
      
      if numeric_value < scale_min || numeric_value > scale_max
        errors << I18n.t('form_questions.errors.rating_out_of_range', 
                        min: scale_min, max: scale_max)
      end
      
      # Validate step increments if specified
      if scale_steps != 1
        unless (numeric_value % scale_steps).zero?
          errors << I18n.t('form_questions.errors.invalid_step', step: scale_steps)
        end
      end
      
      errors
    end
  end
end

# app/models/concerns/question_types/file_upload.rb
module QuestionTypes
  class FileUpload < Base
    def max_file_size
      configuration['max_file_size'] || 10.megabytes
    end
    
    def allowed_file_types
      configuration['allowed_file_types'] || %w[pdf doc docx txt jpg png]
    end
    
    def allow_multiple?
      configuration['allow_multiple'] == true
    end
    
    def max_files
      configuration['max_files'] || (allow_multiple? ? 5 : 1)
    end
    
    protected
    
    def base_processing(answer)
      if allow_multiple?
        Array(answer).map { |file| process_single_file(file) }
      else
        process_single_file(answer)
      end
    end
    
    def type_specific_validation(answer)
      errors = []
      files = allow_multiple? ? Array(answer) : [answer]
      
      files.each_with_index do |file, index|
        file_errors = validate_single_file(file, index)
        errors.concat(file_errors)
      end
      
      if allow_multiple? && files.size > max_files
        errors << I18n.t('form_questions.errors.too_many_files', max: max_files)
      end
      
      errors
    end
    
    private
    
    def process_single_file(file)
      return nil unless file.respond_to?(:original_filename)
      
      {
        filename: file.original_filename,
        content_type: file.content_type,
        size: file.size,
        storage_key: store_file(file)
      }
    end
    
    def validate_single_file(file, index = 0)
      errors = []
      return errors unless file.respond_to?(:size)
      
      if file.size > max_file_size
        errors << I18n.t('form_questions.errors.file_too_large', 
                        filename: file.original_filename,
                        max_size: ActiveSupport::NumberHelper.number_to_human_size(max_file_size))
      end
      
      file_extension = File.extname(file.original_filename).delete('.').downcase
      unless allowed_file_types.include?(file_extension)
        errors << I18n.t('form_questions.errors.invalid_file_type',
                        filename: file.original_filename,
                        allowed_types: allowed_file_types.join(', '))
      end
      
      errors
    end
    
    def store_file(file)
      # Integration with Active Storage or S3
      Forms::FileStorageService.new(file, question.id).store
    end
  end
end
```

### Day 5-7: Controller Layer Implementation

#### 5.1 Application Controller Base
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  
  protect_from_forgery with: :exception
  
  before_action :authenticate_user!, except: [:show, :health]
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_user_context
  
  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from SuperAgent::WorkflowError, with: :handle_workflow_error
  
  protected
  
  def set_current_user_context
    Current.user = current_user if user_signed_in?
  end
  
  def handle_unauthorized
    redirect_to root_path, alert: 'You are not authorized to perform this action.'
  end
  
  def handle_not_found
    render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false
  end
  
  def handle_workflow_error(error)
    Rails.logger.error "Workflow error: #{error.message}"
    render json: { error: 'An error occurred processing your request' }, status: :internal_server_error
  end
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, preferences: {}])
  end
end
```

#### 5.2 Forms Controller (Complete)
```ruby
# app/controllers/forms_controller.rb
class FormsController < ApplicationController
  before_action :set_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :duplicate, :analytics, :export]
  before_action :authorize_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :analytics]
  
  def index
    @forms = policy_scope(Form)
              .includes(:form_analytics, :form_questions)
              .where(search_params)
              .order(sort_params)
              .page(params[:page])
              .per(20)
    
    @stats = Forms::UserStatsService.new(current_user).summary
  end
  
  def show
    @questions = @form.questions_ordered.includes(:question_responses)
    @recent_responses = @form.form_responses.recent.limit(10)
    @analytics_summary = @form.analytics_summary(period: 30.days)
    
    respond_to do |format|
      format.html
      format.json { render json: Forms::FormSerializer.new(@form).as_json }
    end
  end
  
  def new
    @form = current_user.forms.build
    @form.form_settings = default_form_settings
    @form.ai_configuration = default_ai_configuration
    authorize @form
  end
  
  def create
    @form = current_user.forms.build(form_params)
    authorize @form
    
    if @form.save
      # Generate initial workflow in background
      Forms::WorkflowGenerationJob.perform_later(@form.id)
      
      redirect_to edit_form_path(@form), 
                  notice: 'Form created successfully! Add questions to get started.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @questions = @form.questions_ordered
    @question_types = FormQuestion::QUESTION_TYPES
    @ai_features = Forms::AiFeatureRegistry.available_features
    @form_templates = Forms::TemplateRegistry.templates_for_category(@form.category)
  end
  
  def update
    if @form.update(form_params)
      handle_form_update
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @form.destroy
    redirect_to forms_path, notice: 'Form deleted successfully.'
  end
  
  def publish
    result = Forms::PublishingService.new(@form).publish
    
    if result.success?
      redirect_to @form, notice: 'Form published successfully!'
    else
      redirect_to @form, alert: "Could not publish form: #{result.error_message}"
    end
  end
  
  def unpublish
    @form.update!(status: 'draft')
    redirect_to @form, notice: 'Form unpublished and returned to draft.'
  end
  
  def duplicate
    service = Forms::DuplicationService.new(@form, current_user)
    @new_form = service.duplicate
    
    if @new_form.persisted?
      redirect_to edit_form_path(@new_form), notice: 'Form duplicated successfully!'
    else
      redirect_to @form, alert: 'Could not duplicate form.'
    end
  end
  
  def analytics
    @analytics = Forms::AnalyticsService.new(@form).detailed_report
    @insights = Forms::AiInsightsService.new(@form).generate_insights if @form.ai_enhanced?
  end
  
  def export
    format = params[:format] || 'csv'
    exporter = Forms::DataExportService.new(@form, format: format)
    
    respond_to do |f|
      f.csv { send_data exporter.to_csv, filename: "#{@form.name}_responses.csv" }
      f.xlsx { send_data exporter.to_xlsx, filename: "#{@form.name}_responses.xlsx" }
      f.json { render json: exporter.to_json }
    end
  end
  
  # AJAX actions for form builder
  def preview
    @form = current_user.forms.find(params[:id])
    @preview_mode = true
    render layout: 'form_preview'
  end
  
  def test_ai_feature
    feature = params[:feature]
    test_data = params[:test_data]
    
    service = Forms::AiFeatureTestService.new(@form, feature, test_data)
    result = service.test
    
    render json: result
  end
  
  private
  
  def set_form
    @form = current_user.forms.find(params[:id])
  end
  
  def authorize_form
    authorize @form
  end
  
  def form_params
    params.require(:form).permit(
      :name, :description, :category,
      form_settings: {},
      ai_configuration: {},
      style_configuration: {},
      integration_settings: {},
      notification_settings: {}
    )
  end
  
  def search_params
    search = {}
    search[:status] = params[:status] if params[:status].present?
    search[:category] = params[:category] if params[:category].present?
    search
  end
  
  def sort_params
    case params[:sort]
    when 'name' then { name: :asc }
    when 'responses' then { responses_count: :desc }
    when 'completion_rate' then { completions_count: :desc }
    else { updated_at: :desc }
    end
  end
  
  def default_form_settings
    {
      ui: {
        progress_bar: true,
        one_question_per_page: true,
        show_question_numbers: false,
        theme: 'default'
      },
      behavior: {
        allow_back: true,
        auto_save: true,
        show_required_indicator: true
      },
      completion: {
        thank_you_message: "Thank you for your response!",
        redirect_url: nil,
        show_summary: false
      },
      sharing: {
        allow_embedding: true,
        require_authentication: false,
        collect_email: false
      }
    }
  end
  
  def default_ai_configuration
    {
      enabled: false,
      model: 'gpt-4o-mini',
      features: [],
      budget_limit: 10.0,
      confidence_threshold: 0.7
    }
  end
  
  def handle_form_update
    if form_structure_changed?
      Forms::WorkflowRegenerationJob.perform_later(@form.id)
    end
    
    if ai_configuration_changed?
      Forms::AiConfigurationUpdateJob.perform_later(@form.id)
    end
    
    redirect_to @form, notice: 'Form updated successfully!'
  end
  
  def form_structure_changed?
    @form.previous_changes.keys.intersect?(%w[name category form_settings])
  end
  
  def ai_configuration_changed?
    @form.previous_changes.key?('ai_configuration')
  end
end
```

#### 5.3 Form Questions Controller
```ruby
# app/controllers/form_questions_controller.rb
class FormQuestionsController < ApplicationController
  before_action :set_form
  before_action :set_question, only: [:show, :edit, :update, :destroy, :move_up, :move_down, :duplicate]
  before_action :authorize_form_access
  
  def index
    @questions = @form.questions_ordered
    respond_to do |format|
      format.json { render json: Forms::QuestionsSerializer.new(@questions).as_json }
    end
  end
  
  def create
    @question = @form.form_questions.build(question_params)
    @question.position = @form.next_question_position
    authorize @question
    
    if @question.save
      trigger_workflow_update
      render_turbo_response(:append, @question)
    else
      render json: { errors: @question.errors }, status: :unprocessable_entity
    end
  end
  
  def edit
    render_turbo_response(:replace, @question, partial: 'edit_form')
  end
  
  def update
    if @question.update(question_params)
      trigger_workflow_update if structure_changed?
      render_turbo_response(:replace, @question)
    else
      render json: { errors: @question.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @question.destroy
    trigger_workflow_update
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("question-#{@question.id}") }
      format.json { head :ok }
    end
  end
  
  def move_up
    return head :unprocessable_entity unless @question.position > 1
    
    Forms::QuestionReorderingService.new(@form).move_up(@question)
    render json: { success: true, new_position: @question.reload.position }
  end
  
  def move_down
    max_position = @form.form_questions.maximum(:position)
    return head :unprocessable_entity unless @question.position < max_position
    
    Forms::QuestionReorderingService.new(@form).move_down(@question)
    render json: { success: true, new_position: @question.reload.position }
  end
  
  def duplicate
    service = Forms::QuestionDuplicationService.new(@question)
    @new_question = service.duplicate
    
    if @new_question.persisted?
      trigger_workflow_update
      render_turbo_response(:append, @new_question)
    else
      render json: { errors: @new_question.errors }, status: :unprocessable_entity
    end
  end
  
  def bulk_update
    updates = params[:questions] || {}
    service = Forms::BulkQuestionUpdateService.new(@form, updates)
    
    if service.update_all
      trigger_workflow_update
      render json: { success: true, updated_count: updates.size }
    else
      render json: { errors: service.errors }, status: :unprocessable_entity
    end
  end
  
  def ai_enhance
    return head :forbidden unless @form.ai_enhanced?
    
    enhancement_type = params[:enhancement_type]
    service = Forms::AiEnhancementService.new(@question, enhancement_type)
    
    result = service.enhance
    
    if result.success?
      @question.reload
      render_turbo_response(:replace, @question)
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_form
    @form = current_user.forms.find(params[:form_id])
  end
  
  def set_question
    @question = @form.form_questions.find(params[:id])
  end
  
  def authorize_form_access
    authorize @form, :edit?
  end
  
  def question_params
    params.require(:form_question).permit(
      :title, :description, :help_text, :question_type, :required,
      field_configuration: {},
      validation_rules: {},
      conditional_logic: {},
      ai_enhancement: {},
      style_overrides: {}
    )
  end
  
  def trigger_workflow_update
    Forms::WorkflowRegenerationJob.perform_later(@form.id)
  end
  
  def structure_changed?
    @question.previous_changes.keys.intersect?(%w[question_type title required])
  end
  
  def render_turbo_response(action, question, partial: 'question')
    respond_to do |format|
      format.turbo_stream do
        case action
        when :append
          render turbo_stream: turbo_stream.append("questions-list",
----------------------------------------------------------------------------------------
# AgentForm Implementation Blueprint - Part 2

## Continuation from Part 1 - Controller Layer Implementation

### 5.2 Forms Controller (Complete - Continued)

```ruby
# app/controllers/form_questions_controller.rb (continued)

  def render_turbo_response(action, question, partial: 'question')
    respond_to do |format|
      format.turbo_stream do
        case action
        when :append
          render turbo_stream: turbo_stream.append("questions-list", 
                                                  partial: "form_questions/#{partial}",
                                                  locals: { question: question })
        when :replace
          render turbo_stream: turbo_stream.replace("question-#{question.id}",
                                                   partial: "form_questions/#{partial}",
                                                   locals: { question: question })
        when :remove
          render turbo_stream: turbo_stream.remove("question-#{question.id}")
        end
      end
      format.json { render json: Forms::QuestionSerializer.new(question).as_json }
    end
  end
end
```

### 5.3 Response Controller (Public Form Rendering)
```ruby
# app/controllers/responses_controller.rb
class ResponsesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_form_by_token
  before_action :set_or_create_response
  before_action :check_form_accessibility
  before_action :set_current_question, only: [:show, :answer, :navigate]
  
  protect_from_forgery except: [:answer, :analytics_event, :auto_save]
  
  def show
    # Main form display endpoint
    @progress = calculate_progress
    @all_questions = @form.questions_ordered
    @previous_answers = @response.answers_hash
    
    # Initialize form session if needed
    initialize_form_session if @response.in_progress? && @response.question_responses.empty?
    
    # Track page view
    track_event('question_view', question_data)
    
    render layout: 'form_response'
  end
  
  def answer
    # Process question answer
    answer_service = Forms::AnswerProcessingService.new(
      response: @response,
      question: @current_question,
      answer_data: answer_params[:answer_data],
      metadata: answer_metadata
    )
    
    if answer_service.process
      handle_successful_answer(answer_service)
    else
      handle_answer_errors(answer_service.errors)
    end
  end
  
  def navigate
    # Handle navigation between questions
    direction = params[:direction] # 'next', 'previous', 'jump'
    target_position = params[:position]&.to_i
    
    navigation_service = Forms::NavigationService.new(@response)
    
    case direction
    when 'next'
      next_question = navigation_service.next_question(@current_question)
      redirect_to_question(next_question)
    when 'previous'
      previous_question = navigation_service.previous_question(@current_question)
      redirect_to_question(previous_question)
    when 'jump'
      target_question = navigation_service.jump_to_position(target_position)
      redirect_to_question(target_question)
    else
      redirect_to response_path(@form.share_token)
    end
  end
  
  def auto_save
    # Auto-save partial answers
    return head :forbidden unless @form.auto_save_enabled?
    
    draft_data = params[:draft_data]
    
    Rails.cache.write(
      "draft_#{@response.session_id}_#{@current_question.id}",
      draft_data,
      expires_in: 1.hour
    )
    
    track_event('auto_save', { question_id: @current_question.id })
    head :ok
  end
  
  def thank_you
    redirect_to response_path(@form.share_token) unless @response.completed?
    
    @completion_data = @response.metadata
    @recommendations = generate_recommendations if @form.ai_enhanced?
    
    track_event('form_completed')
    
    render layout: 'form_response'
  end
  
  def analytics_event
    # Track user behavior events
    event_type = params[:event_type]
    event_data = params[:event_data] || {}
    
    track_event(event_type, event_data)
    head :ok
  end
  
  def summary
    # Show response summary to user
    return head :forbidden unless @response.completed?
    return head :forbidden unless @form.form_settings.dig('completion', 'show_summary')
    
    @summary_data = Forms::ResponseSummaryService.new(@response).generate
    render layout: 'form_response'
  end
  
  def download_response
    # Allow users to download their responses
    return head :forbidden unless @response.completed?
    return head :forbidden unless @form.form_settings.dig('sharing', 'allow_download')
    
    exporter = Forms::UserResponseExportService.new(@response)
    
    respond_to do |format|
      format.pdf { send_data exporter.to_pdf, filename: "response_#{@response.id}.pdf" }
      format.json { send_data exporter.to_json, filename: "response_#{@response.id}.json" }
    end
  end
  
  private
  
  def set_form_by_token
    @form = Form.published.find_by!(share_token: params[:form_token])
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false
  end
  
  def set_or_create_response
    session_id = session[:form_session_id] || generate_session_id
    session[:form_session_id] = session_id
    
    @response = @form.form_responses.find_or_create_by(session_id: session_id) do |response|
      response.started_at = Time.current
      response.user_agent = request.user_agent
      response.ip_address = request.remote_ip
      response.referrer = request.referer
      response.utm_parameters = extract_utm_parameters
      response.context_data = build_initial_context
    end
  end
  
  def check_form_accessibility
    if @form.form_settings.dig('sharing', 'require_authentication') && !user_signed_in?
      redirect_to new_user_session_path, alert: 'Please sign in to access this form.'
      return
    end
    
    if @form.archived?
      render file: Rails.root.join('public', '410.html'), status: :gone, layout: false
      return
    end
  end
  
  def set_current_question
    position = params[:position]&.to_i || determine_current_position
    @current_question = @form.form_questions.find_by(position: position)
    
    unless @current_question
      if @response.completed?
        redirect_to response_thank_you_path(@form.share_token)
      else
        redirect_to response_path(@form.share_token)
      end
    end
  end
  
  def answer_params
    params.require(:response).permit(answer_data: {})
  end
  
  def answer_metadata
    {
      response_time: params[:response_time]&.to_i,
      revision_count: params[:revision_count]&.to_i || 0,
      interaction_events: params[:interaction_events] || [],
      user_agent: request.user_agent,
      timestamp: Time.current.iso8601
    }
  end
  
  def calculate_progress
    return 0 if @form.form_questions.empty?
    
    if @form.one_question_per_page?
      answered_count = @response.question_responses.count
      total_count = @form.form_questions.count
      (answered_count.to_f / total_count * 100).round
    else
      # Multi-question page progress
      Forms::ProgressCalculationService.new(@response).calculate_percentage
    end
  end
  
  def initialize_form_session
    Forms::SessionInitializationWorkflow.perform_later(@response.id)
  end
  
  def handle_successful_answer(answer_service)
    @response.reload
    
    # Check for dynamic follow-up questions
    if @current_question.generates_followups? && answer_service.should_generate_followup?
      Forms::DynamicQuestionGenerationJob.perform_later(@response.id, @current_question.id)
    end
    
    # Determine next step
    next_question = determine_next_question
    
    if next_question
      redirect_to response_question_path(@form.share_token, next_question.position)
    else
      # Form completion
      @response.mark_completed!
      redirect_to response_thank_you_path(@form.share_token)
    end
  end
  
  def handle_answer_errors(errors)
    @errors = errors
    @progress = calculate_progress
    
    respond_to do |format|
      format.html { render :show, status: :unprocessable_entity, layout: 'form_response' }
      format.json { render json: { errors: errors }, status: :unprocessable_entity }
    end
  end
  
  def determine_next_question
    Forms::NavigationService.new(@response, @current_question).next_question
  end
  
  def determine_current_position
    return 1 if @response.question_responses.empty?
    
    last_answered_position = @response.question_responses
                                     .joins(:form_question)
                                     .maximum('form_questions.position')
    
    navigation_service = Forms::NavigationService.new(@response)
    next_unanswered = navigation_service.next_unanswered_question_after(last_answered_position)
    
    next_unanswered&.position || 1
  end
  
  def redirect_to_question(question)
    if question
      redirect_to response_question_path(@form.share_token, question.position)
    else
      redirect_to response_thank_you_path(@form.share_token)
    end
  end
  
  def generate_session_id
    "resp_#{SecureRandom.urlsafe_base64(16)}_#{Time.current.to_i}"
  end
  
  def extract_utm_parameters
    utm_params = {}
    %w[utm_source utm_medium utm_campaign utm_term utm_content].each do |param|
      utm_params[param] = params[param] if params[param].present?
    end
    utm_params
  end
  
  def build_initial_context
    {
      started_from: request.referer,
      user_agent_details: parse_user_agent,
      screen_resolution: params[:screen_resolution],
      timezone: params[:timezone],
      language: request.headers['Accept-Language']&.split(',')&.first
    }
  end
  
  def parse_user_agent
    # Simple user agent parsing - could use a gem like browser
    ua = request.user_agent
    {
      raw: ua,
      mobile: ua.match?(/Mobile|Android|iPhone|iPad/i),
      bot: ua.match?(/bot|crawler|spider/i)
    }
  end
  
  def track_event(event_type, data = {})
    Forms::AnalyticsTrackingJob.perform_later(
      @response.id,
      event_type,
      data.merge(question_id: @current_question&.id, timestamp: Time.current)
    )
  end
  
  def question_data
    return {} unless @current_question
    
    {
      question_id: @current_question.id,
      question_type: @current_question.question_type,
      position: @current_question.position,
      required: @current_question.required?
    }
  end
  
  def generate_recommendations
    Forms::CompletionRecommendationsService.new(@response).generate
  end
end
```

## Phase 2: SuperAgent Workflow Implementation (Days 8-14)

### Day 8: Base Workflow Classes

#### 8.1 Application Workflow Base
```ruby
# app/workflows/application_workflow.rb
class ApplicationWorkflow < SuperAgent::WorkflowDefinition
  include SuperAgent::WorkflowHelpers
  
  # Global workflow configuration
  timeout 300 # 5 minutes default
  retry_policy max_retries: 2, delay: 1
  
  # Global error handling
  on_error do |error, context|
    Rails.logger.error "Workflow error in #{self.class.name}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Default error response
    {
      error: true,
      error_message: error.message,
      error_type: error.class.name,
      timestamp: Time.current.iso8601
    }
  end
  
  # Common workflow hooks
  before_all do |context|
    Rails.logger.info "Starting workflow #{self.class.name} with context keys: #{context.keys}"
    context.set(:workflow_started_at, Time.current)
  end
  
  after_all do |context|
    started_at = context.get(:workflow_started_at)
    duration = started_at ? Time.current - started_at : 0
    Rails.logger.info "Completed workflow #{self.class.name} in #{duration.round(2)}s"
  end
  
  protected
  
  # Helper method for AI cost tracking
  def track_ai_usage(context, cost, operation)
    user_id = context.get(:user_id) || context.get(:current_user_id)
    return unless user_id
    
    Forms::AiUsageTracker.new(user_id).track_usage(
      operation: operation,
      cost: cost,
      model: context.get(:ai_model) || 'gpt-4o-mini',
      timestamp: Time.current
    )
  end
  
  # Helper for conditional AI execution based on user limits
  def ai_budget_available?(context, estimated_cost)
    user_id = context.get(:user_id)
    return true unless user_id
    
    user = User.find(user_id)
    user.can_use_ai_features? && user.ai_credits_remaining >= estimated_cost
  end
end
```

#### 8.2 Form Response Processing Workflow
```ruby
# app/workflows/forms/response_processing_workflow.rb
module Forms
  class ResponseProcessingWorkflow < ApplicationWorkflow
    workflow do
      # Step 1: Validate and prepare response data
      validate :validate_response_data do
        input :form_response_id, :question_id, :answer_data
        description "Validate incoming response data"
        
        process do |response_id, question_id, answer_data|
          form_response = FormResponse.find(response_id)
          question = FormQuestion.find(question_id)
          
          # Basic validation
          raise "Form response not found" unless form_response
          raise "Question not found" unless question
          raise "Question not part of form" unless question.form_id == form_response.form_id
          
          # Answer validation
          validation_errors = question.validate_answer(answer_data)
          
          {
            valid: validation_errors.empty?,
            validation_errors: validation_errors,
            form_response: form_response,
            question: question,
            processed_answer: question.process_answer(answer_data)
          }
        end
      end
      
      # Step 2: Save question response
      task :save_question_response do
        input :validate_response_data
        run_when :validate_response_data, ->(result) { result[:valid] }
        
        process do |validation_result|
          form_response = validation_result[:form_response]
          question = validation_result[:question]
          processed_answer = validation_result[:processed_answer]
          
          question_response = form_response.question_responses.find_or_initialize_by(
            form_question: question
          )
          
          question_response.assign_attributes(
            answer_data: processed_answer,
            raw_input: validation_result[:answer_data],
            response_time_ms: metadata[:response_time],
            revision_count: (question_response.revision_count || 0) + 1
          )
          
          question_response.save!
          
          {
            question_response_id: question_response.id,
            saved: true,
            is_revision: question_response.revision_count > 1
          }
        end
      end
      
      # Step 3: AI Enhancement (conditional)
      llm :analyze_response_ai do
        input :save_question_response, :validate_response_data
        run_if do |context|
          validation_result = context.get(:validate_response_data)
          question = validation_result[:question]
          form_response = validation_result[:form_response]
          
          question.ai_enhanced? && 
          form_response.form.user.can_use_ai_features? &&
          ai_budget_available?(context, 0.01)
        end
        
        model { |ctx| ctx.get(:validate_response_data)[:question].form.ai_model }
        temperature 0.3
        max_tokens 500
        response_format :json
        
        system_prompt "You are an AI assistant analyzing form responses for insights, sentiment, and quality."
        
        prompt <<~PROMPT
          Analyze this form response:
          
          Question: {{validate_response_data.question.title}}
          Question Type: {{validate_response_data.question.question_type}}
          Answer: {{validate_response_data.processed_answer}}
          
          Previous Context: {{validate_response_data.form_response.context_data}}
          
          Provide analysis in JSON format:
          {
            "sentiment": {
              "label": "positive|negative|neutral",
              "confidence": 0.0-1.0
            },
            "quality": {
              "completeness": 0.0-1.0,
              "relevance": 0.0-1.0,
              "clarity": 0.0-1.0
            },
            "insights": [
              "Key insight about the response"
            ],
            "flags": {
              "needs_followup": boolean,
              "high_value_lead": boolean,
              "potential_issue": boolean
            },
            "suggested_actions": [
              "Action recommendations based on response"
            ]
          }
        PROMPT
      end
      
      # Step 4: Update question response with AI analysis
      task :update_with_ai_analysis do
        input :save_question_response, :analyze_response_ai
        run_when :analyze_response_ai
        
        process do |save_result, ai_analysis|
          question_response = QuestionResponse.find(save_result[:question_response_id])
          
          # Parse AI analysis and update response
          analysis_data = JSON.parse(ai_analysis) rescue {}
          
          question_response.update!(
            ai_analysis: analysis_data,
            confidence_score: analysis_data.dig('quality', 'completeness'),
            completeness_score: analysis_data.dig('quality', 'relevance')
          )
          
          # Track AI usage
          track_ai_usage(context, 0.01, 'response_analysis')
          
          {
            updated: true,
            ai_analysis: analysis_data,
            question_response_id: question_response.id
          }
        end
      end
      
      # Step 5: Generate dynamic follow-up questions (conditional)
      llm :generate_followup_question do
        input :update_with_ai_analysis, :validate_response_data
        run_if do |context|
          ai_result = context.get(:update_with_ai_analysis)
          validation_result = context.get(:validate_response_data)
          question = validation_result[:question]
          
          ai_result&.dig(:ai_analysis, 'flags', 'needs_followup') &&
          question.generates_followups? &&
          ai_budget_available?(context, 0.02)
        end
        
        model { |ctx| ctx.get(:validate_response_data)[:question].form.ai_model }
        temperature 0.7
        max_tokens 300
        response_format :json
        
        system_prompt "You are an expert at generating contextual follow-up questions for forms."
        
        prompt <<~PROMPT
          Based on this response, generate a relevant follow-up question:
          
          Original Question: {{validate_response_data.question.title}}
          User's Answer: {{validate_response_data.processed_answer}}
          AI Analysis: {{update_with_ai_analysis.ai_analysis}}
          Form Context: {{validate_response_data.form_response.answers_hash}}
          
          Generate a JSON response:
          {
            "question": {
              "title": "Follow-up question title",
              "description": "Optional description",
              "question_type": "text_short|multiple_choice|rating",
              "configuration": {
                // Type-specific configuration
              },
              "reasoning": "Why this follow-up is valuable"
            }
          }
          
          Make the follow-up question:
          - Directly relevant to their answer
          - Valuable for gathering additional insights
          - Natural and conversational
          - Appropriately typed for the expected answer
        PROMPT
      end
      
      # Step 6: Create dynamic question
      task :create_dynamic_question do
        input :generate_followup_question, :validate_response_data
        run_when :generate_followup_question
        
        process do |followup_data, validation_result|
          question_data = JSON.parse(followup_data)['question'] rescue nil
          return { created: false, reason: 'Invalid question data' } unless question_data
          
          form_response = validation_result[:form_response]
          source_question = validation_result[:question]
          
          dynamic_question = form_response.dynamic_questions.create!(
            question_type: question_data['question_type'],
            title: question_data['title'],
            description: question_data['description'],
            configuration: question_data['configuration'],
            generated_from_question: source_question,
            generation_context: {
              original_answer: validation_result[:processed_answer],
              ai_reasoning: question_data['reasoning']
            },
            generation_model: form_response.form.ai_model
          )
          
          # Track AI usage
          track_ai_usage(context, 0.02, 'dynamic_question_generation')
          
          {
            created: true,
            dynamic_question_id: dynamic_question.id,
            question_data: question_data
          }
        end
      end
      
      # Step 7: Real-time UI update
      stream :update_form_ui do
        input :save_question_response, :create_dynamic_question
        
        target { |ctx| "form_#{ctx.get(:validate_response_data)[:form_response].form.share_token}" }
        turbo_action :append
        partial "responses/dynamic_question"
        locals do |ctx|
          save_result = ctx.get(:save_question_response)
          dynamic_result = ctx.get(:create_dynamic_question)
          
          {
            question_response_id: save_result[:question_response_id],
            dynamic_question: dynamic_result&.dig(:dynamic_question_id) ? 
                            DynamicQuestion.find(dynamic_result[:dynamic_question_id]) : nil,
            form_response: ctx.get(:validate_response_data)[:form_response]
          }
        end
      end
    end
  end
end
```

### Day 9: AI Enhancement Workflows

#### 9.1 Form Analysis Workflow
```ruby
# app/workflows/forms/analysis_workflow.rb
module Forms
  class AnalysisWorkflow < ApplicationWorkflow
    workflow do
      timeout 120
      
      # Step 1: Gather form data
      task :collect_form_data do
        input :form_id
        description "Collect all form responses and questions for analysis"
        
        process do |form_id|
          form = Form.find(form_id)
          responses = form.form_responses.completed.includes(:question_responses)
          
          {
            form: form,
            total_responses: responses.count,
            questions: form.form_questions.count,
            responses_data: responses.limit(100).map(&:answers_hash), # Sample for analysis
            completion_rate: form.completion_rate,
            avg_time: form.average_completion_time_minutes
          }
        end
      end
      
      # Step 2: Performance analysis
      llm :analyze_form_performance do
        input :collect_form_data
        run_if { |ctx| ctx.get(:collect_form_data)[:total_responses] >= 10 }
        
        model "gpt-4o"
        temperature 0.2
        max_tokens 1000
        response_format :json
        
        system_prompt "You are an expert in form optimization and user experience analysis."
        
        prompt <<~PROMPT
          Analyze this form's performance and provide optimization recommendations:
          
          Form: {{collect_form_data.form.name}}
          Total Responses: {{collect_form_data.total_responses}}
          Completion Rate: {{collect_form_data.completion_rate}}%
          Average Time: {{collect_form_data.avg_time}} minutes
          Questions: {{collect_form_data.questions}}
          
          Sample Response Data:
          {{collect_form_data.responses_data}}
          
          Provide analysis in JSON format:
          {
            "performance_score": 0-100,
            "strengths": [
              "What's working well"
            ],
            "weaknesses": [
              "Areas for improvement"
            ],
            "recommendations": [
              {
                "type": "question_order|question_wording|ui_improvement|conditional_logic",
                "priority": "high|medium|low",
                "description": "Specific recommendation",
                "expected_impact": "Expected improvement description"
              }
            ],
            "user_behavior_insights": [
              "Insights about user behavior patterns"
            ],
            "optimization_opportunities": [
              "Specific optimization opportunities"
            ]
          }
        PROMPT
      end
      
      # Step 3: Question-level analysis
      task :analyze_question_performance do
        input :collect_form_data
        run_if { |ctx| ctx.get(:collect_form_data)[:total_responses] >= 10 }
        
        process do |form_data|
          form = form_data[:form]
          question_analytics = []
          
          form.form_questions.each do |question|
            responses = question.question_responses.includes(:form_response)
            
            analytics = {
              question_id: question.id,
              title: question.title,
              type: question.question_type,
              response_count: responses.count,
              completion_rate: question.completion_rate,
              avg_response_time: question.average_response_time_seconds,
              drop_off_rate: calculate_drop_off_rate(question),
              answer_distribution: calculate_answer_distribution(responses)
            }
            
            question_analytics << analytics
          end
          
          {
            question_analytics: question_analytics,
            bottleneck_questions: identify_bottlenecks(question_analytics),
            high_performing_questions: identify_high_performers(question_analytics)
          }
        end
      end
      
      # Step 4: Generate actionable insights
      llm :generate_optimization_plan do
        input :analyze_form_performance, :analyze_question_performance
        run_when :analyze_form_performance
        
        model "gpt-4o"
        temperature 0.3
        max_tokens 800
        response_format :json
        
        prompt <<~PROMPT
          Create an actionable optimization plan based on this analysis:
          
          Performance Analysis:
          {{analyze_form_performance}}
          
          Question Analytics:
          {{analyze_question_performance.question_analytics}}
          
          Bottleneck Questions:
          {{analyze_question_performance.bottleneck_questions}}
          
          Generate a prioritized optimization plan in JSON:
          {
            "priority_actions": [
              {
                "action_type": "reorder_questions|rewrite_question|add_conditional_logic|ui_improvement",
                "target": "question_id or form_section",
                "description": "What to do",
                "rationale": "Why this will help",
                "estimated_impact": "Expected improvement",
                "effort_level": "low|medium|high",
                "timeline": "immediate|short_term|long_term"
              }
            ],
            "quick_wins": [
              "Easy improvements with immediate impact"
            ],
            "experimental_ideas": [
              "Ideas to test with A/B testing"
            ]
          }
        PROMPT
      end
      
      # Step 5: Save analysis results
      task :save_analysis_results do
        input :analyze_form_performance, :analyze_question_performance, :generate_optimization_plan
        
        process do |performance, questions, optimization|
          form = FormAnalytic.find_or_create_by(
            form_id: context.get(:form_id),
            date: Date.current,
            metric_type: 'ai_analysis'
          )
          
          form.update!(
            ai_insights: {
              performance_analysis: performance,
              question_analytics: questions,
              optimization_plan: optimization,
              analyzed_at: Time.current,
              analysis_version: '1.0'
            }
          )
          
          {
            analysis_saved: true,
            form_analytic_id: form.id,
            insights_count: optimization.dig('priority_actions')&.size || 0
          }
        end
      end
    end
    
    private
    
    def calculate_drop_off_rate(question)
      # Calculate what percentage of users abandon at this question
      form = question.form
      total_attempts = form.form_responses.where(
        'created_at >= ?', question.created_at
      ).count
      
      return 0 if total_attempts.zero?
      
      responses_past_this_question = form.form_responses.joins(:question_responses)
                                         .where(question_responses: { form_question_id: question.id })
                                         .count
      
      ((total_attempts - responses_past_this_question).to_f / total_attempts * 100).round(2)
    end
    
    def calculate_answer_distribution(responses)
      # Analyze distribution of answers for insights
      case responses.first&.form_question&.question_type
      when 'multiple_choice', 'single_choice'
        distribution = responses.group_by(&:answer_data).transform_values(&:count)
        total = responses.count
        distribution.transform_values { |count| (count.to_f / total * 100).round(1) }
      when 'rating', 'scale', 'nps_score'
        ratings = responses.map { |r| r.answer_data.to_f }
        {
          average: (ratings.sum / ratings.size).round(2),
          min: ratings.min,
          max: ratings.max,
          distribution: ratings.group_by(&:itself).transform_values(&:count)
        }
      when 'text_short', 'text_long'
        {
          avg_length: responses.average("LENGTH(answer_data)").to_i,
          response_count: responses.count,
          common_keywords: extract_common_keywords(responses)
        }
              else
        { response_count: responses.count }
        end
    end
    
    def identify_bottlenecks(question_analytics)
      question_analytics.select { |q| q[:drop_off_rate] > 20 || q[:avg_response_time] > 30 }
                       .sort_by { |q| q[:drop_off_rate] }
                       .reverse
    end
    
    def identify_high_performers(question_analytics)
      question_analytics.select { |q| q[:completion_rate] > 90 && q[:avg_response_time] < 15 }
                       .sort_by { |q| q[:completion_rate] }
                       .reverse
    end
    
    def extract_common_keywords(responses)
      # Simple keyword extraction - could use NLP gem for better results
      text_responses = responses.map(&:answer_data).join(' ').downcase
      words = text_responses.scan(/\w+/).reject { |w| w.length < 3 }
      word_freq = words.tally
      word_freq.sort_by { |_, count| -count }.first(10).to_h
    end
  end
end
```

#### 9.2 Dynamic Question Generation Workflow
```ruby
# app/workflows/forms/dynamic_question_workflow.rb
module Forms
  class DynamicQuestionWorkflow < ApplicationWorkflow
    workflow do
      timeout 60
      
      # Step 1: Analyze response context
      task :analyze_response_context do
        input :response_id, :source_question_id
        
        process do |response_id, source_question_id|
          form_response = FormResponse.find(response_id)
          source_question = FormQuestion.find(source_question_id)
          source_answer = form_response.question_responses.find_by(form_question: source_question)
          
          {
            form_response: form_response,
            source_question: source_question,
            source_answer: source_answer&.answer_data,
            form_context: form_response.answers_hash,
            user_journey: analyze_user_journey(form_response),
            form_intent: determine_form_intent(form_response.form)
          }
        end
      end
      
      # Step 2: Generate contextual follow-up
      llm :generate_contextual_followup do
        input :analyze_response_context
        run_if { |ctx| ai_budget_available?(ctx, 0.03) }
        
        model { |ctx| ctx.get(:analyze_response_context)[:form_response].form.ai_model }
        temperature 0.7
        max_tokens 400
        response_format :json
        
        system_prompt <<~SYSTEM
          You are an expert conversation designer creating natural follow-up questions for forms.
          
          Your goals:
          1. Generate questions that feel like natural conversation flow
          2. Gather valuable additional information
          3. Maintain user engagement
          4. Respect user's time and attention
          
          Guidelines:
          - Keep questions concise and clear
          - Make them relevant to the previous answer
          - Choose appropriate question types
          - Avoid repetition or redundancy
          - Consider the form's overall purpose
        SYSTEM
        
        prompt <<~PROMPT
          Generate a contextual follow-up question based on this response:
          
          Form Purpose: {{analyze_response_context.form_intent}}
          Source Question: {{analyze_response_context.source_question.title}}
          User's Answer: {{analyze_response_context.source_answer}}
          
          Previous Answers Context:
          {{analyze_response_context.form_context}}
          
          User Journey Stage: {{analyze_response_context.user_journey.stage}}
          Engagement Level: {{analyze_response_context.user_journey.engagement}}
          
          Generate JSON response:
          {
            "should_generate": boolean,
            "question": {
              "title": "Follow-up question",
              "description": "Optional clarifying description",
              "question_type": "text_short|text_long|multiple_choice|rating|yes_no",
              "required": boolean,
              "configuration": {
                // Type-specific configuration object
              }
            },
            "reasoning": {
              "why_valuable": "Why this follow-up adds value",
              "connection_to_previous": "How it connects to the previous answer",
              "information_goal": "What information we're seeking"
            },
            "alternatives": [
              "Alternative question approaches if primary doesn't work"
            ]
          }
          
          Only generate a follow-up if it would genuinely add value. Set should_generate to false if not needed.
        PROMPT
      end
      
      # Step 3: Validate generated question
      validate :validate_generated_question do
        input :generate_contextual_followup
        run_when :generate_contextual_followup
        
        process do |generation_result|
          question_data = JSON.parse(generation_result)
          
          # Check if we should actually generate
          unless question_data['should_generate']
            return { 
              valid: false, 
              reason: 'AI determined follow-up not valuable',
              question_data: nil 
            }
          end
          
          question_info = question_data['question']
          
          # Validate question structure
          errors = []
          errors << 'Missing title' unless question_info['title'].present?
          errors << 'Invalid question type' unless FormQuestion::QUESTION_TYPES.include?(question_info['question_type'])
          errors << 'Title too long' if question_info['title'].to_s.length > 500
          
          {
            valid: errors.empty?,
            errors: errors,
            question_data: question_info,
            reasoning: question_data['reasoning']
          }
        end
      end
      
      # Step 4: Create dynamic question record
      task :create_dynamic_question_record do
        input :analyze_response_context, :validate_generated_question
        run_when :validate_generated_question, ->(result) { result[:valid] }
        
        process do |context_analysis, validation_result|
          form_response = context_analysis[:form_response]
          source_question = context_analysis[:source_question]
          question_data = validation_result[:question_data]
          
          dynamic_question = form_response.dynamic_questions.create!(
            question_type: question_data['question_type'],
            title: question_data['title'],
            description: question_data['description'],
            configuration: question_data['configuration'] || {},
            generated_from_question: source_question,
            generation_context: {
              source_answer: context_analysis[:source_answer],
              form_context: context_analysis[:form_context],
              user_journey: context_analysis[:user_journey],
              ai_reasoning: validation_result[:reasoning]
            },
            generation_model: form_response.form.ai_model,
            ai_confidence: calculate_generation_confidence(validation_result)
          )
          
          # Track AI usage cost
          track_ai_usage(context, 0.03, 'dynamic_question_generation')
          
          {
            created: true,
            dynamic_question_id: dynamic_question.id,
            question_title: dynamic_question.title,
            insertion_position: determine_insertion_position(form_response, source_question)
          }
        end
      end
      
      # Step 5: Real-time UI insertion
      stream :insert_dynamic_question do
        input :create_dynamic_question_record
        run_when :create_dynamic_question_record
        
        target { |ctx| "form_#{ctx.get(:analyze_response_context)[:form_response].form.share_token}" }
        turbo_action :after
        turbo_target { |ctx| "question-#{ctx.get(:analyze_response_context)[:source_question].id}" }
        partial "responses/dynamic_question_inline"
        
        locals do |ctx|
          dynamic_question = DynamicQuestion.find(ctx.get(:create_dynamic_question_record)[:dynamic_question_id])
          {
            dynamic_question: dynamic_question,
            form_response: ctx.get(:analyze_response_context)[:form_response],
            position: ctx.get(:create_dynamic_question_record)[:insertion_position]
          }
        end
      end
    end
    
    private
    
    def analyze_user_journey(form_response)
      responses_count = form_response.question_responses.count
      total_questions = form_response.form.form_questions.count
      progress = responses_count.to_f / total_questions
      
      {
        stage: determine_journey_stage(progress),
        engagement: calculate_engagement_level(form_response),
        time_spent: form_response.duration_minutes,
        responses_given: responses_count
      }
    end
    
    def determine_form_intent(form)
      case form.category
      when 'lead_qualification' then 'Qualify potential customers and gather contact information'
      when 'customer_feedback' then 'Collect customer satisfaction and improvement suggestions'
      when 'job_application' then 'Evaluate job candidates and collect application information'
      when 'event_registration' then 'Register attendees and gather event preferences'
      when 'survey' then 'Collect opinions and insights from participants'
      else 'Gather information from users'
      end
    end
    
    def determine_journey_stage(progress)
      case progress
      when 0..0.25 then 'beginning'
      when 0.25..0.75 then 'middle'
      when 0.75..1.0 then 'end'
      else 'unknown'
      end
    end
    
    def calculate_engagement_level(form_response)
      # Simple engagement calculation
      time_factor = [form_response.duration_minutes / 10.0, 1.0].min
      progress_factor = form_response.progress_percentage / 100.0
      
      (time_factor * 0.3 + progress_factor * 0.7).round(2)
    end
    
    def calculate_generation_confidence(validation_result)
      # Simple confidence based on validation and reasoning quality
      base_confidence = 0.7
      
      reasoning = validation_result[:reasoning]
      if reasoning && reasoning['why_valuable'].present?
        base_confidence += 0.2
      end
      
      [base_confidence, 1.0].min
    end
    
    def determine_insertion_position(form_response, source_question)
      # Determine where in the form flow to insert the dynamic question
      source_question.position + 1
    end
  end
end
```

### Day 10-11: Agent Implementation

#### 10.1 Form Management Agent
```ruby
# app/agents/forms/management_agent.rb
module Forms
  class ManagementAgent < ApplicationAgent
    def create_form(user, form_data)
      run_workflow(Forms::CreationWorkflow, initial_input: {
        user_id: user.id,
        form_data: form_data,
        timestamp: Time.current
      })
    end
    
    def analyze_form_performance(form)
      run_workflow(Forms::AnalysisWorkflow, initial_input: {
        form_id: form.id,
        user_id: form.user_id,
        analysis_type: 'performance'
      })
    end
    
    def optimize_form(form, optimization_preferences = {})
      run_workflow(Forms::OptimizationWorkflow, initial_input: {
        form_id: form.id,
        preferences: optimization_preferences,
        user_budget: form.user.ai_credits_remaining
      })
    end
    
    def generate_form_from_template(user, template_id, customizations = {})
      run_workflow(Forms::TemplateInstantiationWorkflow, initial_input: {
        user_id: user.id,
        template_id: template_id,
        customizations: customizations
      })
    end
    
    def duplicate_form(source_form, target_user, modifications = {})
      run_workflow(Forms::DuplicationWorkflow, initial_input: {
        source_form_id: source_form.id,
        target_user_id: target_user.id,
        modifications: modifications
      })
    end
    
    def export_form_data(form, export_options = {})
      run_workflow(Forms::DataExportWorkflow, initial_input: {
        form_id: form.id,
        export_format: export_options[:format] || 'csv',
        date_range: export_options[:date_range],
        filters: export_options[:filters] || {}
      })
    end
    
    def publish_form(form)
      run_workflow(Forms::PublishingWorkflow, initial_input: {
        form_id: form.id,
        publish_timestamp: Time.current,
        user_id: form.user_id
      })
    end
  end
end

# app/agents/forms/response_agent.rb
module Forms
  class ResponseAgent < ApplicationAgent
    def process_form_response(form_response, question, answer_data, metadata = {})
      run_workflow(Forms::ResponseProcessingWorkflow, initial_input: {
        form_response_id: form_response.id,
        question_id: question.id,
        answer_data: answer_data,
        metadata: metadata,
        user_id: form_response.form.user_id
      })
    end
    
    def complete_form_response(form_response)
      run_workflow(Forms::CompletionWorkflow, initial_input: {
        form_response_id: form_response.id,
        completion_timestamp: Time.current,
        final_context: form_response.workflow_context
      })
    end
    
    def analyze_response_quality(form_response)
      run_workflow(Forms::QualityAnalysisWorkflow, initial_input: {
        form_response_id: form_response.id,
        analysis_depth: 'standard'
      })
    end
    
    def generate_response_insights(form_response)
      run_workflow(Forms::InsightGenerationWorkflow, initial_input: {
        form_response_id: form_response.id,
        insight_types: ['sentiment', 'intent', 'quality', 'next_actions']
      })
    end
    
    def trigger_integrations(form_response)
      run_workflow(Forms::IntegrationTriggerWorkflow, initial_input: {
        form_response_id: form_response.id,
        integration_settings: form_response.form.integration_settings
      })
    end
    
    def recover_abandoned_response(form_response)
      run_workflow(Forms::AbandonmentRecoveryWorkflow, initial_input: {
        form_response_id: form_response.id,
        abandonment_context: analyze_abandonment_context(form_response)
      })
    end
    
    private
    
    def analyze_abandonment_context(form_response)
      {
        last_question: form_response.question_responses.last&.form_question,
        time_spent: form_response.duration_minutes,
        progress_when_abandoned: form_response.progress_percentage,
        interaction_history: form_response.metadata['interaction_events'] || []
      }
    end
  end
end
```

### Day 12-14: Service Layer Implementation

#### 12.1 Core Services
```ruby
# app/services/forms/answer_processing_service.rb
module Forms
  class AnswerProcessingService
    include ActiveModel::Model
    
    attr_accessor :response, :question, :answer_data, :metadata
    attr_reader :errors, :question_response
    
    def initialize(response:, question:, answer_data:, metadata: {})
      @response = response
      @question = question
      @answer_data = answer_data
      @metadata = metadata
      @errors = []
    end
    
    def process
      return false unless validate_inputs
      return false unless validate_answer_data
      
      ActiveRecord::Base.transaction do
        create_or_update_question_response
        update_response_metadata
        trigger_ai_analysis if should_trigger_ai_analysis?
        trigger_integrations if should_trigger_integrations?
      end
      
      true
    rescue => e
      Rails.logger.error "Answer processing failed: #{e.message}"
      @errors << "Failed to process answer: #{e.message}"
      false
    end
    
    def should_generate_followup?
      return false unless question.generates_followups?
      return false unless @question_response&.ai_analysis&.dig('flags', 'needs_followup')
      
      # Check if we haven't already generated too many follow-ups
      existing_followups = response.dynamic_questions.where(generated_from_question: question).count
      existing_followups < max_followups_per_question
    end
    
    private
    
    def validate_inputs
      if response.blank?
        @errors << "Form response is required"
        return false
      end
      
      if question.blank?
        @errors << "Question is required"
        return false
      end
      
      if question.form_id != response.form_id
        @errors << "Question does not belong to this form"
        return false
      end
      
      true
    end
    
    def validate_answer_data
      validation_errors = question.validate_answer(answer_data)
      
      if validation_errors.any?
        @errors.concat(validation_errors)
        return false
      end
      
      true
    end
    
    def create_or_update_question_response
      @question_response = response.question_responses.find_or_initialize_by(
        form_question: question
      )
      
      @question_response.assign_attributes(
        answer_data: question.process_answer(answer_data),
        raw_input: answer_data,
        response_time_ms: metadata[:response_time],
        revision_count: (@question_response.revision_count || 0) + 1,
        interaction_events: metadata[:interaction_events] || []
      )
      
      @question_response.save!
    end
    
    def update_response_metadata
      response.update!(
        last_activity_at: Time.current,
        metadata: response.metadata.merge(
          last_question_id: question.id,
          total_revisions: response.question_responses.sum(:revision_count)
        )
      )
    end
    
    def should_trigger_ai_analysis?
      question.ai_enhanced? && 
      response.form.user.can_use_ai_features? &&
      answer_data.present?
    end
    
    def should_trigger_integrations?
      response.form.integration_settings.present? &&
      response.form.integration_settings['trigger_on_answer'] == true
    end
    
    def trigger_ai_analysis
      Forms::ResponseAnalysisJob.perform_later(@question_response.id)
    end
    
    def trigger_integrations
      Forms::IntegrationTriggerJob.perform_later(response.id, question.id)
    end
    
    def max_followups_per_question
      question.ai_enhancement.dig('max_followups') || 2
    end
  end
end

# app/services/forms/navigation_service.rb
module Forms
  class NavigationService
    attr_reader :form_response, :current_question
    
    def initialize(form_response, current_question = nil)
      @form_response = form_response
      @current_question = current_question
    end
    
    def next_question
      return nil unless current_question
      
      # Check for dynamic questions first
      dynamic_next = next_dynamic_question
      return dynamic_next if dynamic_next
      
      # Then check regular form questions
      next_static_question
    end
    
    def previous_question
      return nil unless current_question
      return nil unless form.allow_back_navigation?
      
      # Find previous answered question
      answered_positions = answered_question_positions
      current_pos = current_question.position
      
      previous_pos = answered_positions.select { |pos| pos < current_pos }.max
      return nil unless previous_pos
      
      form.form_questions.find_by(position: previous_pos)
    end
    
    def jump_to_position(target_position)
      return nil unless form.allow_back_navigation?
      return nil if target_position > current_question.position # No jumping ahead
      
      target_question = form.form_questions.find_by(position: target_position)
      return nil unless target_question
      
      # Check if user has answered this question
      answered_positions = answered_question_positions
      return nil unless answered_positions.include?(target_position)
      
      target_question
    end
    
    def next_unanswered_question_after(position)
      # Find the next question that hasn't been answered
      unanswered_positions = form.form_questions.pluck(:position) - answered_question_positions
      next_position = unanswered_positions.select { |pos| pos > position }.min
      
      form.form_questions.find_by(position: next_position) if next_position
    end
    
    def completion_eligible?
      required_questions = form.form_questions.where(required: true)
      answered_required = form_response.question_responses
                                      .joins(:form_question)
                                      .where(form_questions: { required: true })
      
      required_questions.count == answered_required.count
    end
    
    def progress_summary
      total_questions = form.form_questions.count
      answered_questions = form_response.question_responses.count
      required_remaining = required_questions_remaining
      
      {
        total_questions: total_questions,
        answered_questions: answered_questions,
        remaining_questions: total_questions - answered_questions,
        required_remaining: required_remaining,
        progress_percentage: (answered_questions.to_f / total_questions * 100).round,
        can_complete: required_remaining.zero?
      }
    end
    
    private
    
    def form
      @form ||= form_response.form
    end
    
    def next_dynamic_question
      # Check for unanswered dynamic questions generated after current question
      form_response.dynamic_questions
                   .where(generated_from_question: current_question)
                   .where.not(id: answered_dynamic_question_ids)
                   .order(:created_at)
                   .first
    end
    
    def next_static_question
      # Find next static question considering conditional logic
      next_position = current_question.position + 1
      
      while next_position <= max_question_position
        candidate = form.form_questions.find_by(position: next_position)
        break unless candidate
        
        # Check conditional logic
        if candidate.should_show_for_response?(form_response)
          return candidate
        end
        
        next_position += 1
      end
      
      nil
    end
    
    def answered_question_positions
      @answered_positions ||= form_response.question_responses
                                          .joins(:form_question)
                                          .pluck('form_questions.position')
                                          .uniq
    end
    
    def answered_dynamic_question_ids
      @answered_dynamic_ids ||= form_response.dynamic_questions
                                            .where.not(answer_data: nil)
                                            .pluck(:id)
    end
    
    def max_question_position
      @max_position ||= form.form_questions.maximum(:position) || 0
    end
    
    def required_questions_remaining
      required_question_ids = form.form_questions.where(required: true).pluck(:id)
      answered_required_ids = form_response.question_responses
                                          .where(form_question_id: required_question_ids)
                                          .pluck(:form_question_id)
      
      required_question_ids - answered_required_ids
    end
  end
end

# app/services/forms/workflow_generator_service.rb
module Forms
  class WorkflowGeneratorService
    attr_reader :form, :workflow_class_name
    
    def initialize(form)
      @form = form
      @workflow_class_name = form.workflow_class_name
    end
    
    def generate_class
      return existing_workflow_class if workflow_exists?
      
      workflow_definition = build_workflow_definition
      create_workflow_class(workflow_definition)
    end
    
    def regenerate_class
      remove_existing_class if workflow_exists?
      generate_class
    end
    
    private
    
    def workflow_exists?
      workflow_class_name.present? && workflow_class_name.safe_constantize
    end
    
    def existing_workflow_class
      workflow_class_name.constantize
    end
    
    def build_workflow_definition
      WorkflowDefinitionBuilder.new(form).build
    end
    
    def create_workflow_class(definition)
      class_code = generate_class_code(definition)
      
      # Dynamically create the class
      Object.const_set(workflow_class_name.demodulize, Class.new(ApplicationWorkflow) do
        class_eval(class_code)
      end)
    end
    
    def remove_existing_class
      module_name = workflow_class_name.deconstantize
      class_name = workflow_class_name.demodulize
      
      if module_name.present?
        module_name.constantize.send(:remove_const, class_name)
      else
        Object.send(:remove_const, class_name)
      end
    rescue NameError
      # Class doesn't exist, which is fine
    end
    
    def generate_class_code(definition)
      <<~RUBY
        workflow do
          #{definition[:global_config]}
          
          #{definition[:steps].map { |step| generate_step_code(step) }.join("\n\n")}
        end
      RUBY
    end
    
    def generate_step_code(step)
      case step[:type]
      when :validation
        generate_validation_step(step)
      when :llm
        generate_llm_step(step)
      when :task
        generate_task_step(step)
      when :integration
        generate_integration_step(step)
      when :stream
        generate_stream_step(step)
      end
    end
    
    def generate_validation_step(step)
      <<~RUBY
        validate :#{step[:name]} do
          #{generate_input_declaration(step[:inputs])}
          description "#{step[:description]}"
          
          process do |#{step[:inputs].join(', ')}|
            #{step[:logic]}
          end
        end
      RUBY
    end
    
    def generate_llm_step(step)
      <<~RUBY
        llm :#{step[:name]} do
          #{generate_input_declaration(step[:inputs])}
          #{generate_conditional_logic(step[:conditions]) if step[:conditions]}
          
          model "#{step[:model] || form.ai_model}"
          temperature #{step[:temperature] || 0.3}
          max_tokens #{step[:max_tokens] || 500}
          #{step[:response_format] ? "response_format :#{step[:response_format]}" : ''}
          
          system_prompt "#{step[:system_prompt]}"
          prompt <<~PROMPT
            #{step[:prompt]}
          PROMPT
        end
      RUBY
    end
    
    def generate_input_declaration(inputs)
      return '' if inputs.empty?
      "input #{inputs.map { |i| ":#{i}" }.join(', ')}"
    end
    
    def generate_conditional_logic(conditions)
      conditions.map do |condition|
        case condition[:type]
        when :run_if
          "run_if { |ctx| #{condition[:logic]} }"
        when :skip_if
          "skip_if { |ctx| #{condition[:logic]} }"
        when :run_when
          "run_when :#{condition[:key]}, #{condition[:value]}"
        end
      end.join("\n")
    end
    
    class WorkflowDefinitionBuilder
      attr_reader :form
      
      def initialize(form)
        @form = form
      end
      
      def build
        {
          global_config: build_global_config,
          steps: build_steps
        }
      end
      
      private
      
      def build_global_config
        config = []
        config << "timeout #{form.form_settings.dig('workflow', 'timeout') || 300}"
        
        if form.ai_enhanced?
          config << 'retry_policy max_retries: 3, delay: 2'
        end
        
        config.join("\n")
      end
      
      def build_steps
        steps = []
        
        # Always start with form validation
        steps << build_form_validation_step
        
        # Add question processing steps
        form.form_questions.order(:position).each do |question|
          steps.concat(build_question_steps(question))
        end
        
        # Add completion steps
        steps << build_completion_step
        
        # Add integration steps if configured
        if form.integration_settings.present?
          steps << build_integration_step
        end
        
        steps
      end
      
      def build_form_validation_step
        {
          name: :validate_form_access,
          type: :validation,
          inputs: [:form_id, :session_id],
          description: 'Validate form access and session',
          logic: 'Forms::AccessValidator.new(form_id, session_id).validate'
        }
      end
      
      def build_question_steps(question)
        steps = []
        
        # Basic question validation
        steps << {
          name: :"validate_question_#{question.position}",
          type: :validation,
          inputs: [:answer_data],
          description: "Validate answer for: #{question.title}",
          logic: "#{question.question_type}_validator(answer_data, #{question.validation_rules})"
        }
        
        # AI enhancement if enabled
        if question.ai_enhanced?
          steps << build_ai_analysis_step(question)
          
          if question.generates_followups?
            steps << build_followup_generation_step(question)
          end
        end
        
        steps
      end
      
      def build_ai_analysis_step(question)
        {
          name: :"analyze_question_#{question.position}",
          type: :llm,
          inputs: [:answer_data, :form_context],
          conditions: [
            { type: :run_if, logic: "ai_budget_available?(context, 0.01)" }
          ],
          model: form.ai_model,
          system_prompt: "Analyze this form response for insights and quality.",
          prompt: build_analysis_prompt(question),
          response_format: :json,
          temperature: 0.3,
          max_tokens: 300
        }
      end
      
      def build_analysis_prompt(question)
        <<~PROMPT
          Question: #{question.title}
          Type: #{question.question_type}
          Answer: {{answer_data}}
          Context: {{form_context}}
          
          Analyze for sentiment, quality, and insights. Return JSON with sentiment, quality scores, and actionable insights.
        PROMPT
      end
      
      def build_completion_step
        {
          name: :complete_form_response,
          type: :task,
          inputs: [:form_response_id],
          description: 'Mark form as completed and trigger final workflows',
          logic: 'Forms::CompletionHandler.new(form_response_id).complete'
        }
      end
    end
  end
end

# app/services/forms/analytics_service.rb
module Forms
  class AnalyticsService
    attr_reader :form, :period
    
    def initialize(form, period: 30.days)
      @form = form
      @period = period
    end
    
    def detailed_report
      {

-------------------------------------------------------------------------------------------

# AgentForm Implementation Blueprint - Part 3

## Continuation from Part 2 - Service Layer Implementation

### 12.1 Analytics Service (Continued)

```ruby
# app/services/forms/analytics_service.rb (continued)
module Forms
  class AnalyticsService
    attr_reader :form, :period
    
    def initialize(form, period: 30.days)
      @form = form
      @period = period
    end
    
    def detailed_report
      {
        overview: overview_metrics,
        performance: performance_metrics,
        user_behavior: user_behavior_metrics,
        questions: question_level_metrics,
        time_analysis: time_based_analysis,
        quality_metrics: quality_analysis,
        ai_insights: ai_generated_insights
      }
    end
    
    def summary
      responses = recent_responses
      
      {
        total_responses: responses.count,
        completion_rate: calculate_completion_rate(responses),
        average_time: calculate_average_completion_time(responses),
        quality_score: calculate_average_quality_score(responses),
        trend_direction: calculate_trend_direction
      }
    end
    
    private
    
    def recent_responses
      @recent_responses ||= form.form_responses.where('created_at >= ?', period.ago)
    end
    
    def overview_metrics
      {
        total_views: form.views_count,
        total_starts: recent_responses.count,
        total_completions: recent_responses.completed.count,
        completion_rate: calculate_completion_rate(recent_responses),
        abandonment_rate: calculate_abandonment_rate(recent_responses),
        average_completion_time: calculate_average_completion_time(recent_responses.completed)
      }
    end
    
    def performance_metrics
      responses = recent_responses.completed
      
      {
        conversion_funnel: build_conversion_funnel,
        drop_off_points: identify_drop_off_points,
        completion_time_distribution: build_time_distribution(responses),
        response_quality_distribution: build_quality_distribution(responses),
        mobile_vs_desktop: device_breakdown
      }
    end
    
    def user_behavior_metrics
      {
        traffic_sources: analyze_traffic_sources,
        geographic_distribution: analyze_geographic_distribution,
        time_patterns: analyze_time_patterns,
        user_flow: analyze_user_flow,
        interaction_patterns: analyze_interaction_patterns
      }
    end
    
    def question_level_metrics
      form.form_questions.map do |question|
        responses = question.question_responses.includes(:form_response)
                           .where(form_responses: { created_at: period.ago.. })
        
        {
          question_id: question.id,
          title: question.title,
          type: question.question_type,
          position: question.position,
          response_count: responses.count,
          completion_rate: calculate_question_completion_rate(question),
          average_response_time: responses.average(:response_time_ms),
          answer_distribution: analyze_answer_distribution(question, responses),
          quality_score: responses.average(:confidence_score),
          ai_insights: question.ai_enhanced? ? extract_question_ai_insights(question) : nil
        }
      end
    end
    
    def time_based_analysis
      daily_data = build_daily_metrics
      
      {
        daily_metrics: daily_data,
        peak_hours: identify_peak_hours,
        seasonal_patterns: identify_seasonal_patterns(daily_data),
        completion_time_trends: analyze_completion_time_trends
      }
    end
    
    def quality_analysis
      responses = recent_responses.completed.where.not(quality_score: nil)
      
      return {} if responses.empty?
      
      {
        average_quality_score: responses.average(:quality_score).round(2),
        quality_distribution: responses.group('FLOOR(quality_score * 10) / 10').count,
        high_quality_responses: responses.where('quality_score >= ?', 0.8).count,
        low_quality_responses: responses.where('quality_score < ?', 0.4).count,
        quality_improvement_suggestions: generate_quality_suggestions(responses)
      }
    end
    
    def ai_generated_insights
      return {} unless form.ai_enhanced?
      
      latest_analysis = form.form_analytics
                            .where(metric_type: 'ai_analysis')
                            .order(:date)
                            .last
      
      return {} unless latest_analysis&.ai_insights
      
      latest_analysis.ai_insights
    end
    
    # Helper methods
    
    def calculate_completion_rate(responses)
      return 0 if responses.count.zero?
      (responses.completed.count.to_f / responses.count * 100).round(2)
    end
    
    def calculate_abandonment_rate(responses)
      100 - calculate_completion_rate(responses)
    end
    
    def calculate_average_completion_time(completed_responses)
      return 0 if completed_responses.empty?
      
      completed_responses.where.not(completed_at: nil, started_at: nil)
                         .average('EXTRACT(EPOCH FROM (completed_at - started_at)) / 60')
                         .to_f
                         .round(2)
    end
    
    def calculate_average_quality_score(responses)
      responses.where.not(quality_score: nil).average(:quality_score).to_f.round(2)
    end
    
    def build_conversion_funnel
      total_views = form.views_count
      total_starts = recent_responses.count
      total_completions = recent_responses.completed.count
      
      [
        { stage: 'Views', count: total_views, percentage: 100 },
        { stage: 'Starts', count: total_starts, percentage: (total_starts.to_f / total_views * 100).round(1) },
        { stage: 'Completions', count: total_completions, percentage: (total_completions.to_f / total_views * 100).round(1) }
      ]
    end
    
    def identify_drop_off_points
      question_positions = form.form_questions.pluck(:position, :id).to_h
      
      drop_offs = question_positions.map do |position, question_id|
        responses_reached = recent_responses.joins(:question_responses)
                                          .where('form_questions.position >= ?', position)
                                          .distinct
                                          .count
        
        responses_answered = recent_responses.joins(:question_responses)
                                           .where(question_responses: { form_question_id: question_id })
                                           .count
        
        drop_off_rate = responses_reached > 0 ? ((responses_reached - responses_answered).to_f / responses_reached * 100).round(1) : 0
        
        {
          position: position,
          question_id: question_id,
          drop_off_rate: drop_off_rate,
          responses_reached: responses_reached,
          responses_answered: responses_answered
        }
      end
      
      drop_offs.sort_by { |d| -d[:drop_off_rate] }
    end
    
    def analyze_traffic_sources
      recent_responses.group(:referrer)
                     .count
                     .transform_keys { |ref| categorize_referrer(ref) }
                     .sort_by { |_, count| -count }
    end
    
    def categorize_referrer(referrer)
      return 'Direct' if referrer.blank?
      
      case referrer
      when /google\.com/ then 'Google'
      when /facebook\.com|fb\.com/ then 'Facebook'
      when /twitter\.com|t\.co/ then 'Twitter'
      when /linkedin\.com/ then 'LinkedIn'
      when /email/ then 'Email'
      else
        uri = URI.parse(referrer) rescue nil
        uri&.host || 'Unknown'
      end
    end
    
    def build_daily_metrics
      (period.ago.to_date..Date.current).map do |date|
        day_responses = recent_responses.where(created_at: date.beginning_of_day..date.end_of_day)
        
        {
          date: date,
          views: 0, # Would need view tracking implementation
          starts: day_responses.count,
          completions: day_responses.completed.count,
          completion_rate: calculate_completion_rate(day_responses),
          avg_time: calculate_average_completion_time(day_responses.completed)
        }
      end
    end
    
    def calculate_trend_direction
      recent_week = form.form_analytics.where('date >= ?', 7.days.ago)
      previous_week = form.form_analytics.where(date: 14.days.ago..7.days.ago)
      
      return 'stable' if recent_week.empty? || previous_week.empty?
      
      recent_completion_rate = recent_week.average(:completions_count) / recent_week.average(:starts_count) * 100
      previous_completion_rate = previous_week.average(:completions_count) / previous_week.average(:starts_count) * 100
      
      difference = recent_completion_rate - previous_completion_rate
      
      case difference
      when 5..Float::INFINITY then 'improving'
      when -5..5 then 'stable'
      else 'declining'
      end
    rescue
      'unknown'
    end
  end
end

# app/services/forms/ai_enhancement_service.rb
module Forms
  class AiEnhancementService
    attr_reader :question, :enhancement_type, :errors
    
    def initialize(question, enhancement_type)
      @question = question
      @enhancement_type = enhancement_type
      @errors = []
    end
    
    def enhance
      return failure("AI features not available") unless can_use_ai?
      return failure("Invalid enhancement type") unless valid_enhancement_type?
      
      case enhancement_type
      when 'smart_validation'
        enhance_with_smart_validation
      when 'dynamic_followups'
        enable_dynamic_followups
      when 'response_analysis'
        enable_response_analysis
      when 'auto_improvement'
        enable_auto_improvement
      else
        failure("Unknown enhancement type: #{enhancement_type}")
      end
    end
    
    private
    
    def can_use_ai?
      question.form.user.can_use_ai_features?
    end
    
    def valid_enhancement_type?
      %w[smart_validation dynamic_followups response_analysis auto_improvement].include?(enhancement_type)
    end
    
    def enhance_with_smart_validation
      # Add AI-powered validation to the question
      current_config = question.ai_enhancement || {}
      
      new_config = current_config.merge(
        'enabled' => true,
        'features' => (current_config['features'] || []) | ['smart_validation'],
        'smart_validation' => {
          'enabled' => true,
          'confidence_threshold' => 0.7,
          'provide_suggestions' => true,
          'context_aware' => true
        }
      )
      
      if question.update(ai_enhancement: new_config)
        success("Smart validation enabled for question")
      else
        failure("Failed to update question: #{question.errors.full_messages.join(', ')}")
      end
    end
    
    def enable_dynamic_followups
      current_config = question.ai_enhancement || {}
      
      new_config = current_config.merge(
        'enabled' => true,
        'features' => (current_config['features'] || []) | ['dynamic_followups'],
        'dynamic_followups' => {
          'enabled' => true,
          'max_followups' => 2,
          'trigger_conditions' => ['incomplete_answer', 'high_value_response'],
          'generation_model' => question.form.ai_model
        }
      )
      
      if question.update(ai_enhancement: new_config)
        success("Dynamic follow-ups enabled for question")
      else
        failure("Failed to update question: #{question.errors.full_messages.join(', ')}")
      end
    end
    
    def enable_response_analysis
      current_config = question.ai_enhancement || {}
      
      new_config = current_config.merge(
        'enabled' => true,
        'features' => (current_config['features'] || []) | ['response_analysis'],
        'response_analysis' => {
          'enabled' => true,
          'analyze_sentiment' => true,
          'analyze_intent' => true,
          'quality_scoring' => true,
          'extract_insights' => true
        }
      )
      
      if question.update(ai_enhancement: new_config)
        success("Response analysis enabled for question")
      else
        failure("Failed to update question: #{question.errors.full_messages.join(', ')}")
      end
    end
    
    def enable_auto_improvement
      current_config = question.ai_enhancement || {}
      
      new_config = current_config.merge(
        'enabled' => true,
        'features' => (current_config['features'] || []) | ['auto_improvement'],
        'auto_improvement' => {
          'enabled' => true,
          'analyze_performance' => true,
          'suggest_optimizations' => true,
          'auto_apply_safe_changes' => false, # Require manual approval
          'improvement_threshold' => 0.15 # 15% improvement needed
        }
      )
      
      if question.update(ai_enhancement: new_config)
        success("Auto-improvement enabled for question")
      else
        failure("Failed to update question: #{question.errors.full_messages.join(', ')}")
      end
    end
    
    def success(message)
      OpenStruct.new(success?: true, message: message, errors: [])
    end
    
    def failure(message)
      @errors << message
      OpenStruct.new(success?: false, message: message, errors: @errors, error_message: message)
    end
  end
end
```

## Phase 3: View Layer Implementation (Days 15-21)

### Day 15: Form Builder Interface

#### 15.1 Form Builder Layout
```erb
<!-- app/views/layouts/form_builder.html.erb -->
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <title><%= content_for(:title) || "Form Builder" %> | AgentForm</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "tailwind", data_turbo_track: "reload" %>
    <%= stylesheet_link_tag "application", data_turbo_track: "reload" %>
    <%= javascript_importmap_tags %>
    
    <!-- Form Builder Specific Styles -->
    <style>
      .question-item { transition: all 0.3s ease; }
      .question-item:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
      .ai-enhanced { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
      .drag-handle:hover { cursor: grab; }
      .drag-handle:active { cursor: grabbing; }
    </style>
  </head>

  <body class="h-full bg-gray-50">
    <div class="min-h-full">
      <!-- Header -->
      <header class="bg-white shadow-sm border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-4">
            <!-- Logo and Navigation -->
            <div class="flex items-center space-x-8">
              <%= link_to root_path, class: "flex items-center space-x-2" do %>
                <div class="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                  <span class="text-white font-bold text-sm">AF</span>
                </div>
                <span class="text-xl font-bold text-gray-900">AgentForm</span>
              <% end %>
              
              <nav class="hidden md:flex space-x-6">
                <%= link_to "Dashboard", forms_path, 
                    class: "text-gray-700 hover:text-gray-900 font-medium" %>
                <%= link_to "Templates", templates_path, 
                    class: "text-gray-700 hover:text-gray-900 font-medium" %>
                <%= link_to "Analytics", analytics_path, 
                    class: "text-gray-700 hover:text-gray-900 font-medium" %>
              </nav>
            </div>
            
            <!-- User Menu -->
            <div class="flex items-center space-x-4">
              <% if @form&.persisted? %>
                <div class="hidden sm:flex items-center space-x-3 text-sm text-gray-600">
                  <span>Status:</span>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium 
                              <%= status_badge_classes(@form.status) %>">
                    <%= @form.status.humanize %>
                  </span>
                  
                  <% if @form.published? %>
                    <span class="text-gray-400">|</span>
                    <span><%= pluralize(@form.responses_count, 'response') %></span>
                  <% end %>
                </div>
              <% end %>
              
              <!-- AI Credits Display -->
              <% if current_user.can_use_ai_features? %>
                <div class="flex items-center space-x-2 text-sm">
                  <div class="w-2 h-2 bg-green-400 rounded-full"></div>
                  <span class="text-gray-600">
                    <%= current_user.ai_credits_remaining %> AI credits
                  </span>
                </div>
              <% end %>
              
              <!-- User Dropdown -->
              <div class="relative" data-controller="dropdown">
                <button data-action="click->dropdown#toggle" 
                        class="flex items-center space-x-2 text-gray-700 hover:text-gray-900">
                  <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center">
                    <span class="text-sm font-medium">
                      <%= current_user.first_name&.first&.upcase || 'U' %>
                    </span>
                  </div>
                  <span class="hidden md:block"><%= current_user.full_name %></span>
                </button>
                
                <div data-dropdown-target="menu" class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50">
                  <%= link_to "Profile", edit_user_registration_path, 
                      class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" %>
                  <%= link_to "Settings", settings_path, 
                      class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" %>
                  <hr class="my-1">
                  <%= link_to "Sign out", destroy_user_session_path, method: :delete,
                      class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <%= yield %>
      </main>
    </div>
    
    <!-- Toast Notifications Container -->
    <div id="toast-container" class="fixed top-4 right-4 z-50 space-y-2"></div>
    
    <!-- Loading Overlay -->
    <div id="loading-overlay" class="hidden fixed inset-0 bg-gray-900 bg-opacity-50 z-40 flex items-center justify-center">
      <div class="bg-white rounded-lg p-6 flex items-center space-x-4">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="text-gray-900 font-medium">Processing...</span>
      </div>
    </div>
    
    <script>
      // Global form builder utilities
      window.FormBuilder = {
        showLoading: function() {
          document.getElementById('loading-overlay').classList.remove('hidden');
        },
        
        hideLoading: function() {
          document.getElementById('loading-overlay').classList.add('hidden');
        },
        
        showToast: function(message, type = 'info') {
          const toast = document.createElement('div');
          toast.className = `transform transition-all duration-300 translate-x-full opacity-0 
                            max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto 
                            ring-1 ring-black ring-opacity-5 p-4`;
          
          const colors = {
            success: 'border-l-4 border-green-400',
            error: 'border-l-4 border-red-400',
            warning: 'border-l-4 border-yellow-400',
            info: 'border-l-4 border-blue-400'
          };
          
          toast.className += ` ${colors[type] || colors.info}`;
          toast.innerHTML = `<p class="text-sm text-gray-900">${message}</p>`;
          
          document.getElementById('toast-container').appendChild(toast);
          
          // Animate in
          setTimeout(() => {
            toast.classList.remove('translate-x-full', 'opacity-0');
          }, 100);
          
          // Auto remove
          setTimeout(() => {
            toast.classList.add('translate-x-full', 'opacity-0');
            setTimeout(() => toast.remove(), 300);
          }, 5000);
        }
      };
    </script>
  </body>
</html>
```

#### 15.2 Form Edit Interface
```erb
<!-- app/views/forms/edit.html.erb -->
<% content_for :title, @form.name %>

<div class="space-y-6" data-controller="form-builder" data-form-id="<%= @form.id %>">
  <!-- Form Header -->
  <div class="bg-white rounded-lg shadow-sm border border-gray-200">
    <div class="px-6 py-4 border-b border-gray-200">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900"><%= @form.name %></h1>
          <p class="mt-1 text-sm text-gray-600">
            <%= @form.description.presence || "Configure your form questions and settings" %>
          </p>
        </div>
        
        <div class="flex items-center space-x-3">
          <%= link_to "Preview", preview_form_path(@form), 
              target: "_blank",
              class: "inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50" %>
          
          <% if @form.draft? %>
            <%= button_to "Publish", publish_form_path(@form), 
                method: :post,
                class: "inline-flex items-center px-4 py-2 bg-blue-600 border border-transparent rounded-md text-sm font-medium text-white hover:bg-blue-700",
                data: { confirm: "Are you sure you want to publish this form?" } %>
          <% else %>
            <%= button_to "Unpublish", unpublish_form_path(@form), 
                method: :post,
                class: "inline-flex items-center px-4 py-2 bg-gray-600 border border-transparent rounded-md text-sm font-medium text-white hover:bg-gray-700" %>
          <% end %>
        </div>
      </div>
    </div>
    
    <!-- Form Configuration Tabs -->
    <div class="px-6">
      <nav class="-mb-px flex space-x-8" data-controller="tabs" data-tabs-default-tab="questions">
        <button data-action="click->tabs#switch" data-tab="questions" 
                class="py-4 px-1 border-b-2 font-medium text-sm tab-button">
          Questions
        </button>
        <button data-action="click->tabs#switch" data-tab="settings"
                class="py-4 px-1 border-b-2 font-medium text-sm tab-button">
          Settings
        </button>
        <button data-action="click->tabs#switch" data-tab="ai"
                class="py-4 px-1 border-b-2 font-medium text-sm tab-button">
          AI Enhancement
        </button>
        <button data-action="click->tabs#switch" data-tab="style"
                class="py-4 px-1 border-b-2 font-medium text-sm tab-button">
          Style
        </button>
        <button data-action="click->tabs#switch" data-tab="integrations"
                class="py-4 px-1 border-b-2 font-medium text-sm tab-button">
          Integrations
        </button>
      </nav>
    </div>
  </div>
  
  <!-- Tab Content -->
  <div class="space-y-6">
    <!-- Questions Tab -->
    <div data-tabs-target="panel" data-tab="questions" class="space-y-6">
      <!-- Add Question Interface -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Questions</h3>
          <button data-action="click->form-builder#showAddQuestion"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 border border-transparent rounded-md text-sm font-medium text-white hover:bg-blue-700">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
            </svg>
            Add Question
          </button>
        </div>
        
        <!-- Questions List -->
        <div id="questions-list" data-controller="sortable" data-sortable-url="<%= bulk_update_form_questions_path(@form) %>">
          <% if @questions.empty? %>
            <div class="text-center py-12 text-gray-500">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No questions yet</h3>
              <p class="mt-1 text-sm text-gray-500">Get started by adding your first question.</p>
            </div>
          <% else %>
            <% @questions.each do |question| %>
              <%= render "form_questions/question_item", question: question %>
            <% end %>
          <% end %>
        </div>
      </div>
      
      <!-- Add Question Modal -->
      <div id="add-question-modal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 z-50" 
           data-controller="modal">
        <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <%= render "form_questions/new_question_form" %>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Settings Tab -->
    <div data-tabs-target="panel" data-tab="settings" class="hidden">
      <%= render "forms/settings_panel" %>
    </div>
    
    <!-- AI Enhancement Tab -->
    <div data-tabs-target="panel" data-tab="ai" class="hidden">
      <%= render "forms/ai_enhancement_panel" %>
    </div>
    
    <!-- Style Tab -->
    <div data-tabs-target="panel" data-tab="style" class="hidden">
      <%= render "forms/style_customization_panel" %>
    </div>
    
    <!-- Integrations Tab -->
    <div data-tabs-target="panel" data-tab="integrations" class="hidden">
      <%= render "forms/integrations_panel" %>
    </div>
  </div>
</div>

<script>
  // Form builder specific JavaScript
  document.addEventListener('DOMContentLoaded', function() {
    // Initialize form builder
    window.FormBuilderInstance = new FormBuilderManager({
      formId: '<%= @form.id %>',
      csrfToken: '<%= form_authenticity_token %>',
      questionTypes: <%= @question_types.to_json.html_safe %>
    });
  });
</script>
```

#### 15.3 Question Item Component
```erb
<!-- app/views/form_questions/_question_item.html.erb -->
<div id="question-<%= question.id %>" class="question-item group relative bg-white border border-gray-200 rounded-lg p-4 hover:border-gray-300" 
     data-question-id="<%= question.id %>" data-position="<%= question.position %>">
  
  <!-- Drag Handle -->
  <div class="absolute left-2 top-4 drag-handle opacity-0 group-hover:opacity-100 transition-opacity">
    <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
    </svg>
  </div>
  
  <!-- Question Content -->
  <div class="ml-6">
    <div class="flex items-start justify-between">
      <div class="flex-1">
        <!-- Question Header -->
        <div class="flex items-center space-x-3">
          <span class="inline-flex items-center justify-center w-6 h-6 bg-gray-100 text-gray-700 text-xs font-medium rounded-full">
            <%= question.position %>
          </span>
          
          <h3 class="text-lg font-medium text-gray-900">
            <%= question.title %>
            <% if question.required? %>
              <span class="text-red-500 ml-1">*</span>
            <% end %>
          </h3>
          
          <!-- Question Type Badge -->
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            <%= question.question_type.humanize %>
          </span>
          
          <!-- AI Enhancement Indicator -->
          <% if question.ai_enhanced? %>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-purple-100 to-pink-100 text-purple-800">
              <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              AI Enhanced
            </span>
          <% end %>
        </div>
        
        <!-- Question Description -->
        <% if question.description.present? %>
          <p class="mt-2 text-sm text-gray-600 ml-9">
            <%= simple_format(question.description) %>
          </p>
        <% end %>
        
        <!-- Configuration Preview -->
        <div class="mt-3 ml-9">
          <div class="flex flex-wrap items-center gap-2 text-xs text-gray-500">
            <% if question.validation_rules.present? %>
              <span class="bg-yellow-100 text-yellow-800 px-2 py-1 rounded">
                Has Validation
              </span>
            <% end %>
            
            <% if question.has_conditional_logic? %>
              <span class="bg-green-100 text-green-800 px-2 py-1 rounded">
                Conditional Logic
              </span>
            <% end %>
            
            <% if question.responses_count > 0 %>
              <span class="bg-gray-100 text-gray-700 px-2 py-1 rounded">
                <%= pluralize(question.responses_count, 'response') %>
              </span>
            <% end %>
          </div>
        </div>
      </div>
      
      <!-- Question Actions -->
      <div class="flex items-center space-x-2 opacity-0 group-hover:opacity-100 transition-opacity">
        <!-- Edit Button -->
        <%= link_to edit_form_question_path(@form, question), 
            remote: true,
            class: "p-2 text-gray-400 hover:text-gray-600 rounded-md hover:bg-gray-100",
            title: "Edit Question",
            data: { action: "click->form-builder#editQuestion" } do %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
          </svg>
        <% end %>
        
        <!-- Duplicate Button -->
        <%= link_to duplicate_form_question_path(@form, question), 
            method: :post,
            remote: true,
            class: "p-2 text-gray-400 hover:text-gray-600 rounded-md hover:bg-gray-100",
            title: "Duplicate Question" do %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
          </svg>
        <% end %>
        
        <!-- AI Enhancement Button -->
        <% if @form.ai_enhanced? && !question.ai_enhanced? %>
          <button data-action="click->form-builder#enhanceWithAI" 
                  data-question-id="<%= question.id %>"
                  class="p-2 text-purple-400 hover:text-purple-600 rounded-md hover:bg-purple-50"
                  title="Enhance with AI">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
            </svg>
          </button>
        <% end %>
        
        <!-- Delete Button -->
        <%= link_to form_question_path(@form, question), 
            method: :delete,
            remote: true,
            data: { 
              confirm: "Are you sure you want to delete this question?",
              action: "click->form-builder#deleteQuestion"
            },
            class: "p-2 text-red-400 hover:text-red-600 rounded-md hover:bg-red-50",
            title: "Delete Question" do %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
          </svg>
        <% end %>
      </div>
    </div>
  </div>
  
  <!-- Question Analytics (if available) -->
  <% if question.responses_count > 0 %>
    <div class="mt-4 ml-9 p-3 bg-gray-50 rounded-md">
      <div class="grid grid-cols-3 gap-4 text-sm">
        <div>
          <span class="text-gray-600">Completion Rate:</span>
          <span class="font-medium ml-1"><%= question.completion_rate.round(1) %>%</span>
        </div>
        <div>
          <span class="text-gray-600">Avg Time:</span>
          <span class="font-medium ml-1"><%= question.average_response_time_seconds.round(1) %>s</span>
        </div>
        <div>
          <span class="text-gray-600">Responses:</span>
          <span class="font-medium ml-1"><%= question.responses_count %></span>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

### Day 16: Form Response Interface

#### 16.1 Form Response Layout
```erb
<!-- app/views/layouts/form_response.html.erb -->
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <title><%= @form.name %> | AgentForm</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "tailwind", data_turbo_track: "reload" %>
    <%= stylesheet_link_tag "application", data_turbo_track: "reload" %>
    <%= javascript_importmap_tags %>
    
    <!-- Form-specific styling from form configuration -->
    <style>
      :root {
        --form-primary-color: <%= @form.style_configuration.dig('colors', 'primary') || '#3B82F6' %>;
        --form-secondary-color: <%= @form.style_configuration.dig('colors', 'secondary') || '#6366F1' %>;
        --form-background: <%= @form.style_configuration.dig('colors', 'background') || '#F9FAFB' %>;
      }
      
      .form-primary { background-color: var(--form-primary-color); }
      .form-primary-text { color: var(--form-primary-color); }
      .form-secondary { background-color: var(--form-secondary-color); }
      .form-bg { background-color: var(--form-background); }
      
      <% if @form.style_configuration.dig('custom_css').present? %>
        <%= @form.style_configuration['custom_css'].html_safe %>
      <% end %>
    </style>
    
    <!-- Analytics tracking -->
    <script>
      window.FormAnalytics = {
        formToken: '<%= @form.share_token %>',
        responseId: '<%= @response&.id %>',
        sessionId: '<%= @response&.session_id %>',
        startTime: Date.now(),
        events: []
      };
    </script>
  </head>

  <body class="h-full form-bg">
    <div class="min-h-full flex flex-col">
      <!-- Form Header -->
      <header class="bg-white shadow-sm">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="flex items-center justify-between">
            <!-- Form Title -->
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 form-primary rounded-lg flex items-center justify-center">
                <span class="text-white font-bold text-sm">
                  <%= @form.name.first.upcase %>
                </span>
              </div>
              <div>
                <h1 class="text-xl font-bold text-gray-900"><%= @form.name %></h1>
                <% if @form.description.present? %>
                  <p class="text-sm text-gray-600"><%= truncate(@form.description, length: 100) %></p>
                <% end %>
              </div>
            </div>
            
            <!-- Progress Indicator -->
            <% if @form.progress_bar_enabled? && @progress %>
              <div class="hidden sm:block">
                <div class="text-right text-sm text-gray-600 mb-1">
                  <%= @progress %>% complete
                </div>
                <div class="w-32 bg-gray-200 rounded-full h-2">
                  <div class="form-primary h-2 rounded-full transition-all duration-500" 
                       style="width: <%= @progress %>%"></div>
                </div>
              </div>
            <% end %>
          </div>
          
          <!-- Mobile Progress Bar -->
          <% if @form.progress_bar_enabled? && @progress %>
            <div class="sm:hidden mt-4">
              <div class="flex items-center justify-between text-sm text-gray-600 mb-2">
                <span>Progress</span>
                <span><%= @progress %>% complete</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="form-primary h-2 rounded-full transition-all duration-500" 
                     style="width: <%= @progress %>%"></div>
              </div>
            </div>
          <% end %>
        </div>
      </header>
      
      <!-- Main Form Content -->
      <main class="flex-1 max-w-3xl mx-auto w-full py-8 px-4 sm:px-6 lg:px-8">
        <div class="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
          <%= yield %>
        </div>
      </main>
      
      <!-- Form Footer -->
      <footer class="bg-white border-t border-gray-200">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="flex items-center justify-between text-sm text-gray-500">
            <div>
              Powered by <span class="font-medium form-primary-text">AgentForm</span>
            </div>
            
            <div class="flex items-center space-x-4">
              <% if @form.form_settings.dig('footer', 'show_question_count') != false %>
                <span>
                  Question <%= @current_question&.position || 1 %> of <%= @form.form_questions.count %>
                </span>
              <% end %>
              
              <% if @form.form_settings.dig('footer', 'show_time_estimate') == true %>
                <span>
                  ~ <%= estimated_time_remaining %> min remaining
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </footer>
    </div>
    
    <!-- Real-time Updates Container -->
    <div id="form-updates-<%= @form.share_token %>" data-controller="form-updates"></div>
    
    <!-- Analytics and Behavior Tracking -->
    <script>
      class FormTracker {
        constructor() {
          this.startTime = Date.now();
          this.questionStartTime = Date.now();
          this.events = [];
          this.setupEventListeners();
          this.trackPageView();
        }
        
        setupEventListeners() {
          // Track form interactions
          document.addEventListener('input', (e) => {
            if (e.target.matches('input, textarea, select')) {
              this.trackEvent('input_change', {
                field: e.target.name,
                timestamp: Date.now()
              });
            }
          });
          
          // Track focus events
          document.addEventListener('focusin', (e) => {
            if (e.target.matches('input, textarea, select')) {
              this.trackEvent('field_focus', {
                field: e.target.name,
                timestamp: Date.now()
              });
            }
          });
          
          // Track scroll behavior
          let scrollTimeout;
          window.addEventListener('scroll', () => {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(() => {
              this.trackEvent('scroll', {
                scrollY: window.scrollY,
                timestamp: Date.now()
              });
            }, 250);
          });
          
          // Track page visibility changes
          document.addEventListener('visibilitychange', () => {
            this.trackEvent('visibility_change', {
              hidden: document.hidden,
              timestamp: Date.now()
            });
          });
        }
        
        trackEvent(eventType, data = {}) {
          this.events.push({ type: eventType, data: data });
          
          // Send to server periodically
          if (this.events.length >= 10) {
            this.flushEvents();
          }
        }
        
        trackPageView() {
          this.trackEvent('question_view', {
            questionId: '<%= @current_question&.id %>',
            position: <%= @current_question&.position || 0 %>
          });
        }
        
        flushEvents() {
          if (this.events.length === 0) return;
          
          fetch('<%= analytics_event_path(@form.share_token) %>', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': '<%= form_authenticity_token %>'
            },
            body: JSON.stringify({
              event_type: 'batch_events',
              event_data: {
                events: this.events,
                session_duration: Date.now() - this.startTime
              }
            })
          });
          
          this.events = [];
        }
        
        onQuestionSubmit(responseTime) {
          this.trackEvent('question_submit', {
            questionId: '<%= @current_question&.id %>',
            responseTime: responseTime,
            timestamp: Date.now()
          });
          
          this.flushEvents();
        }
      }
      
      // Initialize tracker
      document.addEventListener('DOMContentLoaded', () => {
        window.formTracker = new FormTracker();
        
        // Track form submission timing
        const forms = document.querySelectorAll('form[data-track-submission]');
        forms.forEach(form => {
          form.addEventListener('submit', () => {
            const responseTime = Date.now() - window.formTracker.questionStartTime;
            window.formTracker.onQuestionSubmit(responseTime);
          });
        });
      });
      
      // Auto-save functionality
      <% if @form.auto_save_enabled? %>
        let autoSaveTimer;
        document.addEventListener('input', (e) => {
          if (e.target.matches('[data-auto-save]')) {
            clearTimeout(autoSaveTimer);
            autoSaveTimer = setTimeout(() => {
              const formData = new FormData();
              formData.append('draft_data', JSON.stringify({
                [e.target.name]: e.target.value
              }));
              
              fetch('<%= auto_save_path(@form.share_token, @current_question&.position) %>', {
                method: 'POST',
                headers: { 'X-CSRF-Token': '<%= form_authenticity_token %>' },
                body: formData
              });
            }, 2000);
          }
        });
      <% end %>
    </script>
  </body>
</html>
```

#### 16.2 Question Display View
```erb
<!-- app/views/responses/show.html.erb -->
<div class="p-8" data-controller="question-response" 
     data-question-id="<%= @current_question.id %>"
     data-question-type="<%= @current_question.question_type %>">
  
  <!-- Question Header -->
  <div class="mb-8">
    <% if @form.form_settings.dig('ui', 'show_question_numbers') != false %>
      <div class="text-sm font-medium form-primary-text mb-3">
        Question <%= @current_question.position %> of <%= @form.form_questions.count %>
      </div>
    <% end %>
    
    <h2 class="text-3xl font-bold text-gray-900 mb-4 leading-tight">
      <%= @current_question.title %>
      <% if @current_question.required? %>
        <span class="text-red-500 ml-2" title="Required">*</span>
      <% end %>
    </h2>
    
    <% if @current_question.description.present? %>
      <div class="text-lg text-gray-600 leading-relaxed mb-4">
        <%= simple_format(@current_question.description, class: "mb-2 last:mb-0") %>
      </div>
    <% end %>
    
    <% if @current_question.help_text.present? %>
      <div class="flex items-start space-x-2 p-3 bg-blue-50 border border-blue-200 rounded-md">
        <svg class="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path>
        </svg>
        <p class="text-sm text-blue-800">
          <%= simple_format(@current_question.help_text) %>
        </p>
      </div>
    <% end %>
  </div>
  
  <!-- Question Form -->
  <%= form_with model: [@form, @response], 
                url: answer_path(@form.share_token, @current_question.position),
                local: false,
                data: { 
                  turbo: false,
                  controller: "form-submission",
                  track_submission: true
                },
                class: "space-y-8" do |form| %>
    
    <!-- Question Input Area -->
    <div id="question-input-container" class="space-y-6">
      <%= render "question_types/#{@current_question.question_type}", 
                 question: @current_question, 
                 form: form,
                 existing_answer: existing_answer,
                 response: @response %>
    </div>
    
    <!-- Error Display -->
    <% if @errors&.any? %>
      <div class="rounded-md bg-red-50 border border-red-200 p-4" data-controller="error-display">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">
              Please correct the following:
            </h3>
            <div class="mt-2 text-sm text-red-700">
              <ul class="list-disc list-inside space-y-1">
                <% @errors.each do |error| %>
                  <li><%= error %></li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    
    <!-- AI Enhancement Indicators -->
    <% if @current_question.ai_enhanced? %>
      <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-4">
        <div class="flex items-center space-x-2">
          <svg class="w-5 h-5 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
          </svg>
          <span class="text-sm font-medium text-purple-800">AI-Enhanced Question</span>
        </div>
        <p class="mt-1 text-xs text-purple-700">
          This question uses AI to provide smart validation and may generate personalized follow-ups.
        </p>
      </div>
    <% end %>
    
    <!-- Navigation Buttons -->
    <div class="flex items-center justify-between pt-6 border-t border-gray-200">
      <!-- Back Button -->
      <% if @form.allow_back_navigation? && can_go_back? %>
        <%= link_to navigate_path(@form.share_token, direction: 'previous'),
            class: "inline-flex items-center px-6 py-3 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" do %>
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
          </svg>
          Back
        <% end %>
      <% else %>
        <div></div>
      <% end %>
      
      <!-- Next/Submit Button -->
      <div class="flex items-center space-x-4">
        <% if @form.form_settings.dig('ui', 'show_save_draft') == true %>
          <%= button_tag "Save Draft", 
              type: "button",
              data: { action: "click->form-submission#saveDraft" },
              class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50" %>
        <% end %>
        
        <%= form.submit determine_submit_button_text,
            data: { 
              action: "click->form-submission#submit",
              disable_with: "Processing..."
            },
            class: "inline-flex items-center px-8 py-3 form-primary border border-transparent rounded-md text-sm font-medium text-white hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all duration-200" %>
      </div>
    </div>
  <% end %>
  
  <!-- Dynamic Questions Container -->
  <div id="dynamic-questions-container" class="mt-8 space-y-6"></div>
  
  <!-- AI Processing Indicator -->
  <div id="ai-processing-indicator" class="hidden mt-6">
    <div class="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-4">
      <div class="flex items-center space-x-3">
        <div class="flex-shrink-0">
          <div class="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
        </div>
        <div>
          <p class="text-sm font-medium text-blue-900">AI is analyzing your response...</p>
          <p class="text-xs text-blue-700 mt-1">This may generate personalized follow-up questions.</p>
        </div>
      </div>
    </div>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    // Question-specific initialization
    const questionType = '<%= @current_question.question_type %>';
    const questionConfig = <%= @current_question.field_configuration.to_json.html_safe %>;
    
    // Initialize question type specific functionality
    if (window.QuestionTypes && window.QuestionTypes[questionType]) {
      new window.QuestionTypes[questionType](questionConfig);
    }
    
    // Show AI processing indicator if AI enhanced
    <% if @current_question.ai_enhanced? %>
      const form = document.querySelector('form[data-track-submission]');
      if (form) {
        form.addEventListener('submit', function() {
          document.getElementById('ai-processing-indicator').classList.remove('hidden');
        });
      }
    <% end %>
  });
</script>

<%# Helper methods for view %>
<%
  def existing_answer
    @response.question_responses.find_by(form_question: @current_question)&.answer_data
  end
  
  def can_go_back?
    @current_question.position > 1 && @response.question_responses.any?
  end
  
  def determine_submit_button_text
    if @current_question.position >= @form.form_questions.count
      "Complete Form"
    else

-----------------------------------------------------------------
# AgentForm Implementation Blueprint - Part 4

## Continuation from Part 3 - View Layer Implementation

### 16.2 Question Display View (Continued)

```erb
<%# Helper methods for view (continued) %>
<%
  def determine_submit_button_text
    if @current_question.position >= @form.form_questions.count
      "Complete Form"
    else
      "Next Question"
    end
  end
  
  def estimated_time_remaining
    questions_left = @form.form_questions.count - (@current_question.position || 1)
    avg_time_per_question = @form.average_completion_time_minutes / @form.form_questions.count
    (questions_left * avg_time_per_question).round
  end
%>
```

### Day 17: Question Type Components

#### 17.1 Text Input Components
```erb
<!-- app/views/question_types/_text_short.html.erb -->
<div class="space-y-4" data-controller="text-input" 
     data-text-input-min-length="<%= question.text_config[:min_length] %>"
     data-text-input-max-length="<%= question.text_config[:max_length] %>">
  
  <div class="relative">
    <%= form.text_field :answer_data, 
        value: existing_answer,
        placeholder: question.placeholder_text,
        maxlength: question.text_config[:max_length],
        required: question.required?,
        autocomplete: determine_autocomplete(question),
        data: { 
          auto_save: @form.auto_save_enabled?,
          action: "input->text-input#validateLength focus->text-input#trackFocus"
        },
        class: "block w-full px-4 py-3 text-lg border-2 border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 #{question.ai_enhanced? ? 'pr-12' : ''}" %>
    
    <!-- AI Enhancement Indicator -->
    <% if question.has_smart_validation? %>
      <div class="absolute right-3 top-3">
        <div class="w-6 h-6 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center">
          <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
          </svg>
        </div>
      </div>
    <% end %>
  </div>
  
  <!-- Character Counter -->
  <% if question.text_config[:max_length] %>
    <div class="flex justify-end">
      <span data-text-input-target="counter" class="text-sm text-gray-500">
        <span data-text-input-target="current">0</span> / <%= question.text_config[:max_length] %>
      </span>
    </div>
  <% end %>
  
  <!-- AI Suggestions (if enabled) -->
  <div id="ai-suggestions" data-text-input-target="suggestions" class="hidden">
    <div class="bg-blue-50 border border-blue-200 rounded-md p-3">
      <div class="flex items-start space-x-2">
        <svg class="w-4 h-4 text-blue-600 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium text-blue-900">AI Suggestion</p>
          <p data-text-input-target="suggestionText" class="text-sm text-blue-800 mt-1"></p>
        </div>
      </div>
    </div>
  </div>
  
  <%= hidden_field_tag 'response[metadata][response_time]', '', 
                      data: { text_input_target: 'responseTime' } %>
</div>

<script>
  // Text input specific functionality
  class TextInputController extends Application.Controller {
    static targets = ["counter", "current", "suggestions", "suggestionText", "responseTime"]
    static values = { 
      minLength: Number, 
      maxLength: Number 
    }
    
    connect() {
      this.startTime = Date.now()
      this.updateCounter()
      this.setupAIValidation()
    }
    
    validateLength() {
      this.updateCounter()
      this.checkAIValidation()
    }
    
    updateCounter() {
      if (this.hasCounterTarget) {
        const input = this.element.querySelector('input, textarea')
        const currentLength = input.value.length
        this.currentTarget.textContent = currentLength
        
        // Update styling based on length
        const remaining = this.maxLengthValue - currentLength
        if (remaining < 20) {
          this.counterTarget.classList.add('text-red-500')
          this.counterTarget.classList.remove('text-gray-500')
        } else {
          this.counterTarget.classList.remove('text-red-500')
          this.counterTarget.classList.add('text-gray-500')
        }
      }
    }
    
    trackFocus() {
      // Track when user focuses on the input
      window.formTracker?.trackEvent('field_focus', {
        questionId: '<%= question.id %>',
        questionType: 'text_short'
      })
    }
    
    setupAIValidation() {
      <% if question.has_smart_validation? %>
        let validationTimeout
        const input = this.element.querySelector('input, textarea')
        
        input.addEventListener('input', () => {
          clearTimeout(validationTimeout)
          validationTimeout = setTimeout(() => {
            this.requestAIValidation(input.value)
          }, 1500) // Wait for user to stop typing
        })
      <% end %>
    }
    
    checkAIValidation() {
      // Trigger AI validation if enabled and conditions met
      <% if question.has_smart_validation? %>
        const input = this.element.querySelector('input, textarea')
        if (input.value.length >= (<%= question.text_config[:min_length] || 5 %>)) {
          this.requestAIValidation(input.value)
        }
      <% end %>
    }
    
    requestAIValidation(value) {
      if (!value.trim()) return
      
      fetch('/forms/<%= @form.id %>/questions/<%= question.id %>/ai_validate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': '<%= form_authenticity_token %>'
        },
        body: JSON.stringify({
          answer: value,
          context: window.FormAnalytics
        })
      })
      .then(response => response.json())
      .then(data => this.handleAIValidation(data))
      .catch(error => console.warn('AI validation failed:', error))
    }
    
    handleAIValidation(data) {
      if (data.suggestions && data.suggestions.length > 0) {
        this.suggestionTextTarget.textContent = data.suggestions[0]
        this.suggestionsTarget.classList.remove('hidden')
      } else {
        this.suggestionsTarget.classList.add('hidden')
      }
    }
    
    disconnect() {
      // Record response time when leaving
      if (this.hasResponseTimeTarget) {
        const responseTime = Date.now() - this.startTime
        this.responseTimeTarget.value = responseTime
      }
    }
  }
  
  // Register the controller
  application.register("text-input", TextInputController)
</script>

<%
  def determine_autocomplete(question)
    case question.title.downcase
    when /first.?name/ then 'given-name'
    when /last.?name|surname/ then 'family-name'
    when /company|organization/ then 'organization'
    when /phone/ then 'tel'
    when /address/ then 'street-address'
    when /city/ then 'address-level2'
    when /zip|postal/ then 'postal-code'
    else 'off'
    end
  end
%>
```

#### 17.2 Multiple Choice Component
```erb
<!-- app/views/question_types/_multiple_choice.html.erb -->
<div class="space-y-4" data-controller="multiple-choice"
     data-multiple-choice-allows-multiple="<%= question.allows_multiple? %>"
     data-multiple-choice-max-selections="<%= question.choice_options.dig('max_selections') %>">
  
  <div class="space-y-3">
    <% question.display_options(@response.session_id.hash).each_with_index do |option, index| %>
      <label class="relative flex items-start p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-gray-300 hover:bg-gray-50 transition-all duration-200 group"
             data-multiple-choice-target="option"
             data-option-value="<%= option['value'] %>">
        
        <!-- Checkbox/Radio Input -->
        <% if question.allows_multiple? %>
          <%= check_box_tag 'response[answer_data][]', 
              option['value'],
              Array(existing_answer).include?(option['value']),
              data: { 
                action: "change->multiple-choice#handleSelection",
                multiple_choice_target: "input"
              },
              class: "h-4 w-4 text-blue-600 border-2 border-gray-300 rounded focus:ring-2 focus:ring-blue-500 mt-0.5" %>
        <% else %>
          <%= radio_button_tag 'response[answer_data]', 
              option['value'],
              existing_answer == option['value'],
              data: { 
                action: "change->multiple-choice#handleSelection",
                multiple_choice_target: "input"
              },
              class: "h-4 w-4 text-blue-600 border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 mt-0.5" %>
        <% end %>
        
        <!-- Option Content -->
        <div class="ml-4 flex-1">
          <div class="flex items-center justify-between">
            <span class="text-lg font-medium text-gray-900 group-hover:text-gray-700">
              <%= option['label'] %>
            </span>
            
            <!-- Option Icon (if configured) -->
            <% if option['icon'].present? %>
              <div class="w-8 h-8 flex items-center justify-center">
                <%= image_tag option['icon'], class: "w-6 h-6", alt: option['label'] if option['icon'].start_with?('http') %>
                <% unless option['icon'].start_with?('http') %>
                  <span class="text-2xl"><%= option['icon'] %></span>
                <% end %>
              </div>
            <% end %>
          </div>
          
          <!-- Option Description -->
          <% if option['description'].present? %>
            <p class="mt-1 text-sm text-gray-600">
              <%= option['description'] %>
            </p>
          <% end %>
          
          <!-- AI Enhancement: Show selection reasoning -->
          <% if question.ai_enhanced? && option['ai_reasoning'].present? %>
            <div class="mt-2 p-2 bg-purple-50 border border-purple-200 rounded text-xs text-purple-700">
              <strong>AI Insight:</strong> <%= option['ai_reasoning'] %>
            </div>
          <% end %>
        </div>
        
        <!-- Selection Indicator -->
        <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <div class="w-6 h-6 bg-blue-600 rounded-full flex items-center justify-center text-white text-xs font-bold">
            <%= index + 1 %>
          </div>
        </div>
      </label>
    <% end %>
    
    <!-- Other Option (if enabled) -->
    <% if question.has_other_option? %>
      <div class="relative">
        <label class="flex items-start p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-gray-300 transition-all duration-200"
               data-multiple-choice-target="otherOption">
          
          <% if question.allows_multiple? %>
            <%= check_box_tag 'response[answer_data][]', 
                'other',
                Array(existing_answer).include?('other'),
                data: { 
                  action: "change->multiple-choice#handleOtherSelection",
                  multiple_choice_target: "otherCheckbox"
                },
                class: "h-4 w-4 text-blue-600 border-2 border-gray-300 rounded focus:ring-2 focus:ring-blue-500 mt-0.5" %>
          <% else %>
            <%= radio_button_tag 'response[answer_data]', 
                'other',
                existing_answer == 'other',
                data: { 
                  action: "change->multiple-choice#handleOtherSelection",
                  multiple_choice_target: "otherRadio"  
                },
                class: "h-4 w-4 text-blue-600 border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 mt-0.5" %>
          <% end %>
          
          <div class="ml-4 flex-1">
            <span class="text-lg font-medium text-gray-900">Other</span>
            
            <!-- Other Text Input -->
            <div class="mt-2" data-multiple-choice-target="otherInput" 
                 style="<%= 'display: none;' unless Array(existing_answer).include?('other') %>">
              <%= text_field_tag 'response[other_text]', 
                  existing_answer.is_a?(Hash) ? existing_answer['other_text'] : '',
                  placeholder: "Please specify...",
                  data: { 
                    action: "input->multiple-choice#handleOtherText",
                    multiple_choice_target: "otherTextField"
                  },
                  class: "block w-full px-3 py-2 text-base border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent" %>
            </div>
          </div>
        </label>
      </div>
    <% end %>
  </div>
  
  <!-- Selection Limit Warning -->
  <div data-multiple-choice-target="warning" class="hidden">
    <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3">
      <p class="text-sm text-yellow-800">
        <span data-multiple-choice-target="warningText"></span>
      </p>
    </div>
  </div>
</div>

<script>
  class MultipleChoiceController extends Application.Controller {
    static targets = ["option", "input", "otherOption", "otherInput", "otherTextField", 
                     "otherCheckbox", "otherRadio", "warning", "warningText"]
    static values = { 
      allowsMultiple: Boolean,
      maxSelections: Number,
      minSelections: Number
    }
    
    connect() {
      this.updateSelectionCount()
    }
    
    handleSelection(event) {
      this.updateSelectionCount()
      this.trackSelection(event.target.value)
      
      // Hide other input if different option selected (for radio)
      if (!this.allowsMultipleValue && event.target.value !== 'other') {
        this.hideOtherInput()
      }
    }
    
    handleOtherSelection(event) {
      if (event.target.checked) {
        this.showOtherInput()
        this.trackSelection('other')
      } else {
        this.hideOtherInput()
      }
      this.updateSelectionCount()
    }
    
    handleOtherText(event) {
      // Enable/disable the other option based on text content
      const hasText = event.target.value.trim().length > 0
      const otherInput = this.hasOtherCheckboxTarget ? this.otherCheckboxTarget : this.otherRadioTarget
      
      if (hasText && !otherInput.checked) {
        otherInput.checked = true
        this.updateSelectionCount()
      }
    }
    
    updateSelectionCount() {
      if (!this.allowsMultipleValue) return
      
      const selectedCount = this.selectedInputs().length
      const maxSelections = this.maxSelectionsValue
      const minSelections = this.minSelectionsValue
      
      // Show/hide warning based on selection limits
      if (maxSelections && selectedCount >= maxSelections) {
        this.showWarning(`Maximum ${maxSelections} selections allowed`)
        this.disableUnselectedOptions()
      } else if (minSelections && selectedCount < minSelections) {
        this.showWarning(`Please select at least ${minSelections} options`)
        this.enableAllOptions()
      } else {
        this.hideWarning()
        this.enableAllOptions()
      }
    }
    
    selectedInputs() {
      return Array.from(this.inputTargets).filter(input => input.checked)
    }
    
    showWarning(message) {
      this.warningTextTarget.textContent = message
      this.warningTarget.classList.remove('hidden')
    }
    
    hideWarning() {
      this.warningTarget.classList.add('hidden')
    }
    
    showOtherInput() {
      if (this.hasOtherInputTarget) {
        this.otherInputTarget.style.display = 'block'
        this.otherTextFieldTarget.focus()
      }
    }
    
    hideOtherInput() {
      if (this.hasOtherInputTarget) {
        this.otherInputTarget.style.display = 'none'
        this.otherTextFieldTarget.value = ''
      }
    }
    
    disableUnselectedOptions() {
      this.inputTargets.forEach(input => {
        if (!input.checked) {
          input.disabled = true
          input.closest('label').classList.add('opacity-50', 'pointer-events-none')
        }
      })
    }
    
    enableAllOptions() {
      this.inputTargets.forEach(input => {
        input.disabled = false
        input.closest('label').classList.remove('opacity-50', 'pointer-events-none')
      })
    }
    
    trackSelection(value) {
      window.formTracker?.trackEvent('option_selected', {
        questionId: '<%= question.id %>',
        selectedValue: value,
        selectionCount: this.selectedInputs().length
      })
    }
  }
  
  application.register("multiple-choice", MultipleChoiceController)
</script>
```

#### 17.3 Rating Scale Component
```erb
<!-- app/views/question_types/_rating.html.erb -->
<div class="space-y-6" data-controller="rating-scale"
     data-rating-scale-min="<%= question.rating_config[:min] %>"
     data-rating-scale-max="<%= question.rating_config[:max] %>"
     data-rating-scale-current="<%= existing_answer %>">
  
  <!-- Scale Labels -->
  <div class="flex items-center justify-between text-sm text-gray-600 mb-4">
    <span><%= question.rating_config[:labels]['min'] || 'Poor' %></span>
    <span class="text-center font-medium">
      <span data-rating-scale-target="selectedLabel">Select a rating</span>
    </span>
    <span><%= question.rating_config[:labels]['max'] || 'Excellent' %></span>
  </div>
  
  <!-- Rating Scale -->
  <div class="flex items-center justify-center space-x-2 py-4">
    <% (question.rating_config[:min]..question.rating_config[:max]).each do |value| %>
      <label class="relative cursor-pointer group">
        <%= radio_button_tag 'response[answer_data]', 
            value,
            existing_answer.to_i == value,
            data: { 
              action: "change->rating-scale#selectRating",
              rating_scale_target: "input",
              rating_value: value
            },
            class: "sr-only" %>
        
        <!-- Visual Rating Button -->
        <div class="w-12 h-12 rounded-full border-2 border-gray-300 flex items-center justify-center text-lg font-medium transition-all duration-200 hover:border-blue-400 hover:bg-blue-50 group-hover:scale-110"
             data-rating-scale-target="button"
             data-rating-value="<%= value %>">
          
          <!-- Show number or custom icon -->
          <% if question.rating_config[:show_numbers] != false %>
            <%= value %>
          <% else %>
            <!-- Custom rating icons (stars, hearts, etc.) -->
            <div class="rating-icon" data-rating="<%= value %>">
              <%= render_rating_icon(question, value) %>
            </div>
          <% end %>
        </div>
        
        <!-- Custom Label -->
        <% if question.rating_config[:labels][value.to_s].present? %>
          <div class="absolute -bottom-6 left-1/2 transform -translate-x-1/2 text-xs text-gray-500 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity">
            <%= question.rating_config[:labels][value.to_s] %>
          </div>
        <% end %>
      </label>
    <% end %>
  </div>
  
  <!-- Selected Value Display -->
  <div class="text-center">
    <div data-rating-scale-target="selectedDisplay" class="hidden">
      <div class="inline-flex items-center space-x-2 px-4 py-2 bg-blue-50 border border-blue-200 rounded-lg">
        <span class="text-blue-800 font-medium">Selected:</span>
        <span data-rating-scale-target="selectedValue" class="text-blue-900 font-bold text-lg"></span>
        <span class="text-blue-700">/ <%= question.rating_config[:max] %></span>
      </div>
    </div>
  </div>
  
  <!-- AI Analysis Display -->
  <% if question.ai_enhanced? %>
    <div id="rating-ai-analysis" class="hidden mt-4">
      <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-4">
        <div class="flex items-center space-x-2 mb-2">
          <svg class="w-4 h-4 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
          </svg>
          <span class="text-sm font-medium text-purple-900">AI Insight</span>
        </div>
        <p id="rating-ai-insight" class="text-sm text-purple-800"></p>
      </div>
    </div>
  <% end %>
</div>

<script>
  class RatingScaleController extends Application.Controller {
    static targets = ["input", "button", "selectedDisplay", "selectedValue", "selectedLabel"]
    static values = { min: Number, max: Number, current: Number }
    
    connect() {
      this.updateDisplay()
      if (this.currentValue) {
        this.selectRating({ target: { dataset: { ratingValue: this.currentValue } } })
      }
    }
    
    selectRating(event) {
      const selectedValue = parseInt(event.target.dataset.ratingValue)
      this.currentValue = selectedValue
      
      // Update visual state
      this.updateButtonStates(selectedValue)
      this.updateSelectedDisplay(selectedValue)
      this.trackRating(selectedValue)
      
      // Trigger AI analysis if enabled
      <% if question.ai_enhanced? %>
        this.requestAIAnalysis(selectedValue)
      <% end %>
    }
    
    updateButtonStates(selectedValue) {
      this.buttonTargets.forEach(button => {
        const buttonValue = parseInt(button.dataset.ratingValue)
        const isSelected = buttonValue === selectedValue
        const isInRange = buttonValue <= selectedValue
        
        if (isSelected) {
          button.classList.add('border-blue-500', 'bg-blue-500', 'text-white', 'scale-110')
          button.classList.remove('border-gray-300', 'bg-white', 'text-gray-700')
        } else if (isInRange && this.useRangeHighlighting()) {
          button.classList.add('border-blue-300', 'bg-blue-100', 'text-blue-700')
          button.classList.remove('border-gray-300', 'bg-white', 'text-gray-700')
        } else {
          button.classList.remove('border-blue-500', 'bg-blue-500', 'text-white', 'scale-110',
                                  'border-blue-300', 'bg-blue-100', 'text-blue-700')
          button.classList.add('border-gray-300', 'bg-white', 'text-gray-700')
        }
      })
    }
    
    updateSelectedDisplay(selectedValue) {
      if (this.hasSelectedDisplayTarget) {
        this.selectedDisplayTarget.classList.remove('hidden')
        this.selectedValueTarget.textContent = selectedValue
      }
      
      if (this.hasSelectedLabelTarget) {
        this.selectedLabelTarget.textContent = this.getRatingLabel(selectedValue)
      }
    }
    
    useRangeHighlighting() {
      // For star ratings or other sequential scales
      return <%= question.rating_config[:style] == 'stars' ? 'true' : 'false' %>
    }
    
    getRatingLabel(value) {
      const labels = <%= question.rating_config[:labels].to_json.html_safe %>
      return labels[value.toString()] || `${value} / <%= question.rating_config[:max] %>`
    }
    
    trackRating(value) {
      window.formTracker?.trackEvent('rating_selected', {
        questionId: '<%= question.id %>',
        ratingValue: value,
        scale: '<%= question.rating_config[:min] %>-<%= question.rating_config[:max] %>'
      })
    }
    
    requestAIAnalysis(value) {
      // Request AI analysis of rating context
      fetch('/forms/<%= @form.id %>/questions/<%= question.id %>/ai_analyze_rating', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': '<%= form_authenticity_token %>'
        },
        body: JSON.stringify({
          rating: value,
          context: window.FormAnalytics,
          previous_answers: <%= @response.answers_hash.to_json.html_safe %>
        })
      })
      .then(response => response.json())
      .then(data => this.displayAIAnalysis(data))
      .catch(error => console.warn('AI analysis failed:', error))
    }
    
    displayAIAnalysis(data) {
      if (data.insight) {
        document.getElementById('rating-ai-insight').textContent = data.insight
        document.getElementById('rating-ai-analysis').classList.remove('hidden')
      }
    }
  }
  
  application.register("rating-scale", RatingScaleController)
</script>

<%
  def render_rating_icon(question, value)
    style = question.rating_config[:icon_style] || 'stars'
    
    case style
    when 'stars'
      content_tag :svg, class: "w-6 h-6 fill-current", viewBox: "0 0 20 20" do
        content_tag :path, '', d: "M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
      end
    when 'hearts'
      '❤️'
    when 'thumbs'
      value > (question.rating_config[:max] / 2) ? '👍' : '👎'
    else
      value.to_s
    end
  end
%>
```

### Day 18-19: JavaScript Controllers and Stimulus Components

#### 18.1 Form Builder Controller
```javascript
// app/javascript/controllersa

-----------------------------------------------------------------------------

### Day 18-19: JavaScript Controllers and Stimulus Components

#### 18.1 Form Builder Controller
```javascript
// app/javascript/controllers/form_builder_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionsContainer", "addQuestionModal", "questionForm"]
  static values = { formId: String }
  
  connect() {
    this.setupSortable()
    this.setupShortcuts()
  }
  
  // Question Management
  showAddQuestion() {
    this.addQuestionModalTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }
  
  hideAddQuestion() {
    this.addQuestionModalTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }
  
  async addQuestion(event) {
    event.preventDefault()
    
    const formData = new FormData(event.target)
    const questionType = formData.get('question_type')
    
    try {
      FormBuilder.showLoading()
      
      const response = await fetch(`/forms/${this.formIdValue}/questions`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken(),
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (response.ok) {
        const result = await response.json()
        this.appendQuestion(result.question)
        this.hideAddQuestion()
        this.resetQuestionForm()
        FormBuilder.showToast('Question added successfully!', 'success')
      } else {
        const errors = await response.json()
        this.displayErrors(errors.errors)
      }
    } catch (error) {
      FormBuilder.showToast('Failed to add question. Please try again.', 'error')
    } finally {
      FormBuilder.hideLoading()
    }
  }
  
  async editQuestion(event) {
    event.preventDefault()
    
    const questionId = event.target.closest('[data-question-id]').dataset.questionId
    
    try {
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}/edit`, {
        headers: { 'Accept': 'text/vnd.turbo-stream.html' }
      })
      
      if (response.ok) {
        const turboStream = await response.text()
        Turbo.renderStreamMessage(turboStream)
      }
    } catch (error) {
      FormBuilder.showToast('Failed to load question editor', 'error')
    }
  }
  
  async deleteQuestion(event) {
    event.preventDefault()
    
    if (!confirm('Are you sure you want to delete this question? This action cannot be undone.')) {
      return
    }
    
    const questionElement = event.target.closest('[data-question-id]')
    const questionId = questionElement.dataset.questionId
    
    try {
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.csrfToken(),
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        questionElement.style.opacity = '0'
        questionElement.style.transform = 'translateX(-100%)'
        
        setTimeout(() => {
          questionElement.remove()
          this.reorderQuestions()
        }, 300)
        
        FormBuilder.showToast('Question deleted', 'success')
      } else {
        FormBuilder.showToast('Failed to delete question', 'error')
      }
    } catch (error) {
      FormBuilder.showToast('Failed to delete question', 'error')
    }
  }
  
  async enhanceWithAI(event) {
    const questionId = event.target.dataset.questionId
    const enhancementType = await this.selectEnhancementType()
    
    if (!enhancementType) return
    
    try {
      FormBuilder.showLoading()
      
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}/ai_enhance`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({
          enhancement_type: enhancementType
        })
      })
      
      if (response.ok) {
        const result = await response.json()
        FormBuilder.showToast(`${enhancementType.replace('_', ' ')} enabled!`, 'success')
        
        // Update question visual indicators
        const questionElement = document.querySelector(`[data-question-id="${questionId}"]`)
        this.addAIIndicator(questionElement)
      } else {
        const error = await response.json()
        FormBuilder.showToast(error.message, 'error')
      }
    } catch (error) {
      FormBuilder.showToast('AI enhancement failed', 'error')
    } finally {
      FormBuilder.hideLoading()
    }
  }
  
  // UI Enhancement Methods
  setupSortable() {
    if (typeof Sortable !== 'undefined') {
      new Sortable(this.questionsContainerTarget, {
        animation: 150,
        handle: '.drag-handle',
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        onEnd: (evt) => {
          this.handleQuestionReorder(evt)
        }
      })
    }
  }
  
  setupShortcuts() {
    document.addEventListener('keydown', (event) => {
      if (event.ctrlKey || event.metaKey) {
        switch (event.key) {
          case 'n':
            event.preventDefault()
            this.showAddQuestion()
            break
          case 's':
            event.preventDefault()
            this.saveForm()
            break
          case 'p':
            event.preventDefault()
            this.previewForm()
            break
        }
      }
      
      if (event.key === 'Escape') {
        this.hideAddQuestion()
      }
    })
  }
  
  async handleQuestionReorder(evt) {
    const questionId = evt.item.dataset.questionId
    const newPosition = evt.newIndex + 1
    
    try {
      await fetch(`/forms/${this.formIdValue}/questions/${questionId}/reorder`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({
          new_position: newPosition
        })
      })
      
      this.reorderQuestions()
      FormBuilder.showToast('Questions reordered', 'success')
    } catch (error) {
      FormBuilder.showToast('Failed to reorder questions', 'error')
      // Revert visual change
      location.reload()
    }
  }
  
  async selectEnhancementType() {
    return new Promise((resolve) => {
      const modal = document.createElement('div')
      modal.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 z-50 flex items-center justify-center'
      modal.innerHTML = `
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Choose AI Enhancement</h3>
          <div class="space-y-3">
            <button data-enhancement="smart_validation" class="w-full text-left p-3 border border-gray-200 rounded-md hover:border-blue-300">
              <div class="font-medium">Smart Validation</div>
              <div class="text-sm text-gray-600">AI-powered input validation and suggestions</div>
            </button>
            <button data-enhancement="dynamic_followups" class="w-full text-left p-3 border border-gray-200 rounded-md hover:border-blue-300">
              <div class="font-medium">Dynamic Follow-ups</div>
              <div class="text-sm text-gray-600">Generate contextual follow-up questions</div>
            </button>
            <button data-enhancement="response_analysis" class="w-full text-left p-3 border border-gray-200 rounded-md hover:border-blue-300">
              <div class="font-medium">Response Analysis</div>
              <div class="text-sm text-gray-600">Analyze sentiment and extract insights</div>
            </button>
          </div>
          <div class="mt-6 flex justify-end space-x-3">
            <button id="cancel-enhancement" class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50">Cancel</button>
          </div>
        </div>
      `
      
      document.body.appendChild(modal)
      
      modal.addEventListener('click', (e) => {
        if (e.target.dataset.enhancement) {
          resolve(e.target.dataset.enhancement)
          modal.remove()
        } else if (e.target.id === 'cancel-enhancement' || e.target === modal) {
          resolve(null)
          modal.remove()
        }
      })
    })
  }
  
  // Helper Methods
  appendQuestion(questionData) {
    // Create and append new question element
    const questionElement = this.createQuestionElement(questionData)
    this.questionsContainerTarget.appendChild(questionElement)
    
    // Animate in
    questionElement.style.opacity = '0'
    questionElement.style.transform = 'translateY(20px)'
    
    setTimeout(() => {
      questionElement.style.opacity = '1'
      questionElement.style.transform = 'translateY(0)'
    }, 50)
  }
  
  createQuestionElement(questionData) {
    const element = document.createElement('div')
    element.innerHTML = questionData.html
    return element.firstElementChild
  }
  
  reorderQuestions() {
    const questions = Array.from(this.questionsContainerTarget.children)
    questions.forEach((element, index) => {
      const positionElement = element.querySelector('[data-position]')
      if (positionElement) {
        positionElement.dataset.position = index + 1
        positionElement.textContent = index + 1
      }
    })
  }
  
  addAIIndicator(questionElement) {
    const header = questionElement.querySelector('.question-header')
    if (header && !header.querySelector('.ai-indicator')) {
      const indicator = document.createElement('span')
      indicator.className = 'ai-indicator inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-purple-100 to-pink-100 text-purple-800'
      indicator.innerHTML = `
        <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        AI Enhanced
      `
      header.appendChild(indicator)
    }
  }
  
  resetQuestionForm() {
    if (this.hasQuestionFormTarget) {
      this.questionFormTarget.reset()
    }
  }
  
  displayErrors(errors) {
    // Display validation errors in the form
    const errorContainer = document.getElementById('question-form-errors')
    if (errorContainer && errors) {
      errorContainer.innerHTML = Object.entries(errors)
        .map(([field, messages]) => `<li>${field}: ${messages.join(', ')}</li>`)
        .join('')
      errorContainer.parentElement.classList.remove('hidden')
    }
  }
  
  previewForm() {
    window.open(`/forms/${this.formIdValue}/preview`, '_blank')
  }
  
  async saveForm() {
    // Auto-save form configuration
    try {
      FormBuilder.showToast('Saving...', 'info')
      // Implementation would depend on form auto-save strategy
    } catch (error) {
      FormBuilder.showToast('Auto-save failed', 'error')
    }
  }
  
  csrfToken() {
    return document.querySelector('[name="csrf-token"]').content
  }
}
```

#### 18.2 Form Response Controller
```javascript
// app/javascript/controllers/form_response_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressBar", "questionContainer", "navigationButtons"]
  static values = { 
    formToken: String,
    responseId: String,
    currentPosition: Number,
    totalQuestions: Number
  }
  
  connect() {
    this.setupAutoSave()
    this.setupProgressTracking()
    this.trackQuestionView()
  }
  
  // Navigation Methods
  async nextQuestion(event) {
    event.preventDefault()
    
    if (!this.validateCurrentQuestion()) {
      return false
    }
    
    this.showNavigationLoading()
    
    try {
      const formData = this.gatherFormData()
      const response = await this.submitAnswer(formData)
      
      if (response.ok) {
        const result = await response.json()
        
        if (result.next_question_url) {
          window.location.href = result.next_question_url
        } else if (result.completion_url) {
          window.location.href = result.completion_url
        }
      } else {
        const errors = await response.json()
        this.displayErrors(errors.errors)
      }
    } catch (error) {
      this.showError('Failed to submit answer. Please try again.')
    } finally {
      this.hideNavigationLoading()
    }
  }
  
  async previousQuestion() {
    const previousUrl = `/forms/${this.formTokenValue}/navigate?direction=previous&position=${this.currentPositionValue}`
    window.location.href = previousUrl
  }
  
  async jumpToQuestion(position) {
    if (position > this.currentPositionValue) {
      this.showError('Cannot jump ahead to unanswered questions')
      return
    }
    
    const jumpUrl = `/forms/${this.formTokenValue}/navigate?direction=jump&position=${position}`
    window.location.href = jumpUrl
  }
  
  // Form Validation
  validateCurrentQuestion() {
    const form = this.element.querySelector('form')
    const requiredFields = form.querySelectorAll('[required]')
    
    for (const field of requiredFields) {
      if (!this.isFieldValid(field)) {
        this.highlightField(field, 'error')
        this.showError(`Please complete the required field: ${this.getFieldLabel(field)}`)
        return false
      }
    }
    
    return true
  }
  
  isFieldValid(field) {
    switch (field.type) {
      case 'email':
        return field.value && this.isValidEmail(field.value)
      case 'number':
        return field.value && !isNaN(parseFloat(field.value))
      case 'radio':
        const radioGroup = form.querySelectorAll(`[name="${field.name}"]`)
        return Array.from(radioGroup).some(radio => radio.checked)
      case 'checkbox':
        if (field.name.endsWith('[]')) {
          const checkboxGroup = form.querySelectorAll(`[name="${field.name}"]`)
          return Array.from(checkboxGroup).some(checkbox => checkbox.checked)
        }
        return field.checked
      default:
        return field.value.trim().length > 0
    }
  }
  
  // Auto-Save Functionality
  setupAutoSave() {
    let autoSaveTimer
    
    this.element.addEventListener('input', (event) => {
      if (event.target.matches('[data-auto-save]')) {
        clearTimeout(autoSaveTimer)
        
        autoSaveTimer = setTimeout(() => {
          this.performAutoSave(event.target)
        }, 2000)
      }
    })
  }
  
  async performAutoSave(field) {
    const draftData = {
      [field.name]: field.value,
      question_id: this.getCurrentQuestionId(),
      timestamp: new Date().toISOString()
    }
    
    try {
      await fetch(`/forms/${this.formTokenValue}/auto_save`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({ draft_data: draftData })
      })
      
      this.showAutoSaveIndicator()
    } catch (error) {
      console.warn('Auto-save failed:', error)
    }
  }
  
  // Progress Tracking
  setupProgressTracking() {
    this.startTime = Date.now()
    this.questionStartTime = Date.now()
    
    // Track scroll depth
    this.maxScrollDepth = 0
    window.addEventListener('scroll', () => {
      const scrollDepth = (window.scrollY + window.innerHeight) / document.documentElement.scrollHeight
      this.maxScrollDepth = Math.max(this.maxScrollDepth, scrollDepth)
    })
  }
  
  trackQuestionView() {
    this.analytics().trackEvent('question_view', {
      position: this.currentPositionValue,
      question_id: this.getCurrentQuestionId(),
      timestamp: Date.now()
    })
  }
  
  // AI Integration
  async requestAIAssistance(questionType, userInput) {
    if (!this.aiEnabled()) return null
    
    try {
      const response = await fetch(`/forms/${this.formTokenValue}/ai_assist`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({
          question_id: this.getCurrentQuestionId(),
          question_type: questionType,
          user_input: userInput,
          context: this.gatherFormContext()
        })
      })
      
      return response.ok ? await response.json() : null
    } catch (error) {
      console.warn('AI assistance request failed:', error)
      return null
    }
  }
  
  // Utility Methods
  gatherFormData() {
    const form = this.element.querySelector('form')
    return new FormData(form)
  }
  
  gatherFormContext() {
    return {
      session_id: this.responseIdValue,
      current_position: this.currentPositionValue,
      total_questions: this.totalQuestionsValue,
      time_on_question: Date.now() - this.questionStartTime,
      scroll_depth: this.maxScrollDepth
    }
  }
  
  async submitAnswer(formData) {
    const submitUrl = this.element.querySelector('form').action
    
    return fetch(submitUrl, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken(),
        'Accept': 'application/json'
      },
      body: formData
    })
  }
  
  showNavigationLoading() {
    const submitButton = this.element.querySelector('[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.textContent = 'Processing...'
    }
  }
  
  hideNavigationLoading() {
    const submitButton = this.element.querySelector('[type="submit"]')
    if (submitButton) {
      submitButton.disabled = false
      submitButton.textContent = submitButton.dataset.originalText || 'Next'
    }
  }
  
  highlightField(field, type = 'error') {
    const colors = {
      error: ['border-red-500', 'ring-red-500'],
      success: ['border-green-500', 'ring-green-500'],
      warning: ['border-yellow-500', 'ring-yellow-500']
    }
    
    field.classList.remove('border-gray-200', 'border-red-500', 'border-green-500', 'border-yellow-500')
    field.classList.add(...colors[type])
    
    setTimeout(() => {
      field.classList.remove(...colors[type])
      field.classList.add('border-gray-200')
    }, 3000)
  }
  
  showAutoSaveIndicator() {
    let indicator = document.getElementById('auto-save-indicator')
    
    if (!indicator) {
      indicator = document.createElement('div')
      indicator.id = 'auto-save-indicator'
      indicator.className = 'fixed bottom-4 right-4 bg-green-100 border border-green-300 rounded-md px-3 py-2 text-sm text-green-800 z-40'
      indicator.innerHTML = `
        <div class="flex items-center space-x-2">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
          <span>Auto-saved</span>
        </div>
      `
      document.body.appendChild(indicator)
    }
    
    indicator.style.opacity = '1'
    
    setTimeout(() => {
      indicator.style.opacity = '0'
      setTimeout(() => indicator.remove(), 300)
    }, 2000)
  }
  
  showError(message) {
    FormBuilder.showToast(message, 'error')
  }
  
  displayErrors(errors) {
    if (Array.isArray(errors)) {
      errors.forEach(error => this.showError(error))
    } else if (typeof errors === 'object') {
      Object.values(errors).flat().forEach(error => this.showError(error))
    } else {
      this.showError(errors.toString())
    }
  }
  
  getCurrentQuestionId() {
    return this.element.dataset.questionId
  }
  
  getFieldLabel(field) {
    const label = this.element.querySelector(`label[for="${field.id}"]`)
    return label ? label.textContent.trim() : field.name
  }
  
  isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }
  
  aiEnabled() {
    return this.element.dataset.aiEnabled === 'true'
  }
  
  analytics() {
    return window.formTracker || { trackEvent: () => {} }
  }
  
  csrfToken() {
    return document.querySelector('[name="csrf-token"]').content
  }
}
```

### Day 20: Advanced UI Components

#### 20.1 AI Enhancement Panel Component
```erb
<!-- app/views/forms/_ai_enhancement_panel.html.erb -->
<div class="space-y-6" data-controller="ai-enhancement">
  <!-- AI Status Overview -->
  <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-6">
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-3">
        <div class="w-12 h-12 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
          </svg>
        </div>
        <div>
          <h3 class="text-lg font-medium text-gray-900">AI Enhancement</h3>
          <p class="text-sm text-gray-600">
            <% if @form.ai_enhanced? %>
              AI features are <span class="font-medium text-green-600">enabled</span> for this form
            <% else %>
              AI features are <span class="font-medium text-gray-600">disabled</span> for this form
            <% end %>
          </p>
        </div>
      </div>
      
      <!-- Master AI Toggle -->
      <div class="flex items-center">
        <%= form_with model: @form, url: form_path(@form), method: :patch, local: false, 
                     data: { controller: "ai-toggle", action: "change->ai-toggle#handleMasterToggle" } do |f| %>
          <label class="relative inline-flex items-center cursor-pointer">
            <%= f.check_box :ai_enhanced, 
                { checked: @form.ai_enhanced?, 
                  data: { ai_toggle_target: "masterSwitch" } },
                { class: "sr-only" } %>
            <div class="w-14 h-8 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-purple-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-7 after:w-7 after:transition-all peer-checked:bg-purple-600"></div>
          </label>
        <% end %>
      </div>
    </div>
    
    <!-- AI Usage Statistics -->
    <div class="mt-4 grid grid-cols-3 gap-4">
      <div class="text-center">
        <div class="text-2xl font-bold text-purple-600">
          <%= current_user.ai_credits_remaining %>
        </div>
        <div class="text-xs text-gray-600">Credits Remaining</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-pink-600">
          <%= @form.estimated_ai_cost_per_response.round(3) %>
        </div>
        <div class="text-xs text-gray-600">Cost Per Response</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-indigo-600">
          <%= @form.ai_features_enabled.size %>
        </div>
        <div class="text-xs text-gray-600">Active Features</div>
      </div>
    </div>
  </div>
  
  <!-- AI Features Configuration -->
  <% if @form.ai_enhanced? %>
    <div class="bg-white border border-gray-200 rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <h4 class="text-lg font-medium text-gray-900">AI Features</h4>
        <p class="mt-1 text-sm text-gray-600">
          Configure which AI capabilities to enable for your form
        </p>
      </div>
      
      <div class="p-6 space-y-6">
        <!-- Global AI Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- AI Model Selection -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              AI Model
            </label>
            <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
              <%= f.select 'ai_configuration[model]', 
                  options_for_select([
                    ['GPT-4o Mini (Fast, Cost-effective)', 'gpt-4o-mini'],
                    ['GPT-4o (Balanced)', 'gpt-4o'],
                    ['GPT-4 (Highest Quality)', 'gpt-4'],
                    ['Claude 3.5 Sonnet', 'claude-3-5-sonnet-20241022'],
                    ['Claude 3 Haiku (Fast)', 'claude-3-haiku-20240307']
                  ], @form.ai_model),
                  {},
                  { 
                    class: "block w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500",
                    data: { action: "change->ai-enhancement#updateModel" }
                  } %>
            <% end %>
          </div>
          
          <!-- Budget Limit -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Budget Limit (per form)
            </label>
            <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
              <%= f.number_field 'ai_configuration[budget_limit]', 
                  value: @form.ai_configuration.dig('budget_limit') || 10.0,
                  step: 0.1,
                  min: 0.1,
                  class: "block w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500",
                  data: { action: "change->ai-enhancement#updateBudget" } %>
            <% end %>
            <p class="mt-1 text-xs text-gray-500">
              Maximum AI credits to spend per form response
            </p>
          </div>
        </div>
        
        <!-- Feature Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Smart Validation -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-purple-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2# AgentForm Implementation Blueprint - Part 4

## Continuation from Part 3 - View Layer Implementation

### 16.2 Question Display View (Continued)

```erb
<%# Helper methods for view (continued) %>
<%
  def determine_submit_button_text
    if @current_question.position >= @form.form_questions.count
      "Complete Form"
    else
      "Next Question"
    end
  end
  
  def estimated_time_remaining
    questions_left = @form.form_questions.count - (@current_question.position || 1)
    avg_time_per_question = @form.average_completion_time_minutes / @form.form_questions.count
    (questions_left * avg_time_per_question).round
  end
%>
```

### Day 17: Question Type Components

#### 17.1 Text Input Components
```erb
<!-- app/views/question_types/_text_short.html.erb -->
<div class="space-y-4" data-controller="text-input" 
     data-text-input-min-length="<%= question.text_config[:min_length] %>"
     data-text-input-max-length="<%= question.text_config[:max_length] %>">
  
  <div class="relative">
    <%= form.text_field :answer_data, 
        value: existing_answer,
        placeholder: question.placeholder_text,
        maxlength: question.text_config[:max_length],
        required: question.required?,
        autocomplete: determine_autocomplete(question),
        data: { 
          auto_save: @form.auto_save_enabled?,
          action: "input->text-input#validateLength focus->text-input#trackFocus"
        },
        class: "block w-full px-4 py-3 text-lg border-2 border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 #{question.ai_enhanced? ? 'pr-12' : ''}" %>
    
    <!-- AI Enhancement Indicator -->
    <% if question.has_smart_validation? %>
      <div class="absolute right-3 top-3">
        <div class="w-6 h-6 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center">
          <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
          </svg>
        </div>
      </div>
    <% end %>
  </div>
  
  <!-- Character Counter -->
  <% if question.text_config[:max_length] %>
    <div class="flex justify-end">
      <span data-text-input-target="counter" class="text-sm text-gray-500">
        <span data-text-input-target="current">0</span> / <%= question.text_config[:max_length] %>
      </span>
    </div>
  <% end %>
  
  <!-- AI Suggestions (if enabled) -->
  <div id="ai-suggestions" data-text-input-target="suggestions" class="hidden">
    <div class="bg-blue-50 border border-blue-200 rounded-md p-3">
      <div class="flex items-start space-x-2">
        <svg class="w-4 h-4 text-blue-600 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium text-blue-900">AI Suggestion</p>
          <p data-text-input-target="suggestionText" class="text-sm text-blue-800 mt-1"></p>
        </div>
      </div>
    </div>
  </div>
  
  <%= hidden_field_tag 'response[metadata][response_time]', '', 
                      data: { text_input_target: 'responseTime' } %>
</div>

<script>
  // Text input specific functionality
  class TextInputController extends Application.Controller {
    static targets = ["counter", "current", "suggestions", "suggestionText", "responseTime"]
    static values = { 
      minLength: Number, 
      maxLength: Number 
    }
    
    connect() {
      this.startTime = Date.now()
      this.updateCounter()
      this.setupAIValidation()
    }
    
    validateLength() {
      this.updateCounter()
      this.checkAIValidation()
    }
    
    updateCounter() {
      if (this.hasCounterTarget) {
        const input = this.element.querySelector('input, textarea')
        const currentLength = input.value.length
        this.currentTarget.textContent = currentLength
        
        // Update styling based on length
        const remaining = this.maxLengthValue - currentLength
        if (remaining < 20) {
          this.counterTarget.classList.add('text-red-500')
          this.counterTarget.classList.remove('text-gray-500')
        } else {
          this.counterTarget.classList.remove('text-red-500')
          this.counterTarget.classList.add('text-gray-500')
        }
      }
    }
    
    trackFocus() {
      // Track when user focuses on the input
      window.formTracker?.trackEvent('field_focus', {
        questionId: '<%= question.id %>',
        questionType: 'text_short'
      })
    }
    
    setupAIValidation() {
      <% if question.has_smart_validation? %>
        let validationTimeout
        const input = this.element.querySelector('input, textarea')
        
        input.addEventListener('input', () => {
          clearTimeout(validationTimeout)
          validationTimeout = setTimeout(() => {
            this.requestAIValidation(input.value)
          }, 1500) // Wait for user to stop typing
        })
      <% end %>
    }
    
    checkAIValidation() {
      // Trigger AI validation if enabled and conditions met
      <% if question.has_smart_validation? %>
        const input = this.element.querySelector('input, textarea')
        if (input.value.length >= (<%= question.text_config[:min_length] || 5 %>)) {
          this.requestAIValidation(input.value)
        }
      <% end %>
    }
    
    requestAIValidation(value) {
      if (!value.trim()) return
      
      fetch('/forms/<%= @form.id %>/questions/<%= question.id %>/ai_validate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': '<%= form_authenticity_token %>'
        },
        body: JSON.stringify({
          answer: value,
          context: window.FormAnalytics
        })
      })
      .then(response => response.json())
      .then(data => this.handleAIValidation(data))
      .catch(error => console.warn('AI validation failed:', error))
    }
    
    handleAIValidation(data) {
      if (data.suggestions && data.suggestions.length > 0) {
        this.suggestionTextTarget.textContent = data.suggestions[0]
        this.suggestionsTarget.classList.remove('hidden')
      } else {
        this.suggestionsTarget.classList.add('hidden')
      }
    }
    
    disconnect() {
      // Record response time when leaving
      if (this.hasResponseTimeTarget) {
        const responseTime = Date.now() - this.startTime
        this.responseTimeTarget.value = responseTime
      }
    }
  }
  
  // Register the controller
  application.register("text-input", TextInputController)
</script>

<%
  def determine_autocomplete(question)
    case question.title.downcase
    when /first.?name/ then 'given-name'
    when /last.?name|surname/ then 'family-name'
    when /company|organization/ then 'organization'
    when /phone/ then 'tel'
    when /address/ then 'street-address'
    when /city/ then 'address-level2'
    when /zip|postal/ then 'postal-code'
    else 'off'
    end
  end
%>
```

#### 17.2 Multiple Choice Component
```erb
<!-- app/views/question_types/_multiple_choice.html.erb -->
<div class="space-y-4" data-controller="multiple-choice"
     data-multiple-choice-allows-multiple="<%= question.allows_multiple? %>"
     data-multiple-choice-max-selections="<%= question.choice_options.dig('max_selections') %>">
  
  <div class="space-y-3">
    <% question.display_options(@response.session_id.hash).each_with_index do |option, index| %>
      <label class="relative flex items-start p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-gray-300 hover:bg-gray-50 transition-all duration-200 group"
             data-multiple-choice-target="option"
             data-option-value="<%= option['value'] %>">
        
        <!-- Checkbox/Radio Input -->
        <% if question.allows_multiple? %>
          <%= check_box_tag 'response[answer_data][]', 
              option['value'],
              Array(existing_answer).include?(option['value']),
              data: { 
                action: "change->multiple-choice#handleSelection",
                multiple_choice_target: "input"
              },
              class: "h-4 w-4 text-blue-600 border-2 border-gray-300 rounded focus:ring-2 focus:ring-blue-500 mt-0.5" %>
        <% else %>
          <%= radio_button_tag 'response[answer_data]', 
              option['value'],
              existing_answer == option['value'],
              data: { 
                action: "change->multiple-choice#handleSelection",
                multiple_choice_target: "input"
              },
              class: "h-4 w-4 text-blue-600 border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 mt-0.5" %>
        <% end %>
        
        <!-- Option Content -->
        <div class="ml-4 flex-1">
          <div class="flex items-center justify-between">
            <span class="text-lg font-medium text-gray-900 group-hover:text-gray-700">
              <%= option['label'] %>
            </span>
            
            <!-- Option Icon (if configured) -->
            <% if option['icon'].present? %>
              <div class="w-8 h-8 flex items-center justify-center">
                <%= image_tag option['icon'], class: "w-6 h-6", alt: option['label'] if option['icon'].start_with?('http') %>
                <% unless option['icon'].start_with?('http') %>
                  <span class="text-2xl"><%= option['icon'] %></span>
                <% end %>
              </div>
            <% end %>
          </div>
          
          <!-- Option Description -->
          <% if option['description'].present? %>
            <p class="mt-1 text-sm text-gray-600">
              <%= option['description'] %>
            </p>
          <% end %>
          
          <!-- AI Enhancement: Show selection reasoning -->
          <% if question.ai_enhanced? && option['ai_reasoning'].present? %>
            <div class="mt-2 p-2 bg-purple-50 border border-purple-200 rounded text-xs text-purple-700">
              <strong>AI Insight:</strong> <%= option['ai_reasoning'] %>
            </div>
          <% end %>
        </div>
        
        <!-- Selection Indicator -->
        <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <div class="w-6 h-6 bg-blue-600 rounded-full flex items-center justify-center text-white text-xs font-bold">
            <%= index + 1 %>
          </div>
        </div>
      </label>
    <% end %>
    
    <!-- Other Option (if enabled) -->
    <% if question.has_other_option? %>
      <div class="relative">
        <label class="flex items-start p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-gray-300 transition-all duration-200"
               data-multiple-choice-target="otherOption">
          
          <% if question.allows_multiple? %>
            <%= check_box_tag 'response[answer_data][]', 
                'other',
                Array(existing_answer).include?('other'),
                data: { 
                  action: "change->multiple-choice#handleOtherSelection",
                  multiple_choice_target: "otherCheckbox"
                },
                class: "h-4 w-4 text-blue-600 border-2 border-gray-300 rounded focus:ring-2 focus:ring-blue-500 mt-0.5" %>
          <% else %>
            <%= radio_button_tag 'response[answer_data]', 
                'other',
                existing_answer == 'other',
                data: { 
                  action: "change->multiple-choice#handleOtherSelection",
                  multiple_choice_target: "otherRadio"  
                },
                class: "h-4 w-4 text-blue-600 border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 mt-0.5" %>
          <% end %>
          
          <div class="ml-4 flex-1">
            <span class="text-lg font-medium text-gray-900">Other</span>
            
            <!-- Other Text Input -->
            <div class="mt-2" data-multiple-choice-target="otherInput" 
                 style="<%= 'display: none;' unless Array(existing_answer).include?('other') %>">
              <%= text_field_tag 'response[other_text]', 
                  existing_answer.is_a?(Hash) ? existing_answer['other_text'] : '',
                  placeholder: "Please specify...",
                  data: { 
                    action: "input->multiple-choice#handleOtherText",
                    multiple_choice_target: "otherTextField"
                  },
                  class: "block w-full px-3 py-2 text-base border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent" %>
            </div>
          </div>
        </label>
      </div>
    <% end %>
  </div>
  
  <!-- Selection Limit Warning -->
  <div data-multiple-choice-target="warning" class="hidden">
    <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3">
      <p class="text-sm text-yellow-800">
        <span data-multiple-choice-target="warningText"></span>
      </p>
    </div>
  </div>
</div>

<script>
  class MultipleChoiceController extends Application.Controller {
    static targets = ["option", "input", "otherOption", "otherInput", "otherTextField", 
                     "otherCheckbox", "otherRadio", "warning", "warningText"]
    static values = { 
      allowsMultiple: Boolean,
      maxSelections: Number,
      minSelections: Number
    }
    
    connect() {
      this.updateSelectionCount()
    }
    
    handleSelection(event) {
      this.updateSelectionCount()
      this.trackSelection(event.target.value)
      
      // Hide other input if different option selected (for radio)
      if (!this.allowsMultipleValue && event.target.value !== 'other') {
        this.hideOtherInput()
      }
    }
    
    handleOtherSelection(event) {
      if (event.target.checked) {
        this.showOtherInput()
        this.trackSelection('other')
      } else {
        this.hideOtherInput()
      }
      this.updateSelectionCount()
    }
    
    handleOtherText(event) {
      // Enable/disable the other option based on text content
      const hasText = event.target.value.trim().length > 0
      const otherInput = this.hasOtherCheckboxTarget ? this.otherCheckboxTarget : this.otherRadioTarget
      
      if (hasText && !otherInput.checked) {
        otherInput.checked = true
        this.updateSelectionCount()
      }
    }
    
    updateSelectionCount() {
      if (!this.allowsMultipleValue) return
      
      const selectedCount = this.selectedInputs().length
      const maxSelections = this.maxSelectionsValue
      const minSelections = this.minSelectionsValue
      
      // Show/hide warning based on selection limits
      if (maxSelections && selectedCount >= maxSelections) {
        this.showWarning(`Maximum ${maxSelections} selections allowed`)
        this.disableUnselectedOptions()
      } else if (minSelections && selectedCount < minSelections) {
        this.showWarning(`Please select at least ${minSelections} options`)
        this.enableAllOptions()
      } else {
        this.hideWarning()
        this.enableAllOptions()
      }
    }
    
    selectedInputs() {
      return Array.from(this.inputTargets).filter(input => input.checked)
    }
    
    showWarning(message) {
      this.warningTextTarget.textContent = message
      this.warningTarget.classList.remove('hidden')
    }
    
    hideWarning() {
      this.warningTarget.classList.add('hidden')
    }
    
    showOtherInput() {
      if (this.hasOtherInputTarget) {
        this.otherInputTarget.style.display = 'block'
        this.otherTextFieldTarget.focus()
      }
    }
    
    hideOtherInput() {
      if (this.hasOtherInputTarget) {
        this.otherInputTarget.style.display = 'none'
        this.otherTextFieldTarget.value = ''
      }
    }
    
    disableUnselectedOptions() {
      this.inputTargets.forEach(input => {
        if (!input.checked) {
          input.disabled = true
          input.closest('label').classList.add('opacity-50', 'pointer-events-none')
        }
      })
    }
    
    enableAllOptions() {
      this.inputTargets.forEach(input => {
        input.disabled = false
        input.closest('label').classList.remove('opacity-50', 'pointer-events-none')
      })
    }
    
    trackSelection(value) {
      window.formTracker?.trackEvent('option_selected', {
        questionId: '<%= question.id %>',
        selectedValue: value,
        selectionCount: this.selectedInputs().length
      })
    }
  }
  
  application.register("multiple-choice", MultipleChoiceController)
</script>
```

#### 17.3 Rating Scale Component
```erb
<!-- app/views/question_types/_rating.html.erb -->
<div class="space-y-6" data-controller="rating-scale"
     data-rating-scale-min="<%= question.rating_config[:min] %>"
     data-rating-scale-max="<%= question.rating_config[:max] %>"
     data-rating-scale-current="<%= existing_answer %>">
  
  <!-- Scale Labels -->
  <div class="flex items-center justify-between text-sm text-gray-600 mb-4">
    <span><%= question.rating_config[:labels]['min'] || 'Poor' %></span>
    <span class="text-center font-medium">
      <span data-rating-scale-target="selectedLabel">Select a rating</span>
    </span>
    <span><%= question.rating_config[:labels]['max'] || 'Excellent' %></span>
  </div>
  
  <!-- Rating Scale -->
  <div class="flex items-center justify-center space-x-2 py-4">
    <% (question.rating_config[:min]..question.rating_config[:max]).each do |value| %>
      <label class="relative cursor-pointer group">
        <%= radio_button_tag 'response[answer_data]', 
            value,
            existing_answer.to_i == value,
            data: { 
              action: "change->rating-scale#selectRating",
              rating_scale_target: "input",
              rating_value: value
            },
            class: "sr-only" %>
        
        <!-- Visual Rating Button -->
        <div class="w-12 h-12 rounded-full border-2 border-gray-300 flex items-center justify-center text-lg font-medium transition-all duration-200 hover:border-blue-400 hover:bg-blue-50 group-hover:scale-110"
             data-rating-scale-target="button"
             data-rating-value="<%= value %>">
          
          <!-- Show number or custom icon -->
          <% if question.rating_config[:show_numbers] != false %>
            <%= value %>
          <% else %>
            <!-- Custom rating icons (stars, hearts, etc.) -->
            <div class="rating-icon" data-rating="<%= value %>">
              <%= render_rating_icon(question, value) %>
            </div>
          <% end %>
        </div>
        
        <!-- Custom Label -->
        <% if question.rating_config[:labels][value.to_s].present? %>
          <div class="absolute -bottom-6 left-1/2 transform -translate-x-1/2 text-xs text-gray-500 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity">
            <%= question.rating_config[:labels][value.to_s] %>
          </div>
        <% end %>
      </label>
    <% end %>
  </div>
  
  <!-- Selected Value Display -->
  <div class="text-center">
    <div data-rating-scale-target="selectedDisplay" class="hidden">
      <div class="inline-flex items-center space-x-2 px-4 py-2 bg-blue-50 border border-blue-200 rounded-lg">
        <span class="text-blue-800 font-medium">Selected:</span>
        <span data-rating-scale-target="selectedValue" class="text-blue-900 font-bold text-lg"></span>
        <span class="text-blue-700">/ <%= question.rating_config[:max] %></span>
      </div>
    </div>
  </div>
  
  <!-- AI Analysis Display -->
  <% if question.ai_enhanced? %>
    <div id="rating-ai-analysis" class="hidden mt-4">
      <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-4">
        <div class="flex items-center space-x-2 mb-2">
          <svg class="w-4 h-4 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
          </svg>
          <span class="text-sm font-medium text-purple-900">AI Insight</span>
        </div>
        <p id="rating-ai-insight" class="text-sm text-purple-800"></p>
      </div>
    </div>
  <% end %>
</div>

<script>
  class RatingScaleController extends Application.Controller {
    static targets = ["input", "button", "selectedDisplay", "selectedValue", "selectedLabel"]
    static values = { min: Number, max: Number, current: Number }
    
    connect() {
      this.updateDisplay()
      if (this.currentValue) {
        this.selectRating({ target: { dataset: { ratingValue: this.currentValue } } })
      }
    }
    
    selectRating(event) {
      const selectedValue = parseInt(event.target.dataset.ratingValue)
      this.currentValue = selectedValue
      
      // Update visual state
      this.updateButtonStates(selectedValue)
      this.updateSelectedDisplay(selectedValue)
      this.trackRating(selectedValue)
      
      // Trigger AI analysis if enabled
      <% if question.ai_enhanced? %>
        this.requestAIAnalysis(selectedValue)
      <% end %>
    }
    
    updateButtonStates(selectedValue) {
      this.buttonTargets.forEach(button => {
        const buttonValue = parseInt(button.dataset.ratingValue)
        const isSelected = buttonValue === selectedValue
        const isInRange = buttonValue <= selectedValue
        
        if (isSelected) {
          button.classList.add('border-blue-500', 'bg-blue-500', 'text-white', 'scale-110')
          button.classList.remove('border-gray-300', 'bg-white', 'text-gray-700')
        } else if (isInRange && this.useRangeHighlighting()) {
          button.classList.add('border-blue-300', 'bg-blue-100', 'text-blue-700')
          button.classList.remove('border-gray-300', 'bg-white', 'text-gray-700')
        } else {
          button.classList.remove('border-blue-500', 'bg-blue-500', 'text-white', 'scale-110',
                                  'border-blue-300', 'bg-blue-100', 'text-blue-700')
          button.classList.add('border-gray-300', 'bg-white', 'text-gray-700')
        }
      })
    }
    
    updateSelectedDisplay(selectedValue) {
      if (this.hasSelectedDisplayTarget) {
        this.selectedDisplayTarget.classList.remove('hidden')
        this.selectedValueTarget.textContent = selectedValue
      }
      
      if (this.hasSelectedLabelTarget) {
        this.selectedLabelTarget.textContent = this.getRatingLabel(selectedValue)
      }
    }
    
    useRangeHighlighting() {
      // For star ratings or other sequential scales
      return <%= question.rating_config[:style] == 'stars' ? 'true' : 'false' %>
    }
    
    getRatingLabel(value) {
      const labels = <%= question.rating_config[:labels].to_json.html_safe %>
      return labels[value.toString()] || `${value} / <%= question.rating_config[:max] %>`
    }
    
    trackRating(value) {
      window.formTracker?.trackEvent('rating_selected', {
        questionId: '<%= question.id %>',
        ratingValue: value,
        scale: '<%= question.rating_config[:min] %>-<%= question.rating_config[:max] %>'
      })
    }
    
    requestAIAnalysis(value) {
      // Request AI analysis of rating context
      fetch('/forms/<%= @form.id %>/questions/<%= question.id %>/ai_analyze_rating', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': '<%= form_authenticity_token %>'
        },
        body: JSON.stringify({
          rating: value,
          context: window.FormAnalytics,
          previous_answers: <%= @response.answers_hash.to_json.html_safe %>
        })
      })
      .then(response => response.json())
      .then(data => this.displayAIAnalysis(data))
      .catch(error => console.warn('AI analysis failed:', error))
    }
    
    displayAIAnalysis(data) {
      if (data.insight) {
        document.getElementById('rating-ai-insight').textContent = data.insight
        document.getElementById('rating-ai-analysis').classList.remove('hidden')
      }
    }
  }
  
  application.register("rating-scale", RatingScaleController)
</script>

<%
  def render_rating_icon(question, value)
    style = question.rating_config[:icon_style] || 'stars'
    
    case style
    when 'stars'
      content_tag :svg, class: "w-6 h-6 fill-current", viewBox: "0 0 20 20" do
        content_tag :path, '', d: "M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
      end
    when 'hearts'
      '❤️'
    when 'thumbs'
      value > (question.rating_config[:max] / 2) ? '👍' : '👎'
    else
      value.to_s
    end
  end
%>
```

### Day 18-19: JavaScript Controllers and Stimulus Components

#### 18.1 Form Builder Controller
```javascript
// app/javascript/controllers  

----------------------------------------------------------------------------------

# AgentForm Implementation Blueprint - Part 5

## Continuation from Part 4 - AI Enhancement Panel Component

```erb
<!-- app/views/forms/_ai_enhancement_panel.html.erb (continued) -->
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-purple-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                  </svg>
                  Smart Validation
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  AI analyzes user input in real-time to provide intelligent validation and suggestions.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.01 credits per validation
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('smart_validation'),
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "smart_validation" }
                      },
                      'smart_validation', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-purple-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
                </label>
              <% end %>
            </div>
          </div>
          
          <!-- Dynamic Follow-ups -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-blue-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z"/>
                    <path d="M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z"/>
                  </svg>
                  Dynamic Follow-ups
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  Generate contextual follow-up questions based on user responses.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.03 credits per follow-up generated
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('dynamic_followups'),
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "dynamic_followups" }
                      },
                      'dynamic_followups', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              <% end %>
            </div>
          </div>
          
          <!-- Response Analysis -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"/>
                    <path fill-rule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2V6a2 2 0 00-2-2V3a2 2 0 00-2-2H6a2 2 0 00-2 2v2z" clip-rule="evenodd"/>
                  </svg>
                  Response Analysis
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  Analyze sentiment, intent, and quality of responses for deeper insights.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.02 credits per response analyzed
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('response_analysis'),
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "response_analysis" }
                      },
                      'response_analysis', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-green-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-600"></div>
                </label>
              <% end %>
            </div>
          </div>
          
          <!-- Auto Optimization -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-orange-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"/>
                  </svg>
                  Auto Optimization
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  Automatically suggest and apply form improvements based on performance data.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.05 credits per optimization analysis
                </div>
                <div class="mt-2 text-xs text-orange-600 font-medium">
                  Premium Feature
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('auto_optimization'),
                        disabled: !current_user.premium?,
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "auto_optimization" }
                      },
                      'auto_optimization', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-orange-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-orange-600 disabled:opacity-50"></div>
                </label>
              <% end %>
            </div>
          </div>
        </div>
        
        <!-- Advanced Configuration -->
        <div class="border-t border-gray-200 pt-6">
          <h5 class="text-base font-medium text-gray-900 mb-4">Advanced Settings</h5>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Confidence Threshold -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                AI Confidence Threshold
              </label>
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <div class="flex items-center space-x-4">
                  <%= f.range_field 'ai_configuration[confidence_threshold]', 
                      value: @form.ai_configuration.dig('confidence_threshold') || 0.7,
                      min: 0.1, max: 1.0, step: 0.1,
                      class: "flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer",
                      data: { action: "input->ai-enhancement#updateConfidence" } %>
                  <span class="text-sm font-medium text-gray-700 min-w-[3rem]" 
                        data-ai-enhancement-target="confidenceDisplay">
                    <%= (@form.ai_configuration.dig('confidence_threshold') || 0.7).round(1) %>
                  </span>
                </div>
              <% end %>
              <p class="mt-1 text-xs text-gray-500">
                Minimum confidence level required for AI suggestions to be shown
              </p>
            </div>
            
            <!-- Response Quality Filter -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Response Quality Filter
              </label>
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <%= f.select 'ai_configuration[quality_filter]', 
                    options_for_select([
                      ['All Responses', 'none'],
                      ['Medium Quality and Above', 'medium'],
                      ['High Quality Only', 'high']
                    ], @form.ai_configuration.dig('quality_filter') || 'none'),
                    {},
                    { 
                      class: "block w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500"
                    } %>
              <% end %>
              <p class="mt-1 text-xs text-gray-500">
                Filter which responses trigger AI analysis based on quality
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  <% else %>
    <!-- AI Disabled State -->
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
      <div class="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
          <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">AI Features Disabled</h3>
      <p class="text-gray-600 mb-4">
        Enable AI features to unlock intelligent form capabilities like smart validation, 
        dynamic follow-ups, and response analysis.
      </p>
      <button data-action="click->ai-enhancement#enableAI" 
              class="inline-flex items-center px-4 py-2 bg-purple-600 border border-transparent rounded-md text-sm font-medium text-white hover:bg-purple-700">
        Enable AI Features
      </button>
    </div>
  <% end %>
</div>

<script>
  // AI Enhancement Controller
  class AIEnhancementController extends Application.Controller {
    static targets = ["confidenceDisplay"]
    
    async handleMasterToggle(event) {
      const enabled = event.target.checked
      
      try {
        await this.updateFormSetting('ai_configuration[enabled]', enabled)
        
        if (enabled) {
          FormBuilder.showToast('AI features enabled!', 'success')
          this.showAIFeatures()
        } else {
          FormBuilder.showToast('AI features disabled', 'info')
          this.hideAIFeatures()
        }
      } catch (error) {
        FormBuilder.showToast('Failed to update AI settings', 'error')
        event.target.checked = !enabled // Revert
      }
    }
    
    async toggleFeature(event) {
      const feature = event.target.dataset.feature
      const enabled = event.target.checked
      
      if (enabled && !await this.checkAIBudget()) {
        event.target.checked = false
        FormBuilder.showToast('Insufficient AI credits to enable this feature', 'warning')
        return
      }
      
      try {
        const features = this.getCurrentFeatures()
        
        if (enabled) {
          features.push(feature)
        } else {
          const index = features.indexOf(feature)
          if (index > -1) features.splice(index, 1)
        }
        
        await this.updateFormSetting('ai_configuration[features]', features)
        
        FormBuilder.showToast(
          `${this.featureName(feature)} ${enabled ? 'enabled' : 'disabled'}`, 
          'success'
        )
      } catch (error) {
        FormBuilder.showToast('Failed to update feature setting', 'error')
        event.target.checked = !enabled // Revert
      }
    }
    
    updateConfidence(event) {
      const value = parseFloat(event.target.value)
      if (this.hasConfidenceDisplayTarget) {
        this.confidenceDisplayTarget.textContent = value.toFixed(1)
      }
      
      // Debounce the update
      clearTimeout(this.confidenceTimeout)
      this.confidenceTimeout = setTimeout(() => {
        this.updateFormSetting('ai_configuration[confidence_threshold]', value)
      }, 1000)
    }
    
    async updateModel(event) {
      const model = event.target.value
      
      try {
        await this.updateFormSetting('ai_configuration[model]', model)
        FormBuilder.showToast(`AI model updated to ${model}`, 'success')
      } catch (error) {
        FormBuilder.showToast('Failed to update AI model', 'error')
      }
    }
    
    async updateBudget(event) {
      const budget = parseFloat(event.target.value)
      
      try {
        await this.updateFormSetting('ai_configuration[budget_limit]', budget)
        FormBuilder.showToast(`Budget limit set to ${budget} credits`, 'success')
      } catch (error) {
        FormBuilder.showToast('Failed to update budget limit', 'error')
      }
    }
    
    async enableAI() {
      try {
        await this.updateFormSetting('ai_configuration[enabled]', true)
        location.reload() // Refresh to show AI options
      } catch (error) {
        FormBuilder.showToast('Failed to enable AI features', 'error')
      }
    }
    
    // Helper Methods
    async updateFormSetting(setting, value) {
      const formData = new FormData()
      formData.append(setting, value)
      
      const response = await fetch(window.location.pathname, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': this.csrfToken() },
        body: formData
      })
      
      if (!response.ok) {
        throw new Error('Update failed')
      }
    }
    
    async checkAIBudget() {
      // Check if user has sufficient AI credits
      const response = await fetch('/api/ai_budget_check', {
        headers: { 'X-CSRF-Token': this.csrfToken() }
      })
      
      if (response.ok) {
        const data = await response.json()
        return data.sufficient
      }
      
      return false
    }
    
    getCurrentFeatures() {
      return Array.from(document.querySelectorAll('[name*="ai_configuration[features]"]:checked'))
                  .map(input => input.value)
                  .filter(value => value !== '')
    }
    
    featureName(feature) {
      const names = {
        'smart_validation': 'Smart Validation',
        'dynamic_followups': 'Dynamic Follow-ups',
        'response_analysis': 'Response Analysis',
        'auto_optimization': 'Auto Optimization'
      }
      return names[feature] || feature
    }
    
    showAIFeatures() {
      document.querySelectorAll('.ai-feature').forEach(el => {
        el.classList.remove('hidden')
      })
    }
    
    hideAIFeatures() {
      document.querySelectorAll('.ai-feature').forEach(el => {
        el.classList.add('hidden')
      })
    }
    
    csrfToken() {
      return document.querySelector('[name="csrf-token"]').content
    }
  }
  
  application.register("ai-enhancement", AIEnhancementController)
</script>
```

## Phase 4: Background Jobs Implementation (Days 22-25)

### Day 22: Core Job Classes

#### 22.1 Form Workflow Jobs
```ruby
# app/jobs/forms/workflow_generation_job.rb
module Forms
  class WorkflowGenerationJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    
    def perform(form_id)
      form = Form.find(form_id)
      
      Rails.logger.info "Generating workflow for form #{form.id}: #{form.name}"
      
      # Generate the workflow class dynamically
      service = Forms::WorkflowGeneratorService.new(form)
      workflow_class = service.generate_class
      
      # Update form with workflow information
      form.update!(
        workflow_class_name: workflow_class.name,
        workflow_state: { 
          generated_at: Time.current,
          version: '1.0',
          questions_count: form.form_questions.count
        }
      )
      
      # Trigger workflow validation
      Forms::WorkflowValidationJob.perform_later(form.id)
      
      Rails.logger.info "Successfully generated workflow #{workflow_class.name} for form #{form.id}"
    end
  end
end

# app/jobs/forms/response_analysis_job.rb
module Forms
  class ResponseAnalysisJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(question_response_id)
      question_response = QuestionResponse.find(question_response_id)
      form_response = question_response.form_response
      question = question_response.form_question
      
      return unless question.ai_enhanced?
      return unless form_response.form.user.can_use_ai_features?
      
      Rails.logger.info "Analyzing response #{question_response.id} for question #{question.id}"
      
      # Run AI analysis workflow
      agent = Forms::ResponseAgent.new
      result = agent.analyze_response_quality(form_response)
      
      if result.completed?
        # Update the question response with AI insights
        analysis_data = result.final_output
        
        question_response.update!(
          ai_analysis: analysis_data[:ai_analysis],
          confidence_score: analysis_data[:confidence_score],
          completeness_score: analysis_data[:completeness_score]
        )
        
        # Generate dynamic follow-up if needed
        if analysis_data[:generate_followup]
          Forms::DynamicQuestionGenerationJob.perform_later(
            form_response.id, 
            question.id
          )
        end
        
        # Update form response AI analysis
        aggregate_analysis = aggregate_response_analysis(form_response)
        form_response.update!(ai_analysis: aggregate_analysis)
        
        Rails.logger.info "Successfully analyzed response #{question_response.id}"
      else
        Rails.logger.error "Response analysis failed: #{result.error_message}"
      end
    end
    
    private
    
    def aggregate_response_analysis(form_response)
      analyses = form_response.question_responses
                             .where.not(ai_analysis: {})
                             .pluck(:ai_analysis)
      
      return {} if analyses.empty?
      
      # Aggregate sentiment scores
      sentiments = analyses.map { |a| a.dig('sentiment', 'confidence') }.compact
      avg_sentiment = sentiments.any? ? sentiments.sum / sentiments.size : 0.5
      
      # Aggregate quality scores  
      quality_scores = analyses.map { |a| a.dig('quality', 'completeness') }.compact
      avg_quality = quality_scores.any? ? quality_scores.sum / quality_scores.size : 0.5
      
      # Collect insights
      all_insights = analyses.flat_map { |a| a['insights'] || [] }
      
      # Collect flags
      all_flags = analyses.map { |a| a['flags'] || {} }.reduce({}) do |merged, flags|
        flags.each { |key, value| merged[key] = (merged[key] || false) || value }
        merged
      end
      
      {
        overall_sentiment: avg_sentiment,
        overall_quality: avg_quality,
        key_insights: all_insights.uniq.first(5),
        flags: all_flags,
        analysis_count: analyses.size,
        analyzed_at: Time.current
      }
    end
  end
end

# app/jobs/forms/dynamic_question_generation_job.rb
module Forms
  class DynamicQuestionGenerationJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_response_id, source_question_id)
      form_response = FormResponse.find(form_response_id)
      source_question = FormQuestion.find(source_question_id)
      
      return unless source_question.generates_followups?
      return unless form_response.form.user.can_use_ai_features?
      
      # Check if we've already generated enough follow-ups for this question
      existing_count = form_response.dynamic_questions
                                   .where(generated_from_question: source_question)
                                   .count
      
      max_followups = source_question.ai_enhancement.dig('max_followups') || 2
      return if existing_count >= max_followups
      
      Rails.logger.info "Generating dynamic question for response #{form_response_id} from question #{source_question_id}"
      
      # Run dynamic question generation workflow
      agent = Forms::ResponseAgent.new
      result = agent.run_workflow(Forms::DynamicQuestionWorkflow, initial_input: {
        response_id: form_response_id,
        source_question_id: source_question_id,
        user_id: form_response.form.user_id
      })
      
      if result.completed?
        dynamic_question_id = result.output_for(:create_dynamic_question_record)[:dynamic_question_id]
        
        # Broadcast the new question to the user's browser
        Forms::BroadcastDynamicQuestionJob.perform_later(
          form_response.id,
          dynamic_question_id
        )
        
        Rails.logger.info "Successfully generated dynamic question #{dynamic_question_id}"
      else
        Rails.logger.error "Dynamic question generation failed: #{result.error_message}"
      end
    end
  end
end
```

#### 22.2 Integration Jobs
```ruby
# app/jobs/forms/integration_trigger_job.rb
module Forms
  class IntegrationTriggerJob < ApplicationJob
    queue_as :integrations
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    
    def perform(form_response_id, trigger_event = 'form_completed')
      form_response = FormResponse.find(form_response_id)
      form = form_response.form
      
      return unless form.integration_settings.present?
      
      Rails.logger.info "Triggering integrations for form response #{form_response_id}, event: #{trigger_event}"
      
      # Get enabled integrations for this trigger event
      enabled_integrations = form.integration_settings.select do |integration_name, config|
        config['enabled'] == true && 
        config['triggers']&.include?(trigger_event)
      end
      
      # Process each integration
      enabled_integrations.each do |integration_name, config|
        begin
          process_integration(integration_name, config, form_response, trigger_event)
        rescue => e
          Rails.logger.error "Integration #{integration_name} failed: #{e.message}"
          # Don't fail the entire job for one integration failure
        end
      end
    end
    
    private
    
    def process_integration(integration_name, config, form_response, trigger_event)
      case integration_name
      when 'webhook'
        process_webhook_integration(config, form_response, trigger_event)
      when 'email_notification'
        process_email_integration(config, form_response, trigger_event)
      when 'crm_sync'
        process_crm_integration(config, form_response, trigger_event)
      when 'slack_notification'
        process_slack_integration(config, form_response, trigger_event)
      when 'zapier'
        process_zapier_integration(config, form_response, trigger_event)
      else
        Rails.logger.warn "Unknown integration: #{integration_name}"
      end
    end
    
    def process_webhook_integration(config, form_response, trigger_event)
      webhook_url = config['webhook_url']
      return unless webhook_url.present?
      
      payload = {
        event: trigger_event,
        form_id: form_response.form_id,
        response_id: form_response.id,
        form_name: form_response.form.name,
        submitted_at: form_response.completed_at || form_response.created_at,
        data: form_response.answers_hash,
        metadata: {
          session_id: form_response.session_id,
          ip_address: form_response.ip_address,
          user_agent: form_response.user_agent,
          utm_parameters: form_response.utm_parameters
        }
      }
      
      # Add AI analysis if available
      if form_response.ai_analysis.present?
        payload[:ai_analysis] = form_response.ai_analysis
      end
      
      headers = {
        'Content-Type' => 'application/json',
        'User-Agent' => 'AgentForm-Webhook/1.0'
      }
      
      # Add custom headers if configured
      if config['headers'].present?
        headers.merge!(config['headers'])
      end
      
      # Add authentication

---------------------------------------------------------------

# Add authentication if configured
      if config['authentication'].present?
        case config['authentication']['type']
        when 'bearer'
          headers['Authorization'] = "Bearer #{config['authentication']['token']}"
        when 'api_key'
          headers['X-API-Key'] = config['authentication']['api_key']
        when 'basic'
          auth = Base64.encode64("#{config['authentication']['username']}:#{config['authentication']['password']}")
          headers['Authorization'] = "Basic #{auth}"
        end
      end
      
      # Make HTTP request
      uri = URI(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = config['timeout'] || 30
      
      request = Net::HTTP::Post.new(uri.path, headers)
      request.body = payload.to_json
      
      response = http.request(request)
      
      unless response.code.start_with?('2')
        raise "Webhook failed with status #{response.code}: #{response.body}"
      end
      
      Rails.logger.info "Webhook delivered successfully to #{webhook_url}"
    end
    
    def process_email_integration(config, form_response, trigger_event)
      recipient_emails = config['recipients']
      return unless recipient_emails.present?
      
      # Send notification email
      Forms::IntegrationMailer.form_response_notification(
        form_response.id,
        recipient_emails,
        config
      ).deliver_now
    end
    
    def process_crm_integration(config, form_response, trigger_event)
      crm_type = config['crm_type']
      
      case crm_type
      when 'salesforce'
        Forms::Integrations::SalesforceService.new(config).sync_response(form_response)
      when 'hubspot'
        Forms::Integrations::HubspotService.new(config).sync_response(form_response)
      when 'pipedrive'
        Forms::Integrations::PipedriveService.new(config).sync_response(form_response)
      else
        Rails.logger.warn "Unknown CRM type: #{crm_type}"
      end
    end
    
    def process_slack_integration(config, form_response, trigger_event)
      webhook_url = config['slack_webhook_url']
      return unless webhook_url.present?
      
      # Format Slack message
      message = {
        text: "New form response received: #{form_response.form.name}",
        attachments: [{
          color: determine_slack_color(form_response),
          fields: build_slack_fields(form_response),
          footer: "AgentForm",
          ts: form_response.created_at.to_i
        }]
      }
      
      # Send to Slack
      uri = URI(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
      request.body = message.to_json
      
      response = http.request(request)
      
      unless response.code == '200'
        raise "Slack webhook failed with status #{response.code}"
      end
    end
    
    def determine_slack_color(form_response)
      if form_response.quality_score
        case form_response.quality_score
        when 0.8..1.0 then 'good'
        when 0.5..0.8 then 'warning'  
        else 'danger'
        end
      else
        'good'
      end
    end
    
    def build_slack_fields(form_response)
      fields = []
      
      # Add key answers (first 5)
      form_response.answers_hash.first(5).each do |question, answer|
        fields << {
          title: question.humanize,
          value: truncate_answer(answer),
          short: true
        }
      end
      
      # Add metadata
      fields << {
        title: "Completion Time",
        value: "#{form_response.duration_minutes} minutes",
        short: true
      }
      
      if form_response.ai_analysis.present?
        sentiment = form_response.ai_analysis.dig('overall_sentiment')
        fields << {
          title: "AI Sentiment",
          value: sentiment&.humanize || 'Unknown',
          short: true
        }
      end
      
      fields
    end
    
    def truncate_answer(answer)
      answer_text = case answer
      when Array then answer.join(', ')
      when Hash then answer.values.join(', ')
      else answer.to_s
      end
      
      answer_text.length > 50 ? "#{answer_text[0..47]}..." : answer_text
    end
  end
end

# app/jobs/forms/completion_workflow_job.rb
module Forms
  class CompletionWorkflowJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_response_id)
      form_response = FormResponse.find(form_response_id)
      form = form_response.form
      
      Rails.logger.info "Processing form completion for response #{form_response_id}"
      
      # Run completion workflow
      agent = Forms::ResponseAgent.new
      result = agent.complete_form_response(form_response)
      
      if result.completed?
        # Update analytics
        update_form_analytics(form, form_response)
        
        # Trigger integrations
        Forms::IntegrationTriggerJob.perform_later(form_response_id, 'form_completed')
        
        # Send notifications if configured
        if form.notification_settings['completion_notifications']
          Forms::CompletionNotificationJob.perform_later(form_response_id)
        end
        
        # Generate insights if AI enabled
        if form.ai_enhanced?
          Forms::InsightGenerationJob.perform_later(form_response_id)
        end
        
        Rails.logger.info "Successfully processed completion for response #{form_response_id}"
      else
        Rails.logger.error "Completion workflow failed: #{result.error_message}"
      end
    end
    
    private
    
    def update_form_analytics(form, form_response)
      # Update daily analytics
      analytic = FormAnalytic.find_or_create_by(
        form: form,
        date: Date.current,
        metric_type: 'daily'
      )
      
      analytic.increment!(:completions_count)
      
      # Update completion time average
      current_avg = analytic.avg_completion_time || 0
      current_count = analytic.completions_count
      new_time = form_response.duration_minutes
      
      new_avg = ((current_avg * (current_count - 1)) + new_time) / current_count
      analytic.update!(avg_completion_time: new_avg)
      
      # Update form counters
      form.increment!(:completions_count)
      form.update!(last_response_at: Time.current)
    end
  end
end
```

### Day 23: Advanced Workflow Classes

#### 23.1 Form Optimization Workflow  
```ruby
# app/workflows/forms/optimization_workflow.rb
module Forms
  class OptimizationWorkflow < ApplicationWorkflow
    workflow do
      timeout 180
      
      # Step 1: Gather performance data
      task :collect_performance_data do
        input :form_id
        description "Collect comprehensive form performance data"
        
        process do |form_id|
          form = Form.find(form_id)
          
          # Gather response data from last 30 days
          recent_responses = form.form_responses.where('created_at >= ?', 30.days.ago)
          
          # Calculate detailed metrics
          {
            form: form,
            total_responses: recent_responses.count,
            completed_responses: recent_responses.completed.count,
            average_completion_time: calculate_avg_completion_time(recent_responses.completed),
            drop_off_analysis: calculate_drop_off_rates(form),
            question_performance: analyze_question_performance(form),
            user_feedback: extract_user_feedback(recent_responses),
            conversion_metrics: calculate_conversion_metrics(form),
            mobile_performance: analyze_mobile_performance(recent_responses)
          }
        end
      end
      
      # Step 2: AI-powered performance analysis
      llm :analyze_performance_bottlenecks do
        input :collect_performance_data
        run_if { |ctx| ctx.get(:collect_performance_data)[:total_responses] >= 20 }
        
        model "gpt-4o"
        temperature 0.2
        max_tokens 1200
        response_format :json
        
        system_prompt <<~SYSTEM
          You are an expert in form optimization and conversion rate optimization. 
          Analyze form performance data to identify bottlenecks and improvement opportunities.
          
          Focus on:
          1. User experience pain points
          2. Question ordering and flow
          3. Completion rate optimization
          4. Mobile vs desktop performance
          5. Timing and engagement patterns
        SYSTEM
        
        prompt <<~PROMPT
          Analyze this form's performance data and identify optimization opportunities:
          
          Form Performance Summary:
          - Total Responses: {{collect_performance_data.total_responses}}
          - Completion Rate: {{collect_performance_data.completed_responses}} / {{collect_performance_data.total_responses}} 
            ({{collect_performance_data.completed_responses / collect_performance_data.total_responses * 100}}%)
          - Average Time: {{collect_performance_data.average_completion_time}} minutes
          
          Drop-off Analysis:
          {{collect_performance_data.drop_off_analysis}}
          
          Question Performance:
          {{collect_performance_data.question_performance}}
          
          Mobile Performance:
          {{collect_performance_data.mobile_performance}}
          
          Conversion Metrics:
          {{collect_performance_data.conversion_metrics}}
          
          Provide optimization recommendations in JSON format:
          {
            "critical_issues": [
              {
                "issue": "description of the problem",
                "impact": "high|medium|low", 
                "affected_metric": "completion_rate|response_time|user_satisfaction",
                "root_cause": "likely cause of the issue"
              }
            ],
            "optimization_recommendations": [
              {
                "type": "question_reorder|question_modification|ui_improvement|flow_optimization",
                "description": "specific recommendation",
                "expected_improvement": "quantified expected improvement",
                "implementation_effort": "low|medium|high",
                "priority": "high|medium|low",
                "target_questions": ["question_ids if applicable"]
              }
            ],
            "quick_wins": [
              "easily implementable improvements with immediate impact"
            ],
            "a_b_test_suggestions": [
              {
                "test_name": "descriptive test name",
                "hypothesis": "what we're testing and why",
                "variants": ["variant descriptions"],
                "success_metric": "what to measure"
              }
            ],
            "overall_score": "current form performance score 0-100",
            "potential_improvement": "estimated improvement percentage if recommendations implemented"
          }
        PROMPT
      end
      
      # Step 3: Generate specific question improvements
      llm :generate_question_optimizations do
        input :collect_performance_data, :analyze_performance_bottlenecks
        run_when :analyze_performance_bottlenecks
        
        model "gpt-4o"
        temperature 0.3
        max_tokens 1000
        response_format :json
        
        prompt <<~PROMPT
          Based on the performance analysis, generate specific improvements for underperforming questions:
          
          Performance Analysis:
          {{analyze_performance_bottlenecks}}
          
          Question Details:
          {{collect_performance_data.question_performance}}
          
          For each question that needs optimization, provide:
          {
            "question_optimizations": {
              "question_id": {
                "current_title": "existing question title",
                "suggested_title": "improved question title",
                "current_type": "question type",
                "suggested_type": "better question type if different",
                "improvements": [
                  {
                    "type": "wording|type_change|validation|help_text",
                    "description": "what to change",
                    "reasoning": "why this will improve performance"
                  }
                ],
                "expected_impact": "estimated improvement percentage"
              }
            },
            "flow_improvements": [
              {
                "type": "reorder|add_conditional|remove_redundancy",
                "description": "flow improvement description", 
                "affected_questions": ["question positions"],
                "reasoning": "why this improves user experience"
              }
            ]
          }
        PROMPT
      end
      
      # Step 4: Create optimization plan
      task :create_optimization_plan do
        input :analyze_performance_bottlenecks, :generate_question_optimizations
        
        process do |bottlenecks_analysis, question_optimizations|
          form = Form.find(context.get(:form_id))
          
          # Parse AI recommendations
          bottlenecks = JSON.parse(bottlenecks_analysis)
          optimizations = JSON.parse(question_optimizations)
          
          # Create comprehensive optimization plan
          optimization_plan = {
            created_at: Time.current,
            form_id: form.id,
            current_performance: {
              completion_rate: form.completion_rate,
              average_time: form.average_completion_time_minutes,
              quality_score: calculate_form_quality_score(form),
              overall_score: bottlenecks['overall_score']
            },
            critical_issues: bottlenecks['critical_issues'],
            recommendations: combine_recommendations(bottlenecks, optimizations),
            quick_wins: bottlenecks['quick_wins'],
            a_b_tests: bottlenecks['a_b_test_suggestions'],
            estimated_improvement: bottlenecks['potential_improvement']
          }
          
          # Save optimization plan
          FormAnalytic.create!(
            form: form,
            date: Date.current,
            metric_type: 'optimization_plan',
            ai_insights: optimization_plan
          )
          
          {
            plan_created: true,
            optimization_plan: optimization_plan,
            recommendations_count: optimization_plan[:recommendations].size
          }
        end
      end
      
      # Step 5: Auto-apply safe optimizations (if enabled)
      task :auto_apply_optimizations do
        input :create_optimization_plan
        run_if do |ctx|
          form = Form.find(ctx.get(:form_id))
          form.ai_configuration.dig('auto_optimization', 'enabled') == true
        end
        
        process do |optimization_data|
          form = Form.find(context.get(:form_id))
          plan = optimization_data[:optimization_plan]
          
          applied_changes = []
          
          # Only auto-apply low-risk, high-impact changes
          safe_recommendations = plan[:recommendations].select do |rec|
            rec['implementation_effort'] == 'low' && 
            rec['priority'] == 'high' &&
            is_safe_auto_change?(rec['type'])
          end
          
          safe_recommendations.each do |recommendation|
            begin
              change_result = apply_recommendation(form, recommendation)
              applied_changes << change_result if change_result
            rescue => e
              Rails.logger.error "Failed to auto-apply recommendation: #{e.message}"
            end
          end
          
          {
            auto_applied: applied_changes.size > 0,
            applied_changes: applied_changes,
            skipped_unsafe: plan[:recommendations].size - applied_changes.size
          }
        end
      end
    end
    
    private
    
    def calculate_avg_completion_time(completed_responses)
      return 0 if completed_responses.empty?
      
      times = completed_responses.map(&:duration_minutes).compact
      times.any? ? times.sum / times.size : 0
    end
    
    def calculate_drop_off_rates(form)
      questions = form.form_questions.order(:position)
      drop_offs = {}
      
      questions.each do |question|
        total_reached = form.form_responses.joins(:question_responses)
                            .where('form_questions.position >= ?', question.position)
                            .distinct.count
                            
        answered = question.question_responses.joins(:form_response)
                           .where('form_responses.created_at >= ?', 30.days.ago)
                           .count
        
        drop_off_rate = total_reached > 0 ? ((total_reached - answered).to_f / total_reached) : 0
        
        drop_offs[question.id] = {
          position: question.position,
          title: question.title,
          drop_off_rate: (drop_off_rate * 100).round(1),
          total_reached: total_reached,
          answered: answered
        }
      end
      
      drop_offs
    end
    
    def analyze_question_performance(form)
      form.form_questions.map do |question|
        recent_responses = question.question_responses
                                  .joins(:form_response)
                                  .where('form_responses.created_at >= ?', 30.days.ago)
        
        {
          id: question.id,
          title: question.title,
          type: question.question_type,
          position: question.position,
          response_count: recent_responses.count,
          avg_response_time: recent_responses.average(:response_time_ms),
          revision_rate: calculate_revision_rate(recent_responses),
          quality_score: recent_responses.average(:confidence_score)
        }
      end
    end
    
    def calculate_revision_rate(responses)
      return 0 if responses.empty?
      
      total_revisions = responses.sum(:revision_count)
      (total_revisions.to_f / responses.count).round(2)
    end
    
    def extract_user_feedback(responses)
      # Extract feedback from text responses that might indicate UX issues
      text_responses = responses.joins(:question_responses)
                               .where(question_responses: { 
                                 form_questions: { question_type: ['text_long', 'text_short'] }
                               })
                               .pluck('question_responses.answer_data')
      
      # Simple keyword analysis for UX issues
      feedback_indicators = %w[confusing unclear difficult hard problem issue bug error]
      
      negative_feedback = text_responses.select do |response|
        response_text = response.to_s.downcase
        feedback_indicators.any? { |indicator| response_text.include?(indicator) }
      end
      
      {
        total_text_responses: text_responses.size,
        potential_issues: negative_feedback.size,
        issue_rate: text_responses.any? ? (negative_feedback.size.to_f / text_responses.size * 100).round(1) : 0
      }
    end
    
    def calculate_conversion_metrics(form)
      case form.category
      when 'lead_qualification'
        calculate_lead_conversion_metrics(form)
      when 'customer_feedback'
        calculate_satisfaction_metrics(form)
      when 'event_registration'
        calculate_registration_metrics(form)
      else
        calculate_general_metrics(form)
      end
    end
    
    def analyze_mobile_performance(responses)
      mobile_responses = responses.where("user_agent ILIKE '%Mobile%' OR user_agent ILIKE '%Android%' OR user_agent ILIKE '%iPhone%'")
      desktop_responses = responses.where.not(id: mobile_responses.ids)
      
      {
        mobile: {
          count: mobile_responses.count,
          completion_rate: calculate_completion_rate(mobile_responses),
          avg_time: calculate_avg_completion_time(mobile_responses.completed)
        },
        desktop: {
          count: desktop_responses.count,
          completion_rate: calculate_completion_rate(desktop_responses),
          avg_time: calculate_avg_completion_time(desktop_responses.completed)
        }
      }
    end
    
    def calculate_completion_rate(responses)
      return 0 if responses.count.zero?
      (responses.completed.count.to_f / responses.count * 100).round(1)
    end
    
    def is_safe_auto_change?(change_type)
      # Only allow safe changes that won't break functionality
      safe_changes = %w[help_text validation_improvement placeholder_update description_enhancement]
      safe_changes.include?(change_type)
    end
    
    def apply_recommendation(form, recommendation)
      case recommendation['type']
      when 'help_text'
        apply_help_text_improvement(form, recommendation)
      when 'validation_improvement'
        apply_validation_improvement(form, recommendation)
      when 'placeholder_update'
        apply_placeholder_update(form, recommendation)
      else
        nil # Skip unsafe changes
      end
    end
    
    def apply_help_text_improvement(form, recommendation)
      target_questions = recommendation['target_questions']
      return nil unless target_questions
      
      changes_applied = 0
      
      target_questions.each do |question_id|
        question = form.form_questions.find_by(id: question_id)
        next unless question
        
        new_help_text = recommendation['suggested_help_text']
        if new_help_text && question.help_text != new_help_text
          question.update!(help_text: new_help_text)
          changes_applied += 1
        end
      end
      
      {
        type: 'help_text_improvement',
        questions_updated: changes_applied,
        description: recommendation['description']
      }
    end
  end
end
```

### Day 24-25: Background Processing & Jobs

#### 24.1 Analytics Processing Jobs
```ruby
# app/jobs/forms/analytics_processing_job.rb
module Forms
  class AnalyticsProcessingJob < ApplicationJob
    queue_as :analytics
    
    def perform(form_id, date = Date.current)
      form = Form.find(form_id)
      
      Rails.logger.info "Processing analytics for form #{form_id} on #{date}"
      
      # Calculate daily metrics
      daily_responses = form.form_responses.where(
        created_at: date.beginning_of_day..date.end_of_day
      )
      
      analytic = FormAnalytic.find_or_create_by(
        form: form,
        date: date,
        metric_type: 'daily'
      )
      
      # Update basic metrics
      analytic.update!(
        starts_count: daily_responses.count,
        completions_count: daily_responses.completed.count,
        abandons_count: daily_responses.where(status: 'abandoned').count,
        avg_completion_time: calculate_average_time(daily_responses.completed),
        avg_quality_score: calculate_average_quality(daily_responses.completed)
      )
      
      # Generate AI insights if form uses AI
      if form.ai_enhanced? && daily_responses.completed.count >= 5
        Forms::AiInsightGenerationJob.perform_later(form.id, date)
      end
    end
    
    private
    
    def calculate_average_time(responses)
      return 0 if responses.empty?
      
      times = responses.where.not(completed_at: nil, started_at: nil)
                      .pluck(:started_at, :completed_at)
                      .map { |start, finish| (finish - start) / 60.0 }
      
      times.any? ? times.sum / times.size : 0
    end
    
    def calculate_average_quality(responses)
      responses.where.not(quality_score: nil).average(:quality_score) || 0
    end
  end
end

# app/jobs/forms/ai_insight_generation_job.rb
module Forms
  class AiInsightGenerationJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_id, date = Date.current)
      form = Form.find(form_id)
      return unless form.ai_enhanced?
      return unless form.user.can_use_ai_features?
      
      Rails.logger.info "Generating AI insights for form #{form_id} on #{date}"
      
      # Gather data for analysis
      responses_data = prepare_responses_data(form, date)
      return if responses_data[:responses].empty?
      
      # Run AI analysis workflow
      agent = Forms::AnalyticsAgent.new
      result = agent.generate_insights(form, responses_data)
      
      if result.completed?
        insights = result.final_output
        
        # Save insights to analytics record
        analytic = FormAnalytic.find_or_create_by(
          form: form,
          date: date,
          metric_type: 'ai_insights'
        )
        
        analytic.update!(
          ai_insights: insights,
          behavioral_patterns: extract_behavioral_patterns(responses_data),
          optimization_suggestions: insights[:optimization_suggestions]
        )
        
        # Track AI usage
        Forms::AiUsageTracker.new(form.user_id).track_usage(
          operation: 'insight_generation',
          cost: calculate_insight_generation_cost(responses_data),
          model: form.ai_model
        )
        
        Rails.logger.info "Successfully generated AI insights for form #{form_id}"
      else
        Rails.logger.error "AI insight generation failed: #{result.error_message}"
      end
    end
    
    private
    
    def prepare_responses_data(form, date)
      responses = form.form_responses.where(
        created_at: date.beginning_of_day..date.end_of_day
      ).includes(:question_responses)
      
      {
        date: date,
        responses: responses.limit(50), # Limit for AI processing
        total_count: responses.count,
        completion_rate: form.completion_rate,
        average_time: form.average_completion_time_minutes,
        sample_answers: sample_response_data(responses)
      }
    end
    
    def sample_response_data(responses)
      # Create representative sample of responses for AI analysis
      responses.completed.limit(10).map do |response|
        {
          id: response.id,
          duration_minutes: response.duration_minutes,
          answers: response.answers_hash,
          quality_score: response.quality_score,
          sentiment_score: response.sentiment_score,
          device_type: determine_device_type(response.user_agent)
        }
      end
    end
    
    def extract_behavioral_patterns(responses_data)
      # Analyze behavioral patterns from the response data
      {
        common_abandonment_points: identify_abandonment_patterns(responses_data),
        completion_time_patterns: analyze_time_patterns(responses_data),
        answer_quality_trends: analyze_quality_trends(responses_data),
        device_preferences: analyze_device_patterns(responses_data)
      }
    end
    
    def calculate_insight_generation_cost(responses_data)
      # Base cost + per response analysis cost
      base_cost = 0.05
      per_response_cost = responses_data[:responses].count * 0.01
      base_cost + per_response_cost
    end
    
    def determine_device_type(user_agent)
      return 'unknown' unless user_agent
      
      case user_agent.downcase
      when /mobile|android|iphone/ then 'mobile'
      when /tablet|ipad/ then 'tablet'
      else 'desktop'
      end
    end
  end
end
```

## Phase 5: API and Integration Layer (Days 26-30)

### Day 26: REST API Implementation

#### 26.1 API Base Controller
```ruby
# app/controllers/api/base_controller.rb
module Api
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
    
    before_action :authenticate_api_user!
    before_action :set_default_response_format
    
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
    rescue_from SuperAgent::WorkflowError, with: :handle_workflow_error
    rescue_from StandardError, with: :handle_standard_error
    
    protected
    
    def authenticate_api_user!
      authenticate_or_request_with_http_token do |token, _options|
        @current_user = User.joins(:api_tokens)
                           .where(api_tokens: { token: token, active: true })
                           .first
      end
    end
    
    def current_user
      @current_user
    end
    
    def set_default_response_format
      request.format = :json
    end
    
    def render_success(data = {}, status: :ok)
      render json: {
        success: true,
        data: data,
        timestamp: Time.current.iso8601
      }, status: status
    end
    
    def render_error(message, details = {}, status: :bad_request)
      render json: {
        success: false,
        error: {
          message: message,
          details: details,
          code: status.to_s
        },
        timestamp: Time.current.iso8601
      }, status: status
    end
    
    private
    
    def handle_not_found(exception)
      render_error('Resource not found', { resource: exception.model }, :not_found)
    end
    
    def handle_invalid_record(exception)
      render_error('Validation failed', { 
        errors: exception.record.errors.full_messages 
      }, :unprocessable_entity)
    end
    
    def handle_workflow_error(exception)
      render_error('Workflow execution failed', {
        workflow_error: exception.message
      }, :internal_server_error)
    end
    
    def handle_standard_error(exception)
      Rails.logger.error "API Error: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      
      render_error('Internal server error', {}, :internal_server_error)
    end
  end
end

# app/controllers/api/v1/forms_controller.rb
module Api
  module V1
    class FormsController < Api::BaseController
      before_action :set_form, only: [:show, :update, :destroy, :responses, :analytics]
      
      def index
        forms = current_user.forms
                           .includes(:form_questions, :form_analytics)
                           .page(params[:page])
                           .per(params[:per_page] || 20)
        
        render_success({
          forms: forms.map { |form| serialize_form(form) },
          pagination: {
            current_page: forms.current_page,
            total_pages: forms.total_pages,
            total_count: forms.total_count
          }
        })
      end
      
      def show
        render_success({
          form: serialize_form(@form, include_questions: true),
          analytics: @form.analytics_summary(period: 30.days)
        })
      end
      
      def create
        form = current_user.forms.build(form_params)
        
        if form.save
          # Generate workflow in background
          Forms::WorkflowGenerationJob.perform_later(form.id)
          
          render_success({
            form: serialize_form(form),
            message: 'Form created successfully'
          }, status: :created)# AgentForm Implementation Blueprint - Part 5

## Continuation from Part 4 - AI Enhancement Panel Component

```erb
<!-- app/views/forms/_ai_enhancement_panel.html.erb (continued) -->
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-purple-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                  </svg>
                  Smart Validation
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  AI analyzes user input in real-time to provide intelligent validation and suggestions.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.01 credits per validation
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('smart_validation'),
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "smart_validation" }
                      },
                      'smart_validation', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-purple-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
                </label>
              <% end %>
            </div>
          </div>
          
          <!-- Dynamic Follow-ups -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-blue-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z"/>
                    <path d="M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z"/>
                  </svg>
                  Dynamic Follow-ups
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  Generate contextual follow-up questions based on user responses.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.03 credits per follow-up generated
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('dynamic_followups'),
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "dynamic_followups" }
                      },
                      'dynamic_followups', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              <% end %>
            </div>
          </div>
          
          <!-- Response Analysis -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"/>
                    <path fill-rule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2V6a2 2 0 00-2-2V3a2 2 0 00-2-2H6a2 2 0 00-2 2v2z" clip-rule="evenodd"/>
                  </svg>
                  Response Analysis
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  Analyze sentiment, intent, and quality of responses for deeper insights.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.02 credits per response analyzed
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('response_analysis'),
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "response_analysis" }
                      },
                      'response_analysis', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-green-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-600"></div>
                </label>
              <% end %>
            </div>
          </div>
          
          <!-- Auto Optimization -->
          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition-colors">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h5 class="text-base font-medium text-gray-900 flex items-center">
                  <svg class="w-5 h-5 text-orange-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"/>
                  </svg>
                  Auto Optimization
                </h5>
                <p class="mt-2 text-sm text-gray-600">
                  Automatically suggest and apply form improvements based on performance data.
                </p>
                <div class="mt-3 text-xs text-gray-500">
                  <strong>Cost:</strong> ~0.05 credits per optimization analysis
                </div>
                <div class="mt-2 text-xs text-orange-600 font-medium">
                  Premium Feature
                </div>
              </div>
              
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <label class="relative inline-flex items-center cursor-pointer">
                  <%= f.check_box 'ai_configuration[features][]', 
                      { 
                        checked: @form.ai_features_enabled.include?('auto_optimization'),
                        disabled: !current_user.premium?,
                        data: { action: "change->ai-enhancement#toggleFeature", feature: "auto_optimization" }
                      },
                      'auto_optimization', '' %>
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-orange-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-orange-600 disabled:opacity-50"></div>
                </label>
              <% end %>
            </div>
          </div>
        </div>
        
        <!-- Advanced Configuration -->
        <div class="border-t border-gray-200 pt-6">
          <h5 class="text-base font-medium text-gray-900 mb-4">Advanced Settings</h5>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Confidence Threshold -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                AI Confidence Threshold
              </label>
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <div class="flex items-center space-x-4">
                  <%= f.range_field 'ai_configuration[confidence_threshold]', 
                      value: @form.ai_configuration.dig('confidence_threshold') || 0.7,
                      min: 0.1, max: 1.0, step: 0.1,
                      class: "flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer",
                      data: { action: "input->ai-enhancement#updateConfidence" } %>
                  <span class="text-sm font-medium text-gray-700 min-w-[3rem]" 
                        data-ai-enhancement-target="confidenceDisplay">
                    <%= (@form.ai_configuration.dig('confidence_threshold') || 0.7).round(1) %>
                  </span>
                </div>
              <% end %>
              <p class="mt-1 text-xs text-gray-500">
                Minimum confidence level required for AI suggestions to be shown
              </p>
            </div>
            
            <!-- Response Quality Filter -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Response Quality Filter
              </label>
              <%= form_with model: @form, url: form_path(@form), method: :patch, local: false do |f| %>
                <%= f.select 'ai_configuration[quality_filter]', 
                    options_for_select([
                      ['All Responses', 'none'],
                      ['Medium Quality and Above', 'medium'],
                      ['High Quality Only', 'high']
                    ], @form.ai_configuration.dig('quality_filter') || 'none'),
                    {},
                    { 
                      class: "block w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500"
                    } %>
              <% end %>
              <p class="mt-1 text-xs text-gray-500">
                Filter which responses trigger AI analysis based on quality
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  <% else %>
    <!-- AI Disabled State -->
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
      <div class="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
          <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"/>
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">AI Features Disabled</h3>
      <p class="text-gray-600 mb-4">
        Enable AI features to unlock intelligent form capabilities like smart validation, 
        dynamic follow-ups, and response analysis.
      </p>
      <button data-action="click->ai-enhancement#enableAI" 
              class="inline-flex items-center px-4 py-2 bg-purple-600 border border-transparent rounded-md text-sm font-medium text-white hover:bg-purple-700">
        Enable AI Features
      </button>
    </div>
  <% end %>
</div>

<script>
  // AI Enhancement Controller
  class AIEnhancementController extends Application.Controller {
    static targets = ["confidenceDisplay"]
    
    async handleMasterToggle(event) {
      const enabled = event.target.checked
      
      try {
        await this.updateFormSetting('ai_configuration[enabled]', enabled)
        
        if (enabled) {
          FormBuilder.showToast('AI features enabled!', 'success')
          this.showAIFeatures()
        } else {
          FormBuilder.showToast('AI features disabled', 'info')
          this.hideAIFeatures()
        }
      } catch (error) {
        FormBuilder.showToast('Failed to update AI settings', 'error')
        event.target.checked = !enabled // Revert
      }
    }
    
    async toggleFeature(event) {
      const feature = event.target.dataset.feature
      const enabled = event.target.checked
      
      if (enabled && !await this.checkAIBudget()) {
        event.target.checked = false
        FormBuilder.showToast('Insufficient AI credits to enable this feature', 'warning')
        return
      }
      
      try {
        const features = this.getCurrentFeatures()
        
        if (enabled) {
          features.push(feature)
        } else {
          const index = features.indexOf(feature)
          if (index > -1) features.splice(index, 1)
        }
        
        await this.updateFormSetting('ai_configuration[features]', features)
        
        FormBuilder.showToast(
          `${this.featureName(feature)} ${enabled ? 'enabled' : 'disabled'}`, 
          'success'
        )
      } catch (error) {
        FormBuilder.showToast('Failed to update feature setting', 'error')
        event.target.checked = !enabled // Revert
      }
    }
    
    updateConfidence(event) {
      const value = parseFloat(event.target.value)
      if (this.hasConfidenceDisplayTarget) {
        this.confidenceDisplayTarget.textContent = value.toFixed(1)
      }
      
      // Debounce the update
      clearTimeout(this.confidenceTimeout)
      this.confidenceTimeout = setTimeout(() => {
        this.updateFormSetting('ai_configuration[confidence_threshold]', value)
      }, 1000)
    }
    
    async updateModel(event) {
      const model = event.target.value
      
      try {
        await this.updateFormSetting('ai_configuration[model]', model)
        FormBuilder.showToast(`AI model updated to ${model}`, 'success')
      } catch (error) {
        FormBuilder.showToast('Failed to update AI model', 'error')
      }
    }
    
    async updateBudget(event) {
      const budget = parseFloat(event.target.value)
      
      try {
        await this.updateFormSetting('ai_configuration[budget_limit]', budget)
        FormBuilder.showToast(`Budget limit set to ${budget} credits`, 'success')
      } catch (error) {
        FormBuilder.showToast('Failed to update budget limit', 'error')
      }
    }
    
    async enableAI() {
      try {
        await this.updateFormSetting('ai_configuration[enabled]', true)
        location.reload() // Refresh to show AI options
      } catch (error) {
        FormBuilder.showToast('Failed to enable AI features', 'error')
      }
    }
    
    // Helper Methods
    async updateFormSetting(setting, value) {
      const formData = new FormData()
      formData.append(setting, value)
      
      const response = await fetch(window.location.pathname, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': this.csrfToken() },
        body: formData
      })
      
      if (!response.ok) {
        throw new Error('Update failed')
      }
    }
    
    async checkAIBudget() {
      // Check if user has sufficient AI credits
      const response = await fetch('/api/ai_budget_check', {
        headers: { 'X-CSRF-Token': this.csrfToken() }
      })
      
      if (response.ok) {
        const data = await response.json()
        return data.sufficient
      }
      
      return false
    }
    
    getCurrentFeatures() {
      return Array.from(document.querySelectorAll('[name*="ai_configuration[features]"]:checked'))
                  .map(input => input.value)
                  .filter(value => value !== '')
    }
    
    featureName(feature) {
      const names = {
        'smart_validation': 'Smart Validation',
        'dynamic_followups': 'Dynamic Follow-ups',
        'response_analysis': 'Response Analysis',
        'auto_optimization': 'Auto Optimization'
      }
      return names[feature] || feature
    }
    
    showAIFeatures() {
      document.querySelectorAll('.ai-feature').forEach(el => {
        el.classList.remove('hidden')
      })
    }
    
    hideAIFeatures() {
      document.querySelectorAll('.ai-feature').forEach(el => {
        el.classList.add('hidden')
      })
    }
    
    csrfToken() {
      return document.querySelector('[name="csrf-token"]').content
    }
  }
  
  application.register("ai-enhancement", AIEnhancementController)
</script>
```

## Phase 4: Background Jobs Implementation (Days 22-25)

### Day 22: Core Job Classes

#### 22.1 Form Workflow Jobs
```ruby
# app/jobs/forms/workflow_generation_job.rb
module Forms
  class WorkflowGenerationJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    
    def perform(form_id)
      form = Form.find(form_id)
      
      Rails.logger.info "Generating workflow for form #{form.id}: #{form.name}"
      
      # Generate the workflow class dynamically
      service = Forms::WorkflowGeneratorService.new(form)
      workflow_class = service.generate_class
      
      # Update form with workflow information
      form.update!(
        workflow_class_name: workflow_class.name,
        workflow_state: { 
          generated_at: Time.current,
          version: '1.0',
          questions_count: form.form_questions.count
        }
      )
      
      # Trigger workflow validation
      Forms::WorkflowValidationJob.perform_later(form.id)
      
      Rails.logger.info "Successfully generated workflow #{workflow_class.name} for form #{form.id}"
    end
  end
end

# app/jobs/forms/response_analysis_job.rb
module Forms
  class ResponseAnalysisJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(question_response_id)
      question_response = QuestionResponse.find(question_response_id)
      form_response = question_response.form_response
      question = question_response.form_question
      
      return unless question.ai_enhanced?
      return unless form_response.form.user.can_use_ai_features?
      
      Rails.logger.info "Analyzing response #{question_response.id} for question #{question.id}"
      
      # Run AI analysis workflow
      agent = Forms::ResponseAgent.new
      result = agent.analyze_response_quality(form_response)
      
      if result.completed?
        # Update the question response with AI insights
        analysis_data = result.final_output
        
        question_response.update!(
          ai_analysis: analysis_data[:ai_analysis],
          confidence_score: analysis_data[:confidence_score],
          completeness_score: analysis_data[:completeness_score]
        )
        
        # Generate dynamic follow-up if needed
        if analysis_data[:generate_followup]
          Forms::DynamicQuestionGenerationJob.perform_later(
            form_response.id, 
            question.id
          )
        end
        
        # Update form response AI analysis
        aggregate_analysis = aggregate_response_analysis(form_response)
        form_response.update!(ai_analysis: aggregate_analysis)
        
        Rails.logger.info "Successfully analyzed response #{question_response.id}"
      else
        Rails.logger.error "Response analysis failed: #{result.error_message}"
      end
    end
    
    private
    
    def aggregate_response_analysis(form_response)
      analyses = form_response.question_responses
                             .where.not(ai_analysis: {})
                             .pluck(:ai_analysis)
      
      return {} if analyses.empty?
      
      # Aggregate sentiment scores
      sentiments = analyses.map { |a| a.dig('sentiment', 'confidence') }.compact
      avg_sentiment = sentiments.any? ? sentiments.sum / sentiments.size : 0.5
      
      # Aggregate quality scores  
      quality_scores = analyses.map { |a| a.dig('quality', 'completeness') }.compact
      avg_quality = quality_scores.any? ? quality_scores.sum / quality_scores.size : 0.5
      
      # Collect insights
      all_insights = analyses.flat_map { |a| a['insights'] || [] }
      
      # Collect flags
      all_flags = analyses.map { |a| a['flags'] || {} }.reduce({}) do |merged, flags|
        flags.each { |key, value| merged[key] = (merged[key] || false) || value }
        merged
      end
      
      {
        overall_sentiment: avg_sentiment,
        overall_quality: avg_quality,
        key_insights: all_insights.uniq.first(5),
        flags: all_flags,
        analysis_count: analyses.size,
        analyzed_at: Time.current
      }
    end
  end
end

# app/jobs/forms/dynamic_question_generation_job.rb
module Forms
  class DynamicQuestionGenerationJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_response_id, source_question_id)
      form_response = FormResponse.find(form_response_id)
      source_question = FormQuestion.find(source_question_id)
      
      return unless source_question.generates_followups?
      return unless form_response.form.user.can_use_ai_features?
      
      # Check if we've already generated enough follow-ups for this question
      existing_count = form_response.dynamic_questions
                                   .where(generated_from_question: source_question)
                                   .count
      
      max_followups = source_question.ai_enhancement.dig('max_followups') || 2
      return if existing_count >= max_followups
      
      Rails.logger.info "Generating dynamic question for response #{form_response_id} from question #{source_question_id}"
      
      # Run dynamic question generation workflow
      agent = Forms::ResponseAgent.new
      result = agent.run_workflow(Forms::DynamicQuestionWorkflow, initial_input: {
        response_id: form_response_id,
        source_question_id: source_question_id,
        user_id: form_response.form.user_id
      })
      
      if result.completed?
        dynamic_question_id = result.output_for(:create_dynamic_question_record)[:dynamic_question_id]
        
        # Broadcast the new question to the user's browser
        Forms::BroadcastDynamicQuestionJob.perform_later(
          form_response.id,
          dynamic_question_id
        )
        
        Rails.logger.info "Successfully generated dynamic question #{dynamic_question_id}"
      else
        Rails.logger.error "Dynamic question generation failed: #{result.error_message}"
      end
    end
  end
end
```

#### 22.2 Integration Jobs
```ruby
# app/jobs/forms/integration_trigger_job.rb
module Forms
  class IntegrationTriggerJob < ApplicationJob
    queue_as :integrations
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    
    def perform(form_response_id, trigger_event = 'form_completed')
      form_response = FormResponse.find(form_response_id)
      form = form_response.form
      
      return unless form.integration_settings.present?
      
      Rails.logger.info "Triggering integrations for form response #{form_response_id}, event: #{trigger_event}"
      
      # Get enabled integrations for this trigger event
      enabled_integrations = form.integration_settings.select do |integration_name, config|
        config['enabled'] == true && 
        config['triggers']&.include?(trigger_event)
      end
      
      # Process each integration
      enabled_integrations.each do |integration_name, config|
        begin
          process_integration(integration_name, config, form_response, trigger_event)
        rescue => e
          Rails.logger.error "Integration #{integration_name} failed: #{e.message}"
          # Don't fail the entire job for one integration failure
        end
      end
    end
    
    private
    
    def process_integration(integration_name, config, form_response, trigger_event)
      case integration_name
      when 'webhook'
        process_webhook_integration(config, form_response, trigger_event)
      when 'email_notification'
        process_email_integration(config, form_response, trigger_event)
      when 'crm_sync'
        process_crm_integration(config, form_response, trigger_event)
      when 'slack_notification'
        process_slack_integration(config, form_response, trigger_event)
      when 'zapier'
        process_zapier_integration(config, form_response, trigger_event)
      else
        Rails.logger.warn "Unknown integration: #{integration_name}"
      end
    end
    
    def process_webhook_integration(config, form_response, trigger_event)
      webhook_url = config['webhook_url']
      return unless webhook_url.present?
      
      payload = {
        event: trigger_event,
        form_id: form_response.form_id,
        response_id: form_response.id,
        form_name: form_response.form.name,
        submitted_at: form_response.completed_at || form_response.created_at,
        data: form_response.answers_hash,
        metadata: {
          session_id: form_response.session_id,
          ip_address: form_response.ip_address,
          user_agent: form_response.user_agent,
          utm_parameters: form_response.utm_parameters
        }
      }
      
      # Add AI analysis if available
      if form_response.ai_analysis.present?
        payload[:ai_analysis] = form_response.ai_analysis
      end
      
      headers = {
        'Content-Type' => 'application/json',
        'User-Agent' => 'AgentForm-Webhook/1.0'
      }
      
      # Add custom headers if configured
      if config['headers'].present?
        headers.merge!(config['headers'])
      end
      
      # Add authentication

-------------------------------------------------------------

# AgentForm Implementation Blueprint - Part 6

## Continuation from Part 5 - API Implementation

### 26.1 Forms API Controller (Continued)

```ruby
# app/controllers/api/v1/forms_controller.rb (continued)
        else
          render_error('Form creation failed', form.errors.full_messages, :unprocessable_entity)
        end
      end
      
      def update
        if @form.update(form_params)
          # Regenerate workflow if structure changed
          if form_structure_changed?
            Forms::WorkflowRegenerationJob.perform_later(@form.id)
          end
          
          render_success({
            form: serialize_form(@form),
            message: 'Form updated successfully'
          })
        else
          render_error('Form update failed', @form.errors.full_messages, :unprocessable_entity)
        end
      end
      
      def destroy
        @form.destroy
        render_success({ message: 'Form deleted successfully' })
      end
      
      def responses
        responses = @form.form_responses
                         .includes(:question_responses)
                         .where(filter_params)
                         .order(sort_params)
                         .page(params[:page])
                         .per(params[:per_page] || 50)
        
        render_success({
          responses: responses.map { |response| serialize_response(response) },
          pagination: pagination_meta(responses),
          summary: responses_summary(responses)
        })
      end
      
      def analytics
        period = parse_period(params[:period] || '30d')
        analytics_service = Forms::AnalyticsService.new(@form, period: period)
        
        render_success({
          analytics: analytics_service.detailed_report,
          period: {
            start: period.ago.iso8601,
            end: Time.current.iso8601,
            days: period / 1.day
          }
        })
      end
      
      def export
        format = params[:format] || 'json'
        filters = export_filter_params
        
        # Queue export job for large datasets
        if @form.form_responses.count > 1000
          job = Forms::DataExportJob.perform_later(@form.id, format, filters)
          
          render_success({
            export_queued: true,
            job_id: job.job_id,
            message: 'Export started. You will receive an email when ready.'
          }, status: :accepted)
        else
          # Generate export immediately for small datasets
          exporter = Forms::DataExportService.new(@form, format: format, filters: filters)
          
          case format
          when 'csv'
            send_data exporter.to_csv, 
                     filename: "#{@form.name.parameterize}_responses.csv",
                     type: 'text/csv'
          when 'xlsx'
            send_data exporter.to_xlsx, 
                     filename: "#{@form.name.parameterize}_responses.xlsx",
                     type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          when 'json'
            render json: exporter.to_json
          else
            render_error('Unsupported export format', { supported: %w[csv xlsx json] })
          end
        end
      end
      
      private
      
      def set_form
        @form = current_user.forms.find(params[:id])
      end
      
      def form_params
        params.require(:form).permit(
          :name, :description, :category,
          form_settings: {},
          ai_configuration: {},
          style_configuration: {},
          integration_settings: {},
          notification_settings: {}
        )
      end
      
      def filter_params
        filters = {}
        filters[:status] = params[:status] if params[:status].present?
        filters[:created_at] = parse_date_range(params[:date_range]) if params[:date_range].present?
        filters
      end
      
      def sort_params
        case params[:sort]
        when 'created_at_asc' then { created_at: :asc }
        when 'created_at_desc' then { created_at: :desc }
        when 'completed_at_asc' then { completed_at: :asc }
        when 'completed_at_desc' then { completed_at: :desc }
        when 'quality_score' then { quality_score: :desc }
        else { created_at: :desc }
        end
      end
      
      def serialize_form(form, include_questions: false)
        data = {
          id: form.id,
          name: form.name,
          description: form.description,
          status: form.status,
          category: form.category,
          share_token: form.share_token,
          public_url: form.public_url,
          created_at: form.created_at,
          updated_at: form.updated_at,
          stats: {
            views_count: form.views_count,
            responses_count: form.responses_count,
            completions_count: form.completions_count,
            completion_rate: form.completion_rate,
            average_completion_time: form.average_completion_time_minutes
          },
          settings: form.form_settings,
          ai_configuration: form.ai_configuration
        }
        
        if include_questions
          data[:questions] = form.questions_ordered.map { |q| serialize_question(q) }
        end
        
        data
      end
      
      def serialize_question(question)
        {
          id: question.id,
          title: question.title,
          description: question.description,
          question_type: question.question_type,
          position: question.position,
          required: question.required?,
          configuration: question.field_configuration,
          validation_rules: question.validation_rules,
          ai_enhancement: question.ai_enhancement,
          stats: {
            responses_count: question.responses_count,
            completion_rate: question.completion_rate,
            average_response_time: question.average_response_time_seconds
          }
        }
      end
      
      def serialize_response(response)
        {
          id: response.id,
          session_id: response.session_id,
          status: response.status,
          started_at: response.started_at,
          completed_at: response.completed_at,
          duration_minutes: response.duration_minutes,
          progress_percentage: response.progress_percentage,
          answers: response.answers_hash,
          metadata: response.metadata,
          quality_metrics: {
            quality_score: response.quality_score,
            sentiment_score: response.sentiment_score,
            completion_score: response.completion_score
          },
          ai_analysis: response.ai_analysis
        }
      end
      
      def parse_period(period_string)
        case period_string
        when /^(\d+)d$/ then $1.to_i.days
        when /^(\d+)w$/ then $1.to_i.weeks  
        when /^(\d+)m$/ then $1.to_i.months
        else 30.days
        end
      end
      
      def parse_date_range(range_string)
        # Format: "2024-01-01,2024-01-31" or "last_30_days"
        case range_string
        when 'last_7_days' then 7.days.ago..Time.current
        when 'last_30_days' then 30.days.ago..Time.current
        when 'last_90_days' then 90.days.ago..Time.current
        else
          dates = range_string.split(',')
          Date.parse(dates[0])..Date.parse(dates[1])
        end
      rescue
        30.days.ago..Time.current
      end
      
      def form_structure_changed?
        @form.previous_changes.keys.intersect?(%w[name category form_settings])
      end
    end
  end
end

# app/controllers/api/v1/responses_controller.rb
module Api
  module V1
    class ResponsesController < Api::BaseController
      skip_before_action :authenticate_api_user!, only: [:create, :show]
      before_action :find_form_by_token, only: [:create, :show]
      before_action :set_response, only: [:show, :update]
      
      def create
        # API endpoint for submitting form responses
        service = Forms::ApiResponseSubmissionService.new(
          form: @form,
          response_data: response_params[:answers],
          metadata: {
            api_submission: true,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            submitted_at: Time.current
          }
        )
        
        result = service.submit
        
        if result.success?
          render_success({
            response: serialize_response(result.response),
            message: 'Response submitted successfully'
          }, status: :created)
        else
          render_error('Response submission failed', {
            errors: result.errors
          }, :unprocessable_entity)
        end
      end
      
      def show
        render_success({
          response: serialize_response(@response)
        })
      end
      
      def update
        # Allow updating incomplete responses
        if @response.in_progress?
          service = Forms::ResponseUpdateService.new(@response, response_params[:answers])
          
          if service.update
            render_success({
              response: serialize_response(@response.reload),
              message: 'Response updated successfully'
            })
          else
            render_error('Response update failed', service.errors, :unprocessable_entity)
          end
        else
          render_error('Cannot update completed response', {}, :forbidden)
        end
      end
      
      private
      
      def find_form_by_token
        @form = Form.published.find_by!(share_token: params[:form_token])
      rescue ActiveRecord::RecordNotFound
        render_error('Form not found or not published', {}, :not_found)
      end
      
      def set_response
        @response = @form.form_responses.find(params[:id])
      end
      
      def response_params
        params.require(:response).permit(
          :session_id,
          answers: {},
          metadata: {}
        )
      end
    end
  end
end
```

### Day 27: A2A Protocol Implementation

#### 27.1 A2A Server Configuration
```ruby
# app/services/forms/a2a_service.rb
module Forms
  class A2aService
    attr_reader :form
    
    def initialize(form)
      @form = form
    end
    
    def generate_agent_card
      SuperAgent::A2A::AgentCard.new(
        id: "agentform-#{form.id}",
        name: "AgentForm: #{form.name}",
        description: form.description || "AI-powered form processing agent",
        version: "1.0.0",
        service_endpoint_url: a2a_endpoint_url,
        capabilities: generate_capabilities,
        supported_modalities: %w[text json],
        authentication_requirements: authentication_config,
        metadata: {
          form_id: form.id,
          question_count: form.form_questions.count,
          ai_enhanced: form.ai_enhanced?,
          category: form.category
        }
      )
    end
    
    private
    
    def generate_capabilities
      capabilities = []
      
      # Basic form submission capability
      capabilities << SuperAgent::A2A::Capability.new(
        name: 'submit_form_response',
        description: "Submit a response to the #{form.name} form",
        parameters: generate_form_parameters_schema,
        returns: {
          'type' => 'object',
          'properties' => {
            'response_id' => { 'type' => 'string' },
            'status' => { 'type' => 'string' },
            'completion_url' => { 'type' => 'string' }
          }
        },
        examples: [generate_submission_example]
      )
      
      # Form analysis capability (if AI enhanced)
      if form.ai_enhanced?
        capabilities << SuperAgent::A2A::Capability.new(
          name: 'analyze_form_performance',
          description: "Get AI-powered analysis of form performance and optimization suggestions",
          parameters: {
            'type' => 'object',
            'properties' => {
              'period_days' => { 'type' => 'integer', 'default' => 30 },
              'include_insights' => { 'type' => 'boolean', 'default' => true }
            }
          },
          returns: {
            'type' => 'object',
            'properties' => {
              'performance_score' => { 'type' => 'number' },
              'insights' => { 'type' => 'array' },
              'recommendations' => { 'type' => 'array' }
            }
          }
        )
      end
      
      capabilities
    end
    
    def generate_form_parameters_schema
      properties = {}
      required_fields = []
      
      form.form_questions.each do |question|
        field_name = question.title.parameterize(separator: '_')
        
        properties[field_name] = {
          'type' => map_question_type_to_json_type(question.question_type),
          'description' => question.description || question.title
        }
        
        if question.question_type == 'multiple_choice' && question.allows_multiple?
          properties[field_name]['type'] = 'array'
          properties[field_name]['items'] = { 'type' => 'string' }
        end
        
        required_fields << field_name if question.required?
      end
      
      {
        'type' => 'object',
        'properties' => properties,
        'required' => required_fields
      }
    end
    
    def generate_submission_example
      example_data = {}
      
      form.form_questions.limit(3).each do |question|
        field_name = question.title.parameterize(separator: '_')
        example_data[field_name] = generate_example_answer(question)
      end
      
      {
        input: example_data,
        output: {
          response_id: 'resp_example_123',
          status: 'completed',
          completion_url: "#{form.public_url}/thank_you"
        }
      }
    end
    
    def generate_example_answer(question)
      case question.question_type
      when 'text_short' then 'Example text response'
      when 'email' then 'user@example.com'
      when 'number' then 42
      when 'rating' then question.rating_config[:max] / 2
      when 'yes_no' then 'yes'
      when 'multiple_choice'
        if question.allows_multiple?
          question.choice_options.first(2).map { |opt| opt['value'] }
        else
          question.choice_options.first&.dig('value') || 'option_1'
        end
      when 'date' then Date.current.iso8601
      else 'Example answer'
      end
    end
    
    def map_question_type_to_json_type(question_type)
      case question_type
      when 'number', 'rating', 'scale' then 'number'
      when 'yes_no', 'boolean' then 'boolean'
      when 'date', 'datetime' then 'string'
      when 'file_upload' then 'object'
      else 'string'
      end
    end
    
    def a2a_endpoint_url
      Rails.application.routes.url_helpers.a2a_forms_url(
        form_token: form.share_token,
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )
    end
    
    def authentication_config
      if form.form_settings.dig('sharing', 'require_authentication')
        {
          'type' => 'bearer_token',
          'description' => 'API key required for form access'
        }
      else
        {}
      end
    end
  end
end

# app/controllers/a2a/forms_controller.rb
module A2a
  class FormsController < ActionController::API
    include SuperAgent::A2A::ControllerMethods
    
    before_action :authenticate_a2a_request!
    before_action :find_form_by_token
    
    def agent_card
      service = Forms::A2aService.new(@form)
      agent_card = service.generate_agent_card
      
      render json: agent_card.to_json
    end
    
    def health
      render json: {
        status: 'healthy',
        form_id: @form.id,
        form_name: @form.name,
        timestamp: Time.current.iso8601,
        version: '1.0.0'
      }
    end
    
    def invoke
      skill_name = params[:skill] || request_params.dig('method')
      skill_params = params[:parameters] || request_params.dig('params', 'parameters')
      
      case skill_name
      when 'submit_form_response'
        handle_form_submission(skill_params)
      when 'analyze_form_performance'
        handle_performance_analysis(skill_params)
      else
        render_a2a_error(-32601, "Method not found: #{skill_name}")
      end
    end
    
    private
    
    def find_form_by_token
      @form = Form.published.find_by!(share_token: params[:form_token])
    rescue ActiveRecord::RecordNotFound
      render_a2a_error(-32602, "Form not found")
    end
    
    def handle_form_submission(parameters)
      service = Forms::A2aSubmissionService.new(@form, parameters)
      result = service.process
      
      if result.success?
        render_a2a_success({
          response_id: result.response.id,
          status: result.response.status,
          completion_url: result.completion_url,
          ai_analysis: result.ai_analysis
        })
      else
        render_a2a_error(-32603, "Submission failed", result.errors)
      end
    end
    
    def handle_performance_analysis(parameters)
      return render_a2a_error(-32602, "AI features not enabled") unless @form.ai_enhanced?
      
      period = (parameters['period_days'] || 30).days
      include_insights = parameters['include_insights'] != false
      
      analytics_service = Forms::AnalyticsService.new(@form, period: period)
      report = analytics_service.detailed_report
      
      analysis_data = {
        performance_score: calculate_performance_score(report),
        completion_rate: report[:overview][:completion_rate],
        average_time: report[:overview][:average_completion_time],
        total_responses: report[:overview][:total_starts]
      }
      
      if include_insights && report[:ai_insights].present?
        analysis_data[:insights] = report[:ai_insights][:optimization_plan]
        analysis_data[:recommendations] = report[:ai_insights][:priority_actions]
      end
      
      render_a2a_success(analysis_data)
    end
    
    def calculate_performance_score(report)
      # Simple performance scoring algorithm
      completion_rate_score = [report[:overview][:completion_rate], 100].min
      time_score = [100 - (report[:overview][:average_completion_time] * 2), 0].max
      quality_score = (report[:quality_metrics][:average_quality_score] || 0.5) * 100
      
      (completion_rate_score * 0.5 + time_score * 0.3 + quality_score * 0.2).round(1)
    end
  end
end
```

### Day 28: Advanced Workflow Features

#### 28.1 Form Template System
```ruby
# app/models/form_template.rb
class FormTemplate < ApplicationRecord
  belongs_to :creator, class_name: 'User', optional: true
  has_many :form_instances, class_name: 'Form', foreign_key: 'template_id'
  
  enum :category, Form.categories
  enum :visibility, { private: 'private', public: 'public', featured: 'featured' }
  
  validates :name, presence: true
  validates :template_data, presence: true
  validates :category, presence: true
  
  scope :available_to_user, ->(user) { 
    where('visibility = ? OR creator_id = ?', 'public', user.id) 
  }
  scope :featured, -> { where(visibility: 'featured') }
  scope :by_category, ->(category) { where(category: category) }
  
  def questions_config
    template_data['questions'] || []
  end
  
  def form_settings_template
    template_data['form_settings'] || {}
  end
  
  def ai_configuration_template
    template_data['ai_configuration'] || {}
  end
  
  def instantiate_for_user(user, customizations = {})
    Forms::TemplateInstantiationService.new(self, user, customizations).create_form
  end
  
  def preview_data
    {
      id: id,
      name: name,
      description: description,
      category: category,
      questions_count: questions_config.size,
      estimated_completion_time: calculate_estimated_time,
      features: extract_features,
      preview_questions: questions_config.first(3)
    }
  end
  
  private
  
  def calculate_estimated_time
    # Estimate based on question types and count
    base_time = questions_config.size * 0.5 # 30 seconds per question base
    
    complex_questions = questions_config.count do |q|
      %w[text_long file_upload matrix].include?(q['question_type'])
    end
    
    base_time + (complex_questions * 1.0) # Add 1 minute for complex questions
  end
  
  def extract_features
    features = []
    features << 'AI Enhanced' if ai_configuration_template['enabled']
    features << 'Conditional Logic' if questions_config.any? { |q| q['conditional_logic'].present? }
    features << 'File Upload' if questions_config.any? { |q| q['question_type'] == 'file_upload' }
    features << 'Multi-Page' if form_settings_template.dig('ui', 'one_question_per_page')
    features
  end
end

# app/services/forms/template_instantiation_service.rb
module Forms
  class TemplateInstantiationService
    attr_reader :template, :user, :customizations, :errors
    
    def initialize(template, user, customizations = {})
      @template = template
      @user = user
      @customizations = customizations
      @errors = []
    end
    
    def create_form
      ActiveRecord::Base.transaction do
        form = create_base_form
        create_questions(form)
        apply_customizations(form)
        generate_workflow(form)
        
        form
      end
    rescue => e
      @errors << e.message
      nil
    end
    
    private
    
    def create_base_form
      form_attributes = {
        name: customizations[:name] || template.name,
        description: customizations[:description] || template.description,
        category: template.category,
        form_settings: merge_settings(template.form_settings_template, customizations[:form_settings]),
        ai_configuration: merge_ai_config(template.ai_configuration_template, customizations[:ai_configuration])
      }
      
      user.forms.create!(form_attributes)
    end
    
    def create_questions(form)
      template.questions_config.each_with_index do |question_data, index|
        question_attributes = {
          title: question_data['title'],
          description: question_data['description'],
          question_type: question_data['question_type'],
          position: index + 1,
          required: question_data['required'] || false,
          field_configuration: question_data['configuration'] || {},
          validation_rules: question_data['validation_rules'] || {},
          conditional_logic: question_data['conditional_logic'] || {},
          ai_enhancement: question_data['ai_enhancement'] || {}
        }
        
        # Apply question customizations if provided
        if customizations[:questions] && customizations[:questions][index]
          question_attributes.merge!(customizations[:questions][index])
        end
        
        form.form_questions.create!(question_attributes)
      end
    end
    
    def apply_customizations(form)
      return unless customizations[:style_configuration]
      
      form.update!(style_configuration: customizations[:style_configuration])
    end
    
    def generate_workflow(form)
      Forms::WorkflowGenerationJob.perform_later(form.id)
    end
    
    def merge_settings(template_settings, custom_settings)
      template_settings.deep_merge(custom_settings || {})
    end
    
    def merge_ai_config(template_ai, custom_ai)
      merged = template_ai.deep_merge(custom_ai || {})
      
      # Ensure user has permission for AI features
      if merged['enabled'] && !user.can_use_ai_features?
        merged['enabled'] = false
        merged['features'] = []
      end
      
      merged
    end
  end
end
```

### Day 29: Testing Framework

#### 29.1 Workflow Testing Helpers
```ruby
# spec/support/workflow_helpers.rb
module WorkflowHelpers
  def run_workflow(workflow_class, initial_input = {}, user: nil)
    context = SuperAgent::Workflow::Context.new(initial_input)
    context.set(:current_user_id, user.id) if user
    
    engine = SuperAgent::WorkflowEngine.new
    engine.execute(workflow_class, context)
  end
  
  def mock_llm_response(response_text)
    allow_any_instance_of(SuperAgent::LlmInterface)
      .to receive(:complete)
      .and_return(response_text)
  end
  
  def mock_llm_json_response(response_hash)
    mock_llm_response(response_hash.to_json)
  end
  
  def expect_workflow_step(result, step_name)
    expect(result.output_for(step_name)).to be_present
    yield(result.output_for(step_name)) if block_given?
  end
  
  def expect_ai_usage_tracked(user, operation, cost)
    expect(Forms::AiUsageTracker).to have_received(:new).with(user.id)
    expect_any_instance_of(Forms::AiUsageTracker)
      .to have_received(:track_usage)
      .with(hash_including(operation: operation, cost: cost))
  end
end

# spec/workflows/forms/response_processing_workflow_spec.rb
require 'rails_helper'

RSpec.describe Forms::ResponseProcessingWorkflow do
  let(:user) { create(:user, :with_ai_credits) }
  let(:form) { create(:form, :ai_enhanced, user: user) }
  let(:question) { create(:form_question, form: form, question_type: 'text_short', ai_enhancement: { 'enabled' => true, 'features' => ['response_analysis'] }) }
  let(:form_response) { create(:form_response, form: form) }
  
  describe 'successful response processing' do
    let(:initial_input) do
      {
        form_response_id: form_response.id,
        question_id: question.id,
        answer_data: 'This is a great product!',
        metadata: { response_time: 5000 }
      }
    end
    
    before do
      mock_llm_json_response({
        sentiment: { label: 'positive', confidence: 0.9 },
        quality: { completeness: 0.8, relevance: 0.9 },
        insights: ['User shows strong satisfaction'],
        flags: { needs_followup: false, high_value_lead: true }
      })
    end
    
    it 'processes response with AI analysis' do
      result = run_workflow(described_class, initial_input, user: user)
      
      expect(result).to be_completed
      
      expect_workflow_step(result, :validate_response_data) do |validation|
        expect(validation[:valid]).to be true
        expect(validation[:processed_answer]).to eq('This is a great product!')
      end
      
      expect_workflow_step(result, :save_question_response) do |save_result|
        expect(save_result[:saved]).to be true
        
        question_response = QuestionResponse.find(save_result[:question_response_id])
        expect(question_response.answer_data).to eq('This is a great product!')
        expect(question_response.response_time_ms).to eq(5000)
      end
      
      expect_workflow_step(result, :analyze_response_ai) do |ai_analysis|
        parsed_analysis = JSON.parse(ai_analysis)
        expect(parsed_analysis['sentiment']['label']).to eq('positive')
        expect(parsed_analysis['quality']['completeness']).to eq(0.8)
      end
    end
    
    it 'skips AI analysis when user has insufficient credits' do
      user.update!(preferences: { 'ai' => { 'credits_remaining' => 0 } })
      
      result = run_workflow(described_class, initial_input, user: user)
      
      expect(result).to be_completed
      expect(result.output_for(:analyze_response_ai)).to be_nil
    end
    
    it 'generates follow-up questions when flagged by AI' do
      # Mock AI to request follow-up
      mock_llm_json_response({
        sentiment: { label: 'positive', confidence: 0.9 },
        quality: { completeness: 0.6, relevance: 0.8 },
        flags: { needs_followup: true }
      })
      
      # Mock follow-up generation
      allow_any_instance_of(SuperAgent::LlmInterface)
        .to receive(:complete)
        .and_return({
          question: {
            title: 'What specifically do you like about it?',
            question_type: 'text_short',
            configuration: {}
          }
        }.to_json)
      
      question.update!(ai_enhancement: { 'enabled' => true, 'features' => ['response_analysis', 'dynamic_followups'] })
      
      result = run_workflow(described_class, initial_input, user: user)
      
      expect(result).to be_completed
      expect_workflow_step(result, :create_dynamic_question) do |dynamic_result|
        expect(dynamic_result[:created]).to be true
        
        dynamic_question = DynamicQuestion.find(dynamic_result[:dynamic_question_id])
        expect(dynamic_question.title).to eq('What specifically do you like about it?')
      end
    end
  end
  
  describe 'error handling' do
    it 'handles invalid form response ID' do
      invalid_input = initial_input.merge(form_response_id: 'invalid')
      
      expect {
        run_workflow(described_class, invalid_input, user: user)

------------------------------------------------------------------------------------

# AgentForm Implementation Blueprint - Part 7 (Final)

## Continuation from Part 6 - Testing Framework Completion

### 29.1 Workflow Testing (Continued)

```ruby
# spec/workflows/forms/response_processing_workflow_spec.rb (continued)
      it 'handles invalid form response ID' do
        invalid_input = initial_input.merge(form_response_id: 'invalid')
        
        expect {
          run_workflow(described_class, invalid_input, user: user)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
      
      it 'handles validation errors gracefully' do
        # Test with invalid email format
        question.update!(question_type: 'email')
        invalid_input = initial_input.merge(answer_data: 'invalid-email')
        
        result = run_workflow(described_class, invalid_input, user: user)
        
        expect(result).to be_failed
        expect_workflow_step(result, :validate_response_data) do |validation|
          expect(validation[:valid]).to be false
          expect(validation[:validation_errors]).to include('Please enter a valid email address')
        end
      end
    end
  end

# spec/services/forms/answer_processing_service_spec.rb
RSpec.describe Forms::AnswerProcessingService do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let(:question) { create(:form_question, form: form, question_type: 'text_short', required: true) }
  let(:form_response) { create(:form_response, form: form) }
  
  let(:service) do
    described_class.new(
      response: form_response,
      question: question,
      answer_data: 'Test answer',
      metadata: { response_time: 3000 }
    )
  end
  
  describe '#process' do
    it 'successfully processes valid answer' do
      expect(service.process).to be true
      expect(service.errors).to be_empty
      
      question_response = form_response.question_responses.last
      expect(question_response.answer_data).to eq('Test answer')
      expect(question_response.response_time_ms).to eq(3000)
    end
    
    it 'fails validation for required question with empty answer' do
      service.answer_data = ''
      
      expect(service.process).to be false
      expect(service.errors).to include('This field is required')
    end
    
    it 'triggers AI analysis for AI-enhanced questions' do
      question.update!(ai_enhancement: { 'enabled' => true, 'features' => ['response_analysis'] })
      user.update!(preferences: { 'ai' => { 'credits_remaining' => 100 } })
      
      expect(Forms::ResponseAnalysisJob).to receive(:perform_later)
      
      service.process
    end
  end
end
```

## Phase 6: Production Deployment (Days 31-35)

### Day 31: Production Configuration

#### 31.1 Production Environment Setup
```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  
  # Asset compilation and delivery
  config.assets.compile = false
  config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser
  config.asset_host = ENV['CDN_HOST'] if ENV['CDN_HOST'].present?
  
  # Logging
  config.log_level = :info
  config.log_tags = [:request_id, :remote_ip]
  
  # Active Job
  config.active_job.queue_adapter = :sidekiq
  config.active_job.queue_name_prefix = "agentform_#{Rails.env}"
  
  # Action Mailer
  config.action_mailer.default_url_options = { host: ENV['APP_HOST'] }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_HOST'],
    port: ENV['SMTP_PORT'],
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: true
  }
  
  # File storage
  config.active_storage.variant_processor = :image_processing
  if ENV['AWS_ACCESS_KEY_ID'].present?
    config.active_storage.service = :amazon
  end
  
  # Force HTTPS in production
  config.force_ssl = true
  
  # SuperAgent production settings
  config.after_initialize do
    SuperAgent.configure do |config|
      config.logger = Rails.logger
      config.workflow_timeout = 300
      config.max_retries = 3
      config.enable_instrumentation = true
      
      # A2A server for production
      config.a2a_server_enabled = ENV['A2A_SERVER_ENABLED'] == 'true'
      config.a2a_server_port = ENV['A2A_SERVER_PORT'] || 8080
      config.a2a_server_host = '0.0.0.0'
      config.a2a_auth_token = ENV['A2A_AUTH_TOKEN']
    end
  end
end

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  
  # Queue configuration
  config.queues = %w[critical default ai_processing integrations analytics mailers]
  
  # Job retries
  config.death_handlers << lambda do |job, ex|
    Rails.logger.error "Job #{job['jid']} died: #{ex.message}"
    # Send notification to monitoring service
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

# config/initializers/cors.rb (if API access needed)
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['CORS_ORIGINS']&.split(',') || ['localhost:3000']
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
  
  # A2A protocol CORS
  allow do
    origins '*'
    resource '/a2a/*',
      headers: :any,
      methods: [:get, :post, :options],
      credentials: false
  end
end
```

#### 31.2 Docker Configuration
```dockerfile
# Dockerfile
FROM ruby:3.2-alpine

# Install dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    npm \
    git \
    imagemagick \
    vips-dev

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1 && \
    bundle install --jobs 4 --retry 3

# Copy package.json and install node modules
COPY package*.json ./
RUN npm install

# Copy application code
COPY . .

# Precompile assets
RUN RAILS_ENV=production bundle exec rails assets:precompile

# Create non-root user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://postgres:password@db:5432/agentform_production
      - REDIS_URL=redis://redis:6379/0
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
    depends_on:
      - db
      - redis
    volumes:
      - ./storage:/app/storage
  
  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=agentform_production
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
  
  sidekiq:
    build: .
    command: bundle exec sidekiq
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://postgres:password@db:5432/agentform_production
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - ./storage:/app/storage

volumes:
  postgres_data:
  redis_data:
```

### Day 32: Monitoring and Observability

#### 32.1 Application Monitoring
```ruby
# config/initializers/instrumentation.rb
if Rails.env.production?
  # Error tracking with Sentry
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 0.1
    
    # Filter sensitive data
    config.before_send = lambda do |event, hint|
      # Remove sensitive form data
      if event.extra&.dig(:form_data)
        event.extra[:form_data] = '[FILTERED]'
      end
      event
    end
  end
  
  # Performance monitoring
  if ENV['NEW_RELIC_LICENSE_KEY'].present?
    require 'newrelic_rpm'
  end
end

# SuperAgent instrumentation
SuperAgent.configure do |config|
  config.before_workflow_execution = lambda do |workflow_class, context|
    ActiveSupport::Notifications.instrument(
      'workflow.execution.start',
      workflow: workflow_class.name,
      context_keys: context.keys
    )
  end
  
  config.after_workflow_execution = lambda do |workflow_class, context, result|
    ActiveSupport::Notifications.instrument(
      'workflow.execution.complete',
      workflow: workflow_class.name,
      success: result.completed?,
      duration_ms: result.duration_ms,
      error: result.failed? ? result.error_message : nil
    )
  end
end

# Custom metrics for SuperAgent workflows
ActiveSupport::Notifications.subscribe('workflow.execution.complete') do |name, start, finish, id, payload|
  duration = (finish - start) * 1000 # Convert to milliseconds
  
  # Log workflow performance
  Rails.logger.info("Workflow completed: #{payload[:workflow]} in #{duration.round(2)}ms")
  
  # Send metrics to monitoring service
  if defined?(StatsD)
    StatsD.timing('agentform.workflow.duration', duration, tags: ["workflow:#{payload[:workflow]}"])
    StatsD.increment('agentform.workflow.execution', tags: ["workflow:#{payload[:workflow]}", "success:#{payload[:success]}"])
  end
  
  # Track AI usage costs
  if payload[:workflow].include?('AI') || payload[:workflow].include?('Llm')
    Forms::AiUsageMetrics.record_execution(payload)
  end
end

# config/initializers/health_checks.rb
Rails.application.routes.draw do
  get '/health' => 'health#show'
  get '/health/detailed' => 'health#detailed'
end

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!
  
  def show
    checks = {
      database: database_healthy?,
      redis: redis_healthy?,
      storage: storage_healthy?
    }
    
    overall_health = checks.values.all?
    
    render json: {
      status: overall_health ? 'healthy' : 'unhealthy',
      checks: checks,
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version || '1.0.0'
    }, status: overall_health ? :ok : :service_unavailable
  end
  
  def detailed
    render json: {
      status: 'healthy',
      services: {
        database: database_details,
        redis: redis_details,
        superagent: superagent_health,
        ai_providers: ai_providers_health,
        background_jobs: sidekiq_health
      },
      system: {
        memory_usage: memory_usage,
        disk_usage: disk_usage,
        uptime: uptime
      },
      timestamp: Time.current.iso8601
    }
  end
  
  private
  
  def database_healthy?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue
    false
  end
  
  def redis_healthy?
    Sidekiq.redis(&:ping) == 'PONG'
  rescue
    false
  end
  
  def storage_healthy?
    Rails.application.config.active_storage.service == :local || 
    ENV['AWS_ACCESS_KEY_ID'].present?
  end
  
  def superagent_health
    {
      configured: SuperAgent.configured?,
      providers: SuperAgent.configuration.available_providers,
      a2a_enabled: SuperAgent.configuration.a2a_server_enabled
    }
  end
  
  def ai_providers_health
    providers = {}
    
    if ENV['OPENAI_API_KEY'].present?
      providers[:openai] = test_openai_connection
    end
    
    if ENV['ANTHROPIC_API_KEY'].present?
      providers[:anthropic] = test_anthropic_connection
    end
    
    providers
  end
  
  def test_openai_connection
    interface = SuperAgent::LlmInterface.new(provider: :openai)
    interface.complete(prompt: 'test', max_tokens: 1)
    { status: 'healthy' }
  rescue
    { status: 'unhealthy' }
  end
end
```

### Day 33: Performance Optimization

#### 33.1 Database Optimization
```ruby
# config/initializers/database_optimizations.rb
Rails.application.configure do
  # Connection pool optimization
  config.database_configuration[Rails.env]['pool'] = ENV.fetch('DB_POOL', 10).to_i
  config.database_configuration[Rails.env]['timeout'] = 5000
  
  # Query optimization
  config.active_record.strict_loading_by_default = true if Rails.env.development?
  
  # Background job optimization
  config.active_job.queue_adapter = :sidekiq
  config.active_job.default_queue_name = 'default'
end

# Additional database indexes for performance
# db/migrate/020_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Composite indexes for common queries
    add_index :form_responses, [:form_id, :status, :created_at], name: 'index_form_responses_performance'
    add_index :question_responses, [:form_response_id, :created_at], name: 'index_question_responses_performance'
    add_index :form_analytics, [:form_id, :metric_type, :date], name: 'index_form_analytics_performance'
    
    # Partial indexes for AI-enhanced features
    add_index :form_questions, [:form_id], 
              where: "ai_enhancement ->> 'enabled' = 'true'", 
              name: 'index_ai_enhanced_questions'
    
    add_index :form_responses, [:form_id, :created_at], 
              where: "ai_analysis IS NOT NULL", 
              name: 'index_ai_analyzed_responses'
    
    # Full-text search indexes
    execute "CREATE INDEX CONCURRENTLY index_forms_search ON forms USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')))"
    execute "CREATE INDEX CONCURRENTLY index_questions_search ON form_questions USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '')))"
  end
end

# app/models/concerns/cacheable.rb
module Cacheable
  extend ActiveSupport::Concern
  
  included do
    after_commit :bust_cache
  end
  
  class_methods do
    def cached_find(id, expires_in: 1.hour)
      Rails.cache.fetch("#{name.downcase}_#{id}", expires_in: expires_in) do
        find(id)
      end
    end
    
    def cached_count(scope_name = nil, expires_in: 5.minutes)
      cache_key = scope_name ? "#{name.downcase}_#{scope_name}_count" : "#{name.downcase}_count"
      
      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        scope_name ? public_send(scope_name).count : count
      end
    end
  end
  
  def cache_key_with_version
    "#{model_name.cache_key}/#{id}-#{updated_at.to_i}"
  end
  
  private
  
  def bust_cache
    Rails.cache.delete_matched("#{self.class.name.downcase}_#{id}_*")
    Rails.cache.delete("#{self.class.name.downcase}_#{id}")
  end
end

# Include in models
# app/models/form.rb (add to existing)
class Form < ApplicationRecord
  include Cacheable
  
  # Cached methods for performance
  def cached_analytics_summary(period: 30.days)
    Rails.cache.fetch("form_#{id}_analytics_#{period.to_i}", expires_in: 1.hour) do
      analytics_summary(period: period)
    end
  end
  
  def cached_completion_rate
    Rails.cache.fetch("form_#{id}_completion_rate", expires_in: 15.minutes) do
      completion_rate
    end
  end
end
```

#### 33.2 Caching Strategy
```ruby
# app/services/forms/cache_service.rb
module Forms
  class CacheService
    CACHE_PREFIXES = {
      form_config: 'form_config',
      analytics: 'analytics',
      ai_analysis: 'ai_analysis',
      user_session: 'user_session'
    }.freeze
    
    class << self
      def cache_form_config(form)
        cache_key = "#{CACHE_PREFIXES[:form_config]}_#{form.id}"
        
        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          {
            settings: form.form_settings,
            ai_config: form.ai_configuration,
            style_config: form.style_configuration,
            questions: form.questions_ordered.map(&:field_configuration),
            updated_at: form.updated_at
          }
        end
      end
      
      def cache_analytics_data(form, period)
        cache_key = "#{CACHE_PREFIXES[:analytics]}_#{form.id}_#{period.to_i}"
        
        Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          Forms::AnalyticsService.new(form, period: period).detailed_report
        end
      end
      
      def cache_ai_insights(form, insight_type)
        cache_key = "#{CACHE_PREFIXES[:ai_analysis]}_#{form.id}_#{insight_type}"
        
        Rails.cache.fetch(cache_key, expires_in: 2.hours) do
          case insight_type
          when 'performance'
            Forms::PerformanceInsightsService.new(form).generate
          when 'optimization'
            Forms::OptimizationInsightsService.new(form).generate
          else
            {}
          end
        end
      end
      
      def invalidate_form_cache(form)
        pattern = "*_#{form.id}_*"
        Rails.cache.delete_matched(pattern)
      end
      
      def warm_cache_for_form(form)
        # Pre-populate frequently accessed cache entries
        Sidekiq::Client.push(
          'queue' => 'cache_warming',
          'class' => 'Forms::CacheWarmingJob',
          'args' => [form.id]
        )
      end
    end
  end
end
```

### Day 34: Security and Compliance

#### 34.1 Security Configuration
```ruby
# config/initializers/security.rb
Rails.application.configure do
  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    
    # Allow connections to AI providers
    policy.connect_src :self, :https, 'api.openai.com', 'api.anthropic.com'
    
    # Frame options for embedding
    policy.frame_ancestors :self, :https
  end
  
  # Security headers
  config.force_ssl = true if Rails.env.production?
  config.ssl_options = {
    hsts: { expires: 1.year, subdomains: true },
    secure_cookies: true
  }
end

# app/models/concerns/encryptable.rb
module Encryptable
  extend ActiveSupport::Concern
  
  included do
    # Use Rails 7+ encryption for sensitive data
    encrypts :api_keys if has_attribute?(:api_keys)
    encrypts :webhook_secrets if has_attribute?(:webhook_secrets)
    encrypts :integration_credentials if has_attribute?(:integration_credentials)
  end
  
  class_methods do
    def encrypt_field(field_name, **options)
      encrypts field_name, **options
      
      # Create helper methods
      define_method "#{field_name}_decrypted" do
        public_send(field_name)
      end
      
      define_method "#{field_name}_encrypted?" do
        public_send(field_name).present?
      end
    end
  end
end

# app/services/forms/data_privacy_service.rb
module Forms
  class DataPrivacyService
    attr_reader :form
    
    def initialize(form)
      @form = form
    end
    
    def anonymize_responses(older_than: 2.years)
      # Anonymize old form responses while preserving analytics
      old_responses = form.form_responses.where('created_at < ?', older_than.ago)
      
      old_responses.find_each do |response|
        anonymize_response(response)
      end
    end
    
    def export_user_data(email)
      # GDPR data export
      responses = form.form_responses.joins("LEFT JOIN users ON users.email = '#{email}'")
      
      {
        form_name: form.name,
        responses: responses.map do |response|
          {
            submitted_at: response.created_at,
            answers: anonymize_answers(response.answers_hash),
            metadata: sanitize_metadata(response.metadata)
          }
        end
      }
    end
    
    def delete_user_data(email)
      # GDPR right to deletion
      responses = find_user_responses(email)
      
      responses.destroy_all
      
      {
        deleted_responses: responses.count,
        form_name: form.name,
        deleted_at: Time.current
      }
    end
    
    private
    
    def anonymize_response(response)
      # Replace PII with anonymized data
      anonymized_answers = response.answers_hash.transform_values do |answer|
        anonymize_answer_value(answer)
      end
      
      response.update!(
        metadata: response.metadata.merge(anonymized_at: Time.current),
        context_data: {},
        ip_address: nil,
        user_agent: 'anonymized'
      )
      
      # Update question responses
      response.question_responses.update_all(
        answer_data: anonymized_answers,
        raw_input: {}
      )
    end
    
    def anonymize_answer_value(value)
      case value
      when String
        if value.match?(URI::MailTo::EMAIL_REGEXP)
          'user@example.com'
        elsif value.match?(/\d{3}[-.]?\d{3}[-.]?\d{4}/)
          '555-0123'
        else
          value.gsub(/\w/, 'X')
        end
      when Array
        value.map { |v| anonymize_answer_value(v) }
      when Hash
        value.transform_values { |v| anonymize_answer_value(v) }
      else
        value
      end
    end
  end
end
```

#### 34.2 Input Validation and Sanitization
```ruby
# app/services/forms/input_sanitization_service.rb
module Forms
  class InputSanitizationService
    ALLOWED_HTML_TAGS = %w[b i u strong em br p].freeze
    
    class << self
      def sanitize_answer_data(answer_data, question_type)
        case question_type
        when 'text_short'
          sanitize_text(answer_data, allow_html: false)
        when 'text_long'
          sanitize_text(answer_data, allow_html: true)
        when 'email'
          sanitize_email(answer_data)
        when 'url'
          sanitize_url(answer_data)
        when 'number'
          sanitize_number(answer_data)
        when 'multiple_choice', 'single_choice'
          sanitize_choice_data(answer_data)
        else
          sanitize_generic(answer_data)
        end
      end
      
      private
      
      def sanitize_text(text, allow_html: false)
        return '' unless text.present?
        
        cleaned = text.to_s.strip
        
        if allow_html
          ActionController::Base.helpers.sanitize(cleaned, tags: ALLOWED_HTML_TAGS)
        else
          ActionController::Base.helpers.strip_tags(cleaned)
        end
      end
      
      def sanitize_email(email)
        return '' unless email.present?
        
        cleaned = email.to_s.strip.downcase
        
        # Basic email format validation
        if cleaned.match?(URI::MailTo::EMAIL_REGEXP)
          cleaned
        else
          ''
        end
      end
      
      def sanitize_url(url)
        return '' unless url.present?
        
        cleaned = url.to_s.strip
        
        # Ensure URL has protocol
        unless cleaned.match?(%r{^https?://})
          cleaned = "http://#{cleaned}"
        end
        
        # Validate URL format
        begin
          uri = URI.parse(cleaned)
          uri.to_s if uri.host.present?
        rescue URI::InvalidURIError
          ''
        end
      end
      
      def sanitize_number(number)
        return nil unless number.present?
        
        cleaned = number.to_s.gsub(/[^\d.-]/, '')
        Float(cleaned) rescue nil
      end
      
      def sanitize_choice_data(choices)
        return [] unless choices.present?
        
        Array(choices).map { |choice| sanitize_text(choice) }.reject(&:blank?)
      end
      
      def sanitize_generic(data)
        case data
        when String
          sanitize_text(data)
        when Array
          data.map { |item| sanitize_generic(item) }
        when Hash
          data.transform_values { |value| sanitize_generic(value) }
        else
          data
        end
      end
    end
  end
end
```

### Day 35: Final Integration and Launch Preparation

#### 35.1 Deployment Scripts
```bash
#!/bin/bash
# script/deploy.sh

set -e

echo "🚀 Starting AgentForm deployment..."

# Pre-deployment checks
echo "🔍 Running pre-deployment checks..."
bundle exec rails db:check_migrations
bundle exec rails assets:clobber
bundle exec rails assets:precompile

# Database setup
echo "📊 Setting up database..."
bundle exec rails db:migrate

# Seed templates and default data
echo "🌱 Seeding default data..."
bundle exec rails db:seed

# Start services
echo "🎯 Starting application services..."

# Start Sidekiq for background processing
bundle exec sidekiq -d -e production -C config/sidekiq.yml

# Start A2A server if enabled
if [ "$A2A_SERVER_ENABLED" = "true" ]; then
  echo "🤝 Starting A2A server..."
  bundle exec rake super_agent:a2a:serve &
fi

# Start main application
echo "🌐 Starting Rails application..."
bundle exec puma -C config/puma.rb

echo "✅ AgentForm deployment complete!"
```

```ruby
# db/seeds.rb
# Create default form templates
Rails.logger.info "Creating default form templates..."

# Lead Qualification Template
lead_template = FormTemplate.create!(
  name: "Lead Qualification Form",
  description: "Qualify potential customers and gather contact information",
  category: "lead_qualification",
  visibility: "featured",
  template_data: {
    form_settings: {
      ui: { progress_bar: true, one_question_per_page: true },
      behavior: { auto_save: true, allow_back: true }
    },
    ai_configuration: {
      enabled: true,
      features: ["response_analysis", "dynamic_followups"],
      model: "gpt-4o-mini"
    },
    questions: [
      {
        title: "What's your email address?",
        question_type: "email",
        required: true,
        position: 1,
        configuration: { placeholder: "your@email.com" }
      },
      {
        title: "What's your company name?",
        question_type: "text_short", 
        required: true,
        position: 2,
        ai_enhancement: { enabled: true, features: ["smart_validation"] }
      },
      {
        title: "How many employees does your company have?",
        question_type: "single_choice",
        required: true,
        position: 3,
        configuration: {
          options: [
            { label: "1-10 employees", value: "1-10" },
            { label: "11-
-----------------------------------------------------------------------------------------------

