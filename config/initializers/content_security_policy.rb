# frozen_string_literal: true

# Content Security Policy Configuration
# This initializer provides additional CSP configuration and utilities

# CSP violation reporting endpoint should be configured in routes.rb
# See config/routes.rb for the actual route definition

# CSP configuration for different environments
Rails.application.configure do
  # Development: More permissive for easier debugging
  if Rails.env.development?
    config.content_security_policy do |policy|
      policy.default_src :self, :https, :unsafe_eval, :unsafe_inline
      policy.font_src    :self, :https, :data
      policy.img_src     :self, :https, :data
      policy.object_src  :none
      policy.script_src  :self, :https, :unsafe_eval, :unsafe_inline
      policy.style_src   :self, :https, :unsafe_inline
      policy.connect_src :self, :https, :wss, 'ws://localhost:*'
    end
  end

  # Test: Disabled for testing
  if Rails.env.test?
    config.content_security_policy = nil
  end
end

# CSP violation logger
class CSPViolationLogger
  def self.log_violation(violation_report)
    Rails.logger.warn "CSP Violation: #{violation_report.inspect}"
    
    # Send to error tracking service if available
    if defined?(Sentry)
      Sentry.capture_message("CSP Violation", extra: violation_report)
    end
  end
end

# Add CSP violation handling to ApplicationController
Rails.application.config.to_prepare do
  ApplicationController.class_eval do
    # Handle CSP violation reports
    def csp_report
      if request.content_type == 'application/csp-report'
        violation_report = JSON.parse(request.body.read)
        CSPViolationLogger.log_violation(violation_report)
      end
      
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    # Skip CSP for specific actions if needed
    def skip_csp_for_action
      response.headers.delete('Content-Security-Policy')
      response.headers.delete('Content-Security-Policy-Report-Only')
    end
  end
end