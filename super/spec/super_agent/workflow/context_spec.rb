# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SuperAgent::Workflow::Context do
  let(:initial_data) do
    {
      user_id: 123,
      project_name: "Test Project",
      nested: { key: "value", deep: { level: "deep_value" } },
      list: [1, 2, 3],
      empty_string: "",
      nil_value: nil
    }
  end
  let(:context) { described_class.new(initial_data) }

  describe 'basic functionality' do
    it 'initializes with data' do
      expect(context.get(:user_id)).to eq(123)
      expect(context.get(:project_name)).to eq("Test Project")
    end

    it 'handles keyword arguments' do
      ctx = described_class.new(a: 1, b: 2)
      expect(ctx.get(:a)).to eq(1)
      expect(ctx.get(:b)).to eq(2)
    end

    it 'converts keys to symbols' do
      ctx = described_class.new("string_key" => "value")
      expect(ctx.get(:string_key)).to eq("value")
      expect(ctx.get("string_key")).to eq("value")
    end

    it 'is immutable' do
      new_context = context.set(:new_key, "new_value")
      expect(context.get(:new_key)).to be_nil
      expect(new_context.get(:new_key)).to eq("new_value")
    end
  end

  describe 'enhanced access methods' do
    describe '#extract' do
      it 'extracts multiple values' do
        values = context.extract(:user_id, :project_name, :missing)
        expect(values).to eq([123, "Test Project", nil])
      end

      it 'handles empty extraction' do
        expect(context.extract).to eq([])
      end
    end

    describe '#fetch' do
      it 'returns value for existing key' do
        expect(context.fetch(:user_id)).to eq(123)
      end

      it 'returns default for missing key' do
        expect(context.fetch(:missing, "default")).to eq("default")
      end

      it 'returns nil when no default provided' do
        expect(context.fetch(:missing)).to be_nil
      end
    end

    describe '#dig' do
      it 'accesses nested values' do
        expect(context.dig(:nested, :key)).to eq("value")
        expect(context.dig(:nested, :deep, :level)).to eq("deep_value")
      end

      it 'returns nil for invalid path' do
        expect(context.dig(:nested, :missing)).to be_nil
        expect(context.dig(:missing, :key)).to be_nil
      end

      it 'handles array access' do
        expect(context.dig(:list, 0)).to eq(1)
        expect(context.dig(:list, 1)).to eq(2)
        expect(context.dig(:list, 10)).to be_nil
      end
    end

    describe '#merge_safe' do
      it 'merges only non-nil values' do
        new_context = context.merge_safe(
          new_key: "value",
          nil_key: nil,
          user_id: 456
        )
        
        expect(new_context.get(:new_key)).to eq("value")
        expect(new_context.key?(:nil_key)).to be false
        expect(new_context.get(:user_id)).to eq(456)
      end

      it 'returns new instance' do
        new_context = context.merge_safe(key: "value")
        expect(new_context).not_to equal(context)
      end
    end

    describe '#has_all?' do
      it 'returns true when all keys exist' do
        expect(context.has_all?(:user_id, :project_name)).to be true
      end

      it 'returns false when any key is missing' do
        expect(context.has_all?(:user_id, :missing)).to be false
      end

      it 'returns true for empty key list' do
        expect(context.has_all?).to be true
      end
    end

    describe '#has_any?' do
      it 'returns true when any key exists' do
        expect(context.has_any?(:missing, :user_id)).to be true
      end

      it 'returns false when no keys exist' do
        expect(context.has_any?(:missing1, :missing2)).to be false
      end

      it 'returns false for empty key list' do
        expect(context.has_any?).to be false
      end
    end

    describe '#transform' do
      it 'transforms existing value' do
        new_context = context.transform(:user_id) { |v| v * 2 }
        expect(new_context.get(:user_id)).to eq(246)
        expect(context.get(:user_id)).to eq(123)  # Original unchanged
      end

      it 'returns same context for missing key' do
        new_context = context.transform(:missing) { |v| v * 2 }
        expect(new_context.to_h).to eq(context.to_h)
      end

      it 'returns same context for nil value' do
        new_context = context.transform(:nil_value) { |v| "transformed" }
        expect(new_context.get(:nil_value)).to be_nil
      end
    end
  end

  describe 'advanced query methods' do
    describe '#first_present' do
      it 'finds first key with present value' do
        ctx = described_class.new(empty: "", nil_val: nil, valid: "value", also_valid: "another")
        expect(ctx.first_present(:empty, :nil_val, :valid, :also_valid)).to eq(:valid)
      end

      it 'returns nil when no keys have present values' do
        ctx = described_class.new(empty: "", nil_val: nil)
        expect(ctx.first_present(:empty, :nil_val, :missing)).to be_nil
      end
    end

    describe '#first_value' do
      it 'returns first present value' do
        ctx = described_class.new(empty: "", nil_val: nil, valid: "value")
        expect(ctx.first_value(:empty, :nil_val, :valid)).to eq("value")
      end

      it 'returns nil when no present values found' do
        ctx = described_class.new(empty: "", nil_val: nil)
        expect(ctx.first_value(:empty, :nil_val)).to be_nil
      end
    end

    describe '#select_keys' do
      it 'filters keys by condition' do
        numeric_keys = context.select_keys { |key, value| value.is_a?(Numeric) }
        expect(numeric_keys).to eq([:user_id])
      end

      it 'returns empty array when no keys match' do
        float_keys = context.select_keys { |key, value| value.is_a?(Float) }
        expect(float_keys).to eq([])
      end
    end

    describe '#present_keys' do
      it 'returns keys with present values' do
        keys = context.present_keys
        expect(keys).to include(:user_id, :project_name, :nested, :list)
        expect(keys).not_to include(:empty_string, :nil_value)
      end
    end

    describe '#slice' do
      it 'creates sub-context with specified keys' do
        sliced = context.slice(:user_id, :project_name, :missing)
        expect(sliced.keys).to contain_exactly(:user_id, :project_name)
        expect(sliced.get(:user_id)).to eq(123)
        expect(sliced.get(:nested)).to be_nil
      end
    end

    describe '#except' do
      it 'creates context without specified keys' do
        filtered = context.except(:nested, :list)
        expect(filtered.keys).not_to include(:nested, :list)
        expect(filtered.keys).to include(:user_id, :project_name)
      end
    end
  end

  describe 'validation methods' do
    describe '#validate_presence' do
      it 'passes when all keys are present' do
        expect { context.validate_presence(:user_id, :project_name) }.not_to raise_error
      end

      it 'raises error for missing keys' do
        expect {
          context.validate_presence(:user_id, :missing_key)
        }.to raise_error(ArgumentError, /Missing required context keys: missing_key/)
      end

      it 'raises error for blank values' do
        expect {
          context.validate_presence(:empty_string)
        }.to raise_error(ArgumentError, /Missing required context keys: empty_string/)
      end
    end

    describe '#validate_types' do
      it 'passes when types match' do
        expect {
          context.validate_types(user_id: Integer, project_name: String)
        }.not_to raise_error
      end

      it 'raises error for wrong types' do
        expect {
          context.validate_types(user_id: String, project_name: Integer)
        }.to raise_error(ArgumentError, /Type validation failed/)
      end

      it 'ignores nil values' do
        expect {
          context.validate_types(nil_value: String, missing: Integer)
        }.not_to raise_error
      end
    end
  end

  describe 'analysis methods' do
    describe '#stats' do
      it 'provides context statistics' do
        stats = context.stats
        
        expect(stats[:total_keys]).to eq(6)
        expect(stats[:present_keys]).to eq(4)  # user_id, project_name, nested, list
        expect(stats[:private_keys]).to eq(0)
        expect(stats[:data_types]).to be_a(Hash)
        expect(stats[:memory_usage]).to be_a(Numeric)
      end
    end

    describe '#summary' do
      it 'creates readable summary' do
        summary = context.summary
        expect(summary[:user_id]).to eq(123)
        expect(summary[:project_name]).to eq("Test Project")
        expect(summary[:list]).to eq([1, 2, 3])
        expect(summary[:nested]).to eq({ key: "value", deep: { level: "deep_value" } })
      end

      it 'truncates long strings' do
        long_ctx = described_class.new(long_text: "x" * 100)
        summary = long_ctx.summary(max_length: 10)
        expect(summary[:long_text]).to eq("xxxxxxxxxx...")
      end

      it 'filters private keys' do
        private_ctx = described_class.new({ secret: "hidden" }, private_keys: [:secret])
        summary = private_ctx.summary
        expect(summary[:secret]).to eq('[PRIVATE]')
      end
    end
  end

  describe 'debug methods' do
    describe '#pretty_print' do
      it 'generates pretty JSON' do
        json = context.pretty_print
        expect(json).to be_a(String)
        expect { JSON.parse(json) }.not_to raise_error
      end

      it 'includes private data when requested' do
        private_ctx = described_class.new({ secret: "hidden" }, private_keys: [:secret])
        
        json_filtered = private_ctx.pretty_print(include_private: false)
        json_full = private_ctx.pretty_print(include_private: true)
        
        expect(json_filtered).to include('[FILTERED]')
        expect(json_full).to include('hidden')
      end
    end

    describe '#log' do
      let(:mock_logger) { double('logger') }

      it 'logs context state' do
        expect(mock_logger).to receive(:info).with(/Context state/)
        context.log(logger: mock_logger)
      end

      it 'respects log level' do
        expect(mock_logger).to receive(:debug).with(/Custom message/)
        context.log(level: :debug, message: "Custom message", logger: mock_logger)
      end
    end
  end

  describe 'operators and core methods' do
    describe '#[]' do
      it 'allows bracket access' do
        expect(context[:user_id]).to eq(123)
        expect(context[:missing]).to be_nil
      end
    end

    describe '#==' do
      it 'compares contexts correctly' do
        other_context = described_class.new(initial_data)
        expect(context).to eq(other_context)
        
        different_context = described_class.new(user_id: 456)
        expect(context).not_to eq(different_context)
      end

      it 'returns false for non-context objects' do
        expect(context).not_to eq({})
        expect(context).not_to eq("string")
      end
    end

    describe '#hash' do
      it 'generates consistent hash codes' do
        other_context = described_class.new(initial_data)
        expect(context.hash).to eq(other_context.hash)
      end
    end

    describe '#to_s and #inspect' do
      it 'provides readable string representation' do
        str = context.to_s
        expect(str).to include("Context")
        expect(str).to include("keys=")
        
        inspect_str = context.inspect
        expect(inspect_str).to include("Context")
        expect(inspect_str).to include("@data=")
      end
    end
  end

  describe 'private keys functionality' do
    let(:private_context) do
      described_class.new(
        { public_data: "visible", secret_key: "hidden", api_token: "secret" },
        private_keys: [:secret_key, :api_token]
      )
    end

    it 'filters private keys in logging' do
      filtered = private_context.filtered_for_logging
      expect(filtered[:public_data]).to eq("visible")
      expect(filtered[:secret_key]).to eq('[FILTERED]')
      expect(filtered[:api_token]).to eq('[FILTERED]')
    end

    it 'preserves private keys in new contexts' do
      new_context = private_context.set(:new_key, "value")
      filtered = new_context.filtered_for_logging
      expect(filtered[:secret_key]).to eq('[FILTERED]')
    end
  end

  describe 'edge cases' do
    it 'handles empty context' do
      empty_ctx = described_class.new
      expect(empty_ctx.empty?).to be true
      expect(empty_ctx.keys).to eq([])
      expect(empty_ctx.to_h).to eq({})
    end

    it 'handles complex nested structures' do
      complex_data = {
        level1: {
          level2: {
            level3: { value: "deep" }
          }
        }
      }
      complex_ctx = described_class.new(complex_data)
      
      expect(complex_ctx.dig(:level1, :level2, :level3, :value)).to eq("deep")
      expect(complex_ctx.dig(:level1, :level2, :missing)).to be_nil
    end

    it 'handles array-like objects in dig' do
      array_ctx = described_class.new(items: [{ name: "first" }, { name: "second" }])
      expect(array_ctx.dig(:items, 0, :name)).to eq("first")
    end
  end
end
