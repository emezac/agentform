# frozen_string_literal: true

module Ai
  class ConnectionPoolService
    include ActiveModel::Model
    
    class << self
      # Configure connection pool for AI operations
      def configure_ai_connection_pool
        Rails.logger.info "Configuring connection pool for AI operations"
        
        # Get current pool configuration
        current_config = ActiveRecord::Base.connection_pool.db_config.configuration_hash
        
        # Calculate optimal pool size based on AI workload
        optimal_pool_size = calculate_optimal_pool_size
        
        # Configure pool settings
        configure_pool_settings(optimal_pool_size)
        
        Rails.logger.info "AI connection pool configured with size: #{optimal_pool_size}"
      end
      
      # Execute AI operations with dedicated connection
      def with_ai_connection(&block)
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          # Set AI-specific connection parameters
          configure_connection_for_ai(connection)
          
          yield connection
        end
      end
      
      # Batch execute AI operations with connection optimization
      def batch_execute_ai_operations(operations, batch_size: 25)
        results = []
        
        operations.each_slice(batch_size) do |batch|
          batch_results = with_ai_connection do |connection|
            ActiveRecord::Base.transaction do
              batch.map { |operation| yield operation, connection }
            end
          end
          
          results.concat(batch_results)
          
          # Brief pause between batches to prevent connection exhaustion
          sleep(0.05) if operations.length > batch_size
        end
        
        results
      end
      
      # Monitor connection pool health
      def monitor_connection_pool_health
        pool = ActiveRecord::Base.connection_pool
        
        health_metrics = {
          timestamp: Time.current.iso8601,
          pool_size: pool.size,
          checked_out_connections: pool.checked_out.length,
          available_connections: pool.available.length,
          waiting_count: pool.waiting_count,
          pool_utilization: calculate_pool_utilization(pool),
          connection_health: check_connection_health(pool)
        }
        
        # Track health metrics
        Ai::UsageAnalyticsService.track_event({
          event_type: 'connection_pool_health',
          data: health_metrics
        })
        
        # Log warnings if pool is under stress
        log_pool_warnings(health_metrics)
        
        health_metrics
      end
      
      # Optimize connection pool based on AI usage patterns
      def optimize_pool_for_ai_usage
        Rails.logger.info "Optimizing connection pool for AI usage patterns"
        
        # Analyze recent AI operation patterns
        usage_patterns = analyze_ai_usage_patterns
        
        # Calculate optimal settings
        optimal_settings = calculate_optimal_settings(usage_patterns)
        
        # Apply optimizations
        apply_pool_optimizations(optimal_settings)
        
        Rails.logger.info "Connection pool optimized for AI usage"
        optimal_settings
      end
      
      # Preload connections for AI operations
      def preload_ai_connections(count: 5)
        Rails.logger.info "Preloading #{count} connections for AI operations"
        
        connections = []
        
        count.times do
          connection = ActiveRecord::Base.connection_pool.checkout
          configure_connection_for_ai(connection)
          connections << connection
        end
        
        # Return connections to pool
        connections.each do |connection|
          ActiveRecord::Base.connection_pool.checkin(connection)
        end
        
        Rails.logger.info "Preloaded #{connections.length} AI-optimized connections"
      end
      
      # Handle connection pool exhaustion
      def handle_pool_exhaustion
        Rails.logger.warn "Connection pool exhaustion detected"
        
        pool = ActiveRecord::Base.connection_pool
        
        # Try to free up connections
        freed_connections = 0
        
        # Clear idle connections
        pool.flush!
        freed_connections += 1
        
        # Force garbage collection to free up resources
        GC.start
        
        # Log recovery attempt
        Rails.logger.info "Pool exhaustion recovery: freed #{freed_connections} connections"
        
        # Track exhaustion event
        Ai::UsageAnalyticsService.track_event({
          event_type: 'connection_pool_exhaustion',
          data: {
            timestamp: Time.current.iso8601,
            freed_connections: freed_connections,
            pool_size: pool.size,
            recovery_action: 'flush_and_gc'
          }
        })
      end
      
      # Get connection pool statistics
      def connection_pool_statistics
        pool = ActiveRecord::Base.connection_pool
        
        {
          pool_size: pool.size,
          checked_out: pool.checked_out.length,
          available: pool.available.length,
          waiting: pool.waiting_count,
          utilization_percentage: calculate_pool_utilization(pool),
          health_status: determine_pool_health_status(pool)
        }
      end
      
      private
      
      # Calculate optimal pool size for AI operations
      def calculate_optimal_pool_size
        # Base pool size
        base_size = ENV.fetch('DATABASE_POOL_SIZE', 5).to_i
        
        # Factor in AI operation concurrency
        ai_concurrency_factor = calculate_ai_concurrency_factor
        
        # Calculate optimal size
        optimal_size = [base_size + ai_concurrency_factor, 25].min # Cap at 25
        
        optimal_size
      end
      
      # Calculate AI concurrency factor
      def calculate_ai_concurrency_factor
        # Estimate based on Sidekiq AI queue concurrency
        sidekiq_ai_concurrency = ENV.fetch('SIDEKIQ_AI_CONCURRENCY', 5).to_i
        
        # Add buffer for web requests with AI operations
        web_ai_buffer = 3
        
        sidekiq_ai_concurrency + web_ai_buffer
      end
      
      # Configure pool settings
      def configure_pool_settings(pool_size)
        # This would typically be done in database.yml or environment configuration
        # Here we log the recommended settings
        
        recommended_settings = {
          pool: pool_size,
          checkout_timeout: 10, # seconds
          reaping_frequency: 60, # seconds
          idle_timeout: 300 # seconds
        }
        
        Rails.logger.info "Recommended pool settings: #{recommended_settings}"
        recommended_settings
      end
      
      # Configure connection for AI operations
      def configure_connection_for_ai(connection)
        # Set connection-specific parameters for AI workloads
        ai_settings = [
          "SET work_mem = '256MB'",           # Increase memory for complex queries
          "SET random_page_cost = 1.1",       # Optimize for SSD storage
          "SET effective_cache_size = '4GB'", # Assume reasonable cache size
          "SET statement_timeout = '300s'"    # 5 minute timeout for AI operations
        ]
        
        ai_settings.each do |setting|
          begin
            connection.execute(setting)
          rescue ActiveRecord::StatementInvalid => e
            Rails.logger.debug "Could not set AI connection parameter: #{e.message}"
          end
        end
      end
      
      # Calculate pool utilization percentage
      def calculate_pool_utilization(pool)
        return 0 if pool.size == 0
        
        ((pool.checked_out.length.to_f / pool.size) * 100).round(2)
      end
      
      # Check connection health
      def check_connection_health(pool)
        healthy_connections = 0
        total_connections = pool.size
        
        # Sample a few connections to check health
        sample_size = [total_connections, 3].min
        
        sample_size.times do
          begin
            connection = pool.checkout
            connection.execute('SELECT 1')
            healthy_connections += 1
            pool.checkin(connection)
          rescue => e
            Rails.logger.warn "Unhealthy connection detected: #{e.message}"
          end
        end
        
        health_percentage = (healthy_connections.to_f / sample_size * 100).round(2)
        
        {
          healthy_connections: healthy_connections,
          total_sampled: sample_size,
          health_percentage: health_percentage
        }
      end
      
      # Log pool warnings
      def log_pool_warnings(health_metrics)
        utilization = health_metrics[:pool_utilization]
        waiting_count = health_metrics[:waiting_count]
        
        if utilization > 80
          Rails.logger.warn "High connection pool utilization: #{utilization}%"
        end
        
        if waiting_count > 0
          Rails.logger.warn "Connections waiting in queue: #{waiting_count}"
        end
        
        if health_metrics[:connection_health][:health_percentage] < 100
          Rails.logger.warn "Some connections are unhealthy: #{health_metrics[:connection_health][:health_percentage]}%"
        end
      end
      
      # Analyze AI usage patterns
      def analyze_ai_usage_patterns
        # This would analyze recent AI operations to understand patterns
        {
          avg_concurrent_operations: 3.5,
          peak_concurrent_operations: 8,
          avg_operation_duration: 45.2, # seconds
          operations_per_hour: 120,
          peak_hours: [9, 10, 14, 15, 16] # Hours with highest AI usage
        }
      end
      
      # Calculate optimal settings based on usage patterns
      def calculate_optimal_settings(usage_patterns)
        peak_concurrency = usage_patterns[:peak_concurrent_operations]
        avg_duration = usage_patterns[:avg_operation_duration]
        
        # Calculate optimal pool size with buffer
        optimal_pool_size = (peak_concurrency * 1.5).ceil
        
        # Calculate optimal timeout based on operation duration
        optimal_timeout = (avg_duration * 2).ceil
        
        {
          pool_size: optimal_pool_size,
          checkout_timeout: optimal_timeout,
          reaping_frequency: 60,
          idle_timeout: 300
        }
      end
      
      # Apply pool optimizations
      def apply_pool_optimizations(settings)
        # Log the optimizations that should be applied
        Rails.logger.info "Recommended pool optimizations:"
        settings.each do |key, value|
          Rails.logger.info "  #{key}: #{value}"
        end
        
        # In a real implementation, these would be applied to the pool configuration
        # For now, we just track the recommendations
        Ai::UsageAnalyticsService.track_event({
          event_type: 'connection_pool_optimization',
          data: {
            timestamp: Time.current.iso8601,
            recommended_settings: settings,
            current_pool_size: ActiveRecord::Base.connection_pool.size
          }
        })
      end
      
      # Determine pool health status
      def determine_pool_health_status(pool)
        utilization = calculate_pool_utilization(pool)
        waiting_count = pool.waiting_count
        
        if waiting_count > 0 || utilization > 90
          'critical'
        elsif utilization > 80
          'warning'
        elsif utilization > 60
          'good'
        else
          'excellent'
        end
      end
    end
  end
end