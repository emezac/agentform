class Admin::BaseController < ApplicationController
  include AdminSecurity
  
  before_action :authenticate_user!
  before_action :ensure_superadmin!
  before_action :set_admin_session_timeout
  
  # Ensure CSRF protection is enabled for admin actions
  protect_from_forgery with: :exception
  
  # Skip Pundit for admin controllers since we have custom authorization
  skip_after_action :verify_policy_scoped, raise: false
  skip_after_action :verify_authorized, raise: false
  
  layout 'admin'

  private

  def ensure_superadmin!
    unless current_user&.superadmin?
      Rails.logger.warn "Unauthorized admin access attempt by user #{current_user&.id || 'anonymous'}"
      redirect_to root_path, alert: 'Access denied. Superadmin privileges required.'
    end
  end

  def set_admin_session_timeout
    # Enhanced admin session security
    current_time = Time.current.to_i
    last_activity = session[:admin_last_activity]
    session_ip = session[:admin_session_ip]
    
    # Check for session hijacking (IP change)
    if session_ip.present? && session_ip != request.remote_ip
      safe_create_audit_log(
        user: current_user,
        event_type: 'suspicious_admin_activity',
        details: {
          reason: 'ip_address_change',
          original_ip: session_ip,
          new_ip: request.remote_ip,
          user_agent: request.user_agent
        },
        ip_address: request.remote_ip
      )
      
      reset_session
      redirect_to new_user_session_path, alert: 'Security alert: Session terminated due to suspicious activity.'
      return
    end
    
    # Set/update session tracking
    session[:admin_last_activity] = current_time
    session[:admin_session_ip] = request.remote_ip
    
    # Check session timeout (2 hours for admin)
    if last_activity && (current_time - last_activity) > 2.hours
      AuditLog.create!(
        user: current_user,
        event_type: 'admin_session_expired',
        details: {
          last_activity: Time.at(last_activity),
          timeout_duration: current_time - last_activity
        },
        ip_address: request.remote_ip
      )
      
      reset_session
      redirect_to new_user_session_path, alert: 'Admin session expired. Please log in again.'
      return
    end
  end

  def current_admin
    current_user if current_user&.superadmin?
  end
  helper_method :current_admin

  def admin_breadcrumbs
    @admin_breadcrumbs ||= [
      { name: 'Dashboard', path: admin_dashboard_path }
    ]
  end
  helper_method :admin_breadcrumbs

  def add_breadcrumb(name, path = nil)
    admin_breadcrumbs << { name: name, path: path }
  end
  helper_method :add_breadcrumb
end