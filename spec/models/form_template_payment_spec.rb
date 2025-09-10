require 'rails_helper'

RSpec.describe FormTemplate, type: :model do
  describe 'payment validation methods' do
    let(:template_with_payment) { create(:form_template, :with_payment_questions) }
    let(:template_without_payment) { create(:form_template) }

    describe '#has_payment_questions?' do
      it 'returns true for templates with payment questions' do
        expect(template_with_payment.has_payment_questions?).to be true
      end

      it 'returns false for templates without payment questions' do
        expect(template_without_payment.has_payment_questions?).to be false
      end
    end

    describe '#required_features' do
      it 'returns required features for payment templates' do
        features = template_with_payment.required_features
        expect(features).to include('stripe_payments')
        expect(features).to include('premium_subscription')
      end

      it 'returns empty array for non-payment templates' do
        expect(template_without_payment.required_features).to be_empty
      end
    end

    describe '#setup_complexity' do
      it 'returns complexity level for payment templates' do
        complexity = template_with_payment.setup_complexity
        expect(complexity).to be_in(['low', 'medium', 'high', 'very_high'])
      end

      it 'returns none for non-payment templates' do
        expect(template_without_payment.setup_complexity).to eq('none')
      end
    end
  end
end