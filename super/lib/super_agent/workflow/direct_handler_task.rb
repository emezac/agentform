# frozen_string_literal: true

module SuperAgent
  module Workflow
    # Task for executing simple Ruby code blocks or method calls
    class DirectHandlerTask < Task
      def validate!
        unless config[:with] || config[:method]
          raise SuperAgent::ConfigurationError, "DirectHandlerTask requires :with (proc) or :method configuration"
        end
        super
      end

      def execute(context)
        # La validación ahora debe buscar dentro del hash `with`.
        unless config.dig(:with, :handler) || config.dig(:with, :method)
          raise SuperAgent::ConfigurationError, "DirectHandlerTask requires :handler or :method inside :with"
        end

        handler_config = config[:with]
        handler = handler_config[:handler] || handler_config[:method]

        if handler_config[:handler] && handler.respond_to?(:call)
          # Llamamos al proc con el contexto. Esta es la forma correcta y segura.
          handler.call(context)
        elsif handler_config[:method]
          context.get(handler)
        else
          # Fallback si solo se pasa un valor directo en :with
          handler_config
        end
      end

      def description
        "Direct handler execution for #{name}"
      end
    end
  end
end