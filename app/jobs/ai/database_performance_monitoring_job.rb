# frozen_string_literal: true

module Ai
  class DatabasePerformanceMonitoringJob < ApplicationJob
    queue_as :ai_processing
    
    # Retry configuration for monitoring
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    
    def perform
      Rails.logger.info "Starting AI database performance monitoring"
      
      # Monitor connection pool health
      pool_health = Ai::ConnectionPoolService.monitor_connection_pool_health
      
      # Monitor database performance for AI operations
      db_performance = Ai::DatabaseOptimizationService.monitor_ai_database_performance
      
      # Check for performance issues and take action
      handle_performance_issues(pool_health, db_performance)
      
      # Generate performance report
      performance_report = generate_performance_report(pool_health, db_performance)
      
      Rails.logger.info "AI database performance monitoring completed"
      performance_report
    end
    
    private
    
    def handle_performance_issues(pool_health, db_performance)
      # Handle connection pool issues
      if pool_health[:pool_utilization] > 90
        Rails.logger.warn "High connection pool utilization detected: #{pool_health[:pool_utilization]}%"
        
        # Try to optimize pool usage
        Ai::ConnectionPoolService.optimize_pool_for_ai_usage
      end
      
      if pool_health[:waiting_count] > 0
        Rails.logger.warn "Connections waiting in queue: #{pool_health[:waiting_count]}"
        
        # Handle potential pool exhaustion
        Ai::ConnectionPoolService.handle_pool_exhaustion
      end
      
      # Handle slow query issues
      if db_performance[:query_performance][:slow_query_count] > 5
        Rails.logger.warn "High number of slow AI queries detected"
        
        # Trigger database optimization
        Ai::DatabaseOptimizationService.optimize_database_for_ai
      end
    end
    
    def generate_performance_report(pool_health, db_performance)
      {
        timestamp: Time.current.iso8601,
        connection_pool: {
          health_status: determine_pool_health_status(pool_health),
          utilization: pool_health[:pool_utilization],
          waiting_connections: pool_health[:waiting_count],
          recommendations: generate_pool_recommendations(pool_health)
        },
        database_performance: {
          query_performance: db_performance[:query_performance],
          index_usage: db_performance[:index_usage],
          table_sizes: db_performance[:table_sizes],
          recommendations: generate_db_recommendations(db_performance)
        },
        overall_health: calculate_overall_health(pool_health, db_performance)
      }
    end
    
    def determine_pool_health_status(pool_health)
      utilization = pool_health[:pool_utilization]
      waiting = pool_health[:waiting_count]
      
      if waiting > 0 || utilization > 90
        'critical'
      elsif utilization > 80
        'warning'
      elsif utilization > 60
        'good'
      else
        'excellent'
      end
    end
    
    def generate_pool_recommendations(pool_health)
      recommendations = []
      
      if pool_health[:pool_utilization] > 80
        recommendations << "Consider increasing connection pool size"
      end
      
      if pool_health[:waiting_count] > 0
        recommendations << "Optimize long-running AI operations"
        recommendations << "Consider connection pooling optimization"
      end
      
      if pool_health[:connection_health][:health_percentage] < 100
        recommendations << "Check for unhealthy database connections"
      end
      
      recommendations
    end
    
    def generate_db_recommendations(db_performance)
      recommendations = []
      
      if db_performance[:query_performance][:slow_query_count] > 5
        recommendations << "Optimize slow AI-related queries"
        recommendations << "Consider adding additional indexes"
      end
      
      if db_performance[:index_usage][:unused_indexes].any?
        recommendations << "Remove unused indexes to improve write performance"
      end
      
      # Check table sizes
      large_tables = db_performance[:table_sizes].select { |_, size| size.include?('GB') }
      if large_tables.any?
        recommendations << "Consider archiving old data from large tables: #{large_tables.keys.join(', ')}"
      end
      
      recommendations
    end
    
    def calculate_overall_health(pool_health, db_performance)
      pool_score = calculate_pool_health_score(pool_health)
      db_score = calculate_db_health_score(db_performance)
      
      overall_score = (pool_score + db_score) / 2
      
      case overall_score
      when 90..100
        'excellent'
      when 70..89
        'good'
      when 50..69
        'fair'
      when 30..49
        'poor'
      else
        'critical'
      end
    end
    
    def calculate_pool_health_score(pool_health)
      score = 100
      
      # Deduct points for high utilization
      utilization = pool_health[:pool_utilization]
      if utilization > 90
        score -= 30
      elsif utilization > 80
        score -= 20
      elsif utilization > 70
        score -= 10
      end
      
      # Deduct points for waiting connections
      waiting = pool_health[:waiting_count]
      score -= (waiting * 10) if waiting > 0
      
      # Deduct points for unhealthy connections
      health_percentage = pool_health[:connection_health][:health_percentage]
      score -= (100 - health_percentage) if health_percentage < 100
      
      [score, 0].max
    end
    
    def calculate_db_health_score(db_performance)
      score = 100
      
      # Deduct points for slow queries
      slow_queries = db_performance[:query_performance][:slow_query_count]
      score -= (slow_queries * 5) if slow_queries > 0
      
      # Deduct points for poor index usage
      # This would be based on actual index usage statistics
      
      [score, 0].max
    end
  end
end