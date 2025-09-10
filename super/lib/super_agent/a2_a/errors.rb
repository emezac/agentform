# frozen_string_literal: true

module SuperAgent
  module A2A
    module Errors
      # Base error class for all A2A-related errors
      class Error < StandardError; end

      # Specific error types for A2A operations
      class AgentCardError < Error; end
      class InvocationError < Error; end
      class SkillNotFoundError < Error; end
      class AuthenticationError < Error; end
      class ValidationError < Error; end
      class TimeoutError < Error; end
      class NetworkError < Error; end
      class ProtocolError < Error; end

      # Error handler utility for wrapping network and protocol errors
      class ErrorHandler
        class << self
          def wrap_network_error(error)
            case error
            when Net::TimeoutError, Timeout::Error
              TimeoutError.new("Request timeout: #{error.message}")
            when Net::HTTPError, SocketError
              NetworkError.new("Network error: #{error.message}")
            when JSON::ParserError
              ProtocolError.new("Invalid JSON response: #{error.message}")
            when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT
              NetworkError.new("Connection error: #{error.message}")
            else
              Error.new("Unexpected error: #{error.message}")
            end
          end

          def wrap_validation_error(message, field = nil)
            full_message = field ? "#{field}: #{message}" : message
            ValidationError.new(full_message)
          end

          def wrap_authentication_error(message = 'Authentication failed')
            AuthenticationError.new(message)
          end

          def wrap_skill_error(skill_name, available_skills = [])
            message = "Skill '#{skill_name}' not found"
            message += ". Available skills: #{available_skills.join(', ')}" if available_skills.any?
            SkillNotFoundError.new(message)
          end
        end
      end
    end
  end
end
