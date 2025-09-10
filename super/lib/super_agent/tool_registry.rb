# frozen_string_literal: true

module SuperAgent
  # Registry for managing available tasks/tools
  class ToolRegistry
    def initialize
      @tools = {}
      register_default_tools
    end

    # Register a new tool with the registry
    def register(name, tool_class)
      @tools[name.to_sym] = tool_class
    end

    # Get a tool by name
    def get(name)
      @tools[name.to_sym] or raise ArgumentError, "Tool not found: #{name}"
    end

    # List all registered tool names
    def tool_names
      @tools.keys
    end

    # Check if a tool is registered
    def registered?(name)
      @tools.key?(name.to_sym)
    end

    private

    def register_default_tools
      # Ensure all task classes are loaded
      begin
        require_relative 'workflow/tasks/llm_task' unless defined?(SuperAgent::Workflow::Tasks::LlmTask)
        require_relative 'workflow/tasks/web_search_task' unless defined?(SuperAgent::Workflow::Tasks::WebSearchTask)
        require_relative 'workflow/tasks/file_upload_task' unless defined?(SuperAgent::Workflow::Tasks::FileUploadTask)
        unless defined?(SuperAgent::Workflow::Tasks::VectorStoreManagementTask)
          require_relative 'workflow/tasks/vector_store_management_task'
        end
        require_relative 'workflow/tasks/file_search_task' unless defined?(SuperAgent::Workflow::Tasks::FileSearchTask)
        require_relative 'workflow/tasks/cron_task' unless defined?(SuperAgent::Workflow::Tasks::CronTask)
        require_relative 'workflow/tasks/markdown_task' unless defined?(SuperAgent::Workflow::Tasks::MarkdownTask)
        unless defined?(SuperAgent::Workflow::Tasks::ImageGenerationTask)
          require_relative 'workflow/tasks/image_generation_task'
        end
        require_relative 'workflow/direct_handler_task' unless defined?(SuperAgent::Workflow::Tasks::DirectHandlerTask)
        unless defined?(SuperAgent::Workflow::Tasks::LlmCompletionTask)
          require_relative 'workflow/tasks/llm_completion_task'
        end
        unless defined?(SuperAgent::Workflow::Tasks::PunditPolicyTask)
          require_relative 'workflow/tasks/pundit_policy_task'
        end
        unless defined?(SuperAgent::Workflow::Tasks::ActiveRecordFindTask)
          require_relative 'workflow/tasks/active_record_find_task'
        end
        unless defined?(SuperAgent::Workflow::Tasks::ActiveRecordScopeTask)
          require_relative 'workflow/tasks/active_record_scope_task'
        end
        unless defined?(SuperAgent::Workflow::Tasks::ActionMailerTask)
          require_relative 'workflow/tasks/action_mailer_task'
        end
        unless defined?(SuperAgent::Workflow::Tasks::TurboStreamTask)
          require_relative 'workflow/tasks/turbo_stream_task'
        end
        require_relative 'workflow/tasks/a2a_task' unless defined?(SuperAgent::Workflow::Tasks::A2aTask)
      rescue LoadError => e
        # Files may not exist in all environments
      end

      # Register available tools
      if defined?(SuperAgent::Workflow::Tasks::DirectHandlerTask)
        register(:direct_handler, SuperAgent::Workflow::Tasks::DirectHandlerTask)
      end
      register(:llm, SuperAgent::Workflow::Tasks::LlmTask) if defined?(SuperAgent::Workflow::Tasks::LlmTask)
      register(:llm_task, SuperAgent::Workflow::Tasks::LlmTask) if defined?(SuperAgent::Workflow::Tasks::LlmTask)
      if defined?(SuperAgent::Workflow::Tasks::LlmCompletionTask)
        register(:llm_completion, SuperAgent::Workflow::Tasks::LlmCompletionTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::PunditPolicyTask)
        register(:pundit_policy, SuperAgent::Workflow::Tasks::PunditPolicyTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::ActiveRecordFindTask)
        register(:active_record_find, SuperAgent::Workflow::Tasks::ActiveRecordFindTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::ActiveRecordScopeTask)
        register(:active_record_scope, SuperAgent::Workflow::Tasks::ActiveRecordScopeTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::ActionMailerTask)
        register(:action_mailer, SuperAgent::Workflow::Tasks::ActionMailerTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::TurboStreamTask)
        register(:turbo_stream, SuperAgent::Workflow::Tasks::TurboStreamTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::WebSearchTask)
        register(:web_search, SuperAgent::Workflow::Tasks::WebSearchTask)
      end
      register(:a2a, SuperAgent::Workflow::Tasks::A2aTask) if defined?(SuperAgent::Workflow::Tasks::A2aTask)
      if defined?(SuperAgent::Workflow::Tasks::FileUploadTask)
        register(:file_upload, SuperAgent::Workflow::Tasks::FileUploadTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::VectorStoreManagementTask)
        register(:vector_store_management, SuperAgent::Workflow::Tasks::VectorStoreManagementTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::FileSearchTask)
        register(:file_search, SuperAgent::Workflow::Tasks::FileSearchTask)
      end
      register(:cron, SuperAgent::Workflow::Tasks::CronTask) if defined?(SuperAgent::Workflow::Tasks::CronTask)
      if defined?(SuperAgent::Workflow::Tasks::MarkdownTask)
        register(:markdown, SuperAgent::Workflow::Tasks::MarkdownTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::ImageGenerationTask)
        register(:image_generation, SuperAgent::Workflow::Tasks::ImageGenerationTask)
      end
      if defined?(SuperAgent::Workflow::Tasks::AssistantTask)
        register(:assistant, SuperAgent::Workflow::Tasks::AssistantTask)
      end
      return unless defined?(SuperAgent::Workflow::Tasks::FileContentTask)

      register(:file_content, SuperAgent::Workflow::Tasks::FileContentTask)
    end
  end
end
