# frozen_string_literal: true

# Pagination Configuration and Verification
# This initializer verifies that pagination dependencies are properly loaded
# and provides diagnostic information for troubleshooting

Rails.application.config.after_initialize do
  # Verify Kaminari availability and configuration
  pagination_status = verify_pagination_configuration
  
  # Log the status
  log_pagination_status(pagination_status)
  
  # Set up monitoring if available
  setup_pagination_monitoring(pagination_status)
end

def verify_pagination_configuration
  status = {
    kaminari_defined: defined?(Kaminari),
    kaminari_version: nil,
    activerecord_integration: false,
    actionview_integration: false,
    configuration_valid: false,
    error_details: []
  }

  begin
    if status[:kaminari_defined]
      # Check Kaminari version
      status[:kaminari_version] = Kaminari::VERSION if defined?(Kaminari::VERSION)
      
      # Test ActiveRecord integration
      if defined?(ActiveRecord::Base)
        test_relation = ActiveRecord::Base.connection.execute("SELECT 1 LIMIT 1")
        dummy_relation = User.limit(1) if defined?(User)
        
        if dummy_relation&.respond_to?(:page)
          status[:activerecord_integration] = true
        else
          status[:error_details] << "ActiveRecord integration missing - .page method not available"
        end
      end
      
      # Test ActionView integration (for pagination helpers)
      if defined?(ActionView::Base)
        if ActionView::Base.instance_methods.include?(:paginate)
          status[:actionview_integration] = true
        else
          status[:error_details] << "ActionView integration missing - paginate helper not available"
        end
      end
      
      # Overall configuration validity
      status[:configuration_valid] = status[:activerecord_integration] && status[:actionview_integration]
      
    else
      status[:error_details] << "Kaminari gem not loaded or not available"
    end
    
  rescue => e
    status[:error_details] << "Error during pagination verification: #{e.message}"
    Rails.logger.error "Pagination verification failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
  end

  status
end

def log_pagination_status(status)
  if status[:configuration_valid]
    Rails.logger.info "✅ Pagination system fully operational"
    Rails.logger.info "   Kaminari version: #{status[:kaminari_version]}"
    Rails.logger.info "   ActiveRecord integration: ✅"
    Rails.logger.info "   ActionView integration: ✅"
  elsif status[:kaminari_defined]
    Rails.logger.warn "⚠️  Pagination system partially available"
    Rails.logger.warn "   Kaminari version: #{status[:kaminari_version]}"
    Rails.logger.warn "   ActiveRecord integration: #{status[:activerecord_integration] ? '✅' : '❌'}"
    Rails.logger.warn "   ActionView integration: #{status[:actionview_integration] ? '✅' : '❌'}"
    Rails.logger.warn "   Issues: #{status[:error_details].join(', ')}"
  else
    Rails.logger.warn "❌ Pagination system not available - using fallback mode"
    Rails.logger.warn "   Kaminari: Not loaded"
    Rails.logger.warn "   Fallback pagination will be used automatically"
    Rails.logger.warn "   Issues: #{status[:error_details].join(', ')}" if status[:error_details].any?
  end
  
  # Store status for runtime access
  Rails.application.config.pagination_status = status
end

def setup_pagination_monitoring(status)
  # Send initial status to error tracking
  if defined?(Sentry) && !status[:configuration_valid]
    Sentry.capture_message(
      "Pagination system not fully operational",
      level: status[:kaminari_defined] ? :warning : :error,
      extra: {
        pagination_status: status,
        environment: Rails.env,
        timestamp: Time.current
      }
    )
  end
  
  # Set up metrics if available
  if defined?(StatsD)
    StatsD.gauge('pagination.kaminari_available', status[:kaminari_defined] ? 1 : 0)
    StatsD.gauge('pagination.fully_operational', status[:configuration_valid] ? 1 : 0)
  end
end

# Add helper method to check pagination status at runtime
module PaginationStatus
  def self.kaminari_available?
    Rails.application.config.pagination_status&.dig(:kaminari_defined) || false
  end
  
  def self.fully_operational?
    Rails.application.config.pagination_status&.dig(:configuration_valid) || false
  end
  
  def self.status
    Rails.application.config.pagination_status || {}
  end
  
  def self.diagnostic_info
    status = Rails.application.config.pagination_status || {}
    
    {
      kaminari_available: status[:kaminari_defined],
      kaminari_version: status[:kaminari_version],
      activerecord_integration: status[:activerecord_integration],
      actionview_integration: status[:actionview_integration],
      fully_operational: status[:configuration_valid],
      errors: status[:error_details],
      fallback_mode: !status[:configuration_valid],
      timestamp: Time.current,
      environment: Rails.env
    }
  end
end