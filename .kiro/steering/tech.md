# Technology Stack & Principles: mydialogform

This document outlines the technical foundation, architectural patterns, and development standards for the mydialogform project. It serves as a persistent guide for Kiro to ensure consistent and high-quality code generation.

## 1. Core Technology Stack

*   **Backend Framework:** Rails 7.1+
*   **Database:** PostgreSQL
*   **AI/Agent Framework:** SuperAgent Workflow Framework (as a Ruby Gem)
*   **Styling:** Tailwind CSS
*   **Real-time Updates:** Turbo Streams (part of the Hotwire stack)
*   **Background Processing:** Sidekiq
*   **Caching & Sessions:** Redis

## 2. Application Architecture

### Core Architectural Pattern
The application follows a defined, scalable pattern to ensure separation of concerns and clarity of logic flow. Kiro must adhere to this structure:

**`Controllers → Agents → Workflows → Tasks (LLM/DB/Stream) → Services`**

*   **Controllers:** Handle web and API requests, delegate to Agents.
*   **Agents:** High-level business logic coordinators. They invoke specific Workflows to accomplish a goal.
*   **Workflows:** Defined using the SuperAgent DSL. They orchestrate a series of Tasks.
*   **Tasks:** Atomic units within a Workflow (e.g., an LLM call, a database write, a stream update).
*   **Services:** Encapsulate complex business logic or third-party integrations, often called from Tasks or Agents.

Base classes will be implemented for each architectural layer to ensure consistency.

## 3. Database

*   **System:** PostgreSQL is the exclusive database system.
*   **Primary Keys:** All tables must use `UUID` for primary keys. The `pgcrypto` extension will be enabled in the first migration.
*   **Schema:** The schema will be managed through Rails migrations. Key tables include `users`, `forms`, `form_questions`, `form_responses`, etc., as detailed in `structure.md`.

## 4. Background Processing

*   **Provider:** Sidekiq is the exclusive provider for background jobs.
*   **Queues:** A multi-queue strategy will be used to prioritize jobs. Kiro should assign jobs to the correct queue:
    *   `critical`: For time-sensitive tasks like payment processing.
    *   `default`: General-purpose tasks.
    *   `ai_processing`: For all LLM-related tasks and heavy AI computations.
    *   `integrations`: For outbound API calls to third-party services.
    *   `analytics`: For batch processing of analytics data.
*   **Job Policy:** All jobs must include robust retry policies and error handling.

## 5. Authentication & Authorization

*   **User Authentication:** Devise will be used for user authentication, integrated with a custom `User` model.
*   **Authorization:** A role-based permission system will be implemented on the `User` model, with roles such as `user`, `premium`, and `admin`.
*   **API Authentication:** A separate API token system will be implemented for authenticating API requests.

## 6. Frontend Architecture

*   **Framework:** The frontend is built on the Hotwire stack (Turbo and Stimulus).
    *   **Turbo Streams** will be used for real-time UI updates initiated from the server.
    *   **Stimulus** will be used for client-side interactivity.
*   **Styling:** Tailwind CSS is the primary styling framework. A custom `tailwind.config.js` will define the design system. Utility-first principles should be followed.

## 7. API Design

*   **Principle:** The project follows an **API-first** approach. All functionality available in the UI must be exposed through the API.
*   **REST API:** A versioned RESTful API (starting with `v1`) will be the primary interface.
*   **GraphQL:** A GraphQL API is planned for future development to offer more flexible data querying.
*   **A2A Protocol:** The SuperAgent A2A (Agent-to-Agent) protocol will be implemented for advanced, machine-to-machine interactions with forms.

## 8. Testing Strategy

*   **Framework:** RSpec is the preferred testing framework.
*   **Coverage Target:** A minimum of **95% test coverage** is required for all new code.
*   **Tools:**
    *   **FactoryBot** for generating test data.
    *   **VCR** or similar for mocking external HTTP requests.
    *   Custom helpers will be created for testing SuperAgent workflows.
*   **Types:** The test suite will include unit, integration, and system tests. Performance and load testing will be conducted before major releases.

## 9. CI/CD & DevOps

*   **Pipeline:** A CI/CD pipeline will be implemented to automate testing and deployment. It will include:
    *   Execution of the full RSpec suite.
    *   Code quality checks (e.g., RuboCop).
    *   Security vulnerability scanning.
*   **Containerization:** Docker will be used for creating consistent development and production environments.
    *   A `docker-compose.yml` file will orchestrate the development environment (app, PostgreSQL, Redis, Sidekiq).
    *   Production builds will use multi-stage Dockerfiles for optimized, secure images.

## 10. Observability

*   **Error Tracking:** Sentry will be integrated for real-time error tracking and alerting.
*   **Performance Monitoring:** New Relic or Datadog will be used for application performance monitoring (APM), with custom instrumentation for SuperAgent workflows and AI costs.
*   **Logging:** A centralized logging system will be configured, with structured logs for easy parsing.
*   **Health Checks:** The application will expose a `/health` endpoint for basic uptime checks and a detailed endpoint for checking the status of critical components (Database, Redis, AI Providers).

## 11. Core Development Principles

*   **Spec-Driven Development:** We adhere to the Kiro philosophy. All features must start with `requirements.md`, `design.md`, and `tasks.md` before implementation.
*   **Enterprise-Grade Reliability:** The system is being built to handle mission-critical workflows. Stability, security, and data integrity are paramount.
*   **Security by Design:** Security is not an afterthought. Sanitize all inputs, use encryption for sensitive data (`encrypts` in Rails 7+), and follow security best practices.
*   **AI Cost Management:** Be mindful of the cost of LLM calls. Implement intelligent caching, use the most cost-effective model for the task, and track AI credit usage meticulously.
