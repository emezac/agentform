class Admin::DashboardController < Admin::BaseController
  def index
    @dashboard_stats = Admin::DashboardAgent.new.get_dashboard_stats
  end
end