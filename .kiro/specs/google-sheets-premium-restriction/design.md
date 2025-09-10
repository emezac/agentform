# Design Document

## Overview

This design implements premium plan restrictions for Google Sheets integration by leveraging the existing subscription validation patterns used for payment questions and other premium features. The solution ensures consistent user experience while maintaining backward compatibility for existing integrations.

## Architecture

The premium restriction system will be implemented across multiple layers:

1. **Authorization Layer**: Pundit policies enhanced with premium validation
2. **Controller Layer**: Premium checks before processing requests
3. **Service Layer**: Subscription validation in Google Sheets service
4. **UI Layer**: Conditional rendering based on subscription status
5. **Background Jobs**: Premium validation before sync operations

## Components and Interfaces

### 1. User Subscription Validation

**Enhanced User Model Methods:**
```ruby
# app/models/user.rb
def can_use_google_sheets?
  premium? || pro? || admin?
end

def google_sheets_restriction_reason
  return nil if can_use_google_sheets?
  'Google Sheets integration requires a Premium subscription'
end
```

**Subscription Status Checker:**
```ruby
# app/services/subscription_feature_checker.rb
class SubscriptionFeatureChecker
  def self.google_sheets_available?(user)
    user&.can_use_google_sheets?
  end
  
  def self.google_sheets_restriction_info(user)
    return { available: true } if google_sheets_available?(user)
    
    {
      available: false,
      reason: user&.google_sheets_restriction_reason || 'Authentication required',
      upgrade_url: '/subscription_management',
      required_plan: 'Premium'
    }
  end
end
```

### 2. Enhanced Authorization Policies

**Updated GoogleSheetsIntegrationPolicy:**
```ruby
# app/policies/google_sheets_integration_policy.rb
class GoogleSheetsIntegrationPolicy < ApplicationPolicy
  def show?
    user_owns_form? && user_has_premium_access?
  end

  def create?
    user_owns_form? && user_has_premium_access?
  end

  def export?
    user_owns_form? && user_has_premium_access?
  end

  private

  def user_has_premium_access?
    user&.can_use_google_sheets?
  end
end
```

### 3. Controller Premium Validation

**Enhanced GoogleSheetsController:**
```ruby
# app/controllers/integrations/google_sheets_controller.rb
class Integrations::GoogleSheetsController < ApplicationController
  before_action :validate_premium_access, except: [:show]
  
  private
  
  def validate_premium_access
    unless current_user.can_use_google_sheets?
      restriction_info = SubscriptionFeatureChecker.google_sheets_restriction_info(current_user)
      render json: { 
        error: 'Premium subscription required',
        restriction: restriction_info
      }, status: :forbidden
      return
    end
  end
end
```

### 4. Service Layer Validation

**Enhanced GoogleSheetsService:**
```ruby
# app/services/integrations/google_sheets_service.rb
class Integrations::GoogleSheetsService < ApplicationService
  def initialize(form, integration = nil)
    @form = form
    @integration = integration || form.google_sheets_integration
    validate_premium_access!
    # ... existing initialization
  end
  
  private
  
  def validate_premium_access!
    unless @form.user.can_use_google_sheets?
      raise PremiumFeatureError, 'Google Sheets integration requires Premium subscription'
    end
  end
end
```

### 5. Integration Model Enhancements

**Enhanced GoogleSheetsIntegration Model:**
```ruby
# app/models/google_sheets_integration.rb
class GoogleSheetsIntegration < ApplicationRecord
  def can_sync?
    active? && 
    spreadsheet_id.present? && 
    form.user.can_use_google_sheets?
  end
  
  def premium_restriction_status
    return { restricted: false } if form.user.can_use_google_sheets?
    
    {
      restricted: true,
      reason: 'Premium subscription required',
      upgrade_url: '/subscription_management'
    }
  end
  
  def disable_for_downgrade!
    update!(
      active: false,
      auto_sync: false,
      error_message: 'Disabled due to subscription downgrade'
    )
  end
  
  def reactivate_for_upgrade!
    update!(
      active: true,
      error_message: nil
    )
  end
end
```

## Data Models

### 1. Subscription Tracking

No new database tables required. The existing user subscription fields will be used:
- `users.subscription_tier` (premium, pro, basic)
- `users.subscription_status` (active, cancelled, etc.)

### 2. Integration State Management

Enhanced `google_sheets_integrations` table usage:
- `active` field: Controls if integration can be used
- `error_message` field: Stores premium restriction messages
- `auto_sync` field: Automatically disabled on downgrade

## Error Handling

### 1. Premium Restriction Errors

**Custom Exception Class:**
```ruby
# app/errors/premium_feature_error.rb
class PremiumFeatureError < StandardError
  attr_reader :feature, :required_plan, :upgrade_url
  
  def initialize(message, feature: nil, required_plan: 'Premium', upgrade_url: '/subscription_management')
    super(message)
    @feature = feature
    @required_plan = required_plan
    @upgrade_url = upgrade_url
  end
  
  def to_hash
    {
      error_type: 'premium_feature_required',
      message: message,
      feature: feature,
      required_plan: required_plan,
      upgrade_url: upgrade_url
    }
  end
end
```

### 2. Graceful Degradation

**Background Job Handling:**
```ruby
# app/jobs/google_sheets_sync_job.rb
class GoogleSheetsSyncJob < ApplicationJob
  def perform(form_id, action)
    form = Form.find(form_id)
    
    unless form.user.can_use_google_sheets?
      Rails.logger.warn "Google Sheets sync skipped for form #{form_id}: Premium required"
      return
    end
    
    # ... existing sync logic
  end
end
```

## Testing Strategy

### 1. Unit Tests

**Subscription Validation Tests:**
- User model premium access methods
- Service layer premium validation
- Integration model restriction status

**Policy Tests:**
- Premium user access (should allow)
- Basic user access (should deny)
- Edge cases (expired subscriptions, etc.)

### 2. Integration Tests

**Controller Tests:**
- API endpoints with premium/basic users
- Error response format validation
- Upgrade URL generation

**System Tests:**
- UI behavior for premium vs basic users
- Upgrade flow integration
- Existing integration handling

### 3. Subscription Change Tests

**Downgrade Scenarios:**
- Active integrations become disabled
- Auto-sync is turned off
- Data is preserved

**Upgrade Scenarios:**
- Disabled integrations are reactivated
- Previous settings are restored
- Sync functionality resumes

## UI/UX Design

### 1. Premium Upgrade Prompts

**Form Builder Panel:**
```erb
<!-- For basic users -->
<div class="premium-feature-locked">
  <div class="premium-badge">Premium Feature</div>
  <h3>Google Sheets Integration</h3>
  <p>Automatically export form responses to Google Sheets</p>
  <button class="btn-premium-upgrade">Upgrade to Premium</button>
</div>

<!-- For premium users -->
<div class="google-sheets-integration">
  <!-- Existing integration UI -->
</div>
```

### 2. Consistent Premium Styling

**CSS Classes:**
- `.premium-feature-locked`: Disabled state styling
- `.premium-badge`: Premium feature indicator
- `.btn-premium-upgrade`: Consistent upgrade button styling

### 3. Informative Messages

**User-Friendly Messaging:**
- Clear explanation of premium requirement
- Benefits of Google Sheets integration
- Easy upgrade path with pricing information

## Implementation Phases

### Phase 1: Backend Restrictions
1. Implement user subscription validation methods
2. Add premium checks to policies and controllers
3. Enhance service layer with premium validation
4. Update background jobs with premium checks

### Phase 2: UI/UX Updates
1. Create premium upgrade components
2. Update form builder to show premium prompts
3. Implement consistent premium styling
4. Add upgrade flow integration

### Phase 3: Subscription Management
1. Handle subscription downgrades
2. Implement integration reactivation on upgrade
3. Add subscription change webhooks
4. Test complete upgrade/downgrade flows

### Phase 4: Testing and Polish
1. Comprehensive test coverage
2. Error message refinement
3. Performance optimization
4. Documentation updates

This design ensures that Google Sheets integration follows the established premium feature patterns while providing a smooth user experience for both basic and premium users.