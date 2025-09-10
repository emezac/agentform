# frozen_string_literal: true

class Admin::PaymentAnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @date_range = parse_date_range
    @metrics = PaymentAnalyticsService.new.get_dashboard_metrics(date_range: @date_range)
    @recent_events = recent_payment_events
  end

  def export
    @date_range = parse_date_range
    
    respond_to do |format|
      format.csv do
        csv_data = generate_csv_export(@date_range)
        send_data csv_data, filename: "payment_analytics_#{Date.current}.csv"
      end
      format.json do
        metrics = PaymentAnalyticsService.new.get_dashboard_metrics(date_range: @date_range)
        render json: metrics
      end
    end
  end

  private

  def parse_date_range
    start_date = params[:start_date]&.to_date || 30.days.ago
    end_date = params[:end_date]&.to_date || Date.current
    start_date..end_date.end_of_day
  end

  def recent_payment_events
    PaymentAnalytic.includes(:user)
                   .by_date_range(@date_range)
                   .order(timestamp: :desc)
                   .limit(50)
  end

  def generate_csv_export(date_range)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Event Type', 'User ID', 'User Tier', 'Timestamp', 'Context']
      
      PaymentAnalytic.by_date_range(date_range).find_each do |analytic|
        csv << [
          analytic.event_type,
          analytic.user_id,
          analytic.user_subscription_tier,
          analytic.timestamp,
          analytic.context.to_json
        ]
      end
    end
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end