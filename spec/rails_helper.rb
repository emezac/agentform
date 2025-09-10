# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'database_cleaner/active_record'
require 'shoulda/matchers'

# Conditionally require sidekiq testing if available
begin
  require 'rspec/sidekiq'
rescue LoadError
  # Sidekiq testing not available
end

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = ["#{::Rails.root}/spec/fixtures"] if defined?(config.fixture_paths)

  # Database cleaning strategy - use transactions for speed, truncation for system tests
  config.use_transactional_fixtures = false

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # Filter gems from backtrace
  config.filter_gems_from_backtrace("factory_bot", "database_cleaner")

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Include Pundit test helpers (if available)
  config.include Pundit::RSpec::DSL, type: :policy if defined?(Pundit::RSpec::DSL)

  # Include custom test helpers
  config.include AuthenticationHelpers
  config.include ApiHelpers, type: :request
  config.include WorkflowHelpers
  config.include ActiveSupport::Testing::TimeHelpers
  
  # Sidekiq testing configuration (if available)
  if defined?(RSpec::Sidekiq)
    config.include RSpec::Sidekiq::Matchers
  end

  # Database cleaning configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    
    # Load test data that should persist across tests
    Rails.application.load_seed if Rails.env.test?
  end

  config.around(:each) do |example|
    # Use truncation for system tests and tests that require it
    if example.metadata[:type] == :system || example.metadata[:js] || example.metadata[:truncation]
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
    
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Clean up after each test
  config.before(:each) do
    Current.reset
    
    # Clear Sidekiq jobs between tests (if available)
    if defined?(Sidekiq::Testing)
      Sidekiq::Worker.clear_all
    end
  end

  config.after(:each) do
    # Reset any global state
    Rails.cache.clear
    
    # Clear any uploaded files in tests
    FileUtils.rm_rf(Rails.root.join('tmp', 'test_uploads')) if Dir.exist?(Rails.root.join('tmp', 'test_uploads'))
  end

  # System test configuration
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  # Performance test configuration
  config.before(:each, type: :performance) do
    # Ensure consistent performance testing environment
    GC.start
    GC.disable
  end

  config.after(:each, type: :performance) do
    GC.enable
  end

  # API test configuration
  config.before(:each, type: :request) do
    # Set default headers for API tests
    @default_headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Sidekiq testing mode (if available)
if defined?(RSpec::Sidekiq)
  RSpec::Sidekiq.configure do |config|
    config.clear_all_enqueued_jobs = true
    config.enable_terminal_colours = true
    config.warn_when_jobs_not_processed_by_sidekiq = true
  end
end