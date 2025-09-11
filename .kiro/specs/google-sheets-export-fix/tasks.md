# Implementation Plan

- [ ] 1. Enhance data loading in GoogleSheetsService
  - Modify `load_responses_for_export` method to properly include associations
  - Ensure question_responses and form_questions are loaded with proper includes
  - Add validation to check that responses contain actual data
  - Filter responses to only include those with status 'completed' or 'partial'
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 2. Fix answer formatting logic
  - Rewrite `format_answer_value` method with robust data extraction
  - Add fallback mechanisms for different answer_data structures (Hash, String, Array)
  - Implement proper handling for each question type (text, multiple_choice, rating, etc.)
  - Add error handling to prevent formatting failures from breaking export
  - _Requirements: 1.4, 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 3. Add comprehensive logging and debugging
  - Enhance logging in `export_all_responses` method to track each step
  - Add detailed logging in `build_response_row` to show data processing
  - Log answer_data structure and formatted values for debugging
  - Add performance logging to track export duration and data volume
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 4. Implement data validation and error recovery
  - Add validation to ensure form has questions before export
  - Validate that responses contain actual answer data
  - Implement graceful handling of empty or malformed responses
  - Add error recovery mechanisms to continue export even if individual responses fail
  - _Requirements: 1.5, 2.2, 3.4_

- [ ] 5. Create diagnostic tools for troubleshooting
  - Create rake task to test Google Sheets export functionality
  - Add method to validate export data before sending to Google Sheets
  - Implement dry-run mode to test export without actually writing to spreadsheet
  - Add diagnostic endpoint to check export status and data integrity
  - _Requirements: 2.3, 2.4_

- [ ] 6. Write comprehensive tests for export functionality
  - Create unit tests for `format_answer_value` with different question types
  - Test `build_response_row` with various response scenarios (complete, partial, empty)
  - Add integration tests for full export process with real form data
  - Test error handling and fallback mechanisms
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 7. Optimize performance for large datasets
  - Implement batch processing for large response sets
  - Add memory management to prevent issues with large exports
  - Optimize database queries to avoid N+1 problems
  - Add progress tracking for long-running exports
  - _Requirements: 1.2, 2.4_

- [ ] 8. Deploy and monitor the fix
  - Deploy enhanced logging first to confirm issue diagnosis
  - Deploy the fix with comprehensive error handling
  - Monitor export success rates and performance metrics
  - Add user-facing feedback for export status and completion
  - _Requirements: 1.5, 2.1, 2.4_