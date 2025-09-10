# Implementation Plan

- [x] 1. Remove freemium references from AdminCacheService
  - Replace 'freemium' with 'basic' in SQL queries and statistics calculations
  - Update statistics hash to use 'basic_users' instead of 'freemium_users'
  - _Requirements: 1.1, 1.2_

- [x] 2. Remove freemium references from Admin::DashboardAgent
  - Replace 'freemium' with 'basic' in SQL queries and user statistics
  - Update response hash to use 'basic' instead of 'freemium'
  - _Requirements: 4.1, 4.2_

- [x] 3. Update database constraints to remove freemium
  - Modify check constraint to only accept 'basic' and 'premium' tiers
  - Remove 'freemium' from valid subscription tier constraint
  - _Requirements: 2.1_

- [x] 4. Update seed files to use current tiers
  - Replace 'freemium' with 'basic' in db/seeds_freemium.rb
  - Replace 'freemium' with 'basic' in db/seeds_production.rb
  - _Requirements: 3.1, 3.2_

- [x] 5. Update migration files to use basic as default
  - Change default value from 'freemium' to 'basic' in migration files
  - Update migration comments to reflect current tier structure
  - _Requirements: 2.2_
