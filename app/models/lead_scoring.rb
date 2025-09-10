# frozen_string_literal: true

# Model for storing lead scoring results from AI analysis
class LeadScoring < ApplicationRecord
  belongs_to :form_response
  belongs_to :lead_routing, optional: true
  
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :tier, presence: true, inclusion: { in: %w[hot warm lukewarm cold] }
  validates :form_response_id, uniqueness: true
  
  # Scoring tiers
  TIER_DEFINITIONS = {
    hot: { min_score: 80, max_score: 100, priority: 'immediate', sla_hours: 1 },
    warm: { min_score: 60, max_score: 79, priority: 'high', sla_hours: 24 },
    lukewarm: { min_score: 40, max_score: 59, priority: 'medium', sla_hours: 72 },
    cold: { min_score: 0, max_score: 39, priority: 'low', sla_hours: 168 }
  }.freeze
  
  # Scopes for filtering
  scope :hot_leads, -> { where(tier: 'hot') }
  scope :warm_leads, -> { where(tier: 'warm') }
  scope :cold_leads, -> { where(tier: 'cold') }
  scope :recent, -> { where('scored_at > ?', 7.days.ago) }
  scope :by_score_range, ->( min, max ) { where(score: min..max) }
  
  # Instance methods
  def tier_config
    TIER_DEFINITIONS[tier.to_sym]
  end
  
  def priority_level
    tier_config[:priority]
  end
  
  def sla_deadline
    scored_at + tier_config[:sla_hours].hours
  end
  
  def sla_status
    return 'overdue' if Time.current > sla_deadline
    return 'due_soon' if Time.current > (sla_deadline - 2.hours)
    'on_track'
  end
  
  def quality_factors_summary
    return [] unless quality_factors.is_a?(Array)
    
    quality_factors.map do |factor|
      {
        factor: factor['factor'],
        score: factor['score'],
        reasoning: factor['reasoning']
      }
    end
  end
  
  def risk_factors_summary
    return [] unless risk_factors.is_a?(Array)
    
    risk_factors.map do |factor|
      {
        factor: factor['factor'],
        impact: factor['impact'],
        reasoning: factor['reasoning']
      }
    end
  end
  
  def estimated_value_numeric
    return 0 unless estimated_value.present?
    
    # Parse estimated value from string format
    value = estimated_value.to_s.gsub(/[^\d.]/, '').to_f
    value * 1000 if estimated_value.include?('K')
    value * 1000000 if estimated_value.include?('M')
    value
  end
  
  def confidence_percentage
    return 0 unless confidence_level.present?
    (confidence_level * 100).round
  end
  
  def formatted_score
    score.round
  end
  
  def tier_label
    tier.humanize
  end
  
  def tier_color
    case tier
    when 'hot' then 'red'
    when 'warm' then 'orange'
    when 'lukewarm' then 'yellow'
    when 'cold' then 'blue'
    else 'gray'
    end
  end
  
  def buying_signals_summary
    return [] unless analysis_data.is_a?(Hash)
    analysis_data['buying_signals'] || []
  end
  
  def timing_indicators
    return {} unless analysis_data.is_a?(Hash)
    analysis_data['timing_indicators'] || {}
  end
  
  def next_best_action
    return '' unless analysis_data.is_a?(Hash)
    analysis_data['next_best_action'] || ''
  end
  
  # Class methods for analytics
  def self.average_score
    average(:score)
  end
  
  def self.tier_distribution
    group(:tier).count
  end
  
  def self.score_distribution
    ranges = [
      [0, 20], [21, 40], [41, 60], [61, 80], [81, 100]
    ]
    
    ranges.map do |min, max|
      count = where(score: min..max).count
      {
        range: "#{min}-#{max}",
        count: count,
        percentage: count.to_f / total_count * 100
      }
    end
  end
  
  def self.recent_leads_by_tier
    recent.group(:tier).count
  end
  
  def self.high_value_leads(min_value = 10000)
    where("estimated_value ILIKE ? OR estimated_value ILIKE ?", "%$#{min_value}%", "%#{min_value / 1000}K%")
  end
  
  private
  
  def total_count
    @total_count ||= count
  end
end