# Requirements Document

## Introduction

This specification addresses the complete migration from the deprecated 'freemium' subscription tier to the current 'basic' tier across the entire AgentForm application. While the User model has been updated to use 'basic' as the default, there are still references to 'freemium' in services, agents, database constraints, and seed files that need to be updated for consistency.

## Requirements

### Requirement 1: Update Admin Services and Analytics

**User Story:** As a system administrator, I want the admin dashboard and analytics to accurately reflect the current subscription tiers, so that I can make informed business decisions based on correct data.

#### Acceptance Criteria

1. WHEN the admin dashboard loads THEN the system SHALL count users with 'basic' tier instead of 'freemium'
2. WHEN generating user statistics THEN the system SHALL use 'basic' in SQL queries instead of 'freemium'
3. WHEN calculating subscription analytics THEN the system SHALL return 'basic' counts instead of 'freemium' counts
4. WHEN caching admin statistics THEN the system SHALL store 'basic' tier data instead of 'freemium'

### Requirement 2: Update Database Constraints and Migrations

**User Story:** As a database administrator, I want the database constraints to reflect the current subscription tiers, so that data integrity is maintained with the correct tier values.

#### Acceptance Criteria

1. WHEN validating subscription_tier values THEN the system SHALL accept 'basic' instead of 'freemium' in check constraints
2. WHEN running database migrations THEN the system SHALL use 'basic' as the default value instead of 'freemium'
3. WHEN creating new migration files THEN the system SHALL reference 'basic' tier instead of 'freemium'
4. WHEN rolling back migrations THEN the system SHALL handle the freemium-to-basic transition correctly

### Requirement 3: Update Seed Files and Test Data

**User Story:** As a developer, I want the seed files and test data to use current subscription tiers, so that development and testing environments reflect the production data structure.

#### Acceptance Criteria

1. WHEN running database seeds THEN the system SHALL create users with 'basic' tier instead of 'freemium'
2. WHEN generating test data THEN the system SHALL use 'basic' tier for sample users
3. WHEN creating development accounts THEN the system SHALL assign 'basic' tier by default
4. WHEN documenting test credentials THEN the system SHALL reference 'basic' tier users

### Requirement 4: Update Admin Agents and Dashboard Logic

**User Story:** As an admin user, I want the admin dashboard to display accurate subscription statistics, so that I can monitor user distribution across current subscription tiers.

#### Acceptance Criteria

1. WHEN the dashboard agent calculates user statistics THEN it SHALL count 'basic' users instead of 'freemium'
2. WHEN generating subscription reports THEN the system SHALL include 'basic' tier in analytics
3. WHEN displaying user distribution THEN the system SHALL show 'basic' tier percentages
4. WHEN calculating conversion rates THEN the system SHALL use 'basic' as the starting tier

### Requirement 5: Maintain Backward Compatibility

**User Story:** As a system maintainer, I want to ensure that existing data with 'freemium' values continues to work, so that no data is lost during the migration.

#### Acceptance Criteria

1. WHEN encountering existing 'freemium' data THEN the system SHALL handle it gracefully without errors
2. WHEN displaying user information THEN the system SHALL treat 'freemium' users as 'basic' users functionally
3. WHEN validating subscription tiers THEN the system SHALL accept both 'freemium' and 'basic' during transition period
4. WHEN generating reports THEN the system SHALL combine 'freemium' and 'basic' counts as appropriate

### Requirement 6: Update Documentation and Comments

**User Story:** As a developer, I want the code documentation to reflect the current subscription tier structure, so that future development work uses the correct tier names.

#### Acceptance Criteria

1. WHEN reading code comments THEN they SHALL reference 'basic' tier instead of 'freemium'
2. WHEN viewing migration comments THEN they SHALL explain the freemium-to-basic transition
3. WHEN accessing seed file documentation THEN it SHALL show 'basic' tier examples
4. WHEN reviewing service documentation THEN it SHALL use current tier terminology