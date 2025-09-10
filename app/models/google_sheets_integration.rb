class GoogleSheetsIntegration < ApplicationRecord
  belongs_to :form

  validates :spreadsheet_id, presence: true
  validates :sheet_name, presence: true
  
  scope :active, -> { where(active: true) }
  scope :auto_sync_enabled, -> { where(auto_sync: true) }

  def spreadsheet_url
    "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit"
  end

  def mark_sync_success!
    update!(
      last_sync_at: Time.current,
      error_message: nil,
      sync_count: sync_count + 1
    )
  end

  def mark_sync_error!(error)
    update!(
      error_message: error.to_s,
      active: false
    )
  end

  def can_sync?
    active? && spreadsheet_id.present?
  end
end