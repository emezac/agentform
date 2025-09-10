# frozen_string_literal: true

require "rails/generators"

module SuperAgent
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install SuperAgent into a Rails application"

      def create_initializer
        template "super_agent.rb", "config/initializers/super_agent.rb"
      end

      def create_workflow_base
        template "application_workflow.rb", "app/workflows/application_workflow.rb"
      end

      def create_agent_base
        template "application_agent.rb", "app/agents/application_agent.rb"
      end

      def create_directories
        empty_directory "app/workflows"
        empty_directory "app/agents"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end

      private

      def app_name
        Rails.application.class.name.split("::").first
      end
    end
  end
end
EOF < /dev/null