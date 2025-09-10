# frozen_string_literal: true

# Base workflow class for all SuperAgent workflows in this application
class ApplicationWorkflow < SuperAgent::WorkflowDefinition
  # Add common configuration here that applies to all workflows
  
  # Example: Set default error handling for all workflows
  # on_error do |error, context|
  #   Rails.logger.error "Workflow error: #{error.message}"
  #   Rails.logger.error "Context: #{context.to_h}"
  # end
end
EOF < /dev/null