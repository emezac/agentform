module SuperAgent
  module Workflow
    module Tasks
      class LlmCompletionTask < Task
        def execute(context)
          prompt = context.get(:prompt) || context.get(:messages)
          model = context.get(:model) || SuperAgent.configuration.default_llm_model
          temperature = context.get(:temperature) || 0.7
          max_tokens = context.get(:max_tokens)

          response = SuperAgent::LLMInterface.new.complete(
            prompt: prompt,
            model: model,
            temperature: temperature,
            max_tokens: max_tokens
          )

          { content: response }
        end
      end
    end
  end
end