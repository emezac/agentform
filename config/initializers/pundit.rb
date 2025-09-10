# frozen_string_literal: true

# Pundit configuration for AgentForm
# Note: Pundit doesn't have a global configure method, configuration is done per-controller

# Set default policy class if needed
# This can be overridden in individual controllers
Pundit::Configuration.default_policy_class = "ApplicationPolicy" if defined?(Pundit::Configuration)

# Log authorization failures in development
if Rails.env.development?
  ActiveSupport::Notifications.subscribe('pundit.policy_scoped') do |name, start, finish, id, payload|
    Rails.logger.debug "Pundit policy scoped: #{payload[:policy_class]} for #{payload[:scope_class]}"
  end

  ActiveSupport::Notifications.subscribe('pundit.authorize') do |name, start, finish, id, payload|
    Rails.logger.debug "Pundit authorize: #{payload[:policy_class]}##{payload[:query]} for #{payload[:record_class]}"
  end
end