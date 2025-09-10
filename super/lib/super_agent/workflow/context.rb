# frozen_string_literal: true

module SuperAgent
  module Workflow
    # Immutable context object for passing state between workflow tasks
    class Context
      attr_reader :private_keys

      def initialize(initial_data = {}, private_keys: [], **kwargs)
        data = initial_data.is_a?(Hash) ? initial_data.merge(kwargs) : kwargs
        @data = data.transform_keys(&:to_sym)
        @private_keys = Array(private_keys).map(&:to_sym)
      end

      # =====================
      # MÉTODOS BÁSICOS
      # =====================

      # Get a value from the context
      def get(key)
        @data[key.to_sym]
      end

      # Set a value in the context, returning a new immutable instance
      def set(key, value)
        new_data = @data.dup
        new_data[key.to_sym] = value
        self.class.new(new_data, private_keys: @private_keys)
      end

      # Set multiple values at once, returning a new immutable instance
      def merge(new_data)
        merged_data = @data.merge(new_data.transform_keys(&:to_sym))
        self.class.new(merged_data, private_keys: @private_keys)
      end

      # =====================
      # MÉTODOS MEJORADOS DE ACCESO
      # =====================

      # Extraer múltiples valores
      def extract(*keys)
        keys.map { |key| get(key) }
      end

      # Obtener con valor por defecto
      def fetch(key, default = nil)
        get(key) || default
      end

      # Acceso anidado seguro
      def dig(*keys)
        keys.reduce(@data) do |hash, key|
          break nil unless hash.respond_to?(:[])
          
          if key.is_a?(Integer) && hash.is_a?(Array)
            hash[key]
          else
            hash[key.to_sym] || (hash.respond_to?(:[]) ? hash[key] : nil)
          end
        end
      end

      # Merge solo con valores no nulos
      def merge_safe(new_data)
        validated_data = new_data.reject { |_, v| v.nil? }
        merge(validated_data)
      end

      # Verificar múltiples keys
      def has_all?(*keys)
        keys.all? { |key| key?(key) }
      end

      def has_any?(*keys)
        keys.any? { |key| key?(key) }
      end

      # Transformar valores
      def transform(key, &block)
        value = get(key)
        return self if value.nil?
        set(key, block.call(value))
      end

      # =====================
      # MÉTODOS DE CONSULTA AVANZADA
      # =====================

      # Encontrar el primer key que tenga un valor
      def first_present(*keys)
        keys.find { |key| get(key).present? }
      end

      # Obtener el primer valor presente
      def first_value(*keys)
        key = first_present(*keys)
        key ? get(key) : nil
      end

      # Filtrar keys por condición
      def select_keys(&block)
        @data.select { |key, value| block.call(key, value) }.keys
      end

      # Obtener solo los keys con valores presentes
      def present_keys
        @data.select { |_, value| value.present? }.keys
      end

      # Crear un sub-contexto con solo ciertas keys
      def slice(*keys)
        sliced_data = @data.slice(*keys.map(&:to_sym))
        self.class.new(sliced_data, private_keys: @private_keys)
      end

      # Crear un contexto sin ciertas keys
      def except(*keys)
        filtered_data = @data.except(*keys.map(&:to_sym))
        self.class.new(filtered_data, private_keys: @private_keys)
      end

      # =====================
      # MÉTODOS DE VALIDACIÓN
      # =====================

      # Validar que ciertos keys existan y tengan valores
      def validate_presence(*keys)
        missing = keys.select { |key| get(key).blank? }
        return true if missing.empty?
        
        raise ArgumentError, "Missing required context keys: #{missing.join(', ')}"
      end

      # Validar tipos de datos
      def validate_types(**type_specs)
        errors = []
        
        type_specs.each do |key, expected_type|
          value = get(key)
          next if value.nil?
          
          unless value.is_a?(expected_type)
            errors << "#{key} must be a #{expected_type}, got #{value.class}"
          end
        end
        
        return true if errors.empty?
        raise ArgumentError, "Type validation failed: #{errors.join(', ')}"
      end

      # =====================
      # MÉTODOS DE ANÁLISIS
      # =====================

      # Obtener estadísticas del contexto
      def stats
        {
          total_keys: @data.size,
          present_keys: present_keys.size,
          private_keys: @private_keys.size,
          data_types: @data.group_by { |_, v| v.class.name }.transform_values(&:size),
          memory_usage: calculate_memory_usage
        }
      end

      # Crear un resumen legible del contexto
      def summary(max_length: 50)
        @data.each_with_object({}) do |(key, value), summary|
          if @private_keys.include?(key)
            summary[key] = '[PRIVATE]'
          elsif value.is_a?(String) && value.length > max_length
            summary[key] = "#{value[0..(max_length - 1)]}..."
          elsif value.is_a?(Array) && value.size > 3
            summary[key] = "[Array with #{value.size} items]"
          elsif value.is_a?(Hash) && value.size > 3
            summary[key] = "[Hash with #{value.size} keys]"
          else
            summary[key] = value
          end
        end
      end

      # =====================
      # MÉTODOS DE DEBUG
      # =====================

      # Pretty print del contexto
      def pretty_print(include_private: false)
        data_to_print = include_private ? @data : filtered_for_logging
        JSON.pretty_generate(data_to_print)
      end

      # Log del contexto con nivel específico
      def log(level: :info, message: "Context state", logger: Rails.logger)
        return unless logger.respond_to?(level)
        
        logger.send(level, "#{message}: #{summary}")
      end

      # =====================
      # MÉTODOS EXISTENTES
      # =====================

      # Filter sensitive data for logging
      def filtered_for_logging
        filtered_data = @data.dup
        
        @private_keys.each do |key|
          filtered_data[key] = '[FILTERED]' if filtered_data.key?(key)
        end
        
        filtered_data
      end

      # Get all keys in the context
      def keys
        @data.keys
      end

      # Check if context is empty
      def empty?
        @data.empty?
      end

      # Convert to hash
      def to_h
        @data.dup
      end

      # Check if a key exists
      def key?(key)
        @data.key?(key.to_sym)
      end

      # =====================
      # OPERADORES SOBRECARGADOS
      # =====================

      # Permitir acceso con []
      def [](key)
        get(key)
      end

      # Comparación de contextos
      def ==(other)
        other.is_a?(self.class) && @data == other.instance_variable_get(:@data)
      end

      # Hash code para usar como key
      def hash
        @data.hash
      end

      # String representation
      def to_s
        "#<#{self.class.name} keys=#{keys.join(',')}>"
      end

      def inspect
        "#<#{self.class.name}:#{object_id} @data=#{@data.inspect}>"
      end

      private

      def calculate_memory_usage
        # Estimación simple del uso de memoria
        @data.sum do |key, value|
          key_size = key.to_s.bytesize
          value_size = case value
                      when String then value.bytesize
                      when Numeric then 8
                      when Array then value.sum { |v| v.to_s.bytesize rescue 8 }
                      when Hash then value.to_s.bytesize
                      else 8
                      end
          key_size + value_size
        end
      end
    end
  end
end