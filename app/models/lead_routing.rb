# frozen_string_literal: true

# Model for storing lead routing decisions and actions
class LeadRouting < ApplicationRecord
  belongs_to :form_response
  belongs_to :lead_scoring, optional: true
  
  validates :routing_actions, presence: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  validates :priority, inclusion: { in: %w[low medium high critical] }
  
  # Store routing actions as JSON
  store_accessor :routing_actions, :actions, :channels, :assignees
  
  # Scopes for filtering
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END")) }
  scope :overdue, -> { where('scheduled_at < ? AND status != ?', Time.current, 'completed') }
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
  
  # Status methods
  def pending?
    status == 'pending'
  end
  
  def processing?
    status == 'processing'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  # Priority methods
  def critical_priority?
    priority == 'critical'
  end
  
  def high_priority?
    priority == 'high'
  end
  
  def medium_priority?
    priority == 'medium'
  end
  
  def low_priority?
    priority == 'low'
  end
  
  def routing_actions_array
    return [] unless routing_actions.is_a?(Array)
    routing_actions
  end
  
  def primary_action
    routing_actions_array.first
  end
  
  def assignee
    primary_action&.dig(:assign_to) || 'unassigned'
  end
  
  def sla_hours
    primary_action&.dig(:sla_hours) || 24
  end
  
  def sla_deadline
    scheduled_at + sla_hours.hours
  end
  
  def sla_status
    return 'completed' if completed?
    return 'processing' if processing?
    
    if Time.current > sla_deadline
      'overdue'
    elsif Time.current > (sla_deadline - 2.hours)
      'due_soon'
    else
      'on_track'
    end
  end
  
  def channels
    primary_action&.dig(:channels) || ['email']
  end
  
  def priority_label
    priority.humanize
  end
  
  def status_label
    status.humanize
  end
  
  def priority_color
    case priority
    when 'critical' then 'red'
    when 'high' then 'orange'
    when 'medium' then 'yellow'
    when 'low' then 'blue'
    else 'gray'
    end
  end
  
  def status_color
    case status
    when 'completed' then 'green'
    when 'processing' then 'blue'
    when 'failed' then 'red'
    else 'yellow'
    end
  end
  
  def form_name
    form_response.form.name
  end
  
  def lead_score
    lead_scoring&.score || 0
  end
  
  def lead_tier
    lead_scoring&.tier || 'unknown'
  end
  
  def respondent_email
    form_response.answers_hash['email'] || form_response.answers_hash['work_email']
  end
  
  def respondent_name
    form_response.answers_hash['name'] || form_response.answers_hash['full_name'] || 'Anonymous'
  end
  
  def company_name
    if lead_scoring&.enriched_data.present?
      lead_scoring.enriched_data['company_name']
    else
      form_response.answers_hash['company'] || 'Unknown'
    end
  end
  
  def mark_processing!
    update!(status: 'processing', processing_started_at: Time.current)
  end
  
  def mark_completed!(result = {})
    update!(
      status: 'completed',
      completed_at: Time.current,
      result_data: result
    )
  end
  
  def mark_failed!(error = nil)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error
    )
  end
  
  # Class methods for analytics
  def self.by_status
    group(:status).count
  end
  
  def self.by_priority
    group(:priority).count
  end
  
  def self.overdue_count
    overdue.count
  end
  
  def self.completion_rate
    total = count
    return 0 if total.zero?
    
    completed_count.to_f / total * 100
  end
  
  def self.average_processing_time
    where.not(completed_at: nil).where.not(processing_started_at: nil).average(
      Arel.sql("EXTRACT(EPOCH FROM (completed_at - processing_started_at)) / 3600")
    ).to_f
  end
  
  def self.daily_volume(days = 7)
    where('created_at > ?', days.days.ago)
      .group_by_day(:created_at)
      .count
  end
  
  def self.assignee_distribution
    all.map { |r| r.assignee }.tally
  end
  
  private
  
  def completed_count
    where(status: 'completed').count
  end
end