# frozen_string_literal: true

module SuperAgent
  module Workflow
    module Tasks
      # Task for querying ActiveRecord records with scopes
      #
      # @example Usage in a workflow
      #   step :find_projects, uses: :active_record_scope, with: {
      #     model: 'Project',
      #     scope: { status: 'active' },
      #     as: :active_projects
      #   }
      class ActiveRecordScopeTask < Task
        def initialize(name, config = {})
          super(name, config)
          @model_name = config[:model]
          @scope_hash = config[:scope] || {}
          @as_key = config[:as] || @model_name.underscore.pluralize.to_sym
          @order = config[:order]
          @limit = config[:limit]
        end

        def execute(context)
          model_class = @model_name.constantize
          
          raise ArgumentError, "Model '#{@model_name}' not found" unless model_class < ActiveRecord::Base

          scope = model_class.all

          # Apply scope conditions from context
          @scope_hash.each do |key, value|
            actual_value = if value.is_a?(Symbol)
                             context.get(value)
                           else
                             value
                           end
            scope = scope.where(key => actual_value) if actual_value
          end

          scope = scope.order(@order) if @order
          scope = scope.limit(@limit) if @limit

          records = scope.to_a

          { @as_key => records }
        rescue NameError => e
          raise TaskError, "Model class not found: #{@model_name}"
        end

        def self.name
          :active_record_scope
        end
      end
    end
  end
end