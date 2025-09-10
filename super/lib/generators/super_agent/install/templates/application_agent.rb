# frozen_string_literal: true

# Base agent class for all SuperAgent agents in this application
class ApplicationAgent < SuperAgent::Base
  # Add common methods here that apply to all agents
  
  # Example: Common error handling
  # def handle_workflow_error(result)
  #   Rails.logger.error "Workflow failed: #{result.error_message}"
  #   { error: result.error_message }
  # end
end
EOF < /dev/null