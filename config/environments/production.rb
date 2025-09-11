require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on AWS S3 in production (see config/storage.yml for options).
  config.active_storage.service = :amazon

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  config.action_cable.allowed_request_origins = ['https://mydialogform.com']
  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use Redis for caching in production - configuration handled by RedisConfig
  # This will be overridden by config/initializers/redis.rb

  # Use Sidekiq for background jobs in production
  config.active_job.queue_adapter = :sidekiq

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch('APP_DOMAIN', 'localhost') }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # Allow requests from Heroku domain
  config.hosts = [
    ENV.fetch('APP_DOMAIN', 'localhost'),
    /.*\.herokuapp\.com/
  ]
  
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" || request.path == "/health" } }
  
  # Heroku-specific configurations
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  
  # Configure email delivery via SendGrid
  #config.action_mailer.delivery_method = :smtp
  # config.action_mailer.smtp_settings = {
  #   user_name: ENV['SMTP_USERNAME'],
  #   password: ENV['SENDGRID_API_KEY'],
  #   domain: ENV.fetch('APP_DOMAIN', 'localhost'),
  #   address: ENV.fetch('SMTP_ADDRESS', 'smtp.sendgrid.net'),
  #   port: ENV.fetch('SMTP_PORT', 587).to_i,
  #   authentication: :plain,
  #   enable_starttls_auto: true
  # }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              "smtp.gmail.com",
    port:                 587,
    user_name:            ENV["GMAIL_USER"],
    password:             ENV["GMAIL_PASS"],
    authentication:       "plain",
    enable_starttls_auto: true
  }
  config.action_mailer.default_url_options = { host: "https://mydialogform-b93454ae9225.herokuapp.com/" }

  
  # Security configurations
  config.force_ssl = true
  
  # Configure secure cookies
  config.session_store :cookie_store, 
    key: '_mydialogform_session',
    secure: true,
    httponly: true,
    same_site: :lax
  
  # Content Security Policy - Configured for Rails app with inline scripts
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, 'blob:'
    policy.object_src  :none
    # Allow inline scripts and external CDNs
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval, 
                       'https://cdn.tailwindcss.com',
                       'https://js.stripe.com',
                       'https://www.paypal.com'
    policy.style_src   :self, :https, :unsafe_inline
    # Allow WebSocket connections for ActionCable
    policy.connect_src :self, :https, :wss, 
                       "wss://#{ENV.fetch('APP_DOMAIN', 'localhost')}"
    # Allow frames for payment providers
    policy.frame_src   :self, :https,
                       'https://js.stripe.com',
                       'https://www.paypal.com'
  end
  
  # Configure CORS for API endpoints
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins ENV.fetch('APP_DOMAIN', 'localhost')
      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        credentials: true
    end
  end
  
  # Configure logging for Heroku
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end
  
  # Configure log level and tags
  config.log_level = :info
  config.log_tags = [ :request_id ]
end
