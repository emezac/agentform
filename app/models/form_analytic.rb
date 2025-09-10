# frozen_string_literal: true

class FormAnalytic < ApplicationRecord
  # Associations
  belongs_to :form

  # Validations
  validates :date, presence: true
  validates :period_type, presence: true

  # Scopes
  scope :for_period, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_period_type, ->(type) { where(period_type: type) }
  scope :recent, -> { order(date: :desc) }
  scope :daily, -> { where(period_type: 'daily') }
  scope :weekly, -> { where(period_type: 'weekly') }
  scope :monthly, -> { where(period_type: 'monthly') }

  # Class Methods
  def self.aggregate_for_period(form, start_date, end_date)
    analytics = for_period(start_date, end_date).where(form: form)
    
    {
      total_views: analytics.sum(:views_count),
      total_starts: analytics.sum(:started_responses_count),
      total_completions: analytics.sum(:completed_responses_count),
      total_abandons: analytics.sum(:abandoned_responses_count),
      avg_completion_time: analytics.average(:avg_completion_time)&.round(2) || 0.0
    }
  end

  def self.create_daily_snapshot(form, date = Date.current)
    # Calculate metrics for the given date
    responses = form.form_responses.where(created_at: date.beginning_of_day..date.end_of_day)
    
    views_count = form.views_count || 0 # Assuming form tracks views
    starts_count = responses.count
    completions_count = responses.completed.count
    abandons_count = responses.abandoned.count
    
    # Calculate average times
    completed_responses = responses.completed.where.not(completed_at: nil)
    avg_completion_time = if completed_responses.any?
      completed_responses.average('EXTRACT(EPOCH FROM (completed_at - created_at))')&.to_f || 0.0
    else
      0.0
    end
    
    # Calculate average response time per question
    question_responses = QuestionResponse.joins(form_response: :form)
                                        .where(forms: { id: form.id })
                                        .where(created_at: date.beginning_of_day..date.end_of_day)
                                        .where.not(response_time_ms: nil)
    
    avg_time_per_question_ms = question_responses.average(:response_time_ms)&.to_f || 0.0
    
    # Create or update the analytic record
    find_or_create_by(form: form, date: date, period_type: 'daily') do |analytic|
      analytic.views_count = views_count
      analytic.started_responses_count = starts_count
      analytic.completed_responses_count = completions_count
      analytic.abandoned_responses_count = abandons_count
      analytic.avg_completion_time = avg_completion_time.to_i
      analytic.avg_time_per_question = avg_time_per_question_ms.to_i
    end
  end

  # Instance Methods
  def calculated_completion_rate
    return 0.0 if started_responses_count.zero?
    
    (completed_responses_count.to_f / started_responses_count * 100).round(2)
  end

  def calculated_abandonment_rate
    return 0.0 if started_responses_count.zero?
    
    (abandoned_responses_count.to_f / started_responses_count * 100).round(2)
  end

  def performance_score
    # Calculate a composite performance score (0-100)
    completion_weight = 0.4
    speed_weight = 0.3
    engagement_weight = 0.3
    
    # Completion score (0-100)
    completion_score = calculated_completion_rate
    
    # Speed score (inverse of completion time, normalized)
    # Assume 5 minutes (300 seconds) is optimal, 30 minutes (1800 seconds) is poor
    speed_score = if avg_completion_time > 0
      optimal_time = 300.0
      max_acceptable_time = 1800.0
      
      if avg_completion_time <= optimal_time
        100.0
      elsif avg_completion_time >= max_acceptable_time
        20.0
      else
        # Linear interpolation between optimal and max acceptable
        100.0 - ((avg_completion_time - optimal_time) / (max_acceptable_time - optimal_time) * 80.0)
      end
    else
      50.0 # Neutral score if no data
    end
    
    # Engagement score (based on view-to-start conversion)
    engagement_score = if views_count > 0
      (started_responses_count.to_f / views_count * 100).clamp(0, 100)
    else
      50.0 # Neutral score if no view data
    end
    
    # Weighted average
    total_score = (completion_score * completion_weight) + 
                  (speed_score * speed_weight) + 
                  (engagement_score * engagement_weight)
    
    total_score.round(2)
  end

  def trend_direction
    # Compare with previous period to determine trend
    previous_analytic = self.class.where(form: form, period_type: period_type)
                                  .where('date < ?', date)
                                  .order(date: :desc)
                                  .first
    
    return 'neutral' unless previous_analytic
    
    current_score = performance_score
    previous_score = previous_analytic.performance_score
    
    difference = current_score - previous_score
    
    case difference
    when -Float::INFINITY..-5.0
      'declining'
    when -5.0..5.0
      'stable'
    when 5.0..Float::INFINITY
      'improving'
    else
      'neutral'
    end
  end

  def conversion_funnel
    {
      views: views_count,
      starts: started_responses_count,
      completions: completed_responses_count,
      abandons: abandoned_responses_count,
      view_to_start_rate: views_count > 0 ? (started_responses_count.to_f / views_count * 100).round(2) : 0.0,
      start_to_completion_rate: calculated_completion_rate,
      abandonment_rate: calculated_abandonment_rate
    }
  end

  def time_metrics
    {
      avg_completion_time_seconds: avg_completion_time,
      avg_completion_time_formatted: format_duration(avg_completion_time),
      avg_response_time_ms: avg_time_per_question,
      avg_response_time_formatted: "#{avg_time_per_question.round(0)}ms"
    }
  end

  def summary
    {
      date: date,
      period_type: period_type,
      performance_score: performance_score,
      trend: trend_direction,
      completion_rate: calculated_completion_rate,
      abandonment_rate: calculated_abandonment_rate,
      funnel: conversion_funnel,
      timing: time_metrics
    }
  end

  private

  def format_duration(seconds)
    return '0s' if seconds.nil? || seconds.zero?
    
    if seconds < 60
      "#{seconds.round(0)}s"
    elsif seconds < 3600
      minutes = (seconds / 60).round(0)
      remaining_seconds = (seconds % 60).round(0)
      "#{minutes}m #{remaining_seconds}s"
    else
      hours = (seconds / 3600).round(0)
      remaining_minutes = ((seconds % 3600) / 60).round(0)
      "#{hours}h #{remaining_minutes}m"
    end
  end
end