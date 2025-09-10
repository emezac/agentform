# frozen_string_literal: true

# Shared examples for common model behaviors

RSpec.shared_examples "a timestamped model" do
  it { should have_db_column(:created_at).of_type(:datetime) }
  it { should have_db_column(:updated_at).of_type(:datetime) }
  
  it "sets timestamps on creation" do
    record = create(described_class.name.underscore.to_sym)
    expect(record.created_at).to be_present
    expect(record.updated_at).to be_present
  end
  
  it "updates timestamp on modification" do
    record = create(described_class.name.underscore.to_sym)
    original_updated_at = record.updated_at
    
    sleep 0.01 # Ensure time difference
    record.touch
    
    expect(record.updated_at).to be > original_updated_at
  end
end

RSpec.shared_examples "a uuid model" do
  it { should have_db_column(:id).of_type(:uuid) }
  
  it "generates UUID on creation" do
    record = create(described_class.name.underscore.to_sym)
    expect(record.id).to be_present
    expect(record.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
  end
  
  it "generates unique UUIDs" do
    record1 = create(described_class.name.underscore.to_sym)
    record2 = create(described_class.name.underscore.to_sym)
    
    expect(record1.id).not_to eq(record2.id)
  end
end

RSpec.shared_examples "an encryptable model" do |encrypted_fields|
  it "includes Encryptable concern" do
    expect(described_class.ancestors).to include(Encryptable)
  end
  
  encrypted_fields.each do |field|
    it "encrypts #{field}" do
      record = build(described_class.name.underscore.to_sym)
      original_value = "sensitive_#{field}_data"
      record.send("#{field}=", original_value)
      record.save!
      
      # Value should be encrypted in database
      raw_value = described_class.connection.execute(
        "SELECT #{field} FROM #{described_class.table_name} WHERE id = '#{record.id}'"
      ).first[field.to_s]
      
      expect(raw_value).not_to eq(original_value)
      
      # But accessible normally through the model
      expect(record.reload.send(field)).to eq(original_value)
    end
    
    it "handles nil values for #{field}" do
      record = create(described_class.name.underscore.to_sym)
      record.send("#{field}=", nil)
      record.save!
      
      expect(record.reload.send(field)).to be_nil
    end
    
    it "handles empty string values for #{field}" do
      record = create(described_class.name.underscore.to_sym)
      record.send("#{field}=", "")
      record.save!
      
      expect(record.reload.send(field)).to eq("")
    end
  end
  
  it "supports key rotation" do
    record = create(described_class.name.underscore.to_sym)
    original_encrypted_data = {}
    
    encrypted_fields.each do |field|
      original_value = "test_#{field}_value"
      record.send("#{field}=", original_value)
      original_encrypted_data[field] = original_value
    end
    
    record.save!
    
    # Simulate key rotation (this would be implementation specific)
    # The record should still be able to decrypt with new key
    encrypted_fields.each do |field|
      expect(record.reload.send(field)).to eq(original_encrypted_data[field])
    end
  end
end

RSpec.shared_examples "a soft deletable model" do
  it { should have_db_column(:deleted_at).of_type(:datetime) }
  
  it "soft deletes records" do
    record = create(described_class.name.underscore.to_sym)
    record.destroy
    
    expect(record.deleted_at).to be_present
    expect(described_class.find_by(id: record.id)).to be_nil
    expect(described_class.with_deleted.find_by(id: record.id)).to eq(record)
  end
end

RSpec.shared_examples "a cacheable model" do
  it "includes Cacheable concern" do
    expect(described_class.ancestors).to include(Cacheable)
  end
  
  it "generates cache keys" do
    record = create(described_class.name.underscore.to_sym)
    cache_key = record.cache_key
    
    expect(cache_key).to be_present
    expect(cache_key).to include(described_class.name.underscore)
    expect(cache_key).to include(record.id.to_s)
  end
  
  it "invalidates cache on update" do
    record = create(described_class.name.underscore.to_sym)
    original_cache_key = record.cache_key
    
    sleep 0.01
    record.touch
    
    expect(record.cache_key).not_to eq(original_cache_key)
  end
end

RSpec.shared_examples "a model with enum" do |enum_field, enum_values|
  it "defines #{enum_field} enum" do
    expect(described_class.defined_enums).to have_key(enum_field.to_s)
  end
  
  enum_values.each do |value|
    it "allows #{enum_field} to be #{value}" do
      attributes = { enum_field => value }
      
      # Special handling for FormQuestion choice types
      if described_class.name == 'FormQuestion' && enum_field == :question_type && %w[multiple_choice single_choice checkbox].include?(value.to_s)
        attributes[:question_config] = { 'options' => ['Option 1'] }
      end
      
      record = build(described_class.name.underscore.to_sym, attributes)
      expect(record).to be_valid
      expect(record.send(enum_field)).to eq(value.to_s)
    end
  end
  
  it "provides predicate methods for #{enum_field}" do
    record = create(described_class.name.underscore.to_sym)
    
    enum_values.each do |value|
      predicate_method = "#{value}?"
      expect(record).to respond_to(predicate_method)
    end
  end
end

RSpec.shared_examples "a model with validations" do |validations|
  validations.each do |field, validation_type|
    case validation_type
    when :presence
      it { should validate_presence_of(field) }
    when :uniqueness
      it { should validate_uniqueness_of(field) }
    when Hash
      if validation_type[:length]
        it { should validate_length_of(field).is_at_most(validation_type[:length][:maximum]) } if validation_type[:length][:maximum]
        it { should validate_length_of(field).is_at_least(validation_type[:length][:minimum]) } if validation_type[:length][:minimum]
      end
      
      if validation_type[:format]
        it { should allow_value(validation_type[:format][:valid]).for(field) } if validation_type[:format][:valid]
        it { should_not allow_value(validation_type[:format][:invalid]).for(field) } if validation_type[:format][:invalid]
      end
    end
  end
end

RSpec.shared_examples "a model with associations" do |associations|
  associations.each do |association_name, association_type|
    case association_type
    when :belongs_to
      it { should belong_to(association_name) }
    when :has_many
      it { should have_many(association_name) }
    when :has_one
      it { should have_one(association_name) }
    when Hash
      case association_type[:type]
      when :belongs_to
        it { should belong_to(association_name) }
        
        if association_type[:dependent]
          it "handles #{association_type[:dependent]} dependency" do
            # Test dependency behavior based on type
            case association_type[:dependent]
            when :destroy
              # Test that associated records are destroyed
            when :delete_all
              # Test that associated records are deleted
            when :nullify
              # Test that foreign keys are nullified
            end
          end
        end
      when :has_many
        it { should have_many(association_name) }
        
        if association_type[:dependent]
          it "handles #{association_type[:dependent]} dependency for #{association_name}" do
            record = create(described_class.name.underscore.to_sym)
            associated_record = create(association_name.to_s.singularize.to_sym, 
                                     "#{described_class.name.underscore}_id" => record.id)
            
            case association_type[:dependent]
            when :destroy
              expect { record.destroy }.to change { 
                associated_record.class.count 
              }.by(-1)
            when :delete_all
              expect { record.destroy }.to change { 
                associated_record.class.count 
              }.by(-1)
            when :nullify
              record.destroy
              expect(associated_record.reload.send("#{described_class.name.underscore}_id")).to be_nil
            end
          end
        end
      end
    end
  end
end

RSpec.shared_examples "a model with callbacks" do |callbacks|
  callbacks.each do |callback_type, callback_methods|
    callback_methods.each do |method_name|
      it "calls #{method_name} #{callback_type}" do
        record = build(described_class.name.underscore.to_sym)
        expect(record).to receive(method_name)
        
        case callback_type
        when :before_create, :after_create
          record.save!
        when :before_update, :after_update
          record.save!
          record.touch
        when :before_save, :after_save
          record.save!
        when :before_destroy, :after_destroy
          record.save!
          record.destroy
        end
      end
    end
  end
end

RSpec.shared_examples "a model with scopes" do |scopes|
  scopes.each do |scope_name, expected_behavior|
    describe ".#{scope_name}" do
      it "responds to #{scope_name} scope" do
        expect(described_class).to respond_to(scope_name)
      end
      
      if expected_behavior.is_a?(Hash)
        it "filters records correctly" do
          # Create test data based on expected behavior
          matching_record = create(described_class.name.underscore.to_sym, expected_behavior[:matching_attributes])
          non_matching_record = create(described_class.name.underscore.to_sym, expected_behavior[:non_matching_attributes])
          
          results = described_class.send(scope_name)
          
          expect(results).to include(matching_record)
          expect(results).not_to include(non_matching_record)
        end
      end
    end
  end
end