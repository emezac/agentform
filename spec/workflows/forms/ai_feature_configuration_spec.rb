# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Feature Configuration System', type: :workflow do
  let(:workflow) { Forms::AiFormGenerationWorkflow.new }
  
  describe '#determine_ai_features' do
    context 'for feedback forms' do
      let(:content_analysis) do
        {
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'requires_branching_logic' => false
        }
      end
      
      it 'includes sentiment analysis and response categorization' do
        features = workflow.send(:determine_ai_features, content_analysis)
        
        expect(features).to include('response_validation')
        expect(features).to include('sentiment_analysis')
        expect(features).to include('response_categorization')
        expect(features).to include('response_quality_scoring')
      end
    end
    
    context 'for lead capture forms' do
      let(:content_analysis) do
        {
          'recommended_approach' => 'lead_capture',
          'complexity_level' => 'complex',
          'requires_branching_logic' => true
        }
      end
      
      it 'includes lead scoring and intent detection with dynamic followup' do
        features = workflow.send(:determine_ai_features, content_analysis)
        
        expect(features).to include('response_validation')
        expect(features).to include('lead_scoring')
        expect(features).to include('intent_detection')
        expect(features).to include('dynamic_followup')
        expect(features).to include('advanced_analytics')
        expect(features).to include('completion_prediction')
      end
    end
    
    context 'for assessment forms' do
      let(:content_analysis) do
        {
          'recommended_approach' => 'assessment',
          'complexity_level' => 'simple',
          'requires_branching_logic' => false
        }
      end
      
      it 'includes assessment-specific features' do
        features = workflow.send(:determine_ai_features, content_analysis)
        
        expect(features).to include('response_validation')
        expect(features).to include('answer_confidence_scoring')
        expect(features).to include('knowledge_gap_analysis')
        expect(features).not_to include('dynamic_followup')
      end
    end
  end
  
  describe '#should_enable_ai_for_question?' do
    it 'enables AI for text_long questions' do
      result = workflow.send(:should_enable_ai_for_question?, 'text_long')
      expect(result).to be true
    end
    
    it 'enables AI for email questions' do
      result = workflow.send(:should_enable_ai_for_question?, 'email')
      expect(result).to be true
    end
    
    it 'enables AI for rating questions' do
      result = workflow.send(:should_enable_ai_for_question?, 'rating')
      expect(result).to be true
    end
    
    it 'does not enable AI for basic text_short questions' do
      result = workflow.send(:should_enable_ai_for_question?, 'text_short')
      expect(result).to be false
    end
    
    it 'does not enable AI for date questions' do
      result = workflow.send(:should_enable_ai_for_question?, 'date')
      expect(result).to be false
    end
  end
  
  describe '#build_question_ai_config' do
    context 'for text_long questions' do
      let(:question_data) { { 'question_type' => 'text_long' } }
      
      it 'configures comprehensive text analysis' do
        config = workflow.send(:build_question_ai_config, question_data, true)
        
        expect(config[:sentiment_analysis]).to be true
        expect(config[:keyword_extraction]).to be true
        expect(config[:quality_scoring]).to be true
        expect(config[:auto_categorization]).to be true
      end
    end
    
    context 'for email questions' do
      let(:question_data) { { 'question_type' => 'email' } }
      
      it 'configures email validation enhancements' do
        config = workflow.send(:build_question_ai_config, question_data, true)
        
        expect(config[:validation_enhancement]).to be true
        expect(config[:format_suggestions]).to be true
        expect(config[:domain_verification]).to be true
      end
    end
    
    context 'for non-AI enhanced questions' do
      let(:question_data) { { 'question_type' => 'date' } }
      
      it 'returns empty config' do
        config = workflow.send(:build_question_ai_config, question_data, false)
        expect(config).to eq({})
      end
    end
  end
  
  describe '#build_form_settings' do
    let(:base_settings) { { 'allow_multiple_submissions' => true } }
    
    context 'for complex forms' do
      let(:content_analysis) do
        {
          'complexity_level' => 'complex',
          'suggested_question_count' => 8,
          'recommended_approach' => 'lead_capture'
        }
      end
      
      it 'optimizes settings for complex forms' do
        settings = workflow.send(:build_form_settings, base_settings, content_analysis)
        
        expect(settings['one_question_per_page']).to be true
        expect(settings['show_progress_bar']).to be true
        expect(settings['auto_save_enabled']).to be true
        expect(settings['collect_email']).to be true
        expect(settings['mobile_optimized']).to be true
      end
    end
    
    context 'for simple forms' do
      let(:content_analysis) do
        {
          'complexity_level' => 'simple',
          'suggested_question_count' => 3,
          'recommended_approach' => 'feedback'
        }
      end
      
      it 'uses basic settings for simple forms' do
        settings = workflow.send(:build_form_settings, base_settings, content_analysis)
        
        expect(settings['one_question_per_page']).to be_falsy
        expect(settings['show_progress_bar']).to be_falsy
        expect(settings['collect_email']).to be_falsy
        expect(settings['mobile_optimized']).to be true
      end
    end
  end
  
  describe '#generate_thank_you_message' do
    it 'generates contextual messages for different approaches' do
      lead_capture_analysis = { 'recommended_approach' => 'lead_capture' }
      feedback_analysis = { 'recommended_approach' => 'feedback' }
      registration_analysis = { 'recommended_approach' => 'registration' }
      
      expect(workflow.send(:generate_thank_you_message, lead_capture_analysis))
        .to eq("Thank you for your interest! We'll be in touch soon.")
      
      expect(workflow.send(:generate_thank_you_message, feedback_analysis))
        .to eq("Thank you for your valuable feedback!")
      
      expect(workflow.send(:generate_thank_you_message, registration_analysis))
        .to eq("Thank you for registering! Check your email for next steps.")
    end
  end
end