Part 1: Foundation & Core Setup
markdown# AgentForm Complete Implementation Blueprint - Updated TODO

## Project Architecture Overview

**Tech Stack:**
- Rails 7.1+ with PostgreSQL
- SuperAgent workflow framework
- Tailwind CSS for styling
- Turbo Streams for real-time updates
- Sidekiq for background processing
- Redis for caching and sessions

**Core Architecture Pattern:**
Controllers → Agents → Workflows → Tasks (LLM/DB/Stream) → Services

## Phase 1: Foundation Setup & Core Models

### 1.1 Rails Application Setup

#### Essential Infrastructure
- [ ] **Rails Application Configuration**
  ```ruby
  # config/application.rb
  config.active_job.queue_adapter = :sidekiq
  config.autoload_paths += %W(#{config.root}/app/workflows)
  config.autoload_paths += %W(#{config.root}/app/agents)

 SuperAgent Configuration
ruby# config/initializers/super_agent.rb
SuperAgent.configure do |config|
  config.llm_provider = :openai
  config.default_llm_model = "gpt-4o-mini"
  config.workflow_timeout = 300
  config.a2a_server_enabled = true
  config.a2a_server_port = 8080
end


1.2 Database Schema & Migrations
Core Tables Setup

 Enable UUID Extension
ruby# db/migrate/001_enable_uuid_extension.rb
class EnableUuidExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto'
  end
end

 Users Table
ruby# db/migrate/002_create_users.rb
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

 Forms Table
ruby# db/migrate/003_create_forms.rb
class CreateForms < ActiveRecord::Migration[7.1]
  def change
    create_table :forms, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'draft'
      t.string :category
      t.string :share_token, null: false, index: { unique: true }
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.json :form_settings, default: {}
      t.json :ai_configuration, default: {}
      t.json :style_configuration, default: {}
      t.json :integration_settings, default: {}
      t.string :workflow_class_name
      t.json :workflow_state, default: {}
      t.integer :views_count, default: 0
      t.integer :responses_count, default: 0
      t.integer :completions_count, default: 0
      t.datetime :last_response_at
      t.timestamps
    end
    add_index :forms, :status
    add_index :forms, :category
  end
end


1.3 Core Model Classes
User Model

 User Model Implementation
ruby# app/models/user.rb
class User < ApplicationRecord
  include Encryptable
  
  has_secure_password
  has_many :forms, dependent: :destroy
  has_many :form_responses, through: :forms
  has_many :api_tokens, dependent: :destroy
  
  enum :role, { user: 'user', admin: 'admin', premium: 'premium' }
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  
  before_create :set_default_preferences
  before_save :update_last_seen
  
  # Methods to implement:
  def full_name
  def ai_credits_remaining
  def can_use_ai_features?
  def consume_ai_credit(cost = 1)
  def form_usage_stats
  
  private
  
  def set_default_preferences
  def default_ai_credits
  def update_last_seen
end


Form Model

 Form Model Implementation
ruby# app/models/form.rb
class Form < ApplicationRecord
  include Cacheable
  
  belongs_to :user
  has_many :form_questions, -> { order(:position) }, dependent: :destroy
  has_many :form_responses, dependent: :destroy
  has_many :form_analytics, dependent: :destroy
  has_many :dynamic_questions, through: :form_responses
  belongs_to :template, class_name: 'FormTemplate', optional: true
  
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
  
  before_create :generate_share_token
  before_save :set_workflow_class_name, :update_form_cache
  
  # Core Methods to implement:
  def workflow_class
  def create_workflow_class!
  def regenerate_workflow!
  def ai_enhanced?
  def ai_features_enabled
  def estimated_ai_cost_per_response
  def completion_rate
  def questions_ordered
  def next_question_position
  def public_url
  def embed_code(options = {})
  def analytics_summary(period: 30.days)
  def cached_analytics_summary(period: 30.days)
  def cached_completion_rate
  
  private
  
  def generate_share_token
  def set_workflow_class_name
  def update_form_cache
end



## Part 2: Question System & Response Models

```markdown
### 1.4 Question System Implementation

#### FormQuestion Model
- [ ] **FormQuestion Model**
  ```ruby
  # app/models/form_question.rb
  class FormQuestion < ApplicationRecord
    belongs_to :form
    has_many :question_responses, dependent: :destroy
    has_many :dynamic_questions, foreign_key: 'generated_from_question_id'
    
    QUESTION_TYPES = %w[
      text_short text_long email phone url number
      multiple_choice single_choice checkbox
      rating scale slider yes_no boolean
      date datetime time
      file_upload image_upload
      address location payment signature
      nps_score matrix ranking drag_drop
    ].freeze
    
    enum :question_type, QUESTION_TYPES.index_with(&:itself)
    
    validates :title, presence: true, length: { maximum: 500 }
    validates :position, presence: true, numericality: { greater_than: 0 }
    validates :form, presence: true
    
    validate :validate_field_configuration
    validate :validate_conditional_logic
    
    # Core Methods to implement:
    def question_type_handler
    def render_component
    def validate_answer(answer)
    def process_answer(raw_answer)
    def default_value
    def ai_enhanced?
    def ai_features
    def generates_followups?
    def has_smart_validation?
    def has_response_analysis?
    def has_conditional_logic?
    def conditional_rules
    def should_show_for_response?(form_response)
    def choice_options
    def rating_config
    def file_upload_config
    def text_config
    def average_response_time_seconds
    def completion_rate
    
    private
    
    def validate_field_configuration
    def validate_conditional_logic
    def clean_field_configuration
  end
Question Type System

 QuestionTypes::Base Class
ruby# app/models/concerns/question_types/base.rb
module QuestionTypes
  class Base
    attr_reader :question, :configuration
    
    def initialize(question)
      @question = question
      @configuration = question.field_configuration
    end
    
    # Methods to implement:
    def render_component
    def validate_answer(answer)
    def process_answer(raw_answer)
    def default_value
    def placeholder_text
    def help_text
    
    protected
    
    def component_name
    def answer_blank?(answer)
    def base_processing(answer)
    def type_specific_validation(answer)
    def default_placeholder
  end
end

 Specific Question Type Classes
ruby# app/models/concerns/question_types/text_short.rb
module QuestionTypes
  class TextShort < Base
    # Methods to implement:
    def base_processing(answer)
    def type_specific_validation(answer)
    def default_placeholder
    
    private
    
    def min_length
    def max_length
    def pattern
    def pattern_error_message
  end
end

# app/models/concerns/question_types/email.rb
module QuestionTypes
  class Email < Base
    EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    
    # Methods to implement:
    def base_processing(answer)
    def type_specific_validation(answer)
    def default_placeholder
    
    private
    
    def block_disposable?
    def disposable_email?(email)
  end
end

# app/models/concerns/question_types/multiple_choice.rb
module QuestionTypes
  class MultipleChoice < Base
    # Methods to implement:
    def choice_options
    def allows_multiple?
    def has_other_option?
    def randomize_options?
    def display_options(seed = nil)
    def base_processing(answer)
    def type_specific_validation(answer)
    
    private
    
    def validate_multiple_selection_limits(selected_values)
  end
end

# app/models/concerns/question_types/rating.rb
module QuestionTypes
  class Rating < Base
    # Methods to implement:
    def scale_min
    def scale_max
    def scale_labels
    def show_numbers?
    def scale_steps
    def base_processing(answer)
    def type_specific_validation(answer)
  end
end

# app/models/concerns/question_types/file_upload.rb
module QuestionTypes
  class FileUpload < Base
    # Methods to implement:
    def max_file_size
    def allowed_file_types
    def allow_multiple?
    def max_files
    def base_processing(answer)
    def type_specific_validation(answer)
    
    private
    
    def process_single_file(file)
    def validate_single_file(file, index = 0)
    def store_file(file)
  end
end


1.5 Response Models
FormResponse Model

 FormResponse Model
ruby# app/models/form_response.rb
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
  
  # Core Methods to implement:
  def progress_percentage
  def duration_minutes
  def time_since_last_activity
  def is_stale?
  def answers_hash
  def get_answer(question_title_or_id)
  def set_answer(question, answer_data)
  def trigger_ai_analysis!
  def ai_sentiment
  def ai_confidence
  def ai_risk_indicators
  def needs_human_review?
  def calculate_quality_score!
  def calculate_sentiment_score!
  def mark_completed!(completion_data = {})
  def mark_abandoned!(reason = nil)
  def pause!(context = {})
  def resume!
  def workflow_context
  def current_question_position
  
  private
  
  def set_started_at
  def update_last_activity
  def find_question(identifier)
end


QuestionResponse Model

 QuestionResponse Model
ruby# app/models/question_response.rb
class QuestionResponse < ApplicationRecord
  belongs_to :form_response
  belongs_to :form_question
  
  validates :answer_data, presence: true
  
  before_save :process_answer_data, :calculate_response_time
  after_create :trigger_ai_analysis, :update_question_analytics
  
  # Core Methods to implement:
  def processed_answer_data
  def raw_answer
  def formatted_answer
  def answer_text
  def trigger_ai_analysis!
  def ai_sentiment
  def ai_confidence_score
  def ai_insights
  def needs_followup?
  def is_valid?
  def validation_errors
  def quality_indicators
  def response_time_category
  def unusually_fast?
  def unusually_slow?
  
  private
  
  def process_answer_data
  def calculate_response_time
  def trigger_ai_analysis
  def should_trigger_ai_analysis?
  def update_question_analytics
  def calculate_completeness_score
end



## Part 3: Analytics & Dynamic Questions

```markdown
### 1.6 Analytics & Metrics Models

#### FormAnalytic Model
- [ ] **FormAnalytic Model**
  ```ruby
  # db/migrate/007_create_form_analytics.rb
  class CreateFormAnalytics < ActiveRecord::Migration[7.1]
    def change
      create_table :form_analytics, id: :uuid do |t|
        t.references :form, null: false, foreign_key: true, type: :uuid
        t.date :date, null: false
        t.string :metric_type, null: false
        t.integer :views_count, default: 0
        t.integer :starts_count, default: 0
        t.integer :completions_count, default: 0
        t.integer :abandons_count, default: 0
        t.decimal :avg_completion_time, precision: 8, scale: 2
        t.decimal :avg_response_time, precision: 8, scale: 2
        t.json :time_distribution, default: {}
        t.decimal :avg_quality_score, precision: 5, scale: 2
        t.decimal :avg_sentiment_score, precision: 5, scale: 2
        t.json :quality_distribution, default: {}
        t.json :ai_insights, default: {}
        t.json :optimization_suggestions, default: {}
        t.json :behavioral_patterns, default: {}
        t.timestamps
      end
      add_index :form_analytics, [:form_id, :date, :metric_type], unique: true
    end
  end
  
  # app/models/form_analytic.rb
  class FormAnalytic < ApplicationRecord
    belongs_to :form
    
    validates :date, presence: true
    validates :metric_type, presence: true
    
    scope :for_period, ->(start_date, end_date) { where(date: start_date..end_date) }
    scope :by_metric_type, ->(type) { where(metric_type: type) }
    
    # Methods to implement:
    def completion_rate
    def abandonment_rate
    def performance_score
    def trend_direction
  end
DynamicQuestion Model

 DynamicQuestion Model
ruby# db/migrate/008_create_dynamic_questions.rb
class CreateDynamicQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :dynamic_questions, id: :uuid do |t|
      t.references :form_response, null: false, foreign_key: true, type: :uuid
      t.references :generated_from_question, null: true, 
                   foreign_key: { to_table: :form_questions }, type: :uuid
      t.string :question_type, null: false
      t.text :title, null: false
      t.text :description
      t.json :configuration, default: {}
      t.json :generation_context, default: {}
      t.text :generation_prompt
      t.string :generation_model
      t.json :answer_data
      t.decimal :response_time_ms
      t.decimal :ai_confidence, precision: 5, scale: 2
      t.timestamps
    end
  end
end

# app/models/dynamic_question.rb
class DynamicQuestion < ApplicationRecord
  belongs_to :form_response
  belongs_to :generated_from_question, class_name: 'FormQuestion', optional: true
  
  validates :title, presence: true
  validates :question_type, inclusion: { in: FormQuestion::QUESTION_TYPES }
  
  # Methods to implement:
  def question_type_handler
  def validate_answer(answer)
  def process_answer(raw_answer)
  def render_component
  def generation_reasoning
  def was_answered?
end


1.7 Template System
FormTemplate Model

 FormTemplate Model
ruby# db/migrate/009_create_form_templates.rb
class CreateFormTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :form_templates, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.string :visibility, default: 'public'
      t.references :creator, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.json :template_data, null: false
      t.json :preview_data, default: {}
      t.integer :usage_count, default: 0
      t.decimal :rating, precision: 3, scale: 2
      t.integer :reviews_count, default: 0
      t.timestamps
    end
    add_index :form_templates, :category
    add_index :form_templates, :visibility
  end
end

# app/models/form_template.rb
class FormTemplate < ApplicationRecord
  belongs_to :creator, class_name: 'User', optional: true
  has_many :form_instances, class_name: 'Form', foreign_key: 'template_id'
  
  enum :category, Form.categories
  enum :visibility, { private: 'private', public: 'public', featured: 'featured' }
  
  validates :name, presence: true
  validates :template_data, presence: true
  
  # Methods to implement:
  def questions_config
  def form_settings_template
  def ai_configuration_template
  def instantiate_for_user(user, customizations = {})
  def preview_data
  
  private
  
  def calculate_estimated_time
  def extract_features
end


1.8 Concerns & Modules
Cacheable Module

 Cacheable Concern
ruby# app/models/concerns/cacheable.rb
module Cacheable
  extend ActiveSupport::Concern
  
  included do
    after_commit :bust_cache
  end
  
  class_methods do
    def cached_find(id, expires_in: 1.hour)
    def cached_count(scope_name = nil, expires_in: 5.minutes)
  end
  
  # Instance methods to implement:
  def cache_key_with_version
  
  private
  
  def bust_cache
end


Encryptable Module

 Encryptable Concern
ruby# app/models/concerns/encryptable.rb
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
  end
end


ApiToken Model

 ApiToken Model
ruby# db/migrate/010_create_api_tokens.rb
class CreateApiTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :api_tokens, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :token, null: false, index: { unique: true }
      t.json :permissions, default: {}
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.datetime :expires_at
      t.integer :usage_count, default: 0
      t.timestamps
    end
  end
end

# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :token, presence: true, uniqueness: true
  
  before_create :generate_token
  
  # Methods to implement:
  def active?
  def expired?
  def can_access?(resource, action)
  def record_usage!
  
  private
  
  def generate_token
end



## Part 4: SuperAgent Workflows

```markdown
## Phase 2: SuperAgent Workflow Implementation

### 2.1 Base Workflow Classes

#### ApplicationWorkflow Base
- [ ] **ApplicationWorkflow**
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
      {
        error: true,
        error_message: error.message,
        error_type: error.class.name,
        timestamp: Time.current.iso8601
      }
    end
    
    # Common workflow hooks
    before_all do |context|
      Rails.logger.info "Starting workflow #{self.class.name}"
      context.set(:workflow_started_at, Time.current)
    end
    
    after_all do |context|
      started_at = context.get(:workflow_started_at)
      duration = started_at ? Time.current - started_at : 0
      Rails.logger.info "Completed workflow #{self.class.name} in #{duration.round(2)}s"
    end
    
    protected
    
    # Helper methods to implement:
    def track_ai_usage(context, cost, operation)
    def ai_budget_available?(context, estimated_cost)
  end
2.2 Core Workflow Implementations
Response Processing Workflow

 Forms::ResponseProcessingWorkflow
ruby# app/workflows/forms/response_processing_workflow.rb
module Forms
  class ResponseProcessingWorkflow < ApplicationWorkflow
    workflow do
      # Step 1: Validate and prepare response data
      validate :validate_response_data do
        input :form_response_id, :question_id, :answer_data
        description "Validate incoming response data"
        
        process do |response_id, question_id, answer_data|
          # Implementation details
        end
      end
      
      # Step 2: Save question response
      task :save_question_response do
        input :validate_response_data
        run_when :validate_response_data, ->(result) { result[:valid] }
        
        process do |validation_result|
          # Implementation details
        end
      end
      
      # Step 3: AI Enhancement (conditional)
      llm :analyze_response_ai do
        input :save_question_response, :validate_response_data
        run_if do |context|
          # Conditions for AI analysis
        end
        
        model { |ctx| ctx.get(:validate_response_data)[:question].form.ai_model }
        temperature 0.3
        max_tokens 500
        response_format :json
        
        system_prompt "You are an AI assistant analyzing form responses"
        prompt <<~PROMPT
          # Detailed prompt for response analysis
        PROMPT
      end
      
      # Step 4: Update question response with AI analysis
      task :update_with_ai_analysis do
        input :save_question_response, :analyze_response_ai
        run_when :analyze_response_ai
        
        process do |save_result, ai_analysis|
          # Implementation details
        end
      end
      
      # Step 5: Generate dynamic follow-up questions (conditional)
      llm :generate_followup_question do
        input :update_with_ai_analysis, :validate_response_data
        run_if do |context|
          # Conditions for follow-up generation
        end
        
        model { |ctx| ctx.get(:validate_response_data)[:question].form.ai_model }
        temperature 0.7
        max_tokens 300
        response_format :json
        
        system_prompt "You are an expert at generating contextual follow-up questions"
        prompt <<~PROMPT
          # Detailed prompt for follow-up generation
        PROMPT
      end
      
      # Step 6: Create dynamic question
      task :create_dynamic_question do
        input :generate_followup_question, :validate_response_data
        run_when :generate_followup_question
        
        process do |followup_data, validation_result|
          # Implementation details
        end
      end
      
      # Step 7: Real-time UI update
      stream :update_form_ui do
        input :save_question_response, :create_dynamic_question
        
        target { |ctx| "form_#{ctx.get(:validate_response_data)[:form_response].form.share_token}" }
        turbo_action :append
        partial "responses/dynamic_question"
        locals do |ctx|
          # Local variables for the partial
        end
      end
    end
  end
end


Form Analysis Workflow

 Forms::AnalysisWorkflow
ruby# app/workflows/forms/analysis_workflow.rb
module Forms
  class AnalysisWorkflow < ApplicationWorkflow
    workflow do
      timeout 120
      
      # Step 1: Gather form data
      task :collect_form_data do
        input :form_id
        description "Collect all form responses and questions for analysis"
        
        process do |form_id|
          # Implementation details for data collection
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
        
        system_prompt "You are an expert in form optimization and user experience analysis"
        prompt <<~PROMPT
          # Detailed analysis prompt
        PROMPT
      end
      
      # Step 3: Question-level analysis
      task :analyze_question_performance do
        input :collect_form_data
        run_if { |ctx| ctx.get(:collect_form_data)[:total_responses] >= 10 }
        
        process do |form_data|
          # Implementation details
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
          # Optimization plan generation prompt
        PROMPT
      end
      
      # Step 5: Save analysis results
      task :save_analysis_results do
        input :analyze_form_performance, :analyze_question_performance, :generate_optimization_plan
        
        process do |performance, questions, optimization|
          # Implementation details
        end
      end
    end
    
    private
    
    # Helper methods to implement:
    def calculate_drop_off_rate(question)
    def calculate_answer_distribution(responses)
    def identify_bottlenecks(question_analytics)
    def identify_high_performers(question_analytics)
    def extract_common_keywords(responses)
  end
end


Dynamic Question Generation Workflow

 Forms::DynamicQuestionWorkflow
ruby# app/workflows/forms/dynamic_question_workflow.rb
module Forms
  class DynamicQuestionWorkflow < ApplicationWorkflow
    workflow do
      timeout 60
      
      # Step 1: Analyze response context
      task :analyze_response_context do
        input :response_id, :source_question_id
        
        process do |response_id, source_question_id|
          # Implementation details
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
          You are an expert conversation designer creating natural follow-up questions
        SYSTEM
        
        prompt <<~PROMPT
          # Follow-up generation prompt
        PROMPT
      end
      
      # Step 3: Validate generated question
      validate :validate_generated_question do
        input :generate_contextual_followup
        run_when :generate_contextual_followup
        
        process do |generation_result|
          # Implementation details
        end
      end
      
      # Step 4: Create dynamic question record
      task :create_dynamic_question_record do
        input :analyze_response_context, :validate_generated_question
        run_when :validate_generated_question, ->(result) { result[:valid] }
        
        process do |context_analysis, validation_result|
          # Implementation details
        end
      end
      
      # Step 5: Real-time UI insertion
      stream :insert_dynamic_question do
        input :create_dynamic_question_record
        run_when :create_dynamic_question_record
        
        target { |ctx| "form_#{ctx.get(:analyze_response_context)[:form_response].form.share_token}" }
        turbo_action :after
        turbo

RetryEMContinueEditPart 5: Agents & Controllers
markdown### 2.3 Agent Implementation

#### Forms Management Agent
- [ ] **Forms::ManagementAgent**
  ```ruby
  # app/agents/forms/management_agent.rb
  module Forms
    class ManagementAgent < ApplicationAgent
      # Methods to implement:
      def create_form(user, form_data)
      def analyze_form_performance(form)
      def optimize_form(form, optimization_preferences = {})
      def generate_form_from_template(user, template_id, customizations = {})
      def duplicate_form(source_form, target_user, modifications = {})
      def export_form_data(form, export_options = {})
      def publish_form(form)
    end
  end
Forms Response Agent

 Forms::ResponseAgent
ruby# app/agents/forms/response_agent.rb
module Forms
  class ResponseAgent < ApplicationAgent
    # Methods to implement:
    def process_form_response(form_response, question, answer_data, metadata = {})
    def complete_form_response(form_response)
    def analyze_response_quality(form_response)
    def generate_response_insights(form_response)
    def trigger_integrations(form_response)
    def recover_abandoned_response(form_response)
    
    private
    
    def analyze_abandonment_context(form_response)
  end
end


2.4 Controller Layer
Application Controller Base

 ApplicationController
ruby# app/controllers/application_controller.rb
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
  
  # Methods to implement:
  def set_current_user_context
  def handle_unauthorized
  def handle_not_found
  def handle_workflow_error(error)
  def configure_permitted_parameters
end


Forms Controller

 FormsController
ruby# app/controllers/forms_controller.rb
class FormsController < ApplicationController
  before_action :set_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :duplicate, :analytics, :export]
  before_action :authorize_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :analytics]
  
  # Actions to implement:
  def index
  def show
  def new
  def create
  def edit
  def update
  def destroy
  def publish
  def unpublish
  def duplicate
  def analytics
  def export
  def preview
  def test_ai_feature
  
  private
  
  def set_form
  def authorize_form
  def form_params
  def search_params
  def sort_params
  def default_form_settings
  def default_ai_configuration
  def handle_form_update
  def form_structure_changed?
  def ai_configuration_changed?
end


Form Questions Controller

 FormQuestionsController
ruby# app/controllers/form_questions_controller.rb
class FormQuestionsController < ApplicationController
  before_action :set_form
  before_action :set_question, only: [:show, :edit, :update, :destroy, :move_up, :move_down, :duplicate]
  before_action :authorize_form_access
  
  # Actions to implement:
  def index
  def create
  def edit
  def update
  def destroy
  def move_up
  def move_down
  def duplicate
  def bulk_update
  def ai_enhance
  
  private
  
  def set_form
  def set_question
  def authorize_form_access
  def question_params
  def trigger_workflow_update
  def structure_changed?
  def render_turbo_response(action, question, partial: 'question')
end


Response Controller (Public)

 ResponsesController
ruby# app/controllers/responses_controller.rb
class ResponsesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_form_by_token
  before_action :set_or_create_response
  before_action :check_form_accessibility
  before_action :set_current_question, only: [:show, :answer, :navigate]
  
  protect_from_forgery except: [:answer, :analytics_event, :auto_save]
  
  # Actions to implement:
  def show
  def answer
  def navigate
  def auto_save
  def thank_you
  def analytics_event
  def summary
  def download_response
  
  private
  
  def set_form_by_token
  def set_or_create_response
  def check_form_accessibility
  def set_current_question
  def answer_params
  def answer_metadata
  def calculate_progress
  def initialize_form_session
  def handle_successful_answer(answer_service)
  def handle_answer_errors(errors)
  def determine_next_question
  def determine_current_position
  def redirect_to_question(question)
  def generate_session_id
  def extract_utm_parameters
  def build_initial_context
  def parse_user_agent
  def track_event(event_type, data = {})
  def question_data
  def generate_recommendations
end



## Part 6: Services Layer

```markdown
### 2.5 Service Layer Implementation

#### Core Services
- [ ] **Forms::AnswerProcessingService**
  ```ruby
  # app/services/forms/answer_processing_service.rb
  module Forms
    class AnswerProcessingService
      include ActiveModel::Model
      
      attr_accessor :response, :question, :answer_data, :metadata
      attr_reader :errors, :question_response
      
      def initialize(response:, question:, answer_data:, metadata: {})
        # Initialize instance variables
      end
      
      # Methods to implement:
      def process
      def should_generate_followup?
      
      private
      
      def validate_inputs
      def validate_answer_data
      def create_or_update_question_response
      def update_response_metadata
      def should_trigger_ai_analysis?
      def should_trigger_integrations?
      def trigger_ai_analysis
      def trigger_integrations
      def max_followups_per_question
    end
  end

 Forms::NavigationService
ruby# app/services/forms/navigation_service.rb
module Forms
  class NavigationService
    attr_reader :form_response, :current_question
    
    def initialize(form_response, current_question = nil)
      # Initialize instance variables
    end
    
    # Methods to implement:
    def next_question
    def previous_question
    def jump_to_position(target_position)
    def next_unanswered_question_after(position)
    def completion_eligible?
    def progress_summary
    
    private
    
    def form
    def next_dynamic_question
    def next_static_question
    def answered_question_positions
    def answered_dynamic_question_ids
    def max_question_position
    def required_questions_remaining
  end
end

 Forms::WorkflowGeneratorService
ruby# app/services/forms/workflow_generator_service.rb
module Forms
  class WorkflowGeneratorService
    attr_reader :form, :workflow_class_name
    
    def initialize(form)
      @form = form
      @workflow_class_name = form.workflow_class_name
    end
    
    # Methods to implement:
    def generate_class
    def regenerate_class
    
    private
    
    def workflow_exists?
    def existing_workflow_class
    def build_workflow_definition
    def create_workflow_class(definition)
    def remove_existing_class
    def generate_class_code(definition)
    def generate_step_code(step)
    def generate_validation_step(step)
    def generate_llm_step(step)
    def generate_input_declaration(inputs)
    def generate_conditional_logic(conditions)
    
    class WorkflowDefinitionBuilder
      attr_reader :form
      
      def initialize(form)
        @form = form
      end
      
      # Methods to implement:
      def build
      
      private
      
      def build_global_config
      def build_steps
      def build_form_validation_step
      def build_question_steps(question)
      def build_ai_analysis_step(question)
      def build_analysis_prompt(question)
      def build_completion_step
    end
  end
end


Analytics Services

 Forms::AnalyticsService
ruby# app/services/forms/analytics_service.rb
module Forms
  class AnalyticsService
    attr_reader :form, :period
    
    def initialize(form, period: 30.days)
      @form = form
      @period = period
    end
    
    # Methods to implement:
    def detailed_report
    def summary
    
    private
    
    def recent_responses
    def overview_metrics
    def performance_metrics
    def user_behavior_metrics
    def question_level_metrics
    def time_based_analysis
    def quality_analysis
    def ai_generated_insights
    def calculate_completion_rate(responses)
    def calculate_abandonment_rate(responses)
    def calculate_average_completion_time(completed_responses)
    def calculate_average_quality_score(responses)
    def build_conversion_funnel
    def identify_drop_off_points
    def analyze_traffic_sources
    def categorize_referrer(referrer)
    def build_daily_metrics
    def calculate_trend_direction
  end
end

 Forms::AiEnhancementService
ruby# app/services/forms/ai_enhancement_service.rb
module Forms
  class AiEnhancementService
    attr_reader :question, :enhancement_type, :errors
    
    def initialize(question, enhancement_type)
      @question = question
      @enhancement_type = enhancement_type
      @errors = []
    end
    
    # Methods to implement:
    def enhance
    
    private
    
    def can_use_ai?
    def valid_enhancement_type?
    def enhance_with_smart_validation
    def enable_dynamic_followups
    def enable_response_analysis
    def enable_auto_improvement
    def success(message)
    def failure(message)
  end
end


Template Services

 Forms::TemplateInstantiationService
ruby# app/services/forms/template_instantiation_service.rb
module Forms
  class TemplateInstantiationService
    attr_reader :template, :user, :customizations, :errors
    
    def initialize(template, user, customizations = {})
      @template = template
      @user = user
      @customizations = customizations
      @errors = []
    end
    
    # Methods to implement:
    def create_form
    
    private
    
    def create_base_form
    def create_questions(form)
    def apply_customizations(form)
    def generate_workflow(form)
    def merge_settings(template_settings, custom_settings)
    def merge_ai_config(template_ai, custom_ai)
  end
end


Data Services

 Forms::DataExportService
ruby# app/services/forms/data_export_service.rb
module Forms
  class DataExportService
    attr_reader :form, :format, :filters
    
    def initialize(form, format: 'csv', filters: {})
      @form = form
      @format = format
      @filters = filters
    end
    
    # Methods to implement:
    def to_csv
    def to_xlsx
    def to_json
    def to_pdf
    
    private
    
    def filtered_responses
    def response_data_for_export
    def generate_csv_headers
    def format_response_for_csv(response)
    def create_excel_workbook
    def format_json_export
  end
end

 Forms::CacheService
ruby# app/services/forms/cache_service.rb
module Forms
  class CacheService
    CACHE_PREFIXES = {
      form_config: 'form_config',
      analytics: 'analytics',
      ai_analysis: 'ai_analysis',
      user_session: 'user_session'
    }.freeze
    
    class << self
      # Methods to implement:
      def cache_form_config(form)
      def cache_analytics_data(form, period)
      def cache_ai_insights(form, insight_type)
      def invalidate_form_cache(form)
      def warm_cache_for_form(form)
    end
  end
end


Security & Privacy Services

 Forms::DataPrivacyService
ruby# app/services/forms/data_privacy_service.rb
module Forms
  class DataPrivacyService
    attr_reader :form
    
    def initialize(form)
      @form = form
    end
    
    # Methods to implement:
    def anonymize_responses(older_than: 2.years)
    def export_user_data(email)
    def delete_user_data(email)
    
    private
    
    def anonymize_response(response)
    def anonymize_answer_value(value)
    def find_user_responses(email)
  end
end

 Forms::InputSanitizationService
ruby# app/services/forms/input_sanitization_service.rb
module Forms
  class InputSanitizationService
    ALLOWED_HTML_TAGS = %w[b i u strong em br p].freeze
    
    class << self
      # Methods to implement:
      def sanitize_answer_data(answer_data, question_type)
      
      private
      
      def sanitize_text(text, allow_html: false)
      def sanitize_email(email)
      def sanitize_url(url)
      def sanitize_number(number)
      def sanitize_choice_data(choices)
      def sanitize_generic(data)
    end
  end
end



## Part 7: Background Jobs & Processing

```markdown
### 2.6 Background Job Implementation

#### Core Job Classes
- [ ] **Forms::WorkflowGenerationJob**
  ```ruby
  # app/jobs/forms/workflow_generation_job.rb
  module Forms
    class WorkflowGenerationJob < ApplicationJob
      queue_as :default
      retry_on StandardError, wait: :polynomially_longer, attempts: 3
      
      def perform(form_id)
        # Implementation for dynamic workflow generation
      end
    end
  end

 Forms::ResponseAnalysisJob
ruby# app/jobs/forms/response_analysis_job.rb
module Forms
  class ResponseAnalysisJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(question_response_id)
      # Implementation for AI response analysis
    end
    
    private
    
    def aggregate_response_analysis(form_response)
    end
  end
end

 Forms::DynamicQuestionGenerationJob
ruby# app/jobs/forms/dynamic_question_generation_job.rb
module Forms
  class DynamicQuestionGenerationJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_response_id, source_question_id)
      # Implementation for dynamic question generation
    end
  end
end


Integration Jobs

 Forms::IntegrationTriggerJob
ruby# app/jobs/forms/integration_trigger_job.rb
module Forms
  class IntegrationTriggerJob < ApplicationJob
    queue_as :integrations
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    
    def perform(form_response_id, trigger_event = 'form_completed')
      # Implementation for integration triggers
    end
    
    private
    
    def process_integration(integration_name, config, form_response, trigger_event)
    def process_webhook_integration(config, form_response, trigger_event)
    def process_email_integration(config, form_response, trigger_event)
    def process_crm_integration(config, form_response, trigger_event)
    def process_slack_integration(config, form_response, trigger_event)
    def determine_slack_color(form_response)
    def build_slack_fields(form_response)
    def truncate_answer(answer)
  end
end

 Forms::CompletionWorkflowJob
ruby# app/jobs/forms/completion_workflow_job.rb
module Forms
  class CompletionWorkflowJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_response_id)
      # Implementation for form completion processing
    end
    
    private
    
    def update_form_analytics(form, form_response)
  end
end


Analytics Jobs

 Forms::AnalyticsProcessingJob
ruby# app/jobs/forms/analytics_processing_job.rb
module Forms
  class AnalyticsProcessingJob < ApplicationJob
    queue_as :analytics
    
    def perform(form_id, date = Date.current)
      # Implementation for analytics processing
    end
    
    private
    
    def calculate_average_time(responses)
    def calculate_average_quality(responses)
  end
end

 Forms::AiInsightGenerationJob
ruby# app/jobs/forms/ai_insight_generation_job.rb
module Forms
  class AiInsightGenerationJob < ApplicationJob
    queue_as :ai_processing
    retry_on StandardError, wait: :polynomially_longer, attempts: 2
    
    def perform(form_id, date = Date.current)
      # Implementation for AI insight generation
    end
    
    private
    
    def prepare_responses_data(form, date)
    def sample_response_data(responses)
    def extract_behavioral_patterns(responses_data)
    def calculate_insight_generation_cost(responses_data)
    def determine_device_type(user_agent)
  end
end


2.7 Advanced Workflow Classes
Form Optimization Workflow

 Forms::OptimizationWorkflow
ruby# app/workflows/forms/optimization_workflow.rb
module Forms
  class OptimizationWorkflow < ApplicationWorkflow
    workflow do
      timeout 180
      
      # Step 1: Gather performance data
      task :collect_performance_data do
        input :form_id
        description "Collect comprehensive form performance data"
        
        process do |form_id|
          # Implementation details
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
          You are an expert in form optimization and conversion rate optimization
        SYSTEM
        
        prompt <<~PROMPT
          # Detailed optimization analysis prompt
        PROMPT
      end
      
      # Additional steps...
    end
    
    private
    
    # Helper methods to implement:
    def calculate_avg_completion_time(completed_responses)
    def calculate_drop_off_rates(form)
    def analyze_question_performance(form)
    def calculate_revision_rate(responses)
    def extract_user_feedback(responses)
    def analyze_mobile_performance(responses)
    def is_safe_auto_change?(change_type)
    def apply_recommendation(form, recommendation)
  end
end


AI Usage Tracking

 Forms::AiUsageTracker
ruby# app/services/forms/ai_usage_tracker.rb
module Forms
  class AiUsageTracker
    attr_reader :user_id
    
    def initialize(user_id)
      @user_id = user_id
    end
    
    # Methods to implement:
    def track_usage(operation:, cost:, model:, timestamp: Time.current)
    def daily_usage(date = Date.current)
    def monthly_usage(month = Date.current.beginning_of_month)
    def remaining_budget
    def usage_by_operation(period: 30.days)
    def cost_optimization_suggestions
    
    private
    
    def user
    def create_usage_record(operation, cost, model, timestamp)
    def update_user_credits(cost)
  end
end



## Part 8: API & A2A Protocol

```markdown
### 2.8 API Layer Implementation

#### API Base Controller
- [ ] **Api::BaseController**
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
      
      # Methods to implement:
      def authenticate_api_user!
      def current_user
      def set_default_response_format
      def render_success(data = {}, status: :ok)
      def render_error(message, details = {}, status: :bad_request)
      
      private
      
      def handle_not_found(exception)
      def handle_invalid_record(exception)
      def handle_workflow_error(exception)
      def handle_standard_error(exception)
    end
  end
API Controllers

 Api::V1::FormsController
ruby# app/controllers/api/v1/forms_controller.rb
module Api
  module V1
    class FormsController < Api::BaseController
      before_action :set_form, only: [:show, :update, :destroy, :responses, :analytics]
      
      # Actions to implement:
      def index
      def show
      def create
      def update
      def destroy
      def responses
      def analytics
      def export
      
      private
      
      def set_form
      def form_params
      def filter_params
      def sort_params
      def serialize_form(form, include_questions: false)
      def serialize_question(question)
      def serialize_response(response)
      def parse_period(period_string)
      def parse_date_range(range_string)
      def form_structure_changed?
    end
  end
end

 Api::V1::ResponsesController
ruby# app/controllers/api/v1/responses_controller.rb
module Api
  module V1
    class ResponsesController < Api::BaseController
      skip_before_action :authenticate_api_user!, only: [:create, :show]
      before_action :find_form_by_token, only: [:create, :show]
      before_action :set_response, only: [:show, :update]
      
      # Actions to implement:
      def create
      def show
      def update
      
      private
      
      def find_form_by_token
      def set_response
      def response_params
    end
  end
end


2.9 A2A Protocol Implementation
A2A Service

 Forms::A2aService
ruby# app/services/forms/a2a_service.rb
module Forms
  class A2aService
    attr_reader :form
    
    def initialize(form)
      @form = form
    end
    
    # Methods to implement:
    def generate_agent_card
    
    private
    
    def generate_capabilities
    def generate_form_parameters_schema
    def generate_submission_example
    def generate_example_answer(question)
    def map_question_type_to_json_type(question_type)
    def a2a_endpoint_url
    def authentication_config
  end
end


A2A Controller

 A2a::FormsController
ruby# app/controllers/a2a/forms_controller.rb
module A2a
  class FormsController < ActionController::API
    include SuperAgent::A2A::ControllerMethods
    
    before_action :authenticate_a2a_request!
    before_action :find_form_by_token
    
    # Actions to implement:
    def agent_card
    def health
    def invoke
    
    private
    
    def find_form_by_token
    def handle_form_submission(parameters)
    def handle_performance_analysis(parameters)
    def calculate_performance_score(report)
  end
end


API Services

 Forms::ApiResponseSubmissionService
ruby# app/services/forms/api_response_submission_service.rb
module Forms
  class ApiResponseSubmissionService
    attr_reader :form, :response_data, :metadata, :errors
    
    def initialize(form:, response_data:, metadata: {})
      @form = form
      @response_data = response_data
      @metadata = metadata
      @errors = []
    end
    
    # Methods to implement:
    def submit
    def success?
    def response
    
    private
    
    def create_form_response
    def process_answers
    def validate_answer_data
    def trigger_completion_workflow
    def build_success_result
    def build_error_result
  end
end

 Forms::A2aSubmissionService
ruby# app/services/forms/a2a_submission_service.rb
module Forms
  class A2aSubmissionService
    attr_reader :form, :parameters, :errors
    
    def initialize(form, parameters)
      @form = form
      @parameters = parameters
      @errors = []
    end
    
    # Methods to implement:
    def process
    def success?
    def response
    def completion_url
    def ai_analysis
    
    private
    
    def validate_parameters
    def create_response
    def process_submission
    def generate_completion_url
  end
end


2.10 Integration Services
CRM Integration Services

 Forms::Integrations::SalesforceService
ruby# app/services/forms/integrations/salesforce_service.rb
module Forms
  module Integrations
    class SalesforceService
      attr_reader :config, :client
      
      def initialize(config)
        @config = config
        @client = initialize_client
      end
      
      # Methods to implement:
      def sync_response(form_response)
      def create_lead(response_data)
      def update_contact(response_data)
      def create_opportunity(response_data)
      
      private
      
      def initialize_client
      def map_response_to_salesforce(response)
      def handle_api_error(error)
    end
  end
end

 Forms::Integrations::HubspotService
ruby# app/services/forms/integrations/hubspot_service.rb
module Forms
  module Integrations
    class HubspotService
      attr_reader :config, :client
      
      def initialize(config)
        @config = config
        @client = initialize_client
      end
      
      # Methods to implement:
      def sync_response(form_response)
      def create_contact(response_data)
      def create_deal(response_data)
      def add_to_workflow(contact_id, workflow_id)
      
      private
      
      def initialize_client
      def map_response_to_hubspot(response)
      def handle_api_error(error)
    end
  end
end


Email Integration Services

 Forms::Integrations::MailchimpService
ruby# app/services/forms/integrations/mailchimp_service.rb
module Forms
  module Integrations
    class MailchimpService
      attr_reader :config, :client
      
      def initialize(config)
        @config = config
        @client = initialize_client
      end
      
      # Methods to implement:
      def sync_response(form_response)
      def add_subscriber(email, merge_fields = {})
      def update_subscriber(email, merge_fields = {})
      def add_tags(email, tags)
      def trigger_automation(email, automation_id)
      
      private
      
      def initialize_client
      def map_response_to_merge_fields(response)
      def handle_api_error(error)
    end
  end
end



## Part 9: View Layer & UI Components

```markdown
## Phase 3: View Layer & User Interface

### 3.1 Layout Templates

#### Application Layout
- [ ] **Application Layout**
  ```erb
  <!-- app/views/layouts/application.html.erb -->
  <!DOCTYPE html>
  <html lang="en" class="h-full">
    <head>
      <title>AgentForm</title>
      <%= csrf_meta_tags %>
      <%= csp_meta_tag %>
      <%= stylesheet_link_tag "tailwind", data_turbo_track: "reload" %>
      <%= stylesheet_link_tag "application", data_turbo_track: "reload" %>
      <%= javascript_importmap_tags %>
    </head>
    <body class="h-full bg-gray-50">
      <%= render "shared/header" %>
      <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <%= yield %>
      </main>
      <%= render "shared/footer" %>
      <%= render "shared/toast_container" %>
    </body>
  </html>
Form Builder Layout

 Form Builder Layout
erb<!-- app/views/layouts/form_builder.html.erb -->
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <title><%= content_for(:title) || "Form Builder" %> | AgentForm</title>
    <!-- Builder-specific styles and scripts -->
  </head>
  <body class="h-full bg-gray-50">
    <!-- Form builder specific layout implementation -->
  </body>
</html>


Form Response Layout

 Form Response Layout
erb<!-- app/views/layouts/form_response.html.erb -->
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <title><%= @form.name %> | AgentForm</title>

RetryEMContinueEditPart 9: View Layer & UI Components (Continued)
markdown#### Form Response Layout (Continued)
- [ ] **Form Response Layout**
  ```erb
  <!-- app/views/layouts/form_response.html.erb -->
      <!-- Dynamic branding and styling -->
      <style>
        :root {
          --form-primary-color: <%= @form.style_configuration.dig('colors', 'primary') || '#3B82F6' %>;
          --form-secondary-color: <%= @form.style_configuration.dig('colors', 'secondary') || '#6366F1' %>;
        }
      </style>
      <!-- Analytics tracking scripts -->
    </head>
    <body class="h-full form-bg">
      <!-- Progress bar, form content, navigation -->
    </body>
  </html>
3.2 Form Management Views
Forms Index

 Forms Index View
erb<!-- app/views/forms/index.html.erb -->
<div class="space-y-6" data-controller="forms-index">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-gray-900">My Forms</h1>
    <%= link_to "Create Form", new_form_path, 
        class: "btn btn-primary" %>
  </div>
  
  <!-- Forms grid with search, filters, stats -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
    <% @forms.each do |form| %>
      <%= render "form_card", form: form %>
    <% end %>
  </div>
</div>


Form Builder Interface

 Form Edit View
erb<!-- app/views/forms/edit.html.erb -->
<div class="space-y-6" data-controller="form-builder" 
     data-form-id="<%= @form.id %>">
  
  <!-- Form header with status and actions -->
  <%= render "form_header", form: @form %>
  
  <!-- Configuration tabs -->
  <div class="bg-white rounded-lg shadow-sm">
    <%= render "configuration_tabs" %>
    
    <!-- Questions tab content -->
    <div data-tabs-target="panel" data-tab="questions">
      <%= render "questions_panel", form: @form, questions: @questions %>
    </div>
    
    <!-- Settings, AI, Style, Integration tabs -->
    <!-- Each implemented as separate partials -->
  </div>
</div>


3.3 Question Type Components
Text Input Components

 Text Short Component
erb<!-- app/views/question_types/_text_short.html.erb -->
<div class="space-y-4" data-controller="text-input" 
     data-text-input-min-length="<%= question.text_config[:min_length] %>"
     data-text-input-max-length="<%= question.text_config[:max_length] %>">
  
  <div class="relative">
    <%= form.text_field :answer_data, 
        value: existing_answer,
        placeholder: question.placeholder_text,
        class: "form-input" %>
    
    <!-- AI enhancement indicator -->
    <% if question.has_smart_validation? %>
      <div class="absolute right-3 top-3">
        <!-- AI indicator icon -->
      </div>
    <% end %>
  </div>
  
  <!-- Character counter, AI suggestions -->
</div>

 Multiple Choice Component
erb<!-- app/views/question_types/_multiple_choice.html.erb -->
<div class="space-y-4" data-controller="multiple-choice"
     data-multiple-choice-allows-multiple="<%= question.allows_multiple? %>">
  
  <div class="space-y-3">
    <% question.display_options(@response.session_id.hash).each do |option| %>
      <label class="choice-option">
        <!-- Radio/checkbox input -->
        <!-- Option content with icons and descriptions -->
        <!-- AI reasoning display if available -->
      </label>
    <% end %>
  </div>
  
  <!-- Selection limit warnings -->
</div>

 Rating Scale Component
erb<!-- app/views/question_types/_rating.html.erb -->
<div class="space-y-6" data-controller="rating-scale">
  
  <!-- Scale labels -->
  <div class="flex items-center justify-between text-sm text-gray-600">
    <span><%= question.rating_config[:labels]['min'] || 'Poor' %></span>
    <span><%= question.rating_config[:labels]['max'] || 'Excellent' %></span>
  </div>
  
  <!-- Rating buttons -->
  <div class="flex items-center justify-center space-x-2">
    <% (question.rating_config[:min]..question.rating_config[:max]).each do |value| %>
      <!-- Rating button implementation -->
    <% end %>
  </div>
  
  <!-- AI analysis display -->
</div>


3.4 JavaScript Controllers (Stimulus)
Form Builder Controller

 FormBuilderController
javascript// app/javascript/controllers/form_builder_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionsContainer", "addQuestionModal"]
  static values = { formId: String }
  
  // Methods to implement:
  connect() {
    this.setupSortable()
    this.setupShortcuts()
  }
  
  showAddQuestion() {
    // Show add question modal
  }
  
  async addQuestion(event) {
    // Add new question via AJAX
  }
  
  async editQuestion(event) {
    // Edit question inline
  }
  
  async deleteQuestion(event) {
    // Delete question with confirmation
  }
  
  async enhanceWithAI(event) {
    // Enable AI features for question
  }
  
  // Helper methods:
  setupSortable() {}
  setupShortcuts() {}
  handleQuestionReorder(evt) {}
  selectEnhancementType() {}
}


Form Response Controller

 FormResponseController
javascript// app/javascript/controllers/form_response_controller.js
export default class extends Controller {
  static values = { 
    formToken: String,
    responseId: String,
    currentPosition: Number
  }
  
  // Methods to implement:
  connect() {
    this.setupAutoSave()
    this.setupProgressTracking()
    this.trackQuestionView()
  }
  
  async nextQuestion(event) {
    // Navigate to next question
  }
  
  async previousQuestion() {
    // Navigate to previous question
  }
  
  validateCurrentQuestion() {
    // Validate before navigation
  }
  
  setupAutoSave() {
    // Auto-save functionality
  }
  
  async requestAIAssistance(questionType, userInput) {
    // Request AI help if available
  }
}


3.5 AI Enhancement Interface
AI Configuration Panel

 AI Enhancement Panel
erb<!-- app/views/forms/_ai_enhancement_panel.html.erb -->
<div class="space-y-6" data-controller="ai-enhancement">
  
  <!-- AI status overview -->
  <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-6">
    <!-- Master AI toggle, usage statistics -->
  </div>
  
  <!-- Feature configuration cards -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
    
    <!-- Smart Validation Card -->
    <div class="border border-gray-200 rounded-lg p-6">
      <h5 class="text-base font-medium text-gray-900">Smart Validation</h5>
      <p class="mt-2 text-sm text-gray-600">AI-powered input validation</p>
      <!-- Toggle and configuration -->
    </div>
    
    <!-- Dynamic Follow-ups Card -->
    <div class="border border-gray-200 rounded-lg p-6">
      <h5 class="text-base font-medium text-gray-900">Dynamic Follow-ups</h5>
      <p class="mt-2 text-sm text-gray-600">Generate contextual questions</p>
      <!-- Toggle and configuration -->
    </div>
    
    <!-- Response Analysis Card -->
    <div class="border border-gray-200 rounded-lg p-6">
      <h5 class="text-base font-medium text-gray-900">Response Analysis</h5>
      <p class="mt-2 text-sm text-gray-600">Sentiment and quality analysis</p>
      <!-- Toggle and configuration -->
    </div>
    
  </div>
  
  <!-- Advanced settings -->
  <div class="border-t border-gray-200 pt-6">
    <!-- Confidence threshold, model selection, budget limits -->
  </div>
</div>


3.6 Analytics Dashboard
Analytics Overview

 Analytics Dashboard
erb<!-- app/views/forms/analytics.html.erb -->
<div class="space-y-8" data-controller="analytics-dashboard">
  
  <!-- Key metrics cards -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    <div class="metric-card">
      <h3>Response Rate</h3>
      <div class="text-3xl font-bold"><%= @analytics[:completion_rate] %>%</div>
    </div>
    <!-- More metric cards -->
  </div>
  
  <!-- Charts and graphs -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
    <div class="chart-container">
      <h4>Response Trends</h4>
      <canvas data-analytics-dashboard-target="responseChart"></canvas>
    </div>
    
    <div class="chart-container">
      <h4>Drop-off Analysis</h4>
      <canvas data-analytics-dashboard-target="dropoffChart"></canvas>
    </div>
  </div>
  
  <!-- AI insights section -->
  <% if @insights.present? %>
    <div class="ai-insights-section">
      <%= render "ai_insights", insights: @insights %>
    </div>
  <% end %>
</div>


Question Performance View

 Question Analytics Component
erb<!-- app/views/forms/_question_analytics.html.erb -->
<div class="question-analytics">
  <% @form.questions_ordered.each do |question| %>
    <div class="question-metric-card">
      <div class="question-header">
        <h4><%= question.title %></h4>
        <span class="question-type-badge"><%= question.question_type.humanize %></span>
      </div>
      
      <div class="metrics-grid">
        <div class="metric">
          <span class="metric-label">Completion Rate</span>
          <span class="metric-value"><%= question.completion_rate.round(1) %>%</span>
        </div>
        
        <div class="metric">
          <span class="metric-label">Avg Response Time</span>
          <span class="metric-value"><%= question.average_response_time_seconds.round(1) %>s</span>
        </div>
        
        <div class="metric">
          <span class="metric-label">Total Responses</span>
          <span class="metric-value"><%= question.responses_count %></span>
        </div>
      </div>
      
      <!-- AI insights for this question -->
      <% if question.ai_enhanced? && question.generates_ai_insights? %>
        <div class="question-ai-insights">
          <!-- Question-specific AI insights -->
        </div>
      <% end %>
    </div>
  <% end %>
</div>



## Part 10: Production, Testing & Launch

```markdown
### 3.7 Integration Management Interface

#### Integration Dashboard
- [ ] **Integration Management View**
  ```erb
  <!-- app/views/forms/_integrations_panel.html.erb -->
  <div class="space-y-6" data-controller="integrations-manager">
    
    <!-- Connected services overview -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <% %w[webhook crm_sync email_marketing].each do |integration_type| %>
        <div class="integration-card" data-integration="<%= integration_type %>">
          <!-- Integration status, configuration, testing -->
        </div>
      <% end %>
    </div>
    
    <!-- Integration setup wizards -->
    <div class="integration-setup-area">
      <!-- Dynamic integration configuration forms -->
    </div>
  </div>
Phase 4: Production Setup & Testing
4.1 Production Configuration
Environment Configuration

 Production Environment Setup
ruby# config/environments/production.rb
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  
  # Asset optimization
  config.assets.compile = false
  config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser
  
  # Active Job configuration
  config.active_job.queue_adapter = :sidekiq
  config.active_job.queue_name_prefix = "agentform_#{Rails.env}"
  
  # SuperAgent production settings
  config.after_initialize do
    SuperAgent.configure do |config|
      config.logger = Rails.logger
      config.a2a_server_enabled = ENV['A2A_SERVER_ENABLED'] == 'true'
      config.a2a_server_port = ENV['A2A_SERVER_PORT'] || 8080
      config.a2a_auth_token = ENV['A2A_AUTH_TOKEN']
    end
  end
end


Database Configuration

 Production Database Setup
ruby# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  host: <%= ENV['DATABASE_HOST'] %>
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  pool: <%= ENV.fetch("DB_POOL", 10) %>
  timeout: 5000


Sidekiq Configuration

 Background Job Setup
ruby# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
  config.queues = %w[critical default ai_processing integrations analytics]
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end


4.2 Docker Configuration
Application Dockerfile

 Docker Setup
dockerfile# Dockerfile
FROM ruby:3.2-alpine

# Install dependencies
RUN apk add --no-cache build-base postgresql-dev nodejs npm imagemagick

WORKDIR /app

# Install gems and node modules
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

COPY package*.json ./
RUN npm install

# Copy application and precompile assets
COPY . .
RUN RAILS_ENV=production bundle exec rails assets:precompile

# Create non-root user
RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]


Docker Compose

 Development Compose
yaml# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports: ["3000:3000"]
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/agentform_production
      - REDIS_URL=redis://redis:6379/0
    depends_on: [db, redis]
    
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: agentform_production
      POSTGRES_PASSWORD: password
    volumes: [postgres_data:/var/lib/postgresql/data]
    
  redis:
    image: redis:7-alpine
    volumes: [redis_data:/data]
    
  sidekiq:
    build: .
    command: bundle exec sidekiq
    depends_on: [db, redis]
    
volumes:
  postgres_data:
  redis_data:


4.3 Monitoring & Observability
Application Monitoring

 Error Tracking Setup
ruby# config/initializers/instrumentation.rb
if Rails.env.production?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.traces_sample_rate = 0.1
    config.before_send = lambda do |event, hint|
      # Filter sensitive form data
      event.extra[:form_data] = '[FILTERED]' if event.extra&.dig(:form_data)
      event
    end
  end
end

# SuperAgent instrumentation
SuperAgent.configure do |config|
  config.before_workflow_execution = lambda do |workflow_class, context|
    # Workflow execution tracking
  end
  
  config.after_workflow_execution = lambda do |workflow_class, context, result|
    # Performance and error tracking
  end
end


Health Checks

 Health Check Controller
ruby# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!
  
  def show
    # Methods to implement:
    # - database_healthy?
    # - redis_healthy?
    # - storage_healthy?
    # - superagent_health
    # - ai_providers_health
  end
  
  def detailed
    # Comprehensive health check with system metrics
  end
end


4.4 Performance Optimization
Database Performance

 Performance Indexes
ruby# db/migrate/020_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Composite indexes for common queries
    add_index :form_responses, [:form_id, :status, :created_at], 
              name: 'index_form_responses_performance'
    add_index :question_responses, [:form_response_id, :created_at], 
              name: 'index_question_responses_performance'
    
    # Partial indexes for AI features
    add_index :form_questions, [:form_id], 
              where: "ai_enhancement ->> 'enabled' = 'true'", 
              name: 'index_ai_enhanced_questions'
    
    # Full-text search indexes
    execute "CREATE INDEX CONCURRENTLY index_forms_search ON forms USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')))"
  end
end


Caching Strategy

 Cache Optimization
ruby# Updates to existing models to include caching methods:

# app/models/form.rb (additions)
class Form < ApplicationRecord
  # Add cached methods:
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


4.5 Security & Compliance
Security Configuration

 Security Headers & CSP
ruby# config/initializers/security.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, 'api.openai.com', 'api.anthropic.com'
  end
  
  config.force_ssl = true if Rails.env.production?
end


Data Privacy Services (Updates)

 GDPR Compliance Methods
ruby# Add to existing Forms::DataPrivacyService:

class Forms::DataPrivacyService
  # Additional methods to implement:
  def audit_data_access(user_email, action)
  def generate_privacy_report
  def schedule_data_retention_cleanup
  def validate_consent_requirements
  
  private
  
  def log_privacy_action(action, details)
end


4.6 Testing Framework
Test Configuration

 RSpec Setup
ruby# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
  config.include WorkflowHelpers
  config.include ApiHelpers
end


Workflow Testing Helpers

 Workflow Test Utilities
ruby# spec/support/workflow_helpers.rb
module WorkflowHelpers
  def run_workflow(workflow_class, initial_input = {}, user: nil)
    # Workflow execution helper
  end
  
  def mock_llm_response(response_text)
    # LLM response mocking
  end
  
  def expect_workflow_step(result, step_name)
    # Workflow step validation
  end
  
  def expect_ai_usage_tracked(user, operation, cost)
    # AI usage tracking verification
  end
end


Test Examples

 Core Test Specs
ruby# Key test files to implement:

# spec/models/form_spec.rb
# spec/models/form_question_spec.rb  
# spec/models/form_response_spec.rb
# spec/models/question_response_spec.rb
# spec/workflows/forms/response_processing_workflow_spec.rb
# spec/services/forms/answer_processing_service_spec.rb
# spec/controllers/forms_controller_spec.rb
# spec/controllers/responses_controller_spec.rb
# spec/controllers/api/v1/forms_controller_spec.rb
# spec/jobs/forms/response_analysis_job_spec.rb
# spec/agents/forms/management_agent_spec.rb

# Each with comprehensive test coverage including:
# - Happy path scenarios
# - Edge cases and error handling  
# - AI integration testing
# - Workflow execution validation
# - Performance benchmarks


4.7 Deployment & Launch
Deployment Scripts

 Deployment Automation
bash#!/bin/bash
# script/deploy.sh

set -e

echo "Starting AgentForm deployment..."

# Pre-deployment checks
bundle exec rails db:check_migrations
bundle exec rails assets:precompile

# Database setup
bundle exec rails db:migrate
bundle exec rails db:seed

# Start services
bundle exec sidekiq -d -e production

# Start A2A server if enabled
if [ "$A2A_SERVER_ENABLED" = "true" ]; then
  bundle exec rake super_agent:a2a:serve &
fi

# Start main application
bundle exec puma -C config/puma.rb

echo "AgentForm deployment complete!"


Database Seeding

 Production Data Setup
ruby# db/seeds.rb
Rails.logger.info "Creating default form templates..."

# Create featured templates
FormTemplate.create!(
  name: "Lead Qualification Form",
  description: "Qualify potential customers and gather contact information",
  category: "lead_qualification",
  visibility: "featured",
  template_data: {
    form_settings: {
      ui: { progress_bar: true, one_question_per_page: true }
    },
    ai_configuration: {
      enabled: true,
      features: ["response_analysis", "dynamic_followups"]
    },
    questions: [
      {
        title: "What's your email address?",
        question_type: "email",
        required: true,
        position: 1
      },
      # Additional template questions...
    ]
  }
)

# Create other templates for different categories
# Create sample integration configurations
# Create default AI model configurations


4.8 Success Metrics & KPIs
Development Success Metrics

 Quality Targets

99.9% uptime achievement
< 200ms average API response time
95%+ test coverage maintenance
Zero critical security vulnerabilities
AI workflow success rate > 90%



Business Success Metrics

 Growth Targets

10,000 free users in first 6 months
15% free-to-paid conversion rate
$50k MRR within 12 months
4.8/5 average customer rating
20% better completion rates vs competitors



Competitive Positioning

 Market Differentiation Goals

100% feature parity with Youform free tier
Superior UX and reliability metrics
AI-powered form intelligence capabilities
SuperAgent workflow integration advantage
Developer-first API approach adoption




Implementation Priority Order

Phase 1 (Weeks 1-8): Foundation & MVP

Core models and database schema
Basic form builder interface
Question type system
Form response collection
SuperAgent workflow integration


Phase 2 (Weeks 9-16): AI Enhancement & Pro Features

AI workflow implementation
Dynamic question generation
Advanced analytics dashboard
Pro tier features rollout


Phase 3 (Weeks 17-24): API & Integration Layer

REST API implementation
A2A protocol setup
Third-party integrations
SDK development


Phase 4 (Weeks 25-32): Production & Polish

Production environment setup
Performance optimization
Security hardening
Comprehensive testing


Phase 5 (Weeks 33-35): Launch Preparation

Final testing and QA
Documentation completion
Launch strategy execution
Post-launch monitoring setup



This comprehensive blueprint provides the complete class structure and implementation details needed to build AgentForm as envisioned in the TODO_FINAL.md document.

This concludes the 10-part updated TODO.md with all the necessary classes, methods, and implementation details for the AgentForm Rails application with SuperAgent workflow integration. Each part builds systematically from foundation to production deployment, maintaining the architectural pattern of Controllers → Agents → Workflows → Tasks → Services throughout.
