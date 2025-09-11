# Implementation Plan

- [x] 1. Create SafePagination concern module
  - Implement safe_paginate method that checks for Kaminari availability
  - Add fallback pagination using LIMIT/OFFSET when Kaminari is not available
  - Include pagination metadata methods (current_page, total_pages, total_count)
  - Add proper error logging and monitoring integration
  - _Requirements: 1.1, 1.4, 1.5, 2.1, 2.2_

- [x] 2. Add pagination configuration verification
  - Create initializer to verify Kaminari loading at application startup
  - Add logging for pagination system status
  - Include diagnostic information for troubleshooting
  - _Requirements: 2.4, 3.1, 3.2_

- [x] 3. Update FormsController to use safe pagination
  - Include SafePagination concern in FormsController
  - Replace direct .page() call with safe_paginate method
  - Maintain existing functionality for CSV downloads
  - Ensure proper parameter handling for page numbers
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 4. Create comprehensive tests for pagination functionality
  - Write unit tests for SafePagination module with and without Kaminari
  - Test controller responses with both pagination modes
  - Add integration tests for full request cycle
  - Test edge cases like invalid page numbers and empty results
  - _Requirements: 1.1, 2.1, 2.2_

- [ ] 5. Add monitoring and diagnostic tools
  - Create rake task to verify pagination configuration
  - Add Sentry integration for fallback usage tracking
  - Include performance monitoring for large datasets
  - Create diagnostic script for production troubleshooting
  - _Requirements: 2.3, 2.4, 3.3_

- [ ] 6. Deploy immediate fix to production
  - Deploy SafePagination concern and controller updates
  - Verify the fix resolves the NoMethodError in production
  - Monitor application logs for fallback usage
  - Test form responses functionality end-to-end
  - _Requirements: 1.1, 1.2, 2.1_

- [ ] 7. Investigate and fix Kaminari loading issues
  - Analyze why Kaminari is not loading properly in production
  - Check bundler configuration and gem loading order
  - Verify Kaminari initializers and configuration files
  - Test Kaminari functionality across all environments
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 8. Implement production monitoring and alerting
  - Set up metrics tracking for pagination method usage
  - Create alerts for when fallback pagination is used
  - Monitor performance impact of pagination changes
  - Add dashboard for pagination system health
  - _Requirements: 2.3, 2.4, 3.4_