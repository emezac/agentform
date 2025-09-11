# Design Document

## Overview

This design addresses the critical production issue where Kaminari pagination is causing NoMethodError exceptions. The solution implements a resilient pagination system that gracefully degrades when Kaminari is not available, while also ensuring proper Kaminari configuration for optimal performance.

## Architecture

### Current Problem Analysis

The error occurs because:
1. The `page` method is called on ActiveRecord relations
2. Kaminari gem should provide this method but it's not available at runtime
3. This suggests either a loading issue or missing configuration in production

### Solution Approach

We'll implement a multi-layered approach:

1. **Immediate Fix**: Implement a safe pagination helper that checks for Kaminari availability
2. **Fallback Mechanism**: Provide basic limiting when pagination is unavailable  
3. **Configuration Verification**: Ensure Kaminari is properly loaded in all environments
4. **Monitoring**: Add logging to detect when fallbacks are used

## Components and Interfaces

### 1. SafePagination Module

A concern that can be included in controllers to provide safe pagination:

```ruby
module SafePagination
  extend ActiveSupport::Concern
  
  def safe_paginate(relation, page: nil, per_page: 20)
    if defined?(Kaminari) && relation.respond_to?(:page)
      relation.page(page).per(per_page)
    else
      # Fallback: limit results and add pagination info
      offset = ((page&.to_i || 1) - 1) * per_page
      limited_relation = relation.limit(per_page).offset([offset, 0].max)
      add_pagination_metadata(limited_relation, relation, page, per_page)
    end
  end
  
  private
  
  def add_pagination_metadata(limited_relation, original_relation, page, per_page)
    # Add basic pagination methods to the relation
    limited_relation.define_singleton_method(:current_page) { page&.to_i || 1 }
    limited_relation.define_singleton_method(:total_pages) do
      (original_relation.count.to_f / per_page).ceil
    end
    limited_relation.define_singleton_method(:total_count) { original_relation.count }
    limited_relation
  end
end
```

### 2. Kaminari Configuration Verification

Add an initializer to verify Kaminari is properly loaded:

```ruby
# config/initializers/pagination_config.rb
Rails.application.config.after_initialize do
  if defined?(Kaminari)
    Rails.logger.info "✅ Kaminari pagination is available"
  else
    Rails.logger.warn "⚠️  Kaminari pagination is not available - using fallback"
  end
end
```

### 3. Controller Updates

Update the FormsController to use safe pagination:

```ruby
class FormsController < ApplicationController
  include SafePagination
  
  def responses
    authorize @form, :responses?
    
    @responses = safe_paginate(
      @form.form_responses
           .includes(:question_responses, :dynamic_questions)
           .order(created_at: :desc),
      page: params[:page],
      per_page: 20
    )
    
    respond_to do |format|
      format.html
      format.csv { download_responses_csv }
    end
  end
end
```

## Data Models

No changes to data models are required. The solution works with existing ActiveRecord relations.

## Error Handling

### Graceful Degradation Strategy

1. **Primary**: Use Kaminari when available
2. **Fallback**: Use LIMIT/OFFSET with basic pagination metadata
3. **Emergency**: Show all results with a warning (for small datasets only)

### Error Logging

```ruby
def safe_paginate(relation, page: nil, per_page: 20)
  if defined?(Kaminari) && relation.respond_to?(:page)
    relation.page(page).per(per_page)
  else
    Rails.logger.warn "Pagination fallback used - Kaminari not available"
    Sentry.capture_message("Pagination fallback used", level: :warning) if defined?(Sentry)
    # ... fallback implementation
  end
end
```

## Testing Strategy

### Unit Tests

1. Test SafePagination module with and without Kaminari
2. Test controller responses with both pagination modes
3. Test edge cases (invalid page numbers, empty results)

### Integration Tests

1. Test full request cycle with pagination
2. Test CSV download functionality is not affected
3. Test performance with large datasets

### Production Verification

1. Add monitoring to track when fallbacks are used
2. Performance monitoring for large response sets
3. User experience testing for pagination UI

## Performance Considerations

### With Kaminari (Optimal)
- Efficient database queries with LIMIT/OFFSET
- Lazy loading of results
- Built-in caching support

### Fallback Mode (Acceptable)
- Still uses LIMIT/OFFSET for database efficiency
- Slightly more overhead for count queries
- No built-in caching but still performant

### Emergency Mode (Last Resort)
- Only for small datasets (< 100 records)
- Shows warning to users
- Automatic upgrade when Kaminari becomes available

## Deployment Strategy

### Phase 1: Immediate Fix
1. Deploy SafePagination module
2. Update FormsController to use safe pagination
3. Add configuration verification

### Phase 2: Kaminari Investigation
1. Investigate why Kaminari isn't loading in production
2. Fix any bundler or configuration issues
3. Verify proper loading across all environments

### Phase 3: Monitoring
1. Add metrics for pagination usage
2. Monitor performance impact
3. Set up alerts for fallback usage

## Rollback Plan

If issues arise:
1. The fallback mechanism ensures the site remains functional
2. Can temporarily disable pagination entirely if needed
3. Original error state is avoided through safe method checking