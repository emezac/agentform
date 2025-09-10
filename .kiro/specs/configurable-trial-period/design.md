# Design Document

## Overview

This design implements a configurable trial period system that allows administrators to set trial durations via environment variables and provides users with clear visibility into their remaining trial time. The system will track trial expiration dates and display appropriate warnings as the trial period approaches its end.

## Architecture

### Configuration Layer

The trial period configuration will be managed through environment variables with fallback defaults:

```ruby
# config/initializers/trial_config.rb
class TrialConfig
  DEFAULT_TRIAL_DAYS = 14
  
  def self.trial_period_days
    @trial_period_days ||= begin
      days = ENV['TRIAL_PERIOD_DAYS']&.to_i
      if days && days >= 0
        days
      else
        Rails.logger.warn "Invalid TRIAL_PERIOD_DAYS: #{ENV['TRIAL_PERIOD_DAYS']}, using default: #{DEFAULT_TRIAL_DAYS}"
        DEFAULT_TRIAL_DAYS
      end
    end
  end
  
  def self.trial_enabled?
    trial_period_days > 0
  end
end
```

### Database Schema

Add trial tracking to the users table:

```ruby
# Migration: add_trial_tracking_to_users
class AddTrialTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trial_ends_at, :datetime
    add_index :users, :trial_ends_at
    
    # Backfill existing users
    User.where(trial_ends_at: nil, subscription_status: 'trialing').find_each do |user|
      trial_end = user.created_at + TrialConfig.trial_period_days.days
      user.update_column(:trial_ends_at, trial_end)
    end
  end
end
```

## Components and Interfaces

### 1. User Model Extensions

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Trial management methods
  def trial_days_remaining
    return 0 unless trial_ends_at && subscription_status == 'trialing'
    
    days = ((trial_ends_at - Time.current) / 1.day).ceil
    [days, 0].max
  end
  
  def trial_expired?
    return false unless trial_ends_at
    Time.current >= trial_ends_at
  end
  
  def trial_expires_soon?
    trial_days_remaining <= 7 && trial_days_remaining > 0
  end
  
  def trial_expires_today?
    trial_days_remaining == 1
  end
  
  def trial_status_message
    return nil unless subscription_status == 'trialing'
    
    days = trial_days_remaining
    case days
    when 0
      "Your trial has expired"
    when 1
      "Your trial expires today"
    when 2..3
      "Your trial expires in #{days} days"
    when 4..7
      "#{days} days left in your trial"
    else
      "Trial active (#{days} days remaining)"
    end
  end
  
  private
  
  def set_trial_end_date
    if subscription_status == 'trialing' && trial_ends_at.nil?
      self.trial_ends_at = created_at + TrialConfig.trial_period_days.days
    end
  end
end
```

### 2. Registration Process Updates

```ruby
# app/models/user.rb (callback)
before_create :set_trial_end_date

# app/controllers/registrations_controller.rb (if using custom registration)
def create
  @user = User.new(user_params)
  @user.subscription_tier = 'basic'
  @user.subscription_status = TrialConfig.trial_enabled? ? 'trialing' : 'active'
  
  if @user.save
    # Registration success logic
  end
end
```

### 3. Subscription Management View Updates

```erb
<!-- app/views/subscription_management/show.html.erb -->
<% if current_user.subscription_status == 'trialing' %>
  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
    <div class="flex items-start">
      <div class="flex-shrink-0">
        <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
        </svg>
      </div>
      <div class="ml-3 flex-1">
        <h3 class="text-sm font-medium text-blue-800">
          <%= current_user.trial_status_message %>
        </h3>
        <div class="mt-2 text-sm text-blue-700">
          <% if current_user.trial_expires_soon? %>
            <p class="font-medium">Upgrade now to continue using all features without interruption.</p>
          <% elsif current_user.trial_expired? %>
            <p class="font-medium">Please upgrade to continue using AgentForm.</p>
          <% else %>
            <p>Enjoy full access to all features during your trial period.</p>
          <% end %>
        </div>
        <% unless current_user.trial_expired? %>
          <div class="mt-3">
            <div class="bg-blue-200 rounded-full h-2">
              <% progress = [(TrialConfig.trial_period_days - current_user.trial_days_remaining).to_f / TrialConfig.trial_period_days * 100, 100].min %>
              <div class="bg-blue-600 h-2 rounded-full" style="width: <%= progress %>%"></div>
            </div>
            <p class="text-xs text-blue-600 mt-1">
              Day <%= TrialConfig.trial_period_days - current_user.trial_days_remaining + 1 %> of <%= TrialConfig.trial_period_days %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
  </div>
<% end %>
```

## Data Models

### Trial Status Flow

```
Registration → trialing (if trial enabled) → active (after payment) → canceled/expired
             ↘ active (if trial disabled)
```

### Trial Expiration Logic

```ruby
# Background job to handle trial expirations
class TrialExpirationJob < ApplicationJob
  def perform
    expired_users = User.where(
      subscription_status: 'trialing',
      trial_ends_at: ..Time.current
    )
    
    expired_users.find_each do |user|
      user.update!(
        subscription_status: 'expired',
        # Additional logic for handling expired trials
      )
      
      # Send expiration notification
      TrialExpirationMailer.trial_expired(user).deliver_now
    end
  end
end
```

## Error Handling

### Configuration Validation

1. **Invalid Environment Variable**: Log warning and use default
2. **Missing Configuration**: Use sensible defaults
3. **Zero Trial Period**: Disable trial functionality gracefully

### Edge Cases

1. **Timezone Handling**: Use UTC for all trial calculations
2. **Leap Years**: Use Rails date arithmetic for accuracy
3. **Clock Changes**: Handle daylight saving time transitions
4. **Negative Values**: Clamp to zero for display purposes

## Testing Strategy

### Unit Tests

```ruby
# spec/models/user_trial_spec.rb
RSpec.describe User, type: :model do
  describe 'trial methods' do
    let(:user) { create(:user, subscription_status: 'trialing') }
    
    describe '#trial_days_remaining' do
      it 'calculates remaining days correctly' do
        user.update!(trial_ends_at: 5.days.from_now)
        expect(user.trial_days_remaining).to eq(5)
      end
      
      it 'returns 0 for expired trials' do
        user.update!(trial_ends_at: 1.day.ago)
        expect(user.trial_days_remaining).to eq(0)
      end
    end
  end
end
```

### Integration Tests

```ruby
# spec/system/trial_management_spec.rb
RSpec.describe 'Trial Management', type: :system do
  it 'displays trial information correctly' do
    user = create(:user, subscription_status: 'trialing', trial_ends_at: 5.days.from_now)
    sign_in user
    
    visit subscription_management_path
    expect(page).to have_content('5 days left in your trial')
  end
end
```

## Security Considerations

1. **Environment Variables**: Secure storage of configuration
2. **Trial Manipulation**: Prevent users from extending trials
3. **Clock Tampering**: Server-side time validation
4. **Data Integrity**: Validate trial_ends_at consistency

## Performance Considerations

1. **Database Indexes**: Index on trial_ends_at for efficient queries
2. **Caching**: Cache trial calculations for frequently accessed users
3. **Background Jobs**: Process trial expirations asynchronously
4. **Query Optimization**: Efficient queries for trial status checks

## Deployment Strategy

1. **Environment Setup**: Configure TRIAL_PERIOD_DAYS in each environment
2. **Migration**: Run trial tracking migration
3. **Backfill**: Update existing users with trial end dates
4. **Monitoring**: Track trial conversion rates and expiration handling