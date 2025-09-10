# Requirements Document

## Introduction

This feature implements a comprehensive superadmin dashboard system for AgentForm that includes user management and discount code functionality. The system allows superadmins to manage all platform users (create, edit, suspend, delete) and create promotional discount codes that new users can apply during their first subscription purchase. The feature includes a complete admin interface with user administration and discount code management integrated with the existing subscription system.

## Requirements

### Requirement 1: Superadmin Dashboard Access

**User Story:** As a superadmin, I want to access a dedicated admin dashboard so that I can manage the platform's administrative functions including discount codes.

#### Acceptance Criteria

1. WHEN a superadmin logs in THEN the system SHALL display an "Admin Dashboard" link in the navigation
2. WHEN a superadmin accesses `/admin/dashboard` THEN the system SHALL display the admin dashboard with management sections
3. WHEN a non-superadmin user attempts to access admin routes THEN the system SHALL redirect them with an unauthorized error
4. IF a user has role 'superadmin' THEN the system SHALL grant access to all admin functionality
5. WHEN the admin dashboard loads THEN the system SHALL display sections for user management, subscription overview, and discount code management

### Requirement 2: User Management System

**User Story:** As a superadmin, I want to manage all users in the system so that I can handle user accounts, subscriptions, and access levels.

#### Acceptance Criteria

1. WHEN a superadmin accesses the user management section THEN the system SHALL display a paginated list of all users with search and filter capabilities
2. WHEN a superadmin views the user list THEN the system SHALL display user email, name, role, subscription tier, registration date, and last activity
3. WHEN a superadmin clicks "View User" THEN the system SHALL display detailed user information including:
   - Personal information (name, email, registration date)
   - Subscription details (tier, status, payment history)
   - Usage statistics (forms created, responses received)
   - Account status and activity logs
4. WHEN a superadmin clicks "Edit User" THEN the system SHALL allow modification of:
   - User role (user, admin, superadmin)
   - Subscription tier (freemium, premium)
   - Account status (active, suspended)
   - Personal information (name, email)
5. WHEN a superadmin changes a user's subscription tier THEN the system SHALL update the user's access permissions immediately
6. WHEN a superadmin suspends a user account THEN the system SHALL prevent the user from logging in and display appropriate message
7. WHEN a superadmin creates a new user THEN the system SHALL send an invitation email with temporary password
8. WHEN a superadmin deletes a user THEN the system SHALL prompt for confirmation and optionally transfer or delete user's forms
9. WHEN a superadmin searches users THEN the system SHALL allow search by email, name, or subscription status
10. WHEN a superadmin filters users THEN the system SHALL allow filtering by role, subscription tier, registration date, and activity status

### Requirement 3: Discount Code Creation and Management

**User Story:** As a superadmin, I want to create and manage discount codes so that I can offer promotional pricing to new subscribers.

#### Acceptance Criteria

1. WHEN a superadmin accesses the discount codes section THEN the system SHALL display a list of existing discount codes with their details
2. WHEN a superadmin clicks "Create New Discount Code" THEN the system SHALL display a form with the following fields:
   - Code name (alphanumeric, unique)
   - Discount percentage (1-99%)
   - Maximum usage count
   - Expiration date (optional)
   - Active/Inactive status
3. WHEN a superadmin submits a valid discount code form THEN the system SHALL create the discount code and display a success message
4. WHEN a superadmin attempts to create a duplicate code name THEN the system SHALL display an error message
5. WHEN a superadmin views the discount codes list THEN the system SHALL display code name, discount percentage, usage count, max usage, expiration date, and status
6. WHEN a superadmin clicks "Edit" on a discount code THEN the system SHALL allow modification of all fields except the code name
7. WHEN a superadmin clicks "Deactivate" on a discount code THEN the system SHALL set the code to inactive status
8. WHEN a superadmin clicks "Delete" on a discount code THEN the system SHALL prompt for confirmation and remove the code if confirmed

### Requirement 4: Discount Code Application During Subscription

**User Story:** As a new user, I want to apply a discount code during subscription signup so that I can receive promotional pricing on my first subscription.

#### Acceptance Criteria

1. WHEN a user accesses the subscription signup page THEN the system SHALL display an optional "Discount Code" input field
2. WHEN a user enters a discount code and clicks "Apply" THEN the system SHALL validate the code and display the discount amount
3. WHEN a user applies a valid discount code THEN the system SHALL update the displayed subscription price to reflect the discount
4. WHEN a user applies an invalid discount code THEN the system SHALL display an error message "Invalid or expired discount code"
5. WHEN a user applies a discount code that has reached maximum usage THEN the system SHALL display an error message "This discount code is no longer available"
6. WHEN a user applies a discount code that has expired THEN the system SHALL display an error message "This discount code has expired"
7. WHEN a user completes subscription with a discount code THEN the system SHALL apply the discount to the Stripe checkout session
8. WHEN a user has previously used any discount code THEN the system SHALL not allow application of any new discount codes

### Requirement 5: Discount Code Usage Tracking

**User Story:** As a superadmin, I want to track discount code usage so that I can monitor the effectiveness of promotional campaigns.

#### Acceptance Criteria

1. WHEN a user successfully applies a discount code THEN the system SHALL increment the usage count for that code
2. WHEN a user completes a subscription with a discount code THEN the system SHALL record the usage with user details and timestamp
3. WHEN a superadmin views discount code details THEN the system SHALL display usage statistics including:
   - Total uses
   - Remaining uses (if max usage is set)
   - List of users who used the code
   - Revenue impact (total discount amount given)
4. WHEN a discount code reaches maximum usage THEN the system SHALL automatically set it to inactive
5. WHEN a discount code expires THEN the system SHALL automatically set it to inactive

### Requirement 6: User Discount Code Eligibility

**User Story:** As a system, I want to ensure discount codes are only used once per user so that promotional offers are not abused.

#### Acceptance Criteria

1. WHEN a user attempts to apply a discount code THEN the system SHALL check if the user has previously used any discount code
2. WHEN a user has used a discount code before THEN the system SHALL display "Discount codes can only be used once per account"
3. WHEN a new user (never used discount codes) applies a valid code THEN the system SHALL allow the discount
4. WHEN the system processes a subscription with discount THEN the system SHALL mark the user as having used a discount code
5. IF a user's subscription fails or is cancelled THEN the system SHALL still maintain their discount code usage status

### Requirement 7: Integration with Existing Subscription System

**User Story:** As a developer, I want the discount code system to integrate seamlessly with the existing subscription management so that discounted subscriptions work correctly.

#### Acceptance Criteria

1. WHEN a user applies a discount code THEN the system SHALL integrate with SubscriptionManagementService to calculate discounted prices
2. WHEN creating a Stripe checkout session with discount THEN the system SHALL apply the discount as a Stripe coupon or direct price reduction
3. WHEN a discounted subscription is created THEN the system SHALL store the original price, discount amount, and final price
4. WHEN viewing subscription details THEN the system SHALL display if a discount was applied and the savings amount
5. WHEN a discounted subscription renews THEN the system SHALL charge the full price (discount only applies to first payment)
6. WHEN subscription management displays pricing THEN the system SHALL clearly indicate original price and discount savings

### Requirement 8: Security and Validation

**User Story:** As a system administrator, I want the discount code system to be secure and prevent abuse so that promotional offers are protected.

#### Acceptance Criteria

1. WHEN validating discount codes THEN the system SHALL check code format, expiration, usage limits, and active status
2. WHEN storing discount codes THEN the system SHALL use case-insensitive comparison for code names
3. WHEN a user attempts rapid discount code applications THEN the system SHALL implement rate limiting
4. WHEN discount codes are created THEN the system SHALL validate percentage is between 1-99%
5. WHEN discount codes are applied THEN the system SHALL log all attempts for audit purposes
6. IF suspicious discount code activity is detected THEN the system SHALL flag for admin review