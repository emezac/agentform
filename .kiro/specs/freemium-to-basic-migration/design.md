# Design Document

## Overview

This design outlines the systematic approach to complete the migration from 'freemium' to 'basic' subscription tier across the AgentForm application. The migration involves updating services, agents, database constraints, seed files, and maintaining backward compatibility while ensuring data integrity.

## Architecture

### Migration Strategy

The migration follows a **gradual replacement approach** with backward compatibility:

1. **Phase 1**: Update service layer (AdminCacheService, DashboardAgent)
2. **Phase 2**: Update database constraints and migrations
3. **Phase 3**: Update seed files and test data
4. **Phase 4**: Clean up documentation and comments
5. **Phase 5**: Maintain compatibility layer for existing data

### Affected Components

```
┌─────────────────────────────────────────────────────────────┐
│                    AgentForm Application                     │
├─────────────────────────────────────────────────────────────┤
│  Services Layer                                             │
│  ├── AdminCacheService (SQL queries, statistics)           │
│  ├── Admin::DashboardAgent (user analytics)                │
│  └── Other services (future-proofing)                      │
├─────────────────────────────────────────────────────────────┤
│  Database Layer                                             │
│  ├── Migration files (defaults, constraints)               │
│  ├── Check constraints (valid tier validation)             │
│  └── Schema documentation                                   │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                 │
│  ├── Seed files (development data)                         │
│  ├── Test factories (spec data)                            │
│  └── Sample user creation                                   │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. AdminCacheService Updates

**Current State:**
- SQL queries count `subscription_tier = 'freemium'`
- Statistics include `freemium_users` field
- Cache keys reference freemium data

**Target State:**
- SQL queries count `subscription_tier = 'basic'`
- Statistics include `basic_users` field
- Maintain backward compatibility for existing freemium users

**Interface Changes:**
```ruby
# Before
{
  freemium: stats['freemium_users'].to_i,
  # ...
}

# After
{
  basic: stats['basic_users'].to_i,
  # Optionally include freemium for compatibility
  freemium: 0, # Deprecated, always 0 for new queries
  # ...
}
```

### 2. Admin::DashboardAgent Updates

**Current State:**
- Dashboard queries include freemium counts
- User statistics separate freemium from other tiers
- Conversion calculations include freemium as base tier

**Target State:**
- Dashboard queries include basic counts
- User statistics treat basic as the entry tier
- Conversion calculations use basic as starting point

### 3. Database Constraint Updates

**Current State:**
```sql
subscription_tier IN ('freemium', 'basic', 'premium')
```

**Target State:**
```sql
subscription_tier IN ('basic', 'premium', 'pro')
-- Note: Keep freemium temporarily for existing data
subscription_tier IN ('freemium', 'basic', 'premium', 'pro')
```

### 4. Migration File Updates

**Strategy:**
- Update default values in new migrations
- Add comments explaining the freemium deprecation
- Ensure rollback compatibility

## Data Models

### Subscription Tier Hierarchy

```
Current Hierarchy (Target):
┌─────────────────────────────────────┐
│  Subscription Tiers (Active)        │
├─────────────────────────────────────┤
│  basic (0) - Entry level           │
│  premium (2) - Full features        │
│  pro (3) - Advanced features        │
└─────────────────────────────────────┘

Legacy Compatibility:
┌─────────────────────────────────────┐
│  Deprecated Tiers                   │
├─────────────────────────────────────┤
│  freemium (0) - Treat as basic     │
└─────────────────────────────────────┘
```

### Data Transformation Logic

```ruby
# Service layer transformation
def normalize_subscription_tier(tier)
  case tier
  when 'freemium'
    'basic'  # Treat freemium as basic
  else
    tier
  end
end

# Query aggregation
def combined_basic_users_count
  User.where(subscription_tier: ['basic', 'freemium']).count
end
```

## Error Handling

### Migration Safety

1. **Constraint Updates**: Use `IF EXISTS` clauses when dropping old constraints
2. **Data Validation**: Verify no data loss during constraint updates
3. **Rollback Strategy**: Maintain ability to rollback constraint changes

### Service Layer Error Handling

1. **SQL Query Errors**: Handle cases where freemium data exists
2. **Cache Invalidation**: Clear relevant caches after updates
3. **Statistics Calculation**: Handle division by zero in percentage calculations

### Backward Compatibility

1. **API Responses**: Continue to accept freemium in API calls
2. **Database Queries**: Handle both freemium and basic in WHERE clauses
3. **User Interface**: Display freemium users as basic users

## Testing Strategy

### Unit Tests

1. **Service Tests**: Verify statistics calculations with both tier types
2. **Agent Tests**: Ensure dashboard data accuracy
3. **Migration Tests**: Verify constraint updates work correctly

### Integration Tests

1. **Admin Dashboard**: Verify correct user counts display
2. **Statistics API**: Ensure API returns correct tier distributions
3. **Database Integrity**: Verify constraints work with new data

### Data Migration Tests

1. **Seed File Tests**: Verify development data uses correct tiers
2. **Factory Tests**: Ensure test factories create basic users
3. **Constraint Tests**: Verify database accepts valid tier values

## Implementation Phases

### Phase 1: Service Layer Updates
- Update AdminCacheService SQL queries
- Update Admin::DashboardAgent statistics
- Maintain backward compatibility in responses

### Phase 2: Database Layer Updates
- Update check constraints to include basic
- Update migration file defaults
- Add migration comments for clarity

### Phase 3: Data Layer Updates
- Update seed files to use basic tier
- Update test factories and sample data
- Update documentation examples

### Phase 4: Cleanup and Documentation
- Update code comments and documentation
- Add migration notes explaining the change
- Update any remaining references

### Phase 5: Monitoring and Validation
- Verify no freemium users remain in production
- Monitor admin dashboard for correct statistics
- Validate API responses show correct tier distributions

## Security Considerations

1. **Data Integrity**: Ensure no user data is lost during migration
2. **Access Control**: Maintain proper tier-based access controls
3. **Audit Trail**: Log any tier changes for compliance

## Performance Considerations

1. **Query Optimization**: Update indexes if needed for new tier queries
2. **Cache Strategy**: Update cache keys to reflect new tier structure
3. **Statistics Calculation**: Optimize queries to handle both tier types efficiently

## Rollback Strategy

1. **Database Constraints**: Maintain ability to rollback constraint changes
2. **Service Logic**: Keep compatibility code until migration is complete
3. **Data Recovery**: Ensure no permanent data changes during migration