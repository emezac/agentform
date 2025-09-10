# frozen_string_literal: true

class PaymentAnalytic < ApplicationRecord
  belongs_to :user

  validates :event_type, presence: true, inclusion: { in: PaymentAnalyticsService::PAYMENT_EVENTS }
  validates :timestamp, presence: true
  # Context can be empty hash but not nil
  validates :context, exclusion: { in: [nil] }

  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :by_date_range, ->(range) { where(timestamp: range) }
  scope :by_user_tier, ->(tier) { where(user_subscription_tier: tier) }

  # Indexes for performance
  # These would be added in a migration
  # add_index :payment_analytics, [:event_type, :timestamp]
  # add_index :payment_analytics, [:user_id, :timestamp]
  # add_index :payment_analytics, :user_subscription_tier

  def error_type
    context['error_type'] if event_type == 'payment_validation_errors'
  end

  def resolution_path
    context['resolution_path'] if event_type == 'payment_validation_errors'
  end

  def template_id
    context['template_id'] if event_type == 'template_payment_interaction'
  end

  def setup_step
    context['setup_step'] if %w[payment_setup_started payment_setup_completed payment_setup_abandoned].include?(event_type)
  end
end