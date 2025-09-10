class AnalysisReport < ApplicationRecord
  belongs_to :form_response

  validates :report_type, presence: true
  validates :markdown_content, presence: true, unless: :generating?
  validates :status, inclusion: { in: %w[generating completed failed] }

  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(report_type: type) }

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def generating?
    status == 'generating'
  end

  def download_url
    return nil unless completed? && file_path.present?
    Rails.application.routes.url_helpers.download_analysis_report_path(self)
  end

  def file_exists?
    file_path.present? && File.exist?(file_path)
  end

  def formatted_file_size
    return 'Unknown' unless file_size.present?
    
    if file_size < 1024
      "#{file_size} bytes"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(1)} KB"
    else
      "#{(file_size / (1024.0 * 1024)).round(1)} MB"
    end
  end

  def sections_included
    metadata&.dig('sections_included') || []
  end

  def ai_models_used
    metadata&.dig('ai_models_used') || []
  end

  def generation_duration
    return nil unless generated_at.present? && created_at.present?
    ((generated_at - created_at) / 1.minute).round(2)
  end

  # Cleanup old reports
  def self.cleanup_expired
    where('expires_at < ?', Time.current).find_each do |report|
      File.delete(report.file_path) if report.file_path && File.exist?(report.file_path)
      report.destroy
    end
  end
end