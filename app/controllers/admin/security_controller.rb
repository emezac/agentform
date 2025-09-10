# frozen_string_literal: true

class Admin::SecurityController < Admin::BaseController
  before_action :set_monitoring_service

  def index
    @dashboard_data = @monitoring_service.security_dashboard_data
    @alerts = @monitoring_service.check_security_alerts
  end

  def audit_logs
    @audit_logs = AuditLog.includes(:user)
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(50)
    
    # Apply filters
    @audit_logs = @audit_logs.where(event_type: params[:event_type]) if params[:event_type].present?
    @audit_logs = @audit_logs.where(user_id: params[:user_id]) if params[:user_id].present?
    @audit_logs = @audit_logs.by_ip(params[:ip_address]) if params[:ip_address].present?
    
    if params[:date_from].present?
      @audit_logs = @audit_logs.where('created_at >= ?', Date.parse(params[:date_from]))
    end
    
    if params[:date_to].present?
      @audit_logs = @audit_logs.where('created_at <= ?', Date.parse(params[:date_to]).end_of_day)
    end
    
    # Get filter options
    @event_types = AuditLog.distinct.pluck(:event_type).compact.sort
    @users = User.where(role: ['admin', 'superadmin']).pluck(:id, :email)
  end

  def security_report
    start_date = params[:start_date]&.to_date || 7.days.ago
    end_date = params[:end_date]&.to_date || Date.current
    
    @report = @monitoring_service.generate_security_report(start_date, end_date)
    
    respond_to do |format|
      format.html
      format.json { render json: @report }
      format.csv { send_csv_report(@report, start_date, end_date) }
    end
  end

  def user_activity
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @days = (params[:days] || 7).to_i
    
    if @user
      @activity_data = @monitoring_service.monitor_user_activity(@user.id, @days)
    end
    
    @users = User.where(role: ['admin', 'superadmin']).order(:email)
  end

  def block_ip
    ip_address = params[:ip_address]
    
    if ip_address.present?
      # Log the IP blocking action
      AuditLog.create!(
        user: current_user,
        event_type: 'ip_blocked_manually',
        details: {
          ip_address: ip_address,
          blocked_by: current_user.email,
          reason: params[:reason] || 'Manual admin action'
        },
        ip_address: ip_address
      )
      
      # In a real implementation, you would add the IP to a blocklist
      # For now, we'll just log it
      flash[:success] = "IP #{ip_address} has been flagged for blocking"
    else
      flash[:error] = "Invalid IP address"
    end
    
    redirect_to admin_security_index_path
  end

  def alerts
    @alerts = @monitoring_service.check_security_alerts
    @recent_alerts = AuditLog.where(event_type: 'security_alert_generated')
                            .order(created_at: :desc)
                            .limit(50)
                            .includes(:user)
  end

  private

  def set_monitoring_service
    @monitoring_service = AdminMonitoringService.new
  end

  def send_csv_report(report, start_date, end_date)
    csv_data = generate_csv_report(report)
    filename = "security_report_#{start_date.strftime('%Y%m%d')}_#{end_date.strftime('%Y%m%d')}.csv"
    
    send_data csv_data, 
              filename: filename,
              type: 'text/csv',
              disposition: 'attachment'
  end

  def generate_csv_report(report)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Report Period', report[:period]]
      csv << []
      
      csv << ['Security Events Summary']
      csv << ['Total Security Events', report[:total_security_events]]
      csv << []
      
      csv << ['Security Events by Type']
      csv << ['Event Type', 'Count']
      report[:security_events_by_type].each do |event_type, count|
        csv << [event_type, count]
      end
      csv << []
      
      csv << ['Top Targeted IPs']
      csv << ['IP Address', 'Failed Attempts']
      report[:top_targeted_ips].each do |ip, count|
        csv << [ip, count]
      end
      csv << []
      
      csv << ['Recommendations']
      report[:recommendations].each do |recommendation|
        csv << [recommendation]
      end
    end
  end
end