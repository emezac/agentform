# frozen_string_literal: true

# lib/super_agent/workflow_definition.rb

module SuperAgent
  class WorkflowDefinition
    class << self
      attr_reader :steps_definition, :workflow_config

      # Nueva sintaxis principal con DSL amigable
      def workflow(&block)
        @workflow_builder = WorkflowBuilder.new
        @workflow_builder.instance_eval(&block)
        @steps_definition = @workflow_builder.build_steps
        @workflow_config = @workflow_builder.config
      end

      # Mantener compatibilidad con sintaxis antigua
      def steps(&block)
        if SuperAgent.configuration.deprecation_warnings
          warn '[DEPRECATION] `steps` is deprecated. Please use `workflow` instead.'
        end
        @steps_definition = []
        instance_eval(&block) if block_given?
      end

      def step(name, **config)
        if SuperAgent.configuration.deprecation_warnings
          warn '[DEPRECATION] Direct `step` calls are deprecated. Please use `task` inside a `workflow` block.'
        end
        @steps_definition ||= []
        @steps_definition << { name: name.to_sym, config: config }
      end

      # Alias para compatibilidad
      alias define_task step

      def all_steps
        @steps_definition || []
      end
    end

    # Builder principal para el workflow
    class WorkflowBuilder
      attr_reader :steps, :config

      def initialize
        @steps = []
        @config = {
          error_handlers: {},
          before_hooks: [],
          after_hooks: [],
          timeout: nil,
          retry_policy: nil,
        }
      end

      # =====================
      # TAREAS PRINCIPALES
      # =====================

      # Método principal para definir cualquier tipo de tarea
      def task(name, type_or_options = {}, &block)
        if type_or_options.is_a?(Symbol)
          # task :name, :type
          type = type_or_options
          configurator = TaskConfigurator.new(name, type)
        elsif type_or_options.is_a?(Hash)
          # task :name, { type: :llm, prompt: "..." }
          type = type_or_options.delete(:type) || :direct_handler
          configurator = TaskConfigurator.new(name, type)
          type_or_options.each { |k, v| configurator.send(k, v) }
        else
          # task :name (default to direct_handler)
          configurator = TaskConfigurator.new(name, :direct_handler)
        end

        configurator.instance_eval(&block) if block_given?
        @steps << configurator.build
      end

      # =====================
      # ATAJOS PARA TIPOS COMUNES
      # =====================

      # LLM tasks con sintaxis simplificada
      def llm(name, prompt_text = nil, **options, &block)
        task(name, :llm) do
          prompt(prompt_text) if prompt_text
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # Chat completion (alias para llm)
      def chat(name, prompt_text = nil, **options, &block)
        llm(name, prompt_text, **options, &block)
      end

      # Validation tasks
      def validate(name, &block)
        configurator = TaskConfigurator.new(name, :direct_handler)
        configurator.validation(true)
        configurator.instance_eval(&block) if block_given?
        @steps << configurator.build
      end

      # Database queries
      def fetch(name, model_name, **options, &block)
        task(name, :active_record_find) do
          model model_name
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      def query(name, model_name, **options, &block)
        task(name, :active_record_scope) do
          model model_name
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # Email tasks
      def email(name, mailer_class, action_name, **options, &block)
        task(name, :action_mailer) do
          mailer mailer_class
          action action_name
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # Image generation
      def image(name, prompt_text = nil, **options, &block)
        task(name, :image_generation) do
          prompt(prompt_text) if prompt_text
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # File operations
      def upload_file(name, file_path, **options, &block)
        task(name, :file_upload) do
          file_path file_path
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # Web search
      def search(name, query = nil, **options, &block)
        task(name, :web_search) do
          query(query) if query
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # Turbo Stream tasks
      def stream(name, **options, &block)
        task(name, :turbo_stream) do
          options.each { |k, v| send(k, v) }
          instance_eval(&block) if block_given?
        end
      end

      # A2A Agent tasks
      def a2a_agent(name, agent_url = nil, **options, &block)
        if agent_url
          # Simple inline configuration: a2a_agent :name, "http://agent:8080", skill: "process_data"
          task(name, :a2a) do
            agent_url agent_url
            options.each { |k, v| send(k, v) }
            instance_eval(&block) if block_given?
          end
        elsif block_given?
          # Block configuration: a2a_agent :name do ... end
          task(name, :a2a, &block)
        else
          raise ArgumentError, 'Either agent_url or configuration block is required for a2a_agent'
        end
      end

      # =====================
      # HOOKS Y CONFIGURACIÓN GLOBAL
      # =====================

      def before_all(&block)
        @config[:before_hooks] << block
      end

      def after_all(&block)
        @config[:after_hooks] << block
      end

      def on_error(step_name = :global, &block)
        @config[:error_handlers][step_name] = block
      end

      def timeout(seconds)
        @config[:timeout] = seconds
      end

      def retry_policy(max_retries:, delay: 1)
        @config[:retry_policy] = { max_retries: max_retries, delay: delay }
      end

      # =====================
      # FLOW CONTROL
      # =====================

      def parallel(*task_names, &block)
        # TODO: Implement parallel execution
        task_names.each { |name| task(name, &block) }
      end

      def conditional(name, condition, &block)
        task(name) do
          run_if(&condition)
          instance_eval(&block)
        end
      end

      def build_steps
        @steps
      end
    end

    # Configurador mejorado para tareas individuales
    class TaskConfigurator
      attr_reader :name, :type, :config

      def initialize(name, type)
        @name = name
        @type = type
        @config = { uses: type, with: {} }
        @inputs = []
        @outputs = []
        @conditions = []
        @meta = {}
      end

      # =====================
      # CONFIGURACIÓN BÁSICA
      # =====================

      def input(*keys)
        @inputs.concat(keys)
        self
      end

      def output(*keys)
        @outputs.concat(keys)
        self
      end

      def description(text)
        @meta[:description] = text
        self
      end

      def tags(*tag_list)
        @meta[:tags] = tag_list
        self
      end

      # =====================
      # CONDICIONES
      # =====================

      def run_if(&block)
        @conditions << block
        self
      end

      def skip_if(&block)
        @conditions << ->(ctx) { !block.call(ctx) }
        self
      end

      def run_when(key, value = true)
        @conditions << ->(ctx) { ctx.get(key) == value }
        self
      end

      def skip_when(key, value = true)
        @conditions << ->(ctx) { ctx.get(key) != value }
        self
      end

      # =====================
      # HANDLERS Y PROCESOS
      # =====================

      def process(&block)
        @config[:with][:handler] = wrap_handler(block)
        self
      end

      def handler(proc = nil, &block)
        handler_proc = proc || block
        @config[:with][:handler] = wrap_handler(handler_proc)
        self
      end

      # =====================
      # CONFIGURACIÓN LLM
      # =====================

      def prompt(text = nil, &block)
        if block_given?
          store_config(:prompt, block)
        elsif text
          store_config(:prompt, text)
        else
          raise ArgumentError, 'prompt requires either text or a block'
        end
      end

      def system_prompt(text = nil, &block)
        if block_given?
          store_config(:system_prompt, block)
        elsif text
          store_config(:system_prompt, text)
        else
          raise ArgumentError, 'system_prompt requires either text or a block'
        end
      end

      def messages(msgs)
        store_config(:messages, msgs)
      end

      def model(name)
        store_config(:model, name)
      end

      def temperature(value)
        store_config(:temperature, value)
      end

      def max_tokens(value)
        store_config(:max_tokens, value)
      end

      def provider(name)
        store_config(:provider, name)
      end

      # =====================
      # CONFIGURACIÓN ACTIVERECORD
      # =====================

      def model_class(klass)
        store_config(:model, klass)
      end

      def scope(scope_name)
        store_config(:scope, scope_name)
      end

      def where(conditions)
        store_config(:where, conditions)
      end

      def find_by(conditions)
        store_config(:find_by, conditions)
      end

      def includes(*associations)
        store_config(:includes, associations)
      end

      # =====================
      # CONFIGURACIÓN EMAIL
      # =====================

      def mailer(klass)
        store_config(:mailer, klass)
      end

      def action(action_name)
        store_config(:action, action_name)
      end

      def params(hash)
        store_config(:params, hash)
      end

      def delivery_method(method)
        store_config(:delivery_method, method)
      end

      # =====================
      # CONFIGURACIÓN TURBO STREAMS
      # =====================

      def target(selector = nil, &block)
        if block_given?
          store_config(:target, block)
        elsif selector
          store_config(:target, selector)
        else
          raise ArgumentError, 'target requires either a selector string or a block'
        end
      end

      def turbo_action(action_name)
        store_config(:action, action_name)
      end

      def partial(partial_name)
        store_config(:partial, partial_name)
      end

      def locals(hash = nil, &block)
        if block_given?
          store_config(:locals, block)
        elsif hash
          store_config(:locals, hash)
        else
          raise ArgumentError, 'locals requires either a hash or a block'
        end
      end

      # =====================
      # CONFIGURACIÓN DE ARCHIVOS
      # =====================

      def file_path(path)
        store_config(:file_path, path)
      end

      def purpose(purpose_name)
        store_config(:purpose, purpose_name)
      end

      # =====================
      # CONFIGURACIÓN WEB SEARCH
      # =====================

      def query(search_query)
        store_config(:query, search_query)
      end

      def search_context_size(size)
        store_config(:search_context_size, size)
      end

      # =====================
      # CONFIGURACIÓN A2A AGENT
      # =====================

      def agent_url(url)
        store_config(:agent_url, url)
      end

      def skill(skill_name)
        store_config(:skill, skill_name)
      end

      def auth_token(token)
        store_config(:auth, token)
      end

      def auth_env(env_var)
        store_config(:auth, { type: :env, key: env_var })
      end

      def auth_config(config_key)
        store_config(:auth, { type: :config, key: config_key })
      end

      def auth(&block)
        store_config(:auth, block)
      end

      def stream(enabled = true)
        store_config(:stream, enabled)
      end

      def webhook_url(url)
        store_config(:webhook_url, url)
      end

      def fail_on_error(enabled = true)
        store_config(:fail_on_error, enabled)
      end

      def max_retries(count)
        store_config(:max_retries, count)
      end

      def cache_ttl(seconds)
        store_config(:cache_ttl, seconds)
      end

      # =====================
      # CONFIGURACIÓN GENÉRICA
      # =====================

      def timeout(seconds)
        store_config(:timeout, seconds)
      end

      def retries(count)
        store_config(:retries, count)
      end

      def validation(is_validation = true)
        @meta[:validation] = is_validation
        self
      end

      # Método específico para format para evitar conflicto con Ruby's format
      def response_format(value)
        store_config(:format, value)
      end

      # Alias para mantener compatibilidad
      def format(value)
        store_config(:format, value)
      end

      # Capturar métodos no definidos para configuración dinámica
      def method_missing(method_name, *args, &block)
        if args.length == 1 && !block_given?
          store_config(method_name, args.first)
        elsif args.empty? && block_given?
          store_config(method_name, block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        true
      end

      # =====================
      # BUILD
      # =====================

      def build
        # Combinar condiciones
        @config[:if] = combine_conditions(@conditions) if @conditions.any?

        # Añadir metadata
        @config[:inputs] = @inputs if @inputs.any?
        @config[:outputs] = @outputs if @outputs.any?
        @config[:meta] = @meta if @meta.any?

        {
          name: @name.to_sym,
          config: @config,
        }
      end

      private

      def store_config(key, value)
        @config[key] = value
        self
      end

      def wrap_handler(handler_proc)
        lambda { |context|
          begin
            # Log start
            SuperAgent.configuration.logger.debug("[#{@name}] Starting handler")

            # Auto-extraer inputs si están definidos
            if @inputs.any?
              args = @inputs.map { |key| context.get(key) }
              missing_inputs = @inputs.zip(args).select { |_, val| val.nil? }.map(&:first)

              if missing_inputs.any?
                SuperAgent.configuration.logger.warn("[#{@name}] Missing inputs: #{missing_inputs}")
              end

              result = handler_proc.call(*args, context)
            else
              result = handler_proc.call(context)
            end

            # Auto-guardar outputs si están definidos
            if @outputs.any? && result.is_a?(Hash)
              { @outputs.first => result }
            else
              result
            end
          rescue StandardError => e
            SuperAgent.configuration.logger.error("[#{@name}] Handler error: #{e.message}")
            SuperAgent.configuration.logger.error(e.backtrace.first(5).join("\n"))
            raise
          end
        }
      end

      def combine_conditions(conditions)
        lambda { |context|
          conditions.all? { |cond| cond.call(context) }
        }
      end
    end

    # Métodos de instancia
    def steps
      self.class.all_steps
    end

    def find_step(name)
      steps.find { |step| step[:name] == name.to_sym }
    end

    def workflow_config
      self.class.workflow_config || {}
    end
  end
end
