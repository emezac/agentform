# frozen_string_literal: true

namespace :super_agent do
  namespace :a2a do
    desc 'Generate Agent Card for a specific workflow'
    task :generate_card, [:workflow_class] => :environment do |t, args|
      workflow_class_name = args[:workflow_class]

      if workflow_class_name.blank?
        puts 'Usage: rake super_agent:a2a:generate_card[WorkflowClassName]'
        puts 'Example: rake super_agent:a2a:generate_card[MyWorkflow]'
        exit 1
      end

      begin
        workflow_class = workflow_class_name.constantize
        card = SuperAgent::A2A::AgentCard.from_workflow(workflow_class)

        puts card.to_json
      rescue NameError => e
        puts "Error: Workflow class '#{workflow_class_name}' not found"
        puts 'Available workflows:'
        if defined?(Rails)
          # Try to load Rails workflows
          Rails.application.eager_load!
          ObjectSpace.each_object(Class).select do |c|
            c < ApplicationWorkflow
          rescue StandardError
            false
          end.each do |wf|
            puts "  - #{wf.name}"
          end
        else
          puts '  No workflows found (Rails not loaded)'
        end
      rescue StandardError => e
        puts "Error generating agent card: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
      end
    end

    desc 'Generate Agent Card for all workflows (gateway mode)'
    task generate_gateway_card: :environment do
      registry = {}

      if defined?(Rails)
        Rails.application.eager_load!
        ObjectSpace.each_object(Class).select do |c|
          c < ApplicationWorkflow
        rescue StandardError
          false
        end.each do |workflow_class|
          path = "/agents/#{workflow_class.name.underscore}"
          registry[path] = workflow_class
        end
      end

      if registry.empty?
        puts 'No workflows found. Make sure your workflows inherit from ApplicationWorkflow.'
        exit 1
      end

      card = SuperAgent::A2A::AgentCard.from_workflow_registry(registry)
      puts card.to_json
    rescue StandardError => e
      puts "Error generating gateway card: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    end

    desc 'Validate Agent Card JSON Schema'
    task :validate_card, [:json_file] => :environment do |t, args|
      json_file = args[:json_file]

      if json_file.blank? || !File.exist?(json_file)
        puts 'Usage: rake super_agent:a2a:validate_card[path/to/agent_card.json]'
        puts 'Example: rake super_agent:a2a:validate_card[tmp/agent_card.json]'
        exit 1
      end

      begin
        json_content = File.read(json_file)
        card = SuperAgent::A2A::AgentCard.from_json(json_content)

        if card.valid?
          puts '✓ Agent Card is valid'
          puts "  Name: #{card.name}"
          puts "  Version: #{card.version}"
          puts "  Capabilities: #{card.capabilities.size}"
          puts "  Service URL: #{card.service_endpoint_url}"
        else
          puts '✗ Agent Card validation failed:'
          card.errors.full_messages.each { |msg| puts "  - #{msg}" }
          exit 1
        end
      rescue JSON::ParserError => e
        puts "✗ Invalid JSON: #{e.message}"
        exit 1
      rescue StandardError => e
        puts "✗ Error validating agent card: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
        exit 1
      end
    end

    desc 'Start A2A server'
    task :serve, %i[port host] => :environment do |t, args|
      port = args[:port]&.to_i || SuperAgent.configuration.a2a_server_port
      host = args[:host] || SuperAgent.configuration.a2a_server_host

      puts 'Starting SuperAgent A2A server...'
      puts "Port: #{port}"
      puts "Host: #{host}"
      puts "Authentication: #{SuperAgent.configuration.a2a_auth_token ? 'enabled' : 'disabled'}"
      puts "SSL: #{SuperAgent.configuration.a2a_server_ssl_enabled? ? 'enabled' : 'disabled'}"

      ssl_config = if SuperAgent.configuration.a2a_server_ssl_enabled?
                     {
                       cert_path: SuperAgent.configuration.a2a_ssl_cert_path,
                       key_path: SuperAgent.configuration.a2a_ssl_key_path,
                     }
                   end

      server = SuperAgent::A2A::Server.new(
        port: port,
        host: host,
        auth_token: SuperAgent.configuration.a2a_auth_token,
        ssl_config: ssl_config
      )

      puts 'Loading workflows...'
      # Load all workflows
      if defined?(Rails)
        Rails.application.eager_load!
        ObjectSpace.each_object(Class).select do |c|
          c < ApplicationWorkflow
        rescue StandardError
          false
        end.each do |workflow_class|
          server.register_workflow(workflow_class)
        end
      end

      puts 'Registered workflows:'
      server.workflow_registry.each do |path, workflow_class|
        puts "  #{workflow_class.name} -> #{path}"
      end

      puts "\nEndpoints:"
      puts '  GET  /.well-known/agent.json  - Agent Card discovery'
      puts '  GET  /health                   - Health check'
      puts '  POST /invoke                   - Skill invocation'

      server.workflow_registry.each do |path, _|
        puts "  GET  #{path}                 - Workflow info"
        puts "  POST #{path}                 - Direct workflow invocation"
      end

      protocol = ssl_config ? 'https' : 'http'
      puts "\nServer starting at #{protocol}://#{host}:#{port}"
      puts "Press Ctrl+C to stop\n\n"

      begin
        server.start
      rescue Interrupt
        puts "\nShutting down server..."
      rescue StandardError => e
        puts "Error starting server: #{e.message}"
        puts e.backtrace.first(10).join("\n") if ENV['DEBUG']
        exit 1
      end
    end

    desc 'Test A2A agent connectivity'
    task :test_agent, %i[agent_url skill] => :environment do |t, args|
      agent_url = args[:agent_url]
      skill_name = args[:skill]

      if agent_url.blank?
        puts 'Usage: rake super_agent:a2a:test_agent[http://agent-url:port,skill_name]'
        puts 'Example: rake super_agent:a2a:test_agent[http://localhost:8080,process_data]'
        exit 1
      end

      begin
        client = SuperAgent::A2A::Client.new(agent_url)

        puts "Testing connectivity to #{agent_url}..."

        # Test health
        print 'Health check... '
        if client.health_check
          puts '✓ PASSED'
        else
          puts '✗ FAILED'
          exit 1
        end

        # Fetch agent card
        print 'Fetching agent card... '
        card = client.fetch_agent_card
        puts '✓ PASSED'
        puts "  Name: #{card.name}"
        puts "  Version: #{card.version}"
        puts "  Capabilities: #{card.capabilities.size}"

        puts "\nAvailable capabilities:"
        card.capabilities.each do |capability|
          puts "  - #{capability.name}: #{capability.description}"
        end

        # Test skill invocation if specified
        if skill_name.present?
          puts "\nTesting skill invocation: #{skill_name}"
          print 'Invoking skill... '
          result = client.invoke_skill(skill_name, { test: true, timestamp: Time.current.iso8601 })
          puts '✓ PASSED'
          puts "Result: #{result.inspect}"
        end

        puts "\n✓ All tests passed!"
      rescue SuperAgent::A2A::SkillNotFoundError => e
        puts "✗ Skill not found: #{e.message}"
        exit 1
      rescue SuperAgent::A2A::NetworkError => e
        puts "✗ Network error: #{e.message}"
        exit 1
      rescue SuperAgent::A2A::AuthenticationError => e
        puts "✗ Authentication error: #{e.message}"
        exit 1
      rescue StandardError => e
        puts "✗ Test failed: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
        exit 1
      end
    end

    desc 'Benchmark A2A performance'
    task :benchmark, %i[agent_url skill requests] => :environment do |t, args|
      agent_url = args[:agent_url]
      skill_name = args[:skill]
      request_count = args[:requests]&.to_i || 10

      if agent_url.blank? || skill_name.blank?
        puts 'Usage: rake super_agent:a2a:benchmark[http://agent-url:port,skill_name,request_count]'
        puts 'Example: rake super_agent:a2a:benchmark[http://localhost:8080,process_data,10]'
        exit 1
      end

      require 'benchmark'

      client = SuperAgent::A2A::Client.new(agent_url)

      puts 'Benchmarking A2A performance...'
      puts "Agent: #{agent_url}"
      puts "Skill: #{skill_name}"
      puts "Requests: #{request_count}"
      puts

      times = []
      errors = 0

      Benchmark.bm(15) do |x|
        x.report('Sequential:') do
          request_count.times do |i|
            start_time = Time.current
            begin
              client.invoke_skill(skill_name, { benchmark: true, request_id: i, timestamp: Time.current.iso8601 })
              times << (Time.current - start_time)
            rescue StandardError => e
              errors += 1
              puts "Request #{i} failed: #{e.message}"
            end
          end
        end

        if request_count >= 5
          x.report('Concurrent:') do
            threads = []
            concurrent_times = []
            mutex = Mutex.new

            request_count.times do |i|
              threads << Thread.new do
                start_time = Time.current
                begin
                  client.invoke_skill(skill_name, { benchmark: true, request_id: i, timestamp: Time.current.iso8601 })
                  mutex.synchronize { concurrent_times << (Time.current - start_time) }
                rescue StandardError => e
                  mutex.synchronize { errors += 1 }
                end
              end
            end
            threads.each(&:join)
            times.concat(concurrent_times)
          end
        end
      end

      if times.any?
        puts "\nPerformance Statistics:"
        puts "  Total requests: #{times.size}"
        puts "  Errors: #{errors}"
        puts "  Success rate: #{((times.size.to_f / (request_count * (request_count >= 5 ? 2 : 1))) * 100).round(2)}%"
        puts "  Average time: #{(times.sum / times.size * 1000).round(2)}ms"
        puts "  Min time: #{(times.min * 1000).round(2)}ms"
        puts "  Max time: #{(times.max * 1000).round(2)}ms"
        puts "  Median time: #{(times.sort[times.size / 2] * 1000).round(2)}ms"
        puts "  95th percentile: #{(times.sort[(times.size * 0.95).to_i] * 1000).round(2)}ms"
        puts "  Throughput: #{(times.size / times.sum).round(2)} req/sec"
      else
        puts "\nNo successful requests to analyze."
      end
    end

    desc 'List all available A2A tasks and capabilities'
    task list: :environment do
      puts 'SuperAgent A2A Integration Status'
      puts '================================='
      puts

      # Check if A2A is enabled
      if SuperAgent.configuration.a2a_server_enabled
        puts "✓ A2A Server: Enabled (port #{SuperAgent.configuration.a2a_server_port})"
      else
        puts '✗ A2A Server: Disabled'
      end

      puts '✓ A2A Client: Available'
      puts

      # List registered workflows
      if defined?(Rails)
        Rails.application.eager_load!
        workflows = ObjectSpace.each_object(Class).select do |c|
          c < ApplicationWorkflow
        rescue StandardError
          false
        end
      else
        workflows = []
      end

      puts "Registered Workflows (#{workflows.size}):"
      if workflows.any?
        workflows.each do |workflow_class|
          definition = workflow_class.workflow_definition
          a2a_tasks = definition.tasks.select { |t| t.is_a?(SuperAgent::Workflow::Tasks::A2aTask) }

          puts "  #{workflow_class.name}"
          puts "    Tasks: #{definition.tasks.size}"
          puts "    A2A Tasks: #{a2a_tasks.size}"

          if a2a_tasks.any?
            a2a_tasks.each do |task|
              puts "      - #{task.name} -> #{task.agent_url} (#{task.skill_name})"
            end
          end
        rescue StandardError => e
          puts "  #{workflow_class.name} (error loading: #{e.message})"
        end
      else
        puts '  No workflows found'
        puts '  Make sure your workflows inherit from ApplicationWorkflow'
      end

      puts

      # List registered A2A agents
      puts 'Registered A2A Agents:'
      if SuperAgent.configuration.a2a_agent_registry.any?
        SuperAgent.configuration.a2a_agent_registry.each do |name, config|
          puts "  #{name}: #{config[:url]}"
          puts "    Auth: #{config[:auth] ? 'Yes' : 'No'}"
          puts "    Timeout: #{config[:timeout] || 'Default'}"
        end
      else
        puts '  No A2A agents registered'
        puts '  Use SuperAgent.configuration.register_a2a_agent to add agents'
      end

      puts
      puts 'A2A Task Registry:'
      if SuperAgent.configuration.tool_registry.registered?(:a2a)
        puts '  ✓ A2A Task registered and available'
      else
        puts '  ✗ A2A Task not registered'
      end
    end

    desc 'Generate A2A server configuration'
    task generate_config: :environment do
      puts 'Generating A2A server configuration...'

      config = {
        server: {
          enabled: true,
          port: 8080,
          host: '0.0.0.0',
          auth_token: 'your-secure-token-here',
          ssl: {
            enabled: false,
            cert_path: 'config/ssl/cert.pem',
            key_path: 'config/ssl/key.pem',
          },
        },
        client: {
          default_timeout: 30,
          max_retries: 3,
          cache_ttl: 300,
        },
        agents: {},
      }

      config_file = Rails.root.join('config/super_agent_a2a.yml')
      File.write(config_file, config.to_yaml)

      puts "✓ Configuration generated: #{config_file}"
      puts '  Edit this file to customize your A2A setup'
    end
  end
end
