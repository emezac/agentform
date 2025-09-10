# Implementation Plan

- [x] 1. Set up core infrastructure and dependencies
  - Install and configure required gems (PDF::Reader for document processing)
  - Add AI credit tracking columns to User model migration
  - Create database indexes for AI-related queries and performance optimization
  - _Requirements: 1.1, 4.2, 4.6_

- [x] 2. Implement Document Processing Service
  - [x] 2.1 Create Ai::DocumentProcessor service class with ActiveModel validations
    - Implement file validation (content_type, file_size constraints)
    - Add extract_pdf_content method using PDF::Reader for page-by-page extraction
    - Add extract_text_content method with UTF-8 encoding support
    - Include comprehensive error handling with structured response format
    - _Requirements: 1.1, 1.2, 1.3, 1.7, 9.1, 9.2_

  - [x] 2.2 Create comprehensive test suite for DocumentProcessor
    - Write unit tests for file validation edge cases and error conditions
    - Test PDF extraction with various document formats and sizes
    - Test Markdown and text file processing with encoding scenarios
    - Verify error handling and response structure consistency
    - _Requirements: 1.1, 1.7, 9.1, 9.2_

- [x] 3. Extend User model for AI credit management
  - [x] 3.1 Add AI credit tracking attributes and methods to User model
    - Add ai_credits_used and monthly_ai_limit decimal attributes
    - Implement ai_credits_used_this_month calculation method
    - Implement ai_credits_remaining helper method
    - Add validation for credit limits and usage tracking
    - _Requirements: 4.1, 4.2, 4.5_

  - [x] 3.2 Create database migration for AI credit columns
    - Add ai_credits_used decimal column with default 0.0
    - Add monthly_ai_limit decimal column with default 10.0
    - Create indexes for efficient credit usage queries
    - _Requirements: 4.1, 4.2_

- [x] 4. Extend Form and FormQuestion models for AI capabilities
  - [x] 4.1 Add AI-specific attributes to Form model
    - Add ai_enabled boolean attribute with default false
    - Add ai_configuration JSON attribute for AI feature settings
    - Add form_settings JSON attribute for UX optimization settings
    - Add metadata JSON attribute for generation tracking and analytics
    - _Requirements: 5.2, 7.7, 8.1, 8.2_

  - [x] 4.2 Add AI-specific attributes to FormQuestion model
    - Add ai_enhanced boolean attribute for question-level AI features
    - Add ai_config JSON attribute for question-specific AI settings
    - Add metadata JSON attribute for position rationale and generation data
    - _Requirements: 5.4, 7.6, 8.6_

  - [x] 4.3 Create database migrations for AI model extensions
    - Add AI columns to forms table with proper JSON defaults
    - Add AI columns to form_questions table with proper JSON defaults
    - Create indexes for AI-enabled queries and performance optimization
    - _Requirements: 5.2, 5.4_

- [x] 5. Implement SuperAgent workflow foundation
  - [x] 5.1 Create Forms::AiFormGenerationWorkflow base structure
    - Inherit from ApplicationWorkflow with proper SuperAgent configuration
    - Define workflow structure with task sequence and dependencies
    - Implement workflow-level error handling and logging mechanisms
    - _Requirements: 2.1, 2.2, 9.7_

  - [x] 5.2 Implement validate_and_prepare_content task
    - Add user AI credit limit validation with specific error messages
    - Implement content processing logic for both prompt and document inputs
    - Add word count validation (10-5000 words) with actionable feedback
    - Return structured content data with metadata and processing timestamp
    - _Requirements: 2.1, 2.2, 2.3, 4.1, 9.3, 9.4_

- [x] 6. Implement AI content analysis LLM task
  - [x] 6.1 Create analyze_content_intent LLM task
    - Configure GPT-4o-mini model with temperature 0.3 and JSON response format
    - Implement system prompt for form design expertise and content analysis
    - Create structured prompt template with content analysis requirements
    - Define strict JSON output schema for form purpose, audience, and approach
    - _Requirements: 2.4, 2.5, 2.6, 2.7_

  - [x] 6.2 Add content analysis validation and error handling
    - Validate LLM response structure and required fields
    - Implement retry logic for malformed or incomplete responses
    - Add confidence scoring and analysis quality checks
    - _Requirements: 2.6, 9.5, 9.7_

- [x] 7. Implement structured form generation LLM task
  - [x] 7.1 Create generate_structured_questions LLM task
    - Configure GPT-4o model with temperature 0.2 for consistent generation
    - Implement comprehensive system prompt with UX best practices
    - Create detailed prompt template with FormQuestion::QUESTION_TYPES integration
    - Define strict JSON schema with form_meta, questions, and form_settings
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

  - [x] 7.2 Implement question generation logic and validation
    - Ensure question type validation against FormQuestion::QUESTION_TYPES enum
    - Implement logical question ordering with position rationale
    - Add question count limits and complexity-based optimization
    - Include helper text and description generation for user guidance
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.8_

- [x] 8. Implement form validation and data cleaning
  - [x] 8.1 Create validate_and_clean_structure task
    - Implement comprehensive validation for form metadata and questions
    - Add business rule validation (max 20 questions, valid categories)
    - Create data cleaning and normalization logic for database consistency
    - Add specific error messages for validation failures with retry options
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 8.2 Implement form structure optimization
    - Add question configuration enhancement based on question types
    - Implement UX optimization based on complexity and question count
    - Add validation for required fields and proper data formatting
    - _Requirements: 5.5, 8.6_

- [x] 9. Implement AI feature configuration system
  - [x] 9.1 Create AI feature determination logic
    - Implement determine_ai_features method based on content analysis approach
    - Add feature mapping for different form types (feedback, lead_capture, assessment)
    - Implement dynamic_followup feature for branching logic requirements
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 9.2 Create question-level AI configuration
    - Implement build_question_ai_config for type-specific AI settings
    - Add should_enable_ai_for_question logic for appropriate question types
    - Configure validation enhancement, sentiment analysis, and format suggestions
    - _Requirements: 7.6, 7.7_

  - [x] 9.3 Implement form settings optimization
    - Create build_form_settings method with complexity-based UX optimization
    - Implement one_question_per_page logic for complex forms
    - Add progress bar configuration based on question count
    - Configure email collection based on form approach (lead_capture, registration)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 10. Implement database form creation with transactions
  - [x] 10.1 Create create_optimized_form task
    - Implement ActiveRecord transaction wrapper for atomic form creation
    - Create Form record with AI configuration and optimized settings
    - Add AI cost calculation and credit deduction logic
    - Include comprehensive metadata tracking for analytics and billing
    - _Requirements: 5.1, 5.6, 5.7, 4.3, 4.4_

  - [x] 10.2 Implement FormQuestion creation with AI enhancements
    - Create FormQuestion records with enhanced configurations
    - Apply question-specific AI settings and validation rules
    - Add position rationale and generation metadata tracking
    - Implement error handling with transaction rollback on failures
    - _Requirements: 5.4, 5.7, 7.6, 9.6, 9.7_

  - [x] 10.3 Add AI cost calculation and tracking
    - Implement calculate_generation_cost method with base + per-question pricing
    - Add user credit deduction with increment! for atomic updates
    - Include cost tracking in form metadata for billing analytics
    - _Requirements: 4.2, 4.3, 4.5, 4.6_

- [x] 11. Create enhanced user interface with Stimulus controllers
  - [x] 11.1 Implement TabsController for input method switching
    - Create tabs_controller.js with switch action for prompt/document tabs
    - Add default tab selection based on URL parameters
    - Implement smooth tab transitions and state management
    - _Requirements: 6.1, 6.7_

  - [x] 11.2 Implement FileUploadController for document handling
    - Create file_upload_controller.js with drag-and-drop functionality
    - Add dragOver, dragEnter, dragLeave, and drop event handlers
    - Implement file selection validation and visual feedback
    - Add file info display with fileName and fileSize targets
    - _Requirements: 6.3, 6.6_

  - [x] 11.3 Implement FormPreviewController for real-time feedback
    - Create form_preview_controller.js with updatePreview action
    - Add word count tracking with wordCount target for user guidance
    - Implement cost estimation updates based on content length
    - Add preview functionality integration for generated forms
    - _Requirements: 6.2, 6.5, 6.7_

  - [x] 11.4 Implement AiFormGeneratorController for submission handling
    - Create ai_form_generator_controller.js with handleSubmit action
    - Add loading state management with submitButton target
    - Implement progress indicators and status updates during processing
    - Add error handling and user feedback for generation failures
    - _Requirements: 6.4, 6.5_

- [x] 12. Create comprehensive user interface views
  - [x] 12.1 Create new_from_ai.html.erb main interface
    - Implement tabbed interface with prompt and document input sections
    - Add AI credits display and usage indicators for user awareness
    - Create example prompts section with expandable details
    - Include cost estimation display and real-time feedback
    - _Requirements: 6.1, 6.2, 6.5_

  - [x] 12.2 Implement document upload interface
    - Create drag-and-drop file upload area with visual feedback
    - Add supported file format indicators and validation messages
    - Implement file info display with size and type validation
    - Add progress indicators for file processing
    - _Requirements: 6.3, 6.6_

  - [x] 12.3 Create form generation results interface
    - Implement form preview functionality with editing options
    - Add generation summary with cost, complexity, and recommendations
    - Create success/error message handling with actionable feedback
    - Include navigation to form editing interface
    - _Requirements: 6.5, 6.7_

- [x] 13. Implement routing and controller integration
  - [x] 13.1 Add AI form generation routes
    - Create new_from_ai_forms_path route for creation interface
    - Add generate_from_ai_forms_path route for processing requests
    - Configure proper HTTP methods and parameter handling
    - _Requirements: 10.1, 10.2_

  - [x] 13.2 Implement controller actions for AI generation
    - Create new_from_ai action with proper authentication and authorization
    - Implement generate_from_ai action with workflow delegation
    - Add multipart form handling for document uploads
    - Include proper error handling and user feedback
    - _Requirements: 10.3, 10.4, 10.6, 10.7_

  - [x] 13.3 Add workflow integration in controller
    - Implement Forms::AiFormGenerationWorkflow invocation
    - Add proper parameter passing and validation
    - Include success/failure handling with appropriate redirects
    - Add error message preservation and user input retention
    - _Requirements: 10.5, 10.6, 10.7_

- [x] 14. Create comprehensive test suite
  - [x] 14.1 Write unit tests for all workflow tasks
    - Test validate_and_prepare_content with various input scenarios
    - Test AI credit validation and limit enforcement
    - Test content analysis LLM task with mock responses
    - Test form generation LLM task with validation scenarios
    - _Requirements: All requirements - comprehensive coverage_

  - [x] 14.2 Write integration tests for complete workflow
    - Test end-to-end form generation from prompt input
    - Test document upload and processing integration
    - Test database transaction integrity and rollback scenarios
    - Test AI feature configuration and form optimization
    - _Requirements: All requirements - integration coverage_

  - [x] 14.3 Write system tests for user interface
    - Test complete user journey from input to form creation
    - Test Stimulus controller interactions and state management
    - Test file upload functionality with various formats
    - Test error handling and recovery scenarios
    - _Requirements: 6.1-6.7, 10.1-
    .7_

- [x] 15. Implement error handling and monitoring
  - [x] 15.1 Add comprehensive error logging and tracking
    - Implement structured error logging for all workflow failures
    - Add AI cost tracking and usage analytics
    - Create monitoring for LLM API performance and reliability
    - Add user behavior tracking for optimization insights
    - _Requirements: 9.1-9.7_

  - [x] 15.2 Implement user-friendly error messages
    - Create specific error messages for each failure scenario
    - Add actionable guidance for error recovery
    - Implement retry mechanisms with user control
    - Add escalation paths for persistent failures
    - _Requirements: 9.1-9.7_

- [x] 16. Performance optimization and caching
  - [x] 16.1 Implement caching strategies for AI operations
    - Add content analysis result caching for similar inputs
    - Implement form template caching for common patterns
    - Create intelligent cache invalidation and warming
    - _Requirements: Performance and scalability_

  - [x] 16.2 Optimize database queries and transactions
    - Add proper indexing for AI-related queries
    - Optimize form creation batch operations
    - Implement connection pooling for high concurrency
    - _Requirements: Performance and scalability_

- [x] 17. Security implementation and validation
  - [x] 17.1 Implement input validation and sanitization
    - Add comprehensive file upload security validation
    - Implement content sanitization for AI processing
    - Add rate limiting for AI generation requests
    - Create audit logging for all AI operations
    - _Requirements: Security considerations_

  - [x] 17.2 Add AI model security measures
    - Implement prompt injection attack prevention
    - Add content filtering for inappropriate material
    - Create secure API key management and rotation
    - Add usage monitoring and anomaly detection
    - _Requirements: Security considerations_
