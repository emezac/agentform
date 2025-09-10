# frozen_string_literal: true

require 'rails/generators/base'

module SuperAgent
  module Generators
    class A2aServerGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Generates configuration and files for SuperAgent A2A server'

      class_option :port, type: :numeric, default: 8080, desc: 'Server port'
      class_option :auth, type: :boolean, default: false, desc: 'Enable authentication'
      class_option :ssl, type: :boolean, default: false, desc: 'Enable SSL'
      class_option :host, type: :string, default: '0.0.0.0', desc: 'Server host'

      def create_initializer
        template 'initializer.rb.tt', 'config/initializers/super_agent_a2a.rb'
      end

      def create_server_config
        template 'server_config.rb.tt', 'config/super_agent_a2a.rb'
      end

      def create_startup_script
        template 'server_startup.rb.tt', 'bin/super_agent_a2a'
        chmod 'bin/super_agent_a2a', 0o755
      end

      def create_systemd_service
        template 'systemd_service.tt', 'config/super_agent_a2a.service'
      end

      def create_dockerfile
        template 'Dockerfile.a2a.tt', 'Dockerfile.a2a'
      end

      def create_docker_compose
        template 'docker-compose.a2a.yml.tt', 'docker-compose.a2a.yml'
      end

      def create_ssl_directory
        return unless ssl_enabled?

        empty_directory 'config/ssl'
        create_file 'config/ssl/.gitkeep'

        say 'SSL directory created. Please add your SSL certificates:', :yellow
        say '  - config/ssl/cert.pem (SSL certificate)'
        say '  - config/ssl/key.pem (SSL private key)'
      end

      def create_env_example
        template 'env_example.tt', '.env.a2a.example'
      end

      def show_instructions
        say "\n" + ('=' * 60), :green
        say 'SuperAgent A2A Server generated successfully!', :green
        say ('=' * 60), :green

        say "\n📋 Next Steps:", :blue
        say "\n1. Copy environment variables:"
        say '   cp .env.a2a.example .env.a2a'
        say '   # Edit .env.a2a with your configuration'

        if auth_enabled?
          say "\n2. Set authentication token:"
          say '   export SUPER_AGENT_A2A_TOKEN=your-secure-token-here'
        end

        if ssl_enabled?
          say "\n3. Add SSL certificates:"
          say '   # Place your certificates in config/ssl/'
          say '   # - config/ssl/cert.pem'
          say '   # - config/ssl/key.pem'
        end

        say "\n4. Start the server:"
        say '   bin/super_agent_a2a'

        say "\n5. Alternative start methods:"
        say '   # Via rake task:'
        say "   rake super_agent:a2a:serve[#{server_port},#{server_host}]"
        say '   '
        say '   # In production with systemd:'
        say '   sudo cp config/super_agent_a2a.service /etc/systemd/system/'
        say '   sudo systemctl enable super_agent_a2a'
        say '   sudo systemctl start super_agent_a2a'
        say '   '
        say '   # With Docker:'
        say '   docker build -f Dockerfile.a2a -t superagent-a2a .'
        say "   docker run -p #{server_port}:#{server_port} superagent-a2a"
        say '   '
        say '   # With Docker Compose:'
        say '   docker-compose -f docker-compose.a2a.yml up'

        say "\n6. Test the server:"
        say '   # Health check:'
        say "   curl http://#{server_host}:#{server_port}/health"
        say '   '
        say '   # Agent card:'
        say "   curl http://#{server_host}:#{server_port}/.well-known/agent.json"

        say "\n7. Available endpoints:", :yellow
        say '   GET  /.well-known/agent.json  - Agent Card discovery'
        say '   GET  /health                   - Health check'
        say '   POST /invoke                   - Skill invocation'
        say '   GET  /                         - Server information'

        say "\n📚 Documentation:"
        say '   https://github.com/superagent-ai/superagent/blob/main/docs/a2a-protocol.md'

        say "\n" + ('=' * 60), :green
      end

      private

      def auth_enabled?
        options[:auth]
      end

      def ssl_enabled?
        options[:ssl]
      end

      def server_port
        options[:port]
      end

      def server_host
        options[:host]
      end

      def app_name
        Rails.application.class.name.split('::').first.underscore
      end

      def secret_token
        SecureRandom.hex(32)
      end
    end
  end
end
