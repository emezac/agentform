# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SuperAgent::WorkflowHelpers do
  let(:test_class) do
    Class.new do
      include SuperAgent::WorkflowHelpers
    end
  end

  let(:helper) { test_class.new }

  describe 'formatting helpers' do
    describe '#percentage' do
      it 'converts decimal to percentage' do
        expect(helper.percentage(0.75)).to eq(75.0)
        expect(helper.percentage(0.756, decimals: 2)).to eq(75.6)
      end

      it 'returns default for non-numeric' do
        expect(helper.percentage("invalid")).to eq(0.0)
        expect(helper.percentage(nil)).to eq(0.0)
        expect(helper.percentage(nil, default: 50.0)).to eq(50.0)
      end

      it 'handles edge cases' do
        expect(helper.percentage(0)).to eq(0.0)
        expect(helper.percentage(1)).to eq(100.0)
        expect(helper.percentage(1.5)).to eq(150.0)
      end
    end

    describe '#currency' do
      it 'formats numeric as currency' do
        expect(helper.currency(10.556)).to eq(10.56)
        expect(helper.currency(10.554)).to eq(10.55)
        expect(helper.currency(10, decimals: 3)).to eq(10.0)
      end

      it 'returns default for non-numeric' do
        expect(helper.currency("invalid")).to eq(0.00)
        expect(helper.currency(nil, default: 99.99)).to eq(99.99)
      end
    end

    describe '#safe_string' do
      it 'converts to string safely' do
        expect(helper.safe_string(123)).to eq("123")
        expect(helper.safe_string("  text  ")).to eq("text")
        expect(helper.safe_string(nil)).to eq("")
      end

      it 'truncates when max_length specified' do
        long_text = "This is a very long text that should be truncated"
        expect(helper.safe_string(long_text, max_length: 10)).to eq("This is...")
      end

      it 'returns default for nil' do
        expect(helper.safe_string(nil, default: "N/A")).to eq("N/A")
      end
    end

    def humanize_duration(seconds)
      return "0 seconds" unless seconds.is_a?(Numeric)
      
      if seconds < 60
        "#{seconds.to_f} seconds"
      elsif seconds < 3600
        minutes = seconds.to_f / 60  # Use to_f to ensure float division
        "#{minutes} minutes"
      else
        hours = seconds.to_f / 3600  # Use to_f to ensure float division
        "#{hours} hours"
      end
    end
  end

  describe 'array helpers' do
    describe '#safe_array' do
      it 'returns array unchanged' do
        expect(helper.safe_array([1, 2, 3])).to eq([1, 2, 3])
      end

      it 'converts nil to empty array' do
        expect(helper.safe_array(nil)).to eq([])
      end

      it 'wraps non-array in array' do
        expect(helper.safe_array("value")).to eq(["value"])
        expect(helper.safe_array(42)).to eq([42])
      end
    end

    describe '#format_list' do
      it 'formats array as string' do
        expect(helper.format_list([1, 2, 3])).to eq("1, 2 and 3")
        expect(helper.format_list([1])).to eq("1")
        expect(helper.format_list([1, 2])).to eq("1 and 2")
      end

      it 'uses custom formatter' do
        expect(helper.format_list([1, 2], formatter: :to_f)).to eq("1.0 and 2.0")
      end

      it 'uses custom separators' do
        result = helper.format_list([1, 2, 3], separator: " | ", last_separator: " or ")
        expect(result).to eq("1 | 2 or 3")
      end

      it 'handles empty arrays' do
        expect(helper.format_list([])).to eq("")
        expect(helper.format_list(nil)).to eq("")
      end
    end

    describe '#pluck_safely' do
      let(:collection) do
        [
          { name: "Alice", age: 30 },
          double("User", name: "Bob", age: 25),
          { "name" => "Charlie", "age" => 35 }
        ]
      end

      it 'extracts attributes safely' do
        names = helper.pluck_safely(collection, :name)
        expect(names).to eq(["Alice", "Bob", "Charlie"])
      end

      it 'handles missing attributes' do
        emails = helper.pluck_safely(collection, :email)
        expect(emails).to eq([])
      end

      it 'works with nil collection' do
        result = helper.pluck_safely(nil, :name)
        expect(result).to eq([])
      end
    end
  end

  describe 'error handling helpers' do
    describe '#with_fallback' do
      it 'returns result on success' do
        result = helper.with_fallback("fallback") { "success" }
        expect(result).to eq("success")
      end

      it 'returns fallback on error' do
        result = helper.with_fallback("fallback") { raise "error" }
        expect(result).to eq("fallback")
      end

      it 'can disable error logging' do
        expect(Rails.logger).not_to receive(:warn)
        helper.with_fallback("fallback", log_errors: false) { raise "error" }
      end
    end

    describe '#ensure_present' do
      it 'returns value if present' do
        expect(helper.ensure_present("value", "fallback")).to eq("value")
        expect(helper.ensure_present(123, "fallback")).to eq(123)
      end

      it 'returns fallback if blank' do
        expect(helper.ensure_present("", "fallback")).to eq("fallback")
        expect(helper.ensure_present(nil, "fallback")).to eq("fallback")
        expect(helper.ensure_present("   ", "fallback")).to eq("fallback")
      end
    end

    describe '#safe_call' do
      let(:object) { double("Object", existing_method: "result") }

      it 'calls method safely when it exists' do
        result = helper.safe_call(object, :existing_method)
        expect(result).to eq("result")
      end

      it 'returns default when method does not exist' do
        result = helper.safe_call(object, :missing_method, default: "default")
        expect(result).to eq("default")
      end

      it 'handles method call errors' do
        allow(object).to receive(:existing_method).and_raise("Error")
        result = helper.safe_call(object, :existing_method, default: "safe")
        expect(result).to eq("safe")
      end
    end
  end

  describe 'context helpers' do
    let(:context) { SuperAgent::Workflow::Context.new(key1: "value1", key2: nil, key3: "value3") }

    describe '#safe_get' do
      it 'gets value safely' do
        expect(helper.safe_get(context, :key1)).to eq("value1")
        expect(helper.safe_get(context, :key2, "default")).to eq("default")
        expect(helper.safe_get(context, :missing, "default")).to eq("default")
      end
    end

    describe '#safe_extract' do
      it 'extracts multiple values safely' do
        values = helper.safe_extract(context, :key1, :key2, :missing)
        expect(values).to eq(["value1", nil, nil])
      end
    end

    describe '#context_summary' do
      it 'creates summary of all keys when none specified' do
        summary = helper.context_summary(context)
        expect(summary).to eq({ key1: "value1", key3: "value3" })
      end

      it 'creates summary of specified keys' do
        summary = helper.context_summary(context, :key1, :key2)
        expect(summary).to eq({ key1: "value1", key2: nil })
      end

      it 'truncates long string values' do
        long_context = SuperAgent::Workflow::Context.new(
          long_text: "x" * 150
        )
        summary = helper.context_summary(long_context)
        expect(summary[:long_text]).to end_with("...")
        expect(summary[:long_text].length).to be <= 103  # 100 + "..."
      end
    end
  end

  describe 'validation helpers' do
    describe '#valid_email?' do
      it 'validates emails correctly' do
        expect(helper.valid_email?("test@example.com")).to be true
        expect(helper.valid_email?("user.name+tag@domain.co.uk")).to be true
        expect(helper.valid_email?("invalid-email")).to be false
        expect(helper.valid_email?("@domain.com")).to be false
        expect(helper.valid_email?(nil)).to be false
        expect(helper.valid_email?(123)).to be false
      end
    end

    describe '#valid_url?' do
      it 'validates URLs correctly' do
        expect(helper.valid_url?("https://example.com")).to be true
        expect(helper.valid_url?("http://test.org/path?query=1")).to be true
        expect(helper.valid_url?("invalid-url")).to be false
        expect(helper.valid_url?("ftp://example.com")).to be false
        expect(helper.valid_url?(nil)).to be false
      end
    end

    describe '#positive_number?' do
      it 'validates positive numbers' do
        expect(helper.positive_number?(5)).to be true
        expect(helper.positive_number?(0.1)).to be true
        expect(helper.positive_number?(0)).to be false
        expect(helper.positive_number?(-1)).to be false
        expect(helper.positive_number?("5")).to be false
      end
    end

    describe '#within_range?' do
      it 'validates ranges correctly' do
        expect(helper.within_range?(5, min: 1, max: 10)).to be true
        expect(helper.within_range?(1, min: 1, max: 10)).to be true
        expect(helper.within_range?(10, min: 1, max: 10)).to be true
        expect(helper.within_range?(0, min: 1, max: 10)).to be false
        expect(helper.within_range?(11, min: 1, max: 10)).to be false
        expect(helper.within_range?("5", min: 1, max: 10)).to be false
      end
    end
  end

  describe 'domain-specific helpers' do
    describe '#format_products' do
      let(:products) do
        [
          { id: 1, name: "Product 1", price: 10.50, description: "Short desc" },
          { id: 2, name: "Product 2", price: 20.00, description: "A very long description that should be truncated when displayed in the detailed format because it exceeds the maximum length" },
          double("Product", id: 3, name: "Product 3", price: 15.99, description: "Object desc")
        ]
      end

      it 'formats products in simple format' do
        result = helper.format_products(products, format: :simple)
        expect(result).to include("Product 1 - 10.5")
        expect(result).to include("Product 2 - 20.0")
        expect(result).to include("Product 3 - 15.99")
      end

      it 'formats products in detailed format' do
        result = helper.format_products(products, format: :detailed)
        expect(result).to include("ID: 1, Name: Product 1, Price: $10.5")
        expect(result).to include("Description: Short desc")
        expected_truncated_description = "A very long description that should be truncated when displayed in the detailed format because it ex..."
        expect(result).to include("Description: #{expected_truncated_description}")
      end

      it 'formats products in compact format' do
        result = helper.format_products(products, format: :compact)
        expect(result).to eq("3 products (Total: $46.49)")
      end

      it 'handles empty product list' do
        result = helper.format_products([])
        expect(result).to eq("No products available")
      end
    end

    describe '#calculate_discount' do
      it 'calculates discount correctly' do
        result = helper.calculate_discount(100, 20)
        
        expect(result[:original_price]).to eq(100.0)
        expect(result[:discount_percent]).to eq(20.0)
        expect(result[:discount_amount]).to eq(20.0)
        expect(result[:final_price]).to eq(80.0)
        expect(result[:savings]).to eq(20.0)
      end

      it 'returns zero for invalid inputs' do
        expect(helper.calculate_discount(nil, 20)).to eq(0)
        expect(helper.calculate_discount(100, -5)).to eq(0)
        expect(helper.calculate_discount(100, 150)).to eq(0)
      end
    end

    describe '#generate_offer_urgency' do
      it 'generates urgency information' do
        result = helper.generate_offer_urgency(30)
        
        expect(result[:expires_in_minutes]).to eq(30)
        expect(result[:urgency_message]).to include("30 minutes")
        expect(result[:expires_at]).to be_a(Time)
        expect(result[:countdown_target]).to be_a(Integer)
      end
    end

    describe '#calculate_engagement_score' do
      it 'calculates engagement score' do
        session_data = {
          duration: 300,  # 5 minutes
          pages_viewed: 5,
          events: ['click', 'scroll', 'click']
        }
        
        score = helper.calculate_engagement_score(session_data)
        expect(score).to be_a(Float)
        expect(score).to be_between(0, 1)
      end

      it 'handles missing data gracefully' do
        score = helper.calculate_engagement_score({})
        expect(score).to eq(0.05)  # Minimum score for 1 page
      end

      it 'returns 0 for non-hash input' do
        expect(helper.calculate_engagement_score(nil)).to eq(0)
        expect(helper.calculate_engagement_score("invalid")).to eq(0)
      end
    end
  end

  describe 'default responses' do
    describe '#default_response' do
      it 'returns analysis default' do
        response = helper.default_response(:analysis)
        expect(response).to include(:detected_intent, :confidence_score, :recommended_strategy)
      end

      it 'returns learning default' do
        response = helper.default_response(:learning)
        expect(response).to include(:strategy_success_rate, :recommended_discount_range)
      end

      it 'returns offer default' do
        response = helper.default_response(:offer)
        expect(response).to include(:offer_type, :title, :description, :call_to_action)
      end

      it 'returns empty hash for unknown type' do
        expect(helper.default_response(:unknown)).to eq({})
      end
    end

    describe '#success_response' do
      it 'creates success response' do
        response = helper.success_response({ result: "test" })
        
        expect(response[:success]).to be true
        expect(response[:data]).to eq({ result: "test" })
        expect(response[:timestamp]).to be_a(String)
        expect(response[:message]).to include("success")
      end
    end

    describe '#error_response' do
      it 'creates error response' do
        response = helper.error_response("Something went wrong", code: :validation_error)
        
        expect(response[:success]).to be false
        expect(response[:error][:code]).to eq(:validation_error)
        expect(response[:error][:message]).to eq("Something went wrong")
        expect(response[:timestamp]).to be_a(String)
      end
    end
  end

  describe '#analyze_confidence' do
    it 'categorizes confidence scores' do
      expect(helper.analyze_confidence(0.9)).to eq(:very_high)
      expect(helper.analyze_confidence(0.7)).to eq(:high)
      expect(helper.analyze_confidence(0.5)).to eq(:medium)
      expect(helper.analyze_confidence(0.3)).to eq(:low)
      expect(helper.analyze_confidence(0.1)).to eq(:very_low)
    end
  end
end
