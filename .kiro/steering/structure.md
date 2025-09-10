# Project Structure: mydialogform

This document defines the file and directory organization for the mydialogform project. It follows standard Ruby on Rails conventions while incorporating the specific architectural layers required for the SuperAgent framework. This structure is essential for Kiro to generate code consistently and understand the project's layout.

## 1. Top-Level Directory Structure

The project will adhere to the standard Rails directory layout, with specific additions for Kiro and project documentation.

*   `.kiro/`: Contains all configuration and specification files for the Kiro IDE.
*   `app/`: The core application code, detailed below.
*   `bin/`: Executable scripts.
*   `config/`: Application configuration files.
*   `db/`: Database schemas and migrations.
*   `docs/`: Project documentation (manuals, guides, etc.).
*   `lib/`: Custom library code.
*   `log/`: Log files.
*   `public/`: Publicly accessible static files.
*   `spec/`: RSpec test files.
*   `tmp/`: Temporary files.
*   `vendor/`: Third-party code.
*   `Gemfile`, `Gemfile.lock`: Ruby gem dependency management.
*   `README.md`: Project overview.

## 2. The `app/` Directory

The `app/` directory is organized to reflect our core architecture: **Controllers → Agents → Workflows → Tasks → Services**.

*   `app/assets/`:
    *   `stylesheets/`: Houses CSS files. The main file is `application.tailwind.css`.
    *   `javascripts/`:
        *   `controllers/`: Stimulus controllers for frontend interactivity (e.g., `form_builder_controller.js`).

*   `app/controllers/`: Standard Rails controllers.
    *   `application_controller.rb`: Base controller with shared logic.
    *   `api/`: Namespace for all API controllers.
        *   `base_controller.rb`: Base controller for the API, handling authentication and serialization.
        *   `v1/`: For version 1 of the API (e.g., `forms_controller.rb`).

*   `app/jobs/`: Sidekiq background jobs. Jobs are namespaced by feature.
    *   `forms/`:
        *   `response_analysis_job.rb`
        *   `integration_trigger_job.rb`

*   `app/models/`: ActiveRecord models and concerns.
    *   `application_record.rb`: Base model.
    *   `user.rb`, `form.rb`, `form_question.rb`, etc.
    *   `concerns/`: Shared module logic for models (e.g., `Cacheable.rb`, `Encryptable.rb`).

*   **`app/agents/`**: **[SuperAgent Layer]** High-level business logic coordinators.
    *   `application_agent.rb`: Base class for all agents.
    *   `forms/`: Agents are namespaced by feature.
        *   `management_agent.rb`
        *   `response_agent.rb`

*   **`app/workflows/`**: **[SuperAgent Layer]** SuperAgent Workflow Definitions.
    *   `application_workflow.rb`: Base class with global configurations (timeouts, retries).
    *   `forms/`: Workflows are namespaced by feature.
        *   `response_processing_workflow.rb`
        *   `analysis_workflow.rb`

*   **`app/services/`**: Encapsulates complex business logic.
    *   `application_service.rb`: Base class for all services.
    *   `forms/`: Services are namespaced by feature.
        *   `answer_processing_service.rb`
        *   `workflow_generator_service.rb`
        *   `integrations/`: Sub-namespace for third-party services.
            *   `salesforce_service.rb`
            *   `mailchimp_service.rb`

*   `app/views/`:
    *   `layouts/`: Application-wide layouts.
    *   `shared/`: Reusable partials.
    *   `components/`: Reusable ViewComponent classes for complex UI elements.

## 3. The `config/` Directory

This directory contains crucial configuration files.

*   `config/routes.rb`: Defines all application routes, including API and A2A endpoints.
*   `config/database.yml`: Configures the PostgreSQL connection.
*   `config/initializers/`:
    *   `super_agent.rb`: Configuration for the SuperAgent gem (LLM provider, API keys, timeouts).
    *   `sidekiq.rb`: Configures Sidekiq queues and Redis connection.
    *   `devise.rb`: Configures Devise for authentication.
    *   `redis.rb`: Configures the primary Redis connection.
*   `config/tailwind.config.js`: Custom configuration for Tailwind CSS.

## 4. The `db/` Directory

*   `db/migrate/`: Contains all database migration files. The first migration must enable the `pgcrypto` extension for UUID support.
*   `db/schema.rb`: The canonical representation of the database schema.
*   `db/seeds.rb`: Contains data to populate the database for development.

## 5. The `spec/` Directory (Testing)

The testing structure mirrors the `app/` directory.

*   `spec/factories/`: FactoryBot factories for creating test data.
*   `spec/models/`, `spec/controllers/`, `spec/jobs/`, `spec/services/`: Unit and integration tests for each respective component.
*   `spec/agents/`: Tests for SuperAgent Agents.
*   `spec/workflows/`: Tests for SuperAgent Workflows.
*   `spec/support/`: Helper modules and configuration for the test suite (e.g., `workflow_helpers.rb`).

## 6. The `.kiro/` Directory (Kiro IDE)

This directory is essential for Kiro's operation.

*   `.kiro/steering/`: Contains Markdown files that provide **persistent, project-wide context** to Kiro.
    *   `product.md`: The product vision and goals.
    *   `tech.md`: The technology stack and architectural principles.
    *   `structure.md`: This document.
    *   `principles.md`: General development principles (e.g., coding style, error handling).
    *   `testing.md`: The project's testing philosophy and standards.

*   `.kiro/specs/`: Contains **feature-specific specifications** that guide Kiro's implementation work.
    *   `[feature-name]/`: Each directory represents a specific feature or work package.
        *   `requirements.md`: Defines what the feature should do.
        *   `design.md`: Outlines the technical approach for the feature.
        *   `tasks.md`: A checklist of implementation steps generated by Kiro.
