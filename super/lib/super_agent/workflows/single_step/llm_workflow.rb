module SuperAgent
  module Workflows
    module SingleStep
      class LlmWorkflow < WorkflowDefinition
        steps do
          step :llm_completion, uses: :llm_completion
        end
      end
    end
  end
end