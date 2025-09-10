# frozen_string_literal: true

SimpleCov.start 'rails' do
  # Coverage threshold - fail if coverage drops below 95%
  minimum_coverage 95
  refuse_coverage_drop
  
  # Exclude files from coverage
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/db/migrate/'
  add_filter '/app/channels/application_cable/'
  add_filter '/app/mailers/application_mailer.rb'
  add_filter '/app/jobs/application_job.rb'
  
  # Group coverage by component type
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Agents', 'app/agents'
  add_group 'Workflows', 'app/workflows'
  add_group 'Jobs', 'app/jobs'
  add_group 'Helpers', 'app/helpers'
  add_group 'Policies', 'app/policies'
  add_group 'Serializers', 'app/serializers'
  
  # Track individual files that need attention
  track_files '{app,lib}/**/*.rb'
  
  # Merge results from parallel test runs
  use_merging true
  merge_timeout 3600 # 1 hour
  
  # Coverage output formats
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Custom coverage directory
  coverage_dir 'coverage'
end