# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentRequirementDetector do
  describe '.payment_question?' do
    context 'with direct payment question types' do
      it 'identifies payment question type' do
        question = { 'question_type' => 'payment', 'title' => 'Payment Info' }
        expect(described_class.payment_question?(question)).to be true
      end

      it 'identifies subscription question type' do
        question = { 'question_type' => 'subscription', 'title' => 'Subscription Plan' }
        expect(described_class.payment_question?(question)).to be true
      end

      it 'identifies donation question type' do
        question = { 'question_type' => 'donation', 'title' => 'Donation Amount' }
        expect(described_class.payment_question?(question)).to be true
      end
    end

    context 'with payment-related keywords in title' do
      it 'identifies payment keywords' do
        question = { 'question_type' => 'text_short', 'title' => 'Payment Amount' }
        expect(described_class.payment_question?(question)).to be true
      end

      it 'identifies price keywords' do
        question = { 'question_type' => 'number', 'title' => 'Product Price' }
        expect(described_class.payment_question?(question)).to be true
      end

      it 'identifies subscription keywords' do
        question = { 'question_type' => 'single_choice', 'title' => 'Choose Subscription Plan' }
        expect(described_class.payment_question?(question)).to be true
      end

      it 'identifies billing keywords' do
        question = { 'question_type' => 'text_long', 'title' => 'Billing Address' }
        expect(described_class.payment_question?(question)).to be true
      end
    end

    context 'with payment-related keywords in description' do
      it 'identifies payment keywords in description' do
        question = { 
          'question_type' => 'text_short', 
          'title' => 'Amount',
          'description' => 'Enter the payment amount for your order'
        }
        expect(described_class.payment_question?(question)).to be true
      end
    end

    context 'with non-payment questions' do
      it 'does not identify regular text questions' do
        question = { 'question_type' => 'text_short', 'title' => 'Your Name' }
        expect(described_class.payment_question?(question)).to be false
      end

      it 'does not identify email questions' do
        question = { 'question_type' => 'email', 'title' => 'Email Address' }
        expect(described_class.payment_question?(question)).to be false
      end
    end

    context 'with invalid inputs' do
      it 'handles nil input' do
        expect(described_class.payment_question?(nil)).to be false
      end

      it 'handles non-hash input' do
        expect(described_class.payment_question?('invalid')).to be false
      end

      it 'handles empty hash' do
        expect(described_class.payment_question?({})).to be false
      end
    end
  end

  describe '.detect_in_template' do
    context 'with FormTemplate object' do
      let(:template_data) do
        {
          'questions' => [
            { 'title' => 'Name', 'question_type' => 'text_short' },
            { 'title' => 'Payment', 'question_type' => 'payment', 'required' => true },
            { 'title' => 'Email', 'question_type' => 'email' }
          ]
        }
      end
      let(:template) { create(:form_template, template_data: template_data) }

      it 'detects payment questions in template' do
        result = described_class.detect_in_template(template)

        expect(result[:has_payment_questions]).to be true
        expect(result[:payment_questions].length).to eq(1)
        expect(result[:payment_questions].first[:position]).to eq(2)
        expect(result[:payment_questions].first[:title]).to eq('Payment')
        expect(result[:payment_questions].first[:question_type]).to eq('payment')
        expect(result[:payment_questions].first[:required]).to be true
      end
    end

    context 'with hash template data' do
      let(:template_data) do
        {
          'questions' => [
            { 'title' => 'Subscription Plan', 'question_type' => 'subscription' },
            { 'title' => 'Donation Amount', 'question_type' => 'donation' }
          ]
        }
      end

      it 'detects multiple payment question types' do
        result = described_class.detect_in_template(template_data)

        expect(result[:has_payment_questions]).to be true
        expect(result[:payment_questions].length).to eq(2)
        expect(result[:required_features]).to include('stripe_payments', 'premium_subscription', 'subscription_management')
      end
    end

    context 'with array of questions' do
      let(:questions) do
        [
          { 'title' => 'Name', 'question_type' => 'text_short' },
          { 'title' => 'Payment Info', 'question_type' => 'payment' }
        ]
      end

      it 'detects payment questions in array' do
        result = described_class.detect_in_template(questions)

        expect(result[:has_payment_questions]).to be true
        expect(result[:payment_questions].length).to eq(1)
      end
    end

    context 'with no payment questions' do
      let(:template_data) do
        {
          'questions' => [
            { 'title' => 'Name', 'question_type' => 'text_short' },
            { 'title' => 'Email', 'question_type' => 'email' }
          ]
        }
      end

      it 'returns no payment questions' do
        result = described_class.detect_in_template(template_data)

        expect(result[:has_payment_questions]).to be false
        expect(result[:payment_questions]).to be_empty
        expect(result[:required_features]).to be_empty
      end
    end

    context 'with invalid template' do
      it 'handles nil template' do
        result = described_class.detect_in_template(nil)

        expect(result[:has_payment_questions]).to be false
        expect(result[:payment_questions]).to be_empty
      end

      it 'handles invalid template type' do
        result = described_class.detect_in_template('invalid')

        expect(result[:has_payment_questions]).to be false
        expect(result[:payment_questions]).to be_empty
      end
    end
  end

  describe '.required_features_for_question_type' do
    it 'returns correct features for payment type' do
      features = described_class.required_features_for_question_type('payment')
      expect(features).to eq(%w[stripe_payments premium_subscription])
    end

    it 'returns correct features for subscription type' do
      features = described_class.required_features_for_question_type('subscription')
      expect(features).to eq(%w[stripe_payments premium_subscription subscription_management])
    end

    it 'returns correct features for donation type' do
      features = described_class.required_features_for_question_type('donation')
      expect(features).to eq(%w[stripe_payments premium_subscription])
    end

    it 'returns empty array for unknown type' do
      features = described_class.required_features_for_question_type('unknown')
      expect(features).to be_empty
    end
  end

  describe '.payment_keyword_present?' do
    it 'detects payment keywords' do
      expect(described_class.payment_keyword_present?('Enter payment amount')).to be true
      expect(described_class.payment_keyword_present?('Subscription plan selection')).to be true
      expect(described_class.payment_keyword_present?('Donation for charity')).to be true
      expect(described_class.payment_keyword_present?('Product price information')).to be true
    end

    it 'handles case insensitive matching' do
      expect(described_class.payment_keyword_present?('PAYMENT AMOUNT')).to be true
      expect(described_class.payment_keyword_present?('Payment Amount')).to be true
    end

    it 'does not detect non-payment text' do
      expect(described_class.payment_keyword_present?('Your name')).to be false
      expect(described_class.payment_keyword_present?('Email address')).to be false
      expect(described_class.payment_keyword_present?('Phone number')).to be false
    end

    it 'handles empty or nil text' do
      expect(described_class.payment_keyword_present?(nil)).to be false
      expect(described_class.payment_keyword_present?('')).to be false
      expect(described_class.payment_keyword_present?('   ')).to be false
    end
  end

  describe '.setup_requirements' do
    let(:template_data) do
      {
        'questions' => [
          { 'title' => 'Payment', 'question_type' => 'payment' },
          { 'title' => 'Subscription', 'question_type' => 'subscription' }
        ]
      }
    end

    it 'returns setup requirements for payment template' do
      requirements = described_class.setup_requirements(template_data)

      expect(requirements.length).to eq(3)
      
      stripe_req = requirements.find { |r| r[:type] == 'stripe_configuration' }
      expect(stripe_req[:title]).to eq('Stripe Payment Configuration')
      expect(stripe_req[:priority]).to eq('high')

      premium_req = requirements.find { |r| r[:type] == 'premium_subscription' }
      expect(premium_req[:title]).to eq('Premium Subscription')
      expect(premium_req[:priority]).to eq('high')

      subscription_req = requirements.find { |r| r[:type] == 'subscription_management' }
      expect(subscription_req[:title]).to eq('Subscription Management Setup')
      expect(subscription_req[:priority]).to eq('medium')
    end

    it 'returns empty requirements for non-payment template' do
      template_data = {
        'questions' => [
          { 'title' => 'Name', 'question_type' => 'text_short' }
        ]
      }

      requirements = described_class.setup_requirements(template_data)
      expect(requirements).to be_empty
    end
  end

  describe '.payment_complexity_score' do
    it 'calculates complexity score correctly' do
      template_data = {
        'questions' => [
          { 'title' => 'Payment', 'question_type' => 'payment' },
          { 'title' => 'Subscription', 'question_type' => 'subscription' }
        ]
      }

      score = described_class.payment_complexity_score(template_data)
      expect(score).to eq(7) # 2 questions * 2 + 3 features
    end

    it 'returns 0 for non-payment template' do
      template_data = {
        'questions' => [
          { 'title' => 'Name', 'question_type' => 'text_short' }
        ]
      }

      score = described_class.payment_complexity_score(template_data)
      expect(score).to eq(0)
    end
  end

  describe '.requires_premium?' do
    it 'returns true for templates with payment questions' do
      template_data = {
        'questions' => [
          { 'title' => 'Payment', 'question_type' => 'payment' }
        ]
      }

      expect(described_class.requires_premium?(template_data)).to be true
    end

    it 'returns false for templates without payment questions' do
      template_data = {
        'questions' => [
          { 'title' => 'Name', 'question_type' => 'text_short' }
        ]
      }

      expect(described_class.requires_premium?(template_data)).to be false
    end
  end
end