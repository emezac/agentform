# frozen_string_literal: true

# A2A Protocol Module Loader
# This file loads all A2A components in the correct order

module SuperAgent
  module A2A
    # Load error classes first
    require_relative 'a2a/errors'

    # Load utility classes
    require_relative 'a2a/utils/cache_manager'
    require_relative 'a2a/utils/retry_manager'
    require_relative 'a2a/utils/json_validator'

    # Load core classes
    require_relative 'a2a/part'
    require_relative 'a2a/artifact'
    require_relative 'a2a/message'
    require_relative 'a2a/agent_card'

    # Load client and server components
    require_relative 'a2a/client'

    # Load middleware
    require_relative 'a2a/middleware/logging_middleware'
    require_relative 'a2a/middleware/cors_middleware'
    require_relative 'a2a/middleware/auth_middleware'

    # Load handlers
    require_relative 'a2a/handlers/agent_card_handler'
    require_relative 'a2a/handlers/health_handler'
    require_relative 'a2a/handlers/invoke_handler'

    # Load server (last since it depends on other components)
    require_relative 'a2a/server'
  end
end
