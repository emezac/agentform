# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateAnalysisService, type: :service do
  let(:user) { create(:user) }
  
  describe '#call' do
    context 'with valid template' do
      let(:template_data) do
        {
          'questions' => [
            {
              'title' => 'Name',
              'question_type' => 'text_short',
              'required' => true
            },
            {
              'title' => 'Payment Information',
              'question_type' => 'payment',
              'required' => true,
              'configuration' => { 'amount' => 100 }
            },
            {
              'title' => 'Email',
              'question_type' => 'email',
              'required' => true
            }
          ]
        }
      end
      
      let(:template) { create(:form_template, template_data: template_data) }
      let(:service) { described_class.new(template: template) }

      it 'successfully analyzes template with payment questions' do
        result = service.call

        expect(result.success?).to be true
        expect(result.result[:has_payment_questions]).to be true
        expect(result.result[:payment_questions].length).to eq(1)
        expect(result.result[:required_features]).to include('stripe_payments', 'premium_subscription')
        expect(result.result[:setup_complexity]).to eq('medium')
      end

      it 'identifies payment question details correctly' do
        service.call
        payment_question = service.result[:payment_questions].first

        expect(payment_question[:position]).to eq(2)
        expect(payment_question[:title]).to eq('Payment Information')
        expect(payment_question[:question_type]).to eq('payment')
        expect(payment_question[:required]).to be true
        expect(payment_question[:configuration]).to eq({ 'amount' => 100 })
      end

      it 'sets appropriate context' do
        service.call

        expect(service.get_context(:analysis_completed_at)).to be_present
        expect(service.get_context(:questions_analyzed)).to eq(3)
      end
    end

    context 'with template without payment questions' do
      let(:template_data) do
        {
          'questions' => [
            {
              'title' => 'Name',
              'question_type' => 'text_short',
              'required' => true
            },
            {
              'title' => 'Email',
              'question_type' => 'email',
              'required' => true
            }
          ]
        }
      end
      
      let(:template) { create(:form_template, template_data: template_data) }
      let(:service) { described_class.new(template: template) }

      it 'correctly identifies no payment requirements' do
        service.call

        expect(service.success?).to be true
        expect(service.result[:has_payment_questions]).to be false
        expect(service.result[:payment_questions]).to be_empty
        expect(service.result[:required_features]).to be_empty
        expect(service.result[:setup_complexity]).to eq('none')
      end
    end

    context 'with multiple payment question types' do
      let(:template_data) do
        {
          'questions' => [
            {
              'title' => 'Payment',
              'question_type' => 'payment',
              'required' => true
            },
            {
              'title' => 'Subscription',
              'question_type' => 'subscription',
              'required' => true
            },
            {
              'title' => 'Donation',
              'question_type' => 'donation',
              'required' => false
            }
          ]
        }
      end
      
      let(:template) { create(:form_template, template_data: template_data) }
      let(:service) { described_class.new(template: template) }

      it 'identifies all payment questions and calculates high complexity' do
        service.call

        expect(service.result[:has_payment_questions]).to be true
        expect(service.result[:payment_questions].length).to eq(3)
        expect(service.result[:required_features]).to include(
          'stripe_payments', 
          'premium_subscription', 
          'subscription_management'
        )
        expect(service.result[:setup_complexity]).to eq('high')
      end
    end

    context 'with invalid inputs' do
      it 'fails when template is nil' do
        service = described_class.new(template: nil)
        service.call

        expect(service.failure?).to be true
        expect(service.errors[:template]).to include('is required')
      end

      it 'fails when template is not a FormTemplate' do
        service = described_class.new(template: 'invalid')
        service.call

        expect(service.failure?).to be true
        expect(service.errors[:template]).to include('must be a FormTemplate instance')
      end
    end

    context 'with empty template data' do
      let(:template) { create(:form_template, template_data: { 'questions' => [] }) }
      let(:service) { described_class.new(template: template) }

      it 'handles empty template gracefully' do
        service.call

        expect(service.success?).to be true
        expect(service.result[:has_payment_questions]).to be false
        expect(service.result[:payment_questions]).to be_empty
        expect(service.result[:setup_complexity]).to eq('none')
      end
    end
  end

  describe 'complexity calculation' do
    let(:service) { described_class.new(template: template) }

    context 'with low complexity features' do
      let(:template_data) do
        {
          'questions' => [
            { 'title' => 'Payment', 'question_type' => 'payment', 'required' => true }
          ]
        }
      end
      let(:template) { create(:form_template, template_data: template_data) }

      it 'calculates medium complexity for basic payment' do
        service.call
        expect(service.result[:setup_complexity]).to eq('medium')
      end
    end

    context 'with high complexity features' do
      let(:template_data) do
        {
          'questions' => [
            { 'title' => 'Payment', 'question_type' => 'payment', 'required' => true },
            { 'title' => 'Subscription', 'question_type' => 'subscription', 'required' => true }
          ]
        }
      end
      let(:template) { create(:form_template, template_data: template_data) }

      it 'calculates high complexity for multiple payment types' do
        service.call
        expect(service.result[:setup_complexity]).to eq('high')
      end
    end
  end
end