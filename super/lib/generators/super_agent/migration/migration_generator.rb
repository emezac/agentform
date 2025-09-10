# frozen_string_literal: true

require 'rails/generators/active_record'

module SuperAgent
  module Generators
    class MigrationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates a migration for SuperAgent workflow execution tracking'

      def create_migration_file
        migration_template 'migration.rb', 'db/migrate/create_super_agent_executions.rb'
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_model_file
        return unless behavior == :invoke
        
        copy_file "../../../lib/super_agent/execution_model.rb", 
                  "app/models/super_agent/execution_model.rb"
      end
    end
  end
end