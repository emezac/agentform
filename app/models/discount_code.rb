class DiscountCode < ApplicationRecord
  include AdminCacheable
  
  belongs_to :created_by, class_name: 'User'
  has_many :discount_code_usages, dependent: :destroy
  has_many :users, through: :discount_code_usages

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :discount_percentage, presence: true, inclusion: { in: 1..99 }
  validates :max_usage_count, numericality: { greater_than: 0 }, allow_nil: true
  validates :current_usage_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_code

  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :available, -> { active.where('expires_at IS NULL OR expires_at > ?', Time.current) }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def usage_limit_reached?
    max_usage_count.present? && current_usage_count >= max_usage_count
  end

  def available?
    active? && !expired? && !usage_limit_reached?
  end

  def usage_percentage
    return 0 if max_usage_count.nil?
    return 100 if max_usage_count.zero?
    (current_usage_count.to_f / max_usage_count * 100).round(1)
  end

  def remaining_uses
    return nil if max_usage_count.nil?
    [max_usage_count - current_usage_count, 0].max
  end

  def revenue_impact
    discount_code_usages.sum(:discount_amount)
  end

  # Analytics methods
  def average_discount_amount
    return 0 if current_usage_count.zero?
    revenue_impact / current_usage_count
  end

  def total_original_amount
    discount_code_usages.sum(:original_amount)
  end

  def conversion_rate
    return 0 if current_usage_count.zero?
    (current_usage_count.to_f / total_views * 100).round(2) if respond_to?(:total_views)
  end

  def usage_by_month
    discount_code_usages
      .group_by_month(:used_at, last: 12)
      .count
  end

  def recent_usage_trend
    last_30_days = discount_code_usages.where(used_at: 30.days.ago..Time.current)
    previous_30_days = discount_code_usages.where(used_at: 60.days.ago..30.days.ago)
    
    current_count = last_30_days.count
    previous_count = previous_30_days.count
    
    return 0 if previous_count.zero?
    
    ((current_count - previous_count).to_f / previous_count * 100).round(1)
  end

  # Class methods for admin analytics (optimized)
  def self.total_revenue_impact
    DiscountCodeUsage.sum(:discount_amount)
  end

  def self.most_used(limit = 10)
    select('discount_codes.*, discount_codes.current_usage_count')
      .order(current_usage_count: :desc)
      .limit(limit)
  end

  def self.highest_revenue_impact(limit = 10)
    select('discount_codes.*, SUM(discount_code_usages.discount_amount) as revenue_impact')
      .joins(:discount_code_usages)
      .group('discount_codes.id')
      .order('revenue_impact DESC')
      .limit(limit)
  end

  def self.usage_stats_summary
    # Use a single query with aggregations for better performance
    stats = connection.select_one(<<~SQL)
      SELECT 
        COUNT(*) as total_codes,
        COUNT(CASE WHEN active = true THEN 1 END) as active_codes,
        COUNT(CASE WHEN expires_at < NOW() THEN 1 END) as expired_codes,
        SUM(current_usage_count) as total_usage,
        AVG(discount_percentage) as avg_discount_percentage
      FROM discount_codes
    SQL
    
    {
      total_codes: stats['total_codes'].to_i,
      active_codes: stats['active_codes'].to_i,
      expired_codes: stats['expired_codes'].to_i,
      total_usage: stats['total_usage'].to_i,
      total_revenue_impact: total_revenue_impact,
      average_discount_percentage: stats['avg_discount_percentage'].to_f.round(1)
    }
  end

  # Optimized method for dashboard statistics
  def self.dashboard_stats
    Rails.cache.fetch('discount_codes_dashboard_stats', expires_in: 5.minutes) do
      usage_stats_summary
    end
  end

  private

  def normalize_code
    self.code = code&.upcase&.strip
  end
end