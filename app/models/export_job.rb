# frozen_string_literal: true

class ExportJob < ApplicationRecord
  belongs_to :user
  belongs_to :form
  
  enum :status, {
    pending: 'pending',
    processing: 'processing', 
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled'
  }
  
  validates :export_type, inclusion: { in: %w[google_sheets excel csv] }
  validates :job_id, presence: true, uniqueness: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_export_type, ->(type) { where(export_type: type) }
  scope :google_sheets, -> { where(export_type: 'google_sheets') }
  
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end
  
  def success_rate
    return 0 if records_exported.zero?
    total_responses = form.form_responses.count
    return 100 if total_responses.zero?
    (records_exported.to_f / total_responses * 100).round(2)
  end
  
  def progress_percentage
    case status
    when 'pending' then 0
    when 'processing' then 50
    when 'completed' then 100
    when 'failed', 'cancelled' then 0
    else 25
    end
  end
end