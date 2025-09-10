# Implementation Plan

- [x] 1. Create trial configuration initializer
  - Create config/initializers/trial_config.rb with TrialConfig class
  - Implement trial_period_days method that reads from ENV['TRIAL_PERIOD_DAYS']
  - Add default value of 14 days and validation for invalid values
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 6.3_

- [x] 2. Create database migration for trial tracking
  - Generate migration to add trial_ends_at datetime column to users table
  - Add database index on trial_ends_at for performance
  - Include backfill logic for existing users with trialing status
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 3. Add trial management methods to User model
  - Implement trial_days_remaining method to calculate remaining days
  - Add trial_expired?, trial_expires_soon?, and trial_expires_today? methods
  - Create trial_status_message method for user-friendly messages
  - Add before_create callback to set trial_ends_at for new users
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 2.1, 2.2_

- [x] 4. Update user registration process
  - Modify user creation to set trial_ends_at based on configured trial period
  - Update subscription_status logic to handle zero trial period configuration
  - Ensure new users get appropriate trial or active status based on configuration
  - _Requirements: 2.1, 6.4_

- [x] 5. Update Subscription Management view
  - Add trial status display section for users with trialing status
  - Implement progress bar showing trial completion percentage
  - Add warning messages for trials expiring soon (3 days or fewer)
  - Display remaining days prominently with appropriate styling
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 6. Create comprehensive tests for trial functionality
  - Write unit tests for all User model trial methods
  - Create system tests for trial display in Subscription Management
  - Test configuration with different TRIAL_PERIOD_DAYS values
  - Test edge cases like expired trials and timezone handling
  - _Requirements: 2.3, 2.4_

- [x] 7. Update existing user with correct trial end date
  - Set trial_ends_at for <emezac@gmail.com> based on their created_at date
  - Verify trial calculations work correctly for the existing user
  - Test that Subscription Management shows correct remaining days
  - _Requirements: 4.3, 2.2_
