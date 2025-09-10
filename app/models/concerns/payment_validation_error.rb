# frozen_string_literal: true

# Custom error class for payment validation failures
# Provides structured error information with actionable guidance
class PaymentValidationError < StandardError
  attr_reader :error_type, :required_actions, :user_guidance

  def initialize(error_type:, required_actions: [], user_guidance: {})
    @error_type = error_type
    @required_actions = required_actions
    @user_guidance = user_guidance
    
    message = user_guidance[:message] || "Payment validation failed: #{error_type}"
    super(message)
  end

  # Returns a hash representation of the error for API responses
  def to_hash
    {
      error_type: error_type,
      message: message,
      required_actions: required_actions,
      user_guidance: user_guidance
    }
  end

  # Returns a JSON representation of the error
  def to_json(*args)
    to_hash.to_json(*args)
  end

  # Checks if this error is of a specific type
  def type?(check_type)
    error_type.to_s == check_type.to_s
  end

  # Returns true if the error has actionable steps
  def actionable?
    required_actions.any?
  end

  # Returns the primary action URL if available
  def primary_action_url
    user_guidance[:action_url]
  end

  # Returns the primary action text if available
  def primary_action_text
    user_guidance[:action_text]
  end
end