class HealthController < ApplicationController
  # Skip authentication for health checks
  skip_before_action :authenticate_user!, if: :devise_controller?
  
  def show
    # Basic health check - just return 200 if app is running
    render json: { 
      status: 'ok', 
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version || '1.0.0'
    }
  end
  
  def detailed
    # Detailed health check with service status
    checks = {
      database: check_database,
      redis: check_redis,
      sidekiq: check_sidekiq
    }
    
    overall_status = checks.values.all? { |check| check[:status] == 'ok' } ? 'ok' : 'error'
    
    render json: {
      status: overall_status,
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version || '1.0.0',
      checks: checks
    }, status: overall_status == 'ok' ? 200 : 503
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', message: 'Database connection successful' }
  rescue => e
    { status: 'error', message: e.message }
  end
  
  def check_redis
    # Use RedisErrorLogger for comprehensive testing and logging
    connection_successful = RedisErrorLogger.test_and_log_connection(component: 'health_check')
    
    if connection_successful
      diagnostics = RedisErrorLogger.get_connection_diagnostics
      { 
        status: 'ok', 
        message: 'Redis connection successful',
        diagnostics: diagnostics.slice(:redis_version, :connected_clients, :used_memory_human)
      }
    else
      diagnostics = RedisErrorLogger.get_connection_diagnostics
      { 
        status: 'error', 
        message: diagnostics[:connection_error] || 'Redis connection failed',
        diagnostics: diagnostics
      }
    end
  rescue => e
    RedisErrorLogger.log_redis_error(e, {
      component: 'health_controller',
      operation: 'health_check'
    })
    
    { status: 'error', message: e.message }
  end
  
  def check_sidekiq
    # Check if Sidekiq is processing jobs
    stats = Sidekiq::Stats.new
    { 
      status: 'ok', 
      message: 'Sidekiq is running',
      processed: stats.processed,
      failed: stats.failed,
      busy: stats.workers_size,
      queues: stats.queues
    }
  rescue => e
    { status: 'error', message: e.message }
  end
end