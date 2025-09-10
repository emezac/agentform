require 'rails_helper'

RSpec.describe TemplatePaymentAnalysisJob, type: :job do
  let(:user) { create(:user, :premium) }
  let(:template) { create(:form_template, :with_payment_questions) }
  let(:simple_template) { create(:form_template, :simple) }
  
  describe '#perform' do
    context 'with a template containing payment questions' do
      it 'analyzes payment requirements successfully' do
        expect(TemplateAnalysisService).to receive(:new).and_return(
          double(analyze_payment_requirements: {
            has_payment_questions: true,
            required_features: ['stripe_payments', 'premium_subscription'],
            setup_complexity: 'moderate'
          })
        )
        
        result = described_class.new.perform(template.id, user.id)
        
        expect(result[:has_payment_questions]).to be true
        expect(result[:required_features]).to include('stripe_payments')
        expect(result[:setup_complexity]).to eq('moderate')
      end
      
      it 'updates template metadata' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements).and_return({
          has_payment_questions: true,
          required_features: ['stripe_payments'],
          setup_complexity: 'simple'
        })
        
        described_class.new.perform(template.id, user.id)
        
        template.reload
        expect(template.payment_enabled).to be true
        expect(template.required_features).to include('stripe_payments')
        expect(template.setup_complexity).to eq('moderate')
        expect(template.metadata['payment_analysis']).to be_present
        expect(template.metadata['last_analyzed_at']).to be_present
      end
      
      it 'broadcasts completion notification when user is present' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements).and_return({
          has_payment_questions: true,
          required_features: ['stripe_payments'],
          setup_complexity: 'simple'
        })
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}",
          hash_including(target: "template_analysis_status_#{template.id}")
        )
        
        described_class.new.perform(template.id, user.id)
      end
      
      it 'does not broadcast when user is not present' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements).and_return({
          has_payment_questions: false,
          required_features: [],
          setup_complexity: 'simple'
        })
        
        expect(Turbo::StreamsChannel).not_to receive(:broadcast_update_to)
        
        described_class.new.perform(template.id)
      end
    end
    
    context 'with complex templates (>50 questions)' do
      let(:complex_template) do
        questions = []
        60.times do |i|
          questions << {
            'title' => "Question #{i + 1}",
            'question_type' => i < 3 ? ['payment', 'subscription', 'donation'].sample : 'text_short'
          }
        end
        
        create(:form_template, template_data: { 'questions' => questions })
      end
      
      it 'performs deep analysis for large templates' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements).and_return({
          has_payment_questions: true,
          required_features: ['stripe_payments'],
          setup_complexity: 'simple'
        })
        
        result = described_class.new.perform(complex_template.id, user.id)
        
        expect(result[:deep_analysis_performed]).to be true
        expect(result[:flow_complexity]).to be_present
        expect(result[:integration_requirements]).to be_present
      end
      
      it 'calculates payment flow complexity correctly' do
        # Use the complex template that has >50 questions including payment types
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements).and_return({
          has_payment_questions: true,
          required_features: ['stripe_payments'],
          setup_complexity: 'simple'
        })
        
        result = described_class.new.perform(complex_template.id, user.id)
        
        expect(result[:flow_complexity]).to eq('moderate') # 3+5+2 = 10 points
      end
    end
    
    context 'error handling' do
      it 'handles service errors gracefully' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements)
          .and_raise(StandardError.new('Analysis failed'))
        
        expect(Rails.logger).to receive(:error).with(/Template payment analysis failed/)
        
        expect {
          described_class.new.perform(template.id, user.id)
        }.to raise_error(StandardError, 'Analysis failed')
      end
      
      it 'broadcasts error notification when user is present' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements)
          .and_raise(StandardError.new('Analysis failed'))
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "user_#{user.id}",
          hash_including(target: "template_analysis_status_#{template.id}")
        )
        
        expect {
          described_class.new.perform(template.id, user.id)
        }.to raise_error(StandardError)
      end
      
      it 'handles missing template gracefully' do
        expect {
          described_class.new.perform('non-existent-id', user.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    
    context 'retry behavior' do
      it 'is configured with correct queue and retry settings' do
        expect(described_class.sidekiq_options['queue']).to eq('ai_processing')
        expect(described_class.sidekiq_options['retry']).to eq(5)
        expect(described_class.sidekiq_options['backtrace']).to be true
        expect(described_class.sidekiq_options['dead']).to be false
      end
      
      it 'implements exponential backoff correctly' do
        # Test the retry logic by calling the block directly
        retry_block = described_class.sidekiq_options['retry_in']
        
        expect(retry_block.call(0)).to eq(10)
        expect(retry_block.call(1)).to eq(20)
        expect(retry_block.call(2)).to eq(30)
        expect(retry_block.call(3)).to eq(60)
        expect(retry_block.call(4)).to eq(120)
        expect(retry_block.call(5)).to eq(300)
      end
    end
    
    context 'logging' do
      it 'logs job start and completion' do
        allow_any_instance_of(TemplateAnalysisService).to receive(:analyze_payment_requirements).and_return({
          has_payment_questions: false,
          required_features: [],
          setup_complexity: 'simple'
        })
        
        expect(Rails.logger).to receive(:info).with(/Starting template payment analysis/)
        expect(Rails.logger).to receive(:info).with(/Completed template payment analysis/)
        
        described_class.new.perform(template.id, user.id)
      end
    end
  end
  
  describe 'integration requirements detection' do
    let(:job) { described_class.new }
    
    it 'detects recurring payment requirements' do
      questions = [
        { 'question_type' => 'subscription' },
        { 'question_type' => 'payment' }
      ]
      
      requirements = job.send(:determine_integration_requirements, questions)
      
      expect(requirements).to include('recurring_payments')
    end
    
    it 'detects donation processing requirements' do
      questions = [
        { 'question_type' => 'donation' },
        { 'question_type' => 'payment' }
      ]
      
      requirements = job.send(:determine_integration_requirements, questions)
      
      expect(requirements).to include('donation_processing')
    end
    
    it 'detects multi-payment handling requirements' do
      questions = [
        { 'question_type' => 'payment' },
        { 'question_type' => 'payment' }
      ]
      
      requirements = job.send(:determine_integration_requirements, questions)
      
      expect(requirements).to include('multi_payment_handling')
    end
  end
end