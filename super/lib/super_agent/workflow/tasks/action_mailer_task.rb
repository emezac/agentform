# frozen_string_literal: true

module SuperAgent
  module Workflow
    module Tasks
      # Task for sending emails via ActionMailer
      #
      # @example Usage in a workflow
      #   step :send_welcome_email, uses: :action_mailer, with: {
      #     mailer: 'UserMailer',
      #     action: 'welcome_email',
      #     params: { user: :user, project: :project }
      #   }
      class ActionMailerTask < Task
        def initialize(name, config = {})
          super(name, config)
          @mailer_name = config[:mailer]
          @action = config[:action]
          @params = config[:params] || {}
          @delivery_method = config[:delivery_method] || :deliver_now
        end

        def execute(context)
          mailer_class = @mailer_name.constantize
          
          raise ArgumentError, "Mailer '#{@mailer_name}' not found" unless mailer_class < ActionMailer::Base

          # Resolve parameters from context
          resolved_params = {}
          @params.each do |key, value|
            resolved_params[key] = if value.is_a?(Symbol)
                                     context.get(value)
                                   else
                                     value
                                   end
          end

          mail = mailer_class.send(@action, **resolved_params)

          case @delivery_method
          when :deliver_now
            mail.deliver_now
          when :deliver_later
            mail.deliver_later
          else
            raise ArgumentError, "Invalid delivery method: #{@delivery_method}"
          end

          { 
            mail_sent: true,
            mailer: @mailer_name,
            action: @action,
            delivery_method: @delivery_method,
            message_id: mail.message_id
          }
        rescue NameError => e
          raise TaskError, "Mailer class not found: #{@mailer_name}"
        rescue => e
          raise TaskError, "Email delivery failed: #{e.message}"
        end

        def self.name
          :action_mailer
        end
      end
    end
  end
end