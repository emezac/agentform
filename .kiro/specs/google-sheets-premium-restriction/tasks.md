# Implementation Plan

- [x] 1. Add premium validation method to User model
  - Add `can_use_google_sheets?` method that checks if user is premium
  - Use existing premium validation patterns from payment questions
  - Write simple unit test for the new method
  - _Requirements: 1.1, 1.4_

- [x] 2. Update Google Sheets integration view
  - Modify `app/views/forms/_google_sheets_integration.html.erb` to check user premium status
  - Show premium upgrade prompt for basic users instead of integration controls
  - Use existing premium upgrade component styling from payment features
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Add premium validation to Google Sheets controller
  - Add simple premium check to controller actions (create, export, etc.)
  - Return 403 error with upgrade message for basic users
  - Use existing premium validation patterns from other controllers
  - _Requirements: 3.1, 3.2_

- [x] 4. Update Google Sheets integration policy
  - Add premium check to existing Pundit policy methods
  - Follow same pattern as payment question policies
  - Write basic policy tests for premium vs basic users
  - _Requirements: 3.1, 5.1_

- [x] 5. Test the premium restriction implementation
  - Test that basic users see upgrade prompt instead of Google Sheets panel
  - Test that premium users see full Google Sheets functionality
  - Test that API calls from basic users return 403 errors
  - _Requirements: 2.1, 2.4, 3.1_
