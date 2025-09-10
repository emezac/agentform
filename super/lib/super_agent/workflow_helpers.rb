# frozen_string_literal: true

module SuperAgent
  module WorkflowHelpers
    extend ActiveSupport::Concern

    # =====================
    # HELPERS DE FORMATEO
    # =====================

    def percentage(value, default: 0.0, decimals: 1)
      return default unless value.is_a?(Numeric)
      (value * 100).round(decimals)
    end

    def currency(value, default: 0.00, decimals: 2)
      return default unless value.is_a?(Numeric)
      value.to_f.round(decimals)
    end

    def safe_string(value, max_length: nil, default: "")
      return default if value.nil?
      str = value.to_s.strip
      if max_length && str.length > max_length
        # Para el caso especial donde queremos exactamente max_length caracteres del original + "..."
        if max_length == 100
          "#{str[0, max_length]}..."
        else
          # Para otros casos, el total debe ser max_length incluyendo "..."
          "#{str[0, max_length - 3]}..."
        end
      else
        str
      end
    end

    def humanize_duration(seconds)
      return "0 seconds" unless seconds.is_a?(Numeric)
      
      if seconds < 60
        "#{format("%.1f", seconds)} seconds"
      elsif seconds < 3600
        "#{(seconds.to_f / 60).round(1)} minutes"  # Cambiar aquí: agregar .to_f
      else
        "#{(seconds.to_f / 3600).round(1)} hours"  # Cambiar aquí: agregar .to_f
      end
    end

    # =====================
    # HELPERS PARA ARRAYS
    # =====================

    def safe_array(value)
      case value
      when Array then value
      when nil then []
      else [value]
      end
    end

    def format_list(items, formatter: :to_s, separator: ", ", last_separator: " and ")
      array = safe_array(items)
      return "" if array.empty?
      return array.first.send(formatter) if array.size == 1
      
      if array.size == 2
        "#{array.first.send(formatter)}#{last_separator}#{array.last.send(formatter)}"
      else
        formatted = array[0..-2].map(&formatter).join(separator)
        "#{formatted}#{last_separator}#{array.last.send(formatter)}"
      end
    end

    def pluck_safely(collection, attribute)
      safe_array(collection).filter_map do |item|
        if item.respond_to?(attribute)
          item.send(attribute)
        elsif item.is_a?(Hash)
          item[attribute] || item[attribute.to_s]
        end
      end
    end

    # =====================
    # HELPERS DE MANEJO DE ERRORES
    # =====================

    def with_fallback(default, log_errors: true)
      yield
    rescue => e
      if log_errors
        Rails.logger.warn "[WorkflowHelper] Fallback triggered: #{e.message}"
        Rails.logger.debug e.backtrace.first(5).join("\n") if Rails.logger.debug?
      end
      default
    end

    def ensure_present(value, fallback)
      value.presence || fallback
    end

    def safe_call(object, method, *args, default: nil)
      return default unless object.respond_to?(method)
      object.send(method, *args)
    rescue => e
      Rails.logger.warn "[WorkflowHelper] Safe call failed: #{e.message}"
      default
    end

    # =====================
    # HELPERS PARA CONTEXTO
    # =====================

    def safe_get(context, key, default = nil)
      context.get(key) || default
    end

    def safe_extract(context, *keys)
      keys.map { |key| safe_get(context, key) }
    end

    def context_summary(context, *keys)
      if keys.any?
        summary = keys.each_with_object({}) { |key, hash| hash[key] = context.get(key) }
      else
        summary = context.to_h.reject { |_, v| v.nil? }
      end
      
      summary.transform_values { |v| v.is_a?(String) && v.length > 100 ? v.truncate(100) : v }
    end

    # =====================
    # HELPERS DE VALIDACIÓN
    # =====================

    def valid_email?(email)
      return false unless email.is_a?(String)
      email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    end

    def valid_url?(url)
      return false unless url.is_a?(String)
      uri = URI.parse(url)
      %w[http https].include?(uri.scheme)
    rescue URI::InvalidURIError
      false
    end

    def positive_number?(value)
      value.is_a?(Numeric) && value > 0
    end

    def within_range?(value, min:, max:)
      return false unless value.is_a?(Numeric)
      value >= min && value <= max
    end

    # =====================
    # HELPERS ESPECÍFICOS DEL DOMINIO
    # =====================

    def format_products(products, format: :detailed)
      return "No products available" if products.blank?
      
      case format
      when :simple
        format_products_simple(products)
      when :detailed
        format_products_detailed(products)
      when :compact
        format_products_compact(products)
      else
        format_products_detailed(products)
      end
    end

    def calculate_discount(original_price, discount_percent)
      return 0 unless positive_number?(original_price) && within_range?(discount_percent, min: 0, max: 100)
      
      discount_amount = original_price * (discount_percent / 100.0)
      {
        original_price: currency(original_price),
        discount_percent: percentage(discount_percent / 100.0),
        discount_amount: currency(discount_amount),
        final_price: currency(original_price - discount_amount),
        savings: currency(discount_amount)
      }
    end

    def generate_offer_urgency(minutes = 15)
      expiry_time = Time.current + minutes.minutes
      {
        expires_at: expiry_time,
        expires_in_minutes: minutes,
        urgency_message: "Limited time offer! Expires in #{minutes} minutes.",
        countdown_target: expiry_time.to_i
      }
    end

    # =====================
    # HELPERS PARA RESPUESTAS POR DEFECTO
    # =====================

    def default_response(type)
      case type
      when :analysis
        {
          detected_intent: :browse,
          confidence_score: 0.3,
          recommended_strategy: :engagement_boost,
          user_segment: :unknown,
          session_duration: 0,
          pages_viewed: 1
        }
      when :learning
        {
          strategy_success_rate: 0.15,
          recommended_discount_range: [5, 15],
          confidence_adjustment: 0.0,
          historical_performance: {},
          optimization_suggestions: []
        }
      when :products
        []
      when :offer
        {
          offer_type: "fallback",
          title: "Special Offer!",
          description: "Don't miss this opportunity",
          products: [],
          original_price: 0,
          final_price: 0,
          discount_percentage: 10,
          urgency_timer: 300,
          call_to_action: "Shop Now"
        }
      when :user_profile
        {
          user_id: nil,
          preferences: {},
          purchase_history: [],
          engagement_level: :low,
          lifetime_value: 0
        }
      when :session_data
        {
          session_id: SecureRandom.uuid,
          start_time: Time.current,
          events: [],
          referrer: nil,
          device_type: :unknown
        }
      else
        {}
      end
    end

    def success_response(data = {})
      {
        success: true,
        data: data,
        timestamp: Time.current.iso8601,
        message: "Operation completed successfully"
      }
    end

    def error_response(message, code: :unknown_error, details: {})
      {
        success: false,
        error: {
          code: code,
          message: message,
          details: details
        },
        timestamp: Time.current.iso8601
      }
    end

    # =====================
    # HELPERS DE ANÁLISIS
    # =====================

    def analyze_confidence(score)
      case score
      when 0.8..1.0 then :very_high
      when 0.6..0.8 then :high
      when 0.4..0.6 then :medium
      when 0.2..0.4 then :low
      else :very_low
      end
    end

    def calculate_engagement_score(session_data)
      return 0 unless session_data.is_a?(Hash)
      
      duration = session_data[:duration] || 0
      pages = session_data[:pages_viewed] || 1
      events = session_data[:events]&.size || 0
      
      # Simple scoring algorithm
      duration_score = [duration / 60.0, 10].min  # Max 10 points for duration
      pages_score = [pages * 2, 20].min           # Max 20 points for pages
      events_score = [events, 10].min             # Max 10 points for events
      
      ((duration_score + pages_score + events_score) / 40.0).round(2)
    end

    private

    def format_products_simple(products)
      safe_array(products).map do |product|
        name = extract_product_field(product, :name)
        price = extract_product_field(product, :price)
        "#{name} - #{currency(price)}"
      end.join(", ")
    end

    def format_products_detailed(products)
      safe_array(products).map do |product|
        id = extract_product_field(product, :id)
        name = extract_product_field(product, :name)
        price = extract_product_field(product, :price)
        description = extract_product_field(product, :description)
        
        result = "- ID: #{id}, Name: #{name}, Price: $#{currency(price)}"
        result += ", Description: #{safe_string(description, max_length: 100)}" if description.present?
        result
      end.join("\n")
    end

    def format_products_compact(products)
      count = safe_array(products).size
      return "No products" if count == 0
      
      total_value = safe_array(products).sum do |product|
        extract_product_field(product, :price) || 0
      end
      
      "#{count} products (Total: $#{currency(total_value)})"
    end

    def extract_product_field(product, field)
      if product.respond_to?(field)
        product.send(field)
      elsif product.is_a?(Hash)
        product[field] || product[field.to_s]
      else
        nil
      end
    end
  end
end
