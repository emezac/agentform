# Requirements Document

## Introduction

This specification addresses the implementation of a configurable trial period system for AgentForm users. The trial period should be configurable via environment variables and users should be able to see how many days remain in their trial period in the Subscription Management interface.

## Requirements

### Requirement 1: Configurable Trial Period

**User Story:** As a system administrator, I want to configure the trial period duration via environment variables, so that I can adjust the trial length without code changes.

#### Acceptance Criteria

1. WHEN the system starts THEN it SHALL read the trial period from environment variable `TRIAL_PERIOD_DAYS`
2. WHEN no environment variable is set THEN the system SHALL use a default value of 14 days
3. WHEN the trial period is set to 0 THEN users SHALL have no trial period and must pay immediately
4. WHEN the trial period is configured THEN it SHALL accept any positive integer value in days

### Requirement 2: Trial Period Tracking

**User Story:** As a user in trial period, I want to know how many days remain in my trial, so that I can plan when to upgrade to a paid subscription.

#### Acceptance Criteria

1. WHEN a user registers THEN the system SHALL set their trial_ends_at date based on the configured trial period
2. WHEN a user is in trial status THEN the system SHALL calculate remaining trial days accurately
3. WHEN a user's trial expires THEN the system SHALL update their status appropriately
4. WHEN calculating remaining days THEN the system SHALL handle timezone differences correctly

### Requirement 3: Subscription Management Display

**User Story:** As a user, I want to see my remaining trial days in the Subscription Management page, so that I know when I need to upgrade.

#### Acceptance Criteria

1. WHEN a user with trial status visits Subscription Management THEN they SHALL see remaining trial days displayed prominently
2. WHEN trial days are 3 or fewer THEN the system SHALL display an urgent warning message
3. WHEN trial days are 7 or fewer THEN the system SHALL display a warning message
4. WHEN trial has expired THEN the system SHALL display an expired message with upgrade prompt

### Requirement 4: Database Schema Updates

**User Story:** As a developer, I want the user model to track trial expiration dates, so that the system can accurately determine trial status.

#### Acceptance Criteria

1. WHEN creating the migration THEN it SHALL add trial_ends_at datetime field to users table
2. WHEN a user registers THEN their trial_ends_at SHALL be set to created_at + trial_period_days
3. WHEN updating existing users THEN their trial_ends_at SHALL be calculated from their created_at date
4. WHEN trial_ends_at is null THEN the system SHALL handle it gracefully

### Requirement 5: User Model Methods

**User Story:** As a developer, I want convenient methods to check trial status, so that I can easily implement trial-related features.

#### Acceptance Criteria

1. WHEN calling user.trial_days_remaining THEN it SHALL return the number of days left in trial
2. WHEN calling user.trial_expired? THEN it SHALL return true if trial has ended
3. WHEN calling user.trial_expires_soon? THEN it SHALL return true if trial expires within 7 days
4. WHEN calling user.trial_expires_today? THEN it SHALL return true if trial expires today

### Requirement 6: Environment Configuration

**User Story:** As a system administrator, I want to easily configure trial periods for different environments, so that I can have different settings for development, staging, and production.

#### Acceptance Criteria

1. WHEN in development environment THEN the default trial period SHALL be configurable
2. WHEN in production environment THEN the trial period SHALL be read from secure environment variables
3. WHEN the environment variable is invalid THEN the system SHALL log a warning and use default value
4. WHEN the configuration changes THEN it SHALL take effect for new user registrations only