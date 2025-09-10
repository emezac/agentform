require 'rails_helper'

RSpec.describe PaymentSetupValidationJob, type: :job do
  let(:user) { create(:user, :premium, :with_stripe_configuration) }
  let(:incomplete_user) { create(:user, :freemium) }
  let(:form_with_payments) { create(:form, user: user, template: create(:form_template, payment_enabled: true)) }
  let(:form_without_payments) { create(:form, user: user) }
  
  describe '#perform' do
    context 'with valid user setup' do
      it 'validates user payment setup successfully' do
        expect(PaymentSetupValidationService).to receive(:new).and_return(
          double(validate_user_requirements: {
            valid: true,
            missing_requirements: [],
            setup_actions: []
          })
        )
        
        result = described_class.new.perform(user.id, 'setup_change')
        
        expect(result[:validation_result][:valid]).to be true
        expect(result[:trigger_event]).to eq('setup_change')
      end
      
      it 'updates form statuses when validation changes' do
        create(:form, user: user, template: create(:form_template, payment_enabled: true))
        
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        result = described_class.new.perform(user.id, 'setup_completion')
        
        expect(result[:updated_forms_count]).to eq(1)
      end
      
      it 'broadcasts setup status updates' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}",
          hash_including(target: "payment_setup_status")
        )
        
        described_class.new.perform(user.id, 'setup_change')
      end
      
      it 'broadcasts setup completion notification' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}",
          hash_including(target: "payment_setup_status")
        )
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}",
          hash_including(target: "notifications")
        )
        
        described_class.new.perform(user.id, 'setup_completion')
      end
    end
    
    context 'with incomplete user setup' do
      it 'identifies missing requirements' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: false,
          missing_requirements: ['stripe_configuration', 'premium_subscription']
        })
        
        result = described_class.new.perform(incomplete_user.id, 'setup_change')
        
        expect(result[:validation_result][:valid]).to be false
        expect(result[:validation_result][:missing_requirements]).to include('stripe_configuration')
      end
      
      it 'calculates setup completion percentage' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: false,
          missing_requirements: ['stripe_configuration']
        })
        
        result = described_class.new.perform(incomplete_user.id, 'setup_change')
        
        expect(result[:validation_result][:setup_completion_percentage]).to eq(0)
      end
    end
    
    context 'form status updates' do
      it 'updates forms with payment questions only' do
        payment_form = create(:form, user: user, template: create(:form_template, payment_enabled: true))
        regular_form = create(:form, user: user, template: create(:form_template, payment_enabled: false))
        
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        result = described_class.new.perform(user.id, 'setup_change')
        
        expect(result[:updated_forms_count]).to eq(1)
        
        payment_form.reload
        expect(payment_form.payment_setup_complete).to be true
      end
      
      it 'tracks forms that changed status' do
        form = create(:form, user: user, template: create(:form_template, payment_enabled: true), payment_setup_complete: false)
        
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        described_class.new.perform(user.id, 'setup_change')
        
        form.reload
        expect(form.metadata['payment_validation']).to be_present
        expect(form.metadata['payment_validation']['last_validated_at']).to be_present
        expect(form.metadata['payment_validation']['trigger_event']).to eq('setup_change')
      end
      
      it 'broadcasts form-specific updates' do
        form = create(:form, user: user, template: create(:form_template, payment_enabled: true))
        
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "form_#{form.id}",
          hash_including(target: "form_payment_status_#{form.id}")
        )
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "form_editor_#{form.id}",
          hash_including(target: "payment_notification_bar")
        )
        
        described_class.new.perform(user.id, 'setup_change')
      end
    end
    
    context 'error handling' do
      it 'handles service errors gracefully' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements)
          .and_raise(StandardError.new('Validation failed'))
        
        expect(Rails.logger).to receive(:error).with(/Payment setup validation failed/)
        
        expect {
          described_class.new.perform(user.id, 'setup_change')
        }.to raise_error(StandardError, 'Validation failed')
      end
      
      it 'broadcasts error notification' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements)
          .and_raise(StandardError.new('Validation failed'))
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}",
          hash_including(target: "payment_setup_status")
        )
        
        expect {
          described_class.new.perform(user.id, 'setup_change')
        }.to raise_error(StandardError)
      end
      
      it 'handles missing user gracefully' do
        expect {
          described_class.new.perform('non-existent-id', 'setup_change')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    
    context 'retry behavior' do
      it 'is configured with correct queue and retry settings' do
        expect(described_class.sidekiq_options['queue']).to eq('critical')
        expect(described_class.sidekiq_options['retry']).to eq(3)
        expect(described_class.sidekiq_options['backtrace']).to be true
        expect(described_class.sidekiq_options['dead']).to be false
      end
      
      it 'implements exponential backoff correctly' do
        # Test the retry logic by calling the block directly
        retry_block = described_class.sidekiq_options['retry_in']
        
        expect(retry_block.call(0)).to eq(5)
        expect(retry_block.call(1)).to eq(30)
        expect(retry_block.call(2)).to eq(120)
      end
    end
    
    context 'logging' do
      it 'logs job start and completion' do
        allow_any_instance_of(PaymentSetupValidationService).to receive(:validate_user_requirements).and_return({
          valid: true,
          missing_requirements: []
        })
        
        expect(Rails.logger).to receive(:info).with(/Starting payment setup validation/)
        expect(Rails.logger).to receive(:info).with(/Completed payment setup validation/)
        
        described_class.new.perform(user.id, 'setup_change')
      end
    end
  end
  
  describe 'required features determination' do
    let(:job) { described_class.new }
    
    before do
      job.instance_variable_set(:@user, user)
    end
    
    it 'determines required features from user forms' do
      template1 = create(:form_template, payment_enabled: true, required_features: ['stripe_payments'])
      template2 = create(:form_template, payment_enabled: true, required_features: ['premium_subscription'])
      
      create(:form, user: user, template: template1)
      create(:form, user: user, template: template2)
      
      features = job.send(:determine_user_required_features)
      
      expect(features).to include('stripe_payments')
      expect(features).to include('premium_subscription')
    end
    
    it 'returns empty array when no payment forms exist' do
      create(:form, user: user, template: create(:form_template, payment_enabled: false))
      
      features = job.send(:determine_user_required_features)
      
      expect(features).to be_empty
    end
  end
  
  describe 'setup completion calculation' do
    let(:job) { described_class.new }
    
    it 'returns 100% when validation is valid' do
      validation_result = { valid: true }
      
      percentage = job.send(:calculate_setup_completion_percentage, validation_result)
      
      expect(percentage).to eq(100)
    end
    
    it 'returns 0% when validation is invalid' do
      validation_result = { 
        valid: false, 
        missing_requirements: ['stripe_configuration', 'premium_subscription'] 
      }
      
      percentage = job.send(:calculate_setup_completion_percentage, validation_result)
      
      expect(percentage).to eq(0)
    end
    
    it 'returns 0% when no requirements exist' do
      validation_result = { 
        valid: false, 
        missing_requirements: [] 
      }
      
      percentage = job.send(:calculate_setup_completion_percentage, validation_result)
      
      expect(percentage).to eq(0)
    end
  end
end