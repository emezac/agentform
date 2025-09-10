You are absolutely right. My apologies. The key to making Kiro effective is to leverage the detailed blueprints you've provided. The `tasks.md` should not be a general guide; it should be an explicit, granular execution plan that directly instructs Kiro to implement the code *exactly* as specified in your blueprints.

Here is the revised, ultra-complete, and granular `tasks.md` file. It is structured to be the definitive instruction set for Kiro, referencing your `TODO_BLUEPRINT.md` and `TODO_FINAL.md` as the single source of truth for all implementation details.

---

This file should be saved at: `.kiro/specs/foundation-setup/tasks.md`

# Implementation Tasks: AgentForm Foundation & Core Setup

## Introduction

This document provides an ultra-granular implementation plan for the foundational phase of the AgentForm project. It translates the requirements and design into a precise, step-by-step checklist for Kiro.

**Crucial Instruction for Kiro:** The implementation for every class, method, attribute, and configuration must adhere strictly to the definitions provided in `TODO_BLUEPRINT.md` and `TODO_FINAL.md`. These documents are the single source of truth for all code generation.

## Phase 1: Foundation Setup & Core Models (Weeks 1-2)

### 1.1. Rails Application & Gem Configuration

- [x] **1.1.1. Generate Rails Application:** Create a new Rails 7.1+ application named `agentform` using PostgreSQL.
- [x] **1.1.2. Update Gemfile:** Add `super_agent`, `sidekiq`, `redis`, `devise`, `pundit`, `tailwindcss-rails`, `sentry-ruby`, `rspec-rails`, and `factory_bot_rails`.
- [x] **1.1.3. Bundle Install:** Run `bundle install`.
- [x] **1.1.4. Configure Tailwind CSS:** Run `rails tailwindcss:install`.

### 1.2. Initializer Configuration

- [x] **1.2.1. Configure SuperAgent:** Create `config/initializers/super_agent.rb` and implement the configuration exactly as defined in the `TODO_FINAL.md` blueprint.
- [x] **1.2.2. Configure Sidekiq:** Create `config/initializers/sidekiq.rb` and `config/sidekiq.yml`. Define queues: `critical`, `default`, `ai_processing`, `integrations`, `analytics`.
- [x] **1.2.3. Configure Devise & Pundit:** Run the installers to create their respective initializers.

### 1.3. Database Schema Migrations

- [x] **1.3.1. Enable UUID Extension:** Create migration `001_enable_uuid_extension.rb` to enable `pgcrypto`.
- [x] **1.3.2. Create `users` Table:** Create migration `002_create_users.rb` with all columns, types, indexes, and constraints specified in `TODO_BLUEPRINT.md`. Use `id: :uuid`.
- [x] **1.3.3. Create `forms` Table:** Create migration `003_create_forms.rb` with all columns, types, foreign keys, and indexes specified in `TODO_BLUEPRINT.md`. Use `id: :uuid`.
- [x] **1.3.4. Create `form_questions` Table:** Generate the migration for `form_questions` as defined.
- [x] **1.3.5. Create `form_responses` Table:** Generate the migration for `form_responses` as defined.
- [x] **1.3.6. Create `question_responses` Table:** Generate the migration for `question_responses` as defined.
- [x] **1.3.7. Create `form_analytics` Table:** Generate the migration for `form_analytics` as defined.
- [x] **1.3.8. Create `dynamic_questions` Table:** Generate the migration for `dynamic_questions` as defined.
- [x] **1.3.9. Create `form_templates` Table:** Generate the migration for `form_templates` as defined.
- [x] **1.3.10. Create `api_tokens` Table:** Generate the migration for `api_tokens` as defined.
- [x] **1.3.11. Run All Migrations:** Execute `rails db:migrate`.

### 1.4. Core Model Implementation

**Instruction for Kiro:** For each model below, generate the file and implement all specified associations, enums, validations, callbacks, and method signatures from `TODO_BLUEPRINT.md`. The initial implementation should contain the method definitions with comments indicating their purpose, ready for logic to be filled in.

- [x] **1.4.1. Implement `User` Model (`app/models/user.rb`):**
  - [x] Include the `Encryptable` concern.
  - [x] Add `has_secure_password` and all `has_many` associations.
  - [x] Define the `role` enum.
  - [x] Add all `validates` clauses.
  - [x] Implement the `before_create` and `before_save` callbacks.
  - [x] Define all public instance methods (`full_name`, `ai_credits_remaining`, etc.).
  - [x] Define all private methods (`set_default_preferences`, etc.).

- [x] **1.4.2. Implement `Form` Model (`app/models/form.rb`):**
  - [x] Include the `Cacheable` concern.
  - [x] Add all `belongs_to` and `has_many` associations.
  - [x] Define `status` and `category` enums.
  - [x] Implement `before_create` and `before_save` callbacks.
  - [x] Define all public instance methods (`workflow_class`, `completion_rate`, etc.).
  - [x] Define all private methods (`generate_share_token`, etc.).

- [x] **1.4.3. Implement `FormQuestion` Model (`app/models/form_question.rb`):**
  - [x] Add all associations.
  - [x] Define the `QUESTION_TYPES` constant.
  - [x] Define the `question_type` enum.
  - [x] Implement all validations, including custom validation methods.
  - [x] Define all public instance methods (`question_type_handler`, `ai_enhanced?`, etc.).
  - [x] Define all private validation methods.

- [x] **1.4.4. Implement `FormResponse` Model (`app/models/form_response.rb`):**
  - [x] Add all associations.
  - [x] Define the `status` enum.
  - [x] Implement `before_create` and `before_save` callbacks.
  - [x] Define all public instance methods (`progress_percentage`, `trigger_ai_analysis!`, etc.).

- [x] **1.4.5. Implement `QuestionResponse` Model (`app/models/question_response.rb`):**
  - [x] Add all associations.
  - [x] Implement `before_save` and `after_create` callbacks.
  - [x] Define all public instance methods (`processed_answer_data`, `trigger_ai_analysis!`, etc.).

- [x] **1.4.6. Implement Other Core Models:**
  - [x] `FormAnalytic`
  - [x] `DynamicQuestion`
  - [x] `FormTemplate`
  - [x] `ApiToken`

### 1.5. Concerns & Modules Implementation

- [x] **1.5.1. Implement `Cacheable` Concern (`app/models/concerns/cacheable.rb`):** Implement the class methods and instance methods as defined.
- [x] **1.5.2. Implement `Encryptable` Concern (`app/models/concerns/encryptable.rb`):** Implement the encryption logic using Rails 7 `encrypts` for the specified fields.

## Phase 2: SuperAgent Workflow Implementation

**Instruction for Kiro:** For each workflow, create the class file and implement the workflow using the SuperAgent DSL precisely as defined in `TODO_BLUEPRINT.md`. This includes all steps (`validate`, `task`, `llm`, `stream`), their inputs, conditions (`run_if`, `run_when`), and the logic within their `process` blocks.

### 2.1. Base Workflow & Agent Classes

- [x] **2.1.1. Implement `ApplicationWorkflow` Base (`app/workflows/application_workflow.rb`):** Configure global `timeout`, `retry_policy`, `on_error`, `before_all`, and `after_all` hooks. Implement the specified helper methods.
- [x] **2.1.2. Implement `ApplicationAgent` Base (`app/agents/application_agent.rb`):** Create the base class.
- [x] **2.1.3. Implement `ApplicationJob` and `ApplicationService` Base Classes.**

### 2.2. Core Workflow Implementation

- [x] **2.2.1. Implement `Forms::ResponseProcessingWorkflow` (`app/workflows/forms/response_processing_workflow.rb`):**
  - [x] Define the entire 7-step workflow structure.
  - [x] Implement the `process` block logic for `:validate_response_data`.
  - [x] Implement the `run_when` condition for `:save_question_response`.
  - [x] Implement the `run_if` condition for `:analyze_response_ai`.
  - [x] Configure the `:analyze_response_ai` LLM step with the specified model, temperature, format, and prompts.
  - [x] Implement the remaining `task`, `llm`, and `stream` steps with their respective logic and configurations.

- [x] **2.2.2. Implement `Forms::AnalysisWorkflow` (`app/workflows/forms/analysis_workflow.rb`):**
  - [x] Define the 5-step workflow structure.
  - [x] Implement the data collection, LLM analysis, and result-saving logic as specified.
  - [x] Define the private helper methods.

- [x] **2.2.3. Implement `Forms::DynamicQuestionWorkflow` (`app/workflows/forms/dynamic_question_workflow.rb`):**
  - [x] Define the 5-step workflow for generating and inserting dynamic questions.
  - [x] Configure the LLM step with the specified prompts for contextual follow-ups.

### 2.3. Agent Implementation

- [x] **2.3.1. Implement `Forms::ManagementAgent` (`app/agents/forms/management_agent.rb`):** Define all specified public methods.
- [x] **2.3.2. Implement `Forms::ResponseAgent` (`app/agents/forms/response_agent.rb`):** Define all specified public methods.

### 2.4. Service Layer Implementation

- [x] **2.4.1. Implement `Forms::AnswerProcessingService`:** Create the service with all attributes and methods defined in the blueprint.
- [x] **2.4.2. Implement `Forms::NavigationService`:** Create the service with its methods.
- [x] **2.4.3. Implement `Forms::WorkflowGeneratorService`:**
  - [x] Create the main service class.
  - [x] Implement the nested `WorkflowDefinitionBuilder` class and its methods as specified.

### 2.5. Background Job Implementation

- [x] **2.5.1. Create `Forms::WorkflowGenerationJob`:** Implement the `perform` method logic.
- [x] **2.5.2. Create `Forms::ResponseAnalysisJob`:** Implement the `perform` method logic.
- [x] **2.5.3. Create `Forms::DynamicQuestionGenerationJob`:** Implement the `perform` method logic.
- [x] **2.5.4. Create `Forms::IntegrationTriggerJob`:** Implement the `perform` method and its private helper methods for different integrations (Webhook, Slack, etc.).
- [x] **2.5.5. Create `Forms::CompletionWorkflowJob`:** Implement the `perform` method logic.

## Phase 3: Controller & View Layer (UI/API)

### 3.1. Controller Implementation

- [x] **3.1.1. Implement `ApplicationController`:** Set up Pundit, authentication, and global rescue handlers.
- [x] **3.1.2. Implement `FormsController`:** Create all specified public actions (`index`, `publish`, `analytics`, etc.) and private methods.
- [x] **3.1.3. Implement `FormQuestionsController`:** Create all specified public actions (`create`, `move_up`, `ai_enhance`, etc.) and private methods.
- [x] **3.1.4. Implement `ResponsesController` (Public):** Create all public actions (`show`, `answer`, `thank_you`, etc.) and the extensive list of private helper methods.

### 3.2. API Layer Implementation

- [x] **3.2.1. Implement `Api::BaseController`:** Set up token authentication and API-specific error handling.
- [x] **3.2.2. Implement `Api::V1::FormsController`:** Create all specified API endpoints for form management.
- [x] **3.2.3. Implement `Api::V1::ResponsesController`:** Create all specified API endpoints for response submission.

### 3.3. View and UI Component Implementation

- [x] **3.3.1. Create Layouts:** Build `application.html.erb`, `form_builder.html.erb`, and `form_response.html.erb`.
- [x] **3.3.2. Build Form Builder UI:**
  - [x] Create `forms/index.html.erb` with the `_form_card` partial.
  - [x] Create `forms/edit.html.erb` and its partials (`_form_header`, `_questions_panel`, `_configuration_tabs`).
- [x] **3.3.3. Build Stimulus Controllers:**
  - [x] `form_builder_controller.js` with methods for sortable, add/edit/delete questions.
  - [x] `form_response_controller.js` with methods for auto-save and navigation.
- [x] **3.3.4. Build Question Type Components:** Create a partial in `app/views/question_types/` for each core question type (`_text_short.html.erb`, `_multiple_choice.html.erb`, etc.).
