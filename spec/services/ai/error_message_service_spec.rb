# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::ErrorMessageService, type: :service do
  describe '.get_user_friendly_error' do
    context 'with credit limit exceeded error' do
      it 'returns appropriate error information' do
        result = described_class.get_user_friendly_error('credit_limit_exceeded', {
          credits_used: 8,
          monthly_limit: 10
        })

        expect(result[:title]).to eq('Monthly AI Usage Limit Reached')
        expect(result[:message]).to include('8 of your 10 monthly AI credits')
        expect(result[:severity]).to eq('warning')
        expect(result[:recoverable]).to be true
        expect(result[:actions]).to be_present
        expect(result[:actions].first[:label]).to eq('Upgrade Plan')
      end
    end

    context 'with content length error' do
      it 'handles content too short' do
        result = described_class.get_user_friendly_error('content_length_error', {
          word_count: 5
        })

        expect(result[:message]).to include('too short (5 words)')
        expect(result[:guidance]).to include('at least 10 words')
      end

      it 'handles content too long' do
        result = described_class.get_user_friendly_error('content_length_error', {
          word_count: 6000
        })

        expect(result[:message]).to include('too long (6000 words)')
        expect(result[:guidance]).to include('under 5,000 words')
      end
    end

    context 'with document processing error' do
      it 'customizes message for PDF errors' do
        result = described_class.get_user_friendly_error('document_processing_error', {
          error_class: 'PDF::Reader::MalformedPDFError'
        })

        expect(result[:message]).to include('corrupted or invalid')
        expect(result[:guidance]).to include('re-saving the PDF')
      end

      it 'customizes message for encoding errors' do
        result = described_class.get_user_friendly_error('document_processing_error', {
          error_class: 'Encoding::InvalidByteSequenceError'
        })

        expect(result[:message]).to include('encoding issues')
        expect(result[:guidance]).to include('UTF-8 encoding')
      end
    end

    context 'with unknown error type' do
      it 'returns generic error information' do
        result = described_class.get_user_friendly_error('nonexistent_error')

        expect(result[:title]).to eq('Unexpected Error')
        expect(result[:message]).to include('Something went wrong')
        expect(result[:severity]).to eq('error')
        expect(result[:recoverable]).to be true
      end
    end
  end

  describe 'retry context handling' do
    let(:service) { described_class.new(error_type: 'llm_error', retry_count: 2) }

    it 'adds retry context for multiple attempts' do
      result = service.get_user_friendly_error

      expect(result[:message]).to include('Multiple attempts failed')
      expect(result[:guidance]).to include('occurred 3 times')
    end

    it 'adds escalation path for persistent failures' do
      service = described_class.new(error_type: 'llm_error', retry_count: 3)
      result = service.get_user_friendly_error

      expect(result[:title]).to include('Persistent Issue')
      expect(result[:guidance]).to include('contacting our support team')
      expect(result[:actions].first[:action]).to eq('support')
    end
  end

  describe '.get_action_url' do
    it 'returns correct URLs for different actions' do
      expect(described_class.get_action_url('upgrade')).to eq('/subscriptions/upgrade')
      expect(described_class.get_action_url('support')).to eq('/support')
      expect(described_class.get_action_url('manual_form')).to eq('/forms/new')
      expect(described_class.get_action_url('retry', { current_url: '/test' })).to eq('/test')
    end
  end

  describe '.recoverable?' do
    it 'correctly identifies recoverable errors' do
      expect(described_class.recoverable?('credit_limit_exceeded')).to be true
      expect(described_class.recoverable?('llm_error')).to be true
      expect(described_class.recoverable?('unknown_error')).to be true
    end
  end

  describe '.get_severity' do
    it 'returns correct severity levels' do
      expect(described_class.get_severity('credit_limit_exceeded')).to eq('warn')
      expect(described_class.get_severity('llm_error')).to eq('error')
      expect(described_class.get_severity('empty_prompt')).to eq('info')
      expect(described_class.get_severity('nonexistent')).to eq('error')
    end
  end

  describe '.get_retry_delay' do
    it 'returns appropriate delays for different error types' do
      expect(described_class.get_retry_delay('rate_limit_error', 0)).to eq(30)
      expect(described_class.get_retry_delay('rate_limit_error', 1)).to eq(60)
      expect(described_class.get_retry_delay('llm_error', 0)).to eq(5)
      expect(described_class.get_retry_delay('content_length_error', 0)).to eq(0)
    end
  end
end