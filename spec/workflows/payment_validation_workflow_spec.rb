# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentValidationWorkflow, type: :workflow do
  let(:user) { create(:user) }
  let(:template) { create(:form_template) }

  # Mock the services to return successful results
  let(:successful_analysis_service) do
    double('TemplateAnalysisService',
      success?: true,
      result: {
        has_payment_questions: false,
        required_features: [],
        setup_complexity: 'none'
      }
    )
  end

  let(:successful_validation_service) do
    double('PaymentSetupValidationService',
      success?: true,
      result: {
        valid: true,
        missing_requirements: [],
        setup_actions: []
      }
    )
  end

  before do
    allow(TemplateAnalysisService).to receive(:call).and_return(successful_analysis_service)
    allow(PaymentSetupValidationService).to receive(:call).and_return(successful_validation_service)
  end

  describe '.execute' do
    context 'with valid inputs' do
      let(:params) { { template: template, user: user } }

      context 'when template has no payment questions' do
        it 'completes successfully without requiring payment setup' do
          result = described_class.execute(**params)

          expect(result[:success]).to be true
          expect(result[:guidance_type]).to eq('no_payment_setup_needed')
          expect(result[:can_proceed]).to be true
          expect(result[:setup_required]).to be false
        end
      end

      context 'when template has payment questions and user setup is complete' do
        before do
          # Mock analysis service to return payment questions found
          analysis_with_payments = double('TemplateAnalysisService',
            success?: true,
            result: {
              has_payment_questions: true,
              required_features: ['stripe_payments'],
              setup_complexity: 'moderate'
            }
          )
          allow(TemplateAnalysisService).to receive(:call).and_return(analysis_with_payments)
        end

        it 'completes successfully allowing user to proceed' do
          result = described_class.execute(**params)

          expect(result[:success]).to be true
          expect(result[:guidance_type]).to eq('setup_complete')
          expect(result[:can_proceed]).to be true
          expect(result[:setup_required]).to be false
        end
      end

    end

    context 'with invalid inputs' do
      it 'handles missing template gracefully' do
        result = described_class.execute(user: user)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include('Missing required inputs: template')
      end

      it 'handles missing user gracefully' do
        result = described_class.execute(template: template)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include('Missing required inputs: user')
      end
    end
  end
end