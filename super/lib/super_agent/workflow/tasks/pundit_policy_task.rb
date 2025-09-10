# frozen_string_literal: true

module SuperAgent
  module Workflow
    module Tasks
      # Task for checking Pundit policy authorization
      #
      # @example Usage in a workflow
      #   step :authorize_user, uses: :pundit_policy, with: {
      #     record: :project,
      #     action: :update?
      #   }
      class PunditPolicyTask < Task

        def initialize(name, config = {})
          super(name, config)
          @record_key = config[:record]
          @action = config[:action]
          @policy_class = config[:policy_class]
          @user_key = config[:user] || :current_user
        end

        def execute(context)
          unless defined?(Pundit)
            raise TaskError, "Pundit gem is not available. Please add `gem 'pundit'` to your Gemfile."
          end

          user = context.get(@user_key)
          record = context.get(@record_key)

          raise ArgumentError, "User not found in context: #{@user_key}" unless user
          raise ArgumentError, "Record not found in context: #{@record_key}" unless record

          policy = if @policy_class
                     @policy_class.new(user, record)
                   else
                     Pundit.policy(user, record)
                   end

          authorized = policy.send(@action)

          unless authorized
            raise TaskError, "User #{user.id} not authorized to #{@action} on #{record.class.name}##{record.id}"
          end

          { authorized: true, user: user, record: record, action: @action }
        end

        def self.name
          :pundit_policy
        end
      end
    end
  end
end