# frozen_string_literal: true

module SuperAgent
  module Workflow
    module Tasks
      # Task for finding ActiveRecord records
      #
      # @example Usage in a workflow
      #   step :find_user, uses: :active_record_find, with: {
      #     model: 'User',
      #     id: :user_id,
      #     as: :user
      #   }
      class ActiveRecordFindTask < Task
        def initialize(name, config = {})
          super(name, config)
          @model_name = config[:model]
          @id_key = config[:id]
          @as_key = config[:as] || @model_name.underscore.to_sym
          @scope_key = config[:scope]
        end

        def execute(context)
          model_class = @model_name.constantize
          id_value = context.get(@id_key)

          raise ArgumentError, "Model '#{@model_name}' not found" unless model_class < ActiveRecord::Base
          raise ArgumentError, "ID value not found in context: #{@id_key}" unless id_value

          record = if @scope_key
                     scope = context.get(@scope_key)
                     raise ArgumentError, "Scope not found in context: #{@scope_key}" unless scope
                     model_class.where(scope).find(id_value)
                   else
                     model_class.find(id_value)
                   end

          { @as_key => record }
        rescue ActiveRecord::RecordNotFound => e
          raise TaskError, "Record not found: #{@model_name}##{id_value}" 
        rescue NameError => e
          raise TaskError, "Model class not found: #{@model_name}"
        end

        def self.name
          :active_record_find
        end
      end
    end
  end
end