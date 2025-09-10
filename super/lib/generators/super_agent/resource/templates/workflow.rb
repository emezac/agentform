# frozen_string_literal: true

class <%= class_name %>Workflow < ApplicationWorkflow
  # Define your workflow steps here
  
  # Example:
  # define_task :validate_input, :direct_handler do |config|
  #   config.handler = ->(context) {
  #     # Validation logic here
  #     { valid: true }
  #   }
  # end
  
  # define_task :process_with_llm, :llm do |config|
  #   config.system_prompt = "Process <%= file_name.humanize.downcase %> data"
  #   config.template = "Data: {{input}}"
  # end
  
  # define_task :finalize, :direct_handler do |config|
  #   config.handler = ->(context) {
  #     { result: "Processed #{file_name}" }
  #   }
  # end
end
EOF < /dev/null