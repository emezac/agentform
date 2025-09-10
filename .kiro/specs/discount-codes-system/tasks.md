# Implementation Plan

- [x] 1. Set up database schema and models
  - Create migration for discount_codes table with proper indexes and constraints
  - Create migration for discount_code_usages table with unique constraint per user
  - Add new columns to users table (discount_code_used, suspended_at, suspended_reason)
  - _Requirements: 3.2, 4.1, 5.4, 6.4_

- [x] 1.1 Create DiscountCode model with validations
  - Implement DiscountCode model with associations and validations
  - Add scopes for active, expired, and available codes
  - Implement instance methods for availability checking and usage calculations
  - Write comprehensive unit tests for DiscountCode model
  - _Requirements: 3.2, 3.3, 5.1, 5.4_

- [x] 1.2 Create DiscountCodeUsage model with constraints
  - Implement DiscountCodeUsage model with unique user constraint
  - Add validations for amount fields and associations
  - Implement methods for calculating savings percentage
  - Write unit tests for DiscountCodeUsage model
  - _Requirements: 4.1, 5.1, 6.1, 6.4_

- [x] 1.3 Enhance User model for discount tracking
  - Add discount_code_used boolean field and suspension fields to User model
  - Implement methods to check discount eligibility
  - Add user suspension/reactivation methods
  - Write tests for new User model functionality
  - _Requirements: 2.4, 2.6, 6.1, 6.4_

- [x] 2. Create admin base infrastructure
  - Create Admin::BaseController with superadmin authorization
  - Implement admin layout with navigation and styling
  - Create admin routes namespace with proper constraints
  - Add admin navigation helpers and view components
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2.1 Implement admin authorization system
  - Create before_action filters for superadmin access control
  - Implement redirect logic for unauthorized users
  - Add admin session management and timeout handling
  - Write tests for admin authorization enforcement
  - _Requirements: 1.3, 1.4, 8.1, 8.2_

- [x] 2.2 Create admin dashboard layout and styling
  - Implement responsive admin dashboard layout following AgentForm design system
  - Create admin-specific CSS components and utilities
  - Add admin navigation with active state indicators
  - Implement breadcrumb navigation for admin sections
  - _Requirements: 1.5, 2.1, 3.1_

- [x] 3. Build user management system
  - Create Admin::UsersController with full CRUD operations
  - Implement user listing with pagination, search, and filters
  - Create user detail view with comprehensive information display
  - Add user creation, editing, suspension, and deletion functionality
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

- [x] 3.1 Implement UserManagementService for business logic
  - Create service class for user management operations
  - Implement user listing with search and filter capabilities
  - Add user creation with invitation email functionality
  - Implement user suspension and reactivation logic
  - Write comprehensive tests for UserManagementService
  - _Requirements: 2.3, 2.4, 2.6, 2.7_

- [x] 3.2 Create user management views and forms
  - Build user listing view with search, filters, and pagination
  - Create user detail view showing comprehensive user information
  - Implement user creation and editing forms with validation
  - Add user suspension modal with reason input
  - Style all views following AgentForm design system
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 3.3 Add user invitation and notification system
  - Create UserMailer for admin invitations and notifications
  - Implement invitation email templates with temporary passwords
  - Add suspension notification emails with reason
  - Create background jobs for async email delivery
  - Write tests for email functionality
  - _Requirements: 2.7, 2.6_

- [x] 4. Build discount code management system
  - Create Admin::DiscountCodesController with full CRUD operations
  - Implement discount code listing with usage statistics
  - Create discount code creation and editing forms
  - Add discount code activation/deactivation functionality
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 4.1 Implement DiscountCodeService for validation and application
  - Create service class for discount code validation logic
  - Implement discount calculation and application methods
  - Add usage recording and tracking functionality
  - Implement automatic code deactivation when limits reached
  - Write comprehensive tests for DiscountCodeService
  - _Requirements: 4.1, 4.2, 4.3, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2_

- [x] 4.2 Create discount code management views
  - Build discount code listing view with usage statistics
  - Create discount code creation form with validation
  - Implement discount code editing interface
  - Add usage details view with user list and revenue impact
  - Style all views following AgentForm design system
  - _Requirements: 3.1, 3.2, 3.5, 5.3_

- [x] 4.3 Add discount code usage tracking and analytics
  - Implement usage statistics calculation and display
  - Create revenue impact tracking and reporting
  - Add automatic code deactivation for expired/exhausted codes
  - Implement audit logging for discount code operations
  - Write tests for tracking and analytics functionality
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 8.5_

- [-] 5. Integrate discount codes with subscription system
  - Enhance SubscriptionManagementService to handle discount codes
  - Add discount code input field to subscription signup page
  - Implement real-time discount validation and price calculation
  - Integrate discount application with Stripe checkout sessions
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 5.1 Add discount code validation to subscription flow
  - Create JavaScript controller for real-time discount code validation
  - Implement AJAX endpoints for discount code checking
  - Add visual feedback for valid/invalid discount codes
  - Implement price recalculation when discount is applied
  - Write integration tests for discount validation flow
  - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 6.1, 6.2_

- [x] 5.2 Integrate discount application with Stripe
  - Modify Stripe checkout session creation to include discounts
  - Implement discount as Stripe coupon or direct price reduction
  - Add discount information to subscription metadata
  - Handle discount application in webhook processing
  - Write tests for Stripe integration with discounts
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 5.3 Implement discount usage recording and user eligibility
  - Add discount usage recording after successful subscription
  - Implement user eligibility checking (one discount per user)
  - Update user discount_code_used flag after usage
  - Add error handling for discount eligibility violations
  - Write tests for usage recording and eligibility enforcement
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 6. Create admin dashboard with statistics
  - Build main admin dashboard with key metrics and statistics
  - Implement real-time statistics for users, subscriptions, and discount codes
  - Add recent activity feed showing important admin events
  - Create quick action buttons for common admin tasks
  - _Requirements: 1.5, 2.1, 3.1, 5.3_

- [x] 6.1 Implement Admin::DashboardAgent for statistics
  - Create agent class for gathering dashboard statistics
  - Implement methods for user, subscription, and discount code metrics
  - Add recent activity tracking and display
  - Optimize queries for dashboard performance
  - Write tests for dashboard statistics accuracy
  - _Requirements: 1.5, 5.3_

- [x] 6.2 Create dashboard views and components
  - Build responsive dashboard layout with metric cards
  - Implement charts and graphs for usage trends
  - Create recent activity timeline component
  - Add quick navigation to management sections
  - Style dashboard following AgentForm design system
  - _Requirements: 1.5, 2.1, 3.1_

- [x] 7. Implement security and validation measures
  - Add rate limiting for discount code validation attempts
  - Implement audit logging for all admin operations
  - Add CSRF protection for admin forms
  - Implement secure session management for admin users
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [x] 7.1 Add comprehensive input validation and sanitization
  - Implement strong parameter filtering for all admin controllers
  - Add input sanitization for discount code creation
  - Implement validation for user management operations
  - Add protection against SQL injection and XSS attacks
  - Write security tests for input validation
  - _Requirements: 8.3, 8.4, 8.5_

- [x] 7.2 Implement audit logging and monitoring
  - Create audit log system for all admin operations
  - Add logging for discount code creation, usage, and modifications
  - Implement user management operation logging
  - Create admin activity monitoring and alerting
  - Write tests for audit logging functionality
  - _Requirements: 8.5, 8.6_

- [x] 8. Add comprehensive testing suite
  - Write unit tests for all models, services, and controllers
  - Create integration tests for complete admin workflows
  - Implement system tests for end-to-end admin functionality
  - Add security tests for authorization and input validation
  - _Requirements: All requirements coverage_

- [x] 8.1 Write model and service unit tests
  - Create comprehensive tests for DiscountCode and DiscountCodeUsage models
  - Write tests for DiscountCodeService validation and application logic
  - Add tests for UserManagementService operations
  - Implement tests for enhanced User model functionality
  - Ensure 95%+ test coverage for all business logic
  - _Requirements: 3.2, 3.3, 4.1, 5.1, 6.1_

- [x] 8.2 Create controller and integration tests
  - Write tests for all admin controllers with authorization scenarios
  - Create integration tests for discount code application flow
  - Add tests for user management operations and workflows
  - Implement tests for admin dashboard functionality
  - Test error handling and edge cases
  - _Requirements: 1.1, 1.3, 2.1, 3.1, 4.1_

- [x] 8.3 Implement system and security tests
  - Create end-to-end tests for complete admin workflows
  - Add security tests for admin authorization enforcement
  - Implement tests for discount code abuse prevention
  - Create performance tests for admin dashboard and user listing
  - Test rate limiting and audit logging functionality
  - _Requirements: 8.1, 8.2, 8.3, 8.5, 8.6_

- [x] 9. Performance optimization and deployment preparation
  - Optimize database queries with proper indexing
  - Implement caching for frequently accessed admin data
  - Add background job processing for heavy admin operations
  - Optimize admin interface loading times and responsiveness
  - _Requirements: Performance considerations from design_

- [x] 9.1 Database and query optimization
  - Add database indexes for admin query performance
  - Optimize user listing queries with includes and pagination
  - Implement efficient discount code lookup and validation
  - Add database constraints for data integrity
  - Write performance tests for critical admin operations
  - _Requirements: Performance and data integrity_

- [x] 9.2 Implement caching and background processing
  - Add Redis caching for admin dashboard statistics
  - Implement background jobs for email notifications
  - Cache frequently accessed discount code data
  - Add background cleanup jobs for expired codes
  - Write tests for caching and background job functionality
  - _Requirements: Performance and scalability_
