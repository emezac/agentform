# Implementation Plan

- [x] 1. Create core payment validation services
  - Implement TemplateAnalysisService to detect payment questions in templates
  - Implement PaymentRequirementDetector utility class for payment question detection
  - Create PaymentSetupValidationService to validate user's Stripe and subscription status
  - Implement StripeConfigurationChecker utility for detailed Stripe validation
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 8.1, 8.2_

- [x] 2. Enhance existing models with payment validation methods
  - Add payment_requirements, has_payment_questions?, required_features, and setup_complexity methods to Template model
  - Add payment_setup_complete?, payment_setup_requirements, and can_publish_with_payments? methods to Form model  
  - Add payment_setup_status and calculate_setup_completion methods to User model
  - Create comprehensive unit tests for all new model methods
  - _Requirements: 1.4, 1.5, 2.4, 2.5, 5.1, 5.2, 5.3_

- [x] 3. Implement FormPublishValidationService for pre-publish checks
  - Create FormPublishValidationService with validate_payment_readiness method
  - Implement PaymentReadinessChecker utility for comprehensive readiness validation
  - Add validation for payment questions configuration and user setup
  - Create structured error responses with specific guidance for resolution
  - Write unit tests for all validation scenarios and error cases
  - _Requirements: 2.6, 2.7, 4.1, 4.2, 4.3, 8.3_

- [x] 4. Create PaymentValidationError system for structured error handling
  - Implement PaymentValidationError class with error_type, required_actions, and user_guidance attributes
  - Create PaymentValidationErrors module with predefined error types and responses
  - Add error types for STRIPE_NOT_CONFIGURED, PREMIUM_REQUIRED, and MULTIPLE_REQUIREMENTS
  - Integrate error system with existing Rails error handling patterns
  - Write tests for error generation, formatting, and handling
  - _Requirements: 4.4, 4.5, 4.6, 4.7, 9.1, 9.2_

- [x] 5. Implement SuperAgent PaymentValidationWorkflow
  - Create PaymentValidationWorkflow class extending ApplicationWorkflow
  - Implement validate_and_prepare_template task for template validation
  - Implement analyze_payment_requirements task using TemplateAnalysisService
  - Implement validate_user_setup task using PaymentSetupValidationService
  - Implement generate_user_guidance task for creating actionable guidance
  - Write workflow tests with mocked services and various input scenarios
  - _Requirements: 2.1, 2.2, 2.3, 8.4, 8.5, 8.6_

- [x] 6. Create PaymentSetupController Stimulus controller for frontend guidance
  - Implement PaymentSetupController with targets for setupChecklist, requirementItem, actionButton, statusIndicator
  - Add values for hasPaymentQuestions, stripeConfigured, isPremium, requiredFeatures
  - Implement connect(), updateSetupStatus(), showRequiredActions(), initiateSetup(), and checkSetupProgress() methods
  - Create real-time UI updates for setup status changes
  - Write JavaScript tests for controller functionality and user interactions
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 7.1, 7.2_

- [x] 7. Create TemplatePreviewController for template selection guidance
  - Implement TemplatePreviewController with targets for paymentBadge, requirementsList, setupModal
  - Add values for templateId, hasPaymentQuestions, requiredFeatures
  - Implement showPaymentRequirements(), proceedWithSetup(), and proceedWithoutSetup() methods
  - Create modal components for payment requirements display and setup guidance
  - Write tests for template preview interactions and setup initiation
  - _Requirements: 1.3, 1.4, 6.5, 6.6, 6.7_

- [x] 8. Enhance forms controller with payment validation integration
  - Update forms#publish method to use FormPublishValidationService before attempting publish
  - Integrate PaymentValidationError handling with existing error handling system
  - Add pre-publish validation checks that prevent publish attempts when requirements are missing
  - Update error responses to include structured guidance with action links
  - Modify Turbo Stream responses to show payment setup guidance instead of generic errors
  - Write controller tests for publish validation with various user setup states
  - _Requirements: 2.5, 2.6, 4.1, 4.2, 4.3, 4.4_

- [x] 9. Create template selection enhancement with payment indicators
  - Update template gallery to display payment requirement badges for templates with payment questions
  - Add filtering capability to show/hide templates based on payment requirements
  - Implement template metadata display showing required features and setup complexity
  - Create setup checklist modal that appears when selecting payment-enabled templates
  - Add educational content about payment features and setup requirements
  - Write system tests for template selection flow with payment requirements
  - _Requirements: 1.1, 1.2, 1.3, 5.4, 5.5, 6.1_

- [x] 10. Implement form editor integration with payment setup status
  - Add payment status indicator to form header showing current setup completeness
  - Create persistent notification bar for incomplete payment setup with action buttons
  - Implement real-time updates when payment setup is completed in another tab
  - Add validation when payment questions are added/removed from forms
  - Create setup progress tracking and completion percentage display
  - Write integration tests for form editor payment setup workflow
  - _Requirements: 7.3, 7.4, 7.5, 7.6, 7.7_

- [x] 11. Create background jobs for payment validation processing
  - Implement TemplatePaymentAnalysisJob for complex template analysis processing
  - Create PaymentSetupValidationJob for updating form statuses when user setup changes
  - Add appropriate job priorities and queue assignments (high priority for user-initiated actions)
  - Implement job completion notifications via Turbo Streams for real-time UI updates
  - Add error handling, retry logic with exponential backoff, and maximum retry limits
  - Write job tests including failure scenarios and retry behavior
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

- [x] 12. Implement PaymentConfigurationService for setup status management
  - Create PaymentConfigurationService with update_user_status method for tracking setup progress
  - Implement setup completion tracking and status persistence
  - Add methods for calculating setup progress and identifying next required steps
  - Create integration with existing Stripe settings and subscription management
  - Add caching for setup status to improve performance
  - Write service tests for status updates and progress tracking
  - _Requirements: 5.6, 5.7, 8.4, 8.7_

- [x] 13. Create comprehensive error handling and user guidance system
  - Implement user-friendly error messages with specific resolution steps for each error type
  - Create consistent UI components for displaying payment setup errors and guidance
  - Add contextual help and educational content about payment features and requirements
  - Implement error recovery workflows that guide users through setup completion
  - Create fallback validation for when background jobs fail
  - Write comprehensive error handling tests covering all error scenarios and recovery paths
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 6.2, 6.3, 6.4_

- [x] 14. Add analytics and monitoring for payment template usage
  - Implement event tracking for template_payment_interaction, payment_setup_started, payment_setup_completed events
  - Add tracking for payment_setup_abandoned and payment_form_published events with relevant context
  - Create payment_validation_errors tracking with error types and resolution paths
  - Implement dashboard metrics for setup completion rates and common failure points
  - Add monitoring for job processing performance and error rates
  - Write analytics tests and create monitoring dashboards for payment feature usage
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_

- [ ] 15. Create integration tests for complete payment validation workflow
  - Write end-to-end tests for template selection with payment requirements through form publishing
  - Test complete user journey from template selection to successful form publication with payment setup
  - Create tests for error scenarios and recovery workflows
  - Test integration between frontend controllers, backend services, and background jobs
  - Add performance tests for template analysis and user validation with large datasets
  - Write system tests covering all user personas and setup scenarios
  - _Requirements: All requirements - comprehensive integration testing_
