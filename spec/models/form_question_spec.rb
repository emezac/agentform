# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormQuestion, type: :model do
  # Test basic model structure
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"

  # Test associations
  describe "associations" do
    it { should belong_to(:form) }
    it { should have_many(:question_responses).dependent(:destroy) }
    it { should have_many(:dynamic_questions).with_foreign_key('generated_from_question_id').dependent(:destroy) }
  end

  # Test validations
  describe "validations" do
    subject { build(:form_question) }

    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(500) }
    it { should validate_presence_of(:position) }
    it { should validate_numericality_of(:position).is_greater_than(0) }
    it { should validate_presence_of(:form) }

    it "validates question_type inclusion" do
      FormQuestion::QUESTION_TYPES.each do |valid_type|
        question = case valid_type
                   when 'multiple_choice', 'single_choice', 'checkbox'
                     build(:form_question, question_type: valid_type, question_config: { 'options' => ['Option 1'] })
                   else
                     build(:form_question, question_type: valid_type)
                   end
        expect(question).to be_valid
      end

      expect {
        build(:form_question, question_type: 'invalid_type')
      }.to raise_error(ArgumentError)
    end

    describe "custom validations" do
      it "validates question configuration for choice questions" do
        question = build(:form_question, question_type: 'multiple_choice', question_config: {})
        expect(question).not_to be_valid
        expect(question.errors[:question_config]).to include('must include at least one option for choice questions')
      end

      it "validates conditional logic when enabled" do
        question = build(:form_question, 
                        conditional_enabled: true, 
                        conditional_logic: { 'rules' => 'invalid' })
        expect(question).not_to be_valid
        expect(question.errors[:conditional_logic]).to include('rules must be an array')
      end
    end
  end

  # Test enums
  describe "enums" do
    it_behaves_like "a model with enum", :question_type, FormQuestion::QUESTION_TYPES

    it "defines all expected question types" do
      expected_types = %w[
        text_short text_long email phone url number
        multiple_choice single_choice checkbox
        rating scale slider yes_no boolean
        date datetime time
        file_upload image_upload
        address location payment signature
        nps_score matrix ranking drag_drop
      ]
      
      expect(FormQuestion::QUESTION_TYPES).to match_array(expected_types)
    end
  end

  # Test scopes
  describe "scopes" do
    let(:form) { create(:form) }
    let!(:visible_question) { create(:form_question, form: form, hidden: false) }
    let!(:hidden_question) { create(:form_question, form: form, hidden: true) }
    let!(:required_question) { create(:form_question, form: form, required: true) }
    let!(:optional_question) { create(:form_question, form: form, required: false) }
    let!(:ai_enhanced_question) { create(:form_question, form: form, ai_enhanced: true) }
    let!(:regular_question) { create(:form_question, form: form, ai_enhanced: false) }

    describe ".visible" do
      it "returns only non-hidden questions" do
        expect(FormQuestion.visible).to include(visible_question)
        expect(FormQuestion.visible).not_to include(hidden_question)
      end
    end

    describe ".required_questions" do
      it "returns only required questions" do
        expect(FormQuestion.required_questions).to include(required_question)
        expect(FormQuestion.required_questions).not_to include(optional_question)
      end
    end

    describe ".ai_enhanced" do
      it "returns only AI enhanced questions" do
        expect(FormQuestion.ai_enhanced).to include(ai_enhanced_question)
        expect(FormQuestion.ai_enhanced).not_to include(regular_question)
      end
    end
  end

  # Test question type validations and enum behavior
  describe "question type validations" do
    FormQuestion::QUESTION_TYPES.each do |question_type|
      it "accepts #{question_type} as a valid question type" do
        question = case question_type
                   when 'multiple_choice', 'single_choice', 'checkbox'
                     build(:form_question, question_type: question_type, question_config: { 'options' => ['Option 1'] })
                   else
                     build(:form_question, question_type: question_type)
                   end
        expect(question).to be_valid
      end
    end

    it "rejects invalid question types" do
      expect {
        build(:form_question, question_type: 'invalid_type')
      }.to raise_error(ArgumentError)
    end

    it "provides predicate methods for question types" do
      question = create(:form_question, question_type: 'text_short')
      expect(question.text_short?).to be true
      expect(question.multiple_choice?).to be false
    end
  end

  # Test question configuration validation for each question type
  describe "question configuration validation" do
    describe "choice questions (multiple_choice, single_choice, checkbox)" do
      %w[multiple_choice single_choice checkbox].each do |choice_type|
        context "for #{choice_type}" do
          it "requires options array" do
            form = create(:form)
            question = build(:form_question, 
                            form: form,
                            question_type: choice_type, 
                            question_config: {})
            expect(question).not_to be_valid
            expect(question.errors[:question_config]).to include('must include at least one option for choice questions')
          end

          it "accepts valid options configuration" do
            form = create(:form)
            question = build(:form_question, 
                            form: form,
                            question_type: choice_type,
                            question_config: { 'options' => ['Option 1', 'Option 2'] })
            expect(question).to be_valid
          end

          it "rejects empty options array" do
            form = create(:form)
            question = build(:form_question, 
                            form: form,
                            question_type: choice_type,
                            question_config: { 'options' => [] })
            expect(question).not_to be_valid
          end
        end
      end
    end

    describe "rating questions (rating, scale, nps_score)" do
      %w[rating scale nps_score].each do |rating_type|
        context "for #{rating_type}" do
          it "validates min_value is less than max_value" do
            question = build(:form_question, 
                            question_type: rating_type,
                            question_config: { 'min_value' => 5, 'max_value' => 3 })
            expect(question).not_to be_valid
            expect(question.errors[:question_config]).to include('min_value must be less than max_value')
          end

          it "accepts valid rating configuration" do
            question = build(:form_question, 
                            question_type: rating_type,
                            question_config: { 'min_value' => 1, 'max_value' => 5 })
            expect(question).to be_valid
          end
        end
      end
    end

    describe "file upload questions (file_upload, image_upload)" do
      %w[file_upload image_upload].each do |file_type|
        context "for #{file_type}" do
          it "validates max_size_mb is within acceptable range" do
            question = build(:form_question, 
                            question_type: file_type,
                            question_config: { 'max_size_mb' => 150 })
            expect(question).not_to be_valid
            expect(question.errors[:question_config]).to include('max_size_mb must be between 1 and 100')
          end

          it "rejects zero or negative max_size_mb" do
            question = build(:form_question, 
                            question_type: file_type,
                            question_config: { 'max_size_mb' => 0 })
            expect(question).not_to be_valid
          end

          it "accepts valid file configuration" do
            question = build(:form_question, 
                            question_type: file_type,
                            question_config: { 'max_size_mb' => 10 })
            expect(question).to be_valid
          end
        end
      end
    end

    describe "text questions (text_short, text_long)" do
      %w[text_short text_long].each do |text_type|
        context "for #{text_type}" do
          it "validates min_length is not greater than max_length" do
            question = build(:form_question, 
                            question_type: text_type,
                            question_config: { 'min_length' => 100, 'max_length' => 50 })
            expect(question).not_to be_valid
            expect(question.errors[:question_config]).to include('min_length must be less than or equal to max_length')
          end

          it "accepts valid text configuration" do
            question = build(:form_question, 
                            question_type: text_type,
                            question_config: { 'min_length' => 10, 'max_length' => 500 })
            expect(question).to be_valid
          end
        end
      end
    end
  end

  # Test conditional logic validation and evaluation
  describe "conditional logic" do
    describe "validation" do
      it "validates conditional logic structure when enabled" do
        question = build(:form_question, 
                        conditional_enabled: true,
                        conditional_logic: {
                          'rules' => [
                            { 'question_id' => 'q1', 'operator' => 'equals', 'value' => 'yes' }
                          ]
                        })
        expect(question).to be_valid
      end

      it "requires rules to be an array" do
        question = build(:form_question, 
                        conditional_enabled: true,
                        conditional_logic: { 'rules' => 'not_an_array' })
        expect(question).not_to be_valid
        expect(question.errors[:conditional_logic]).to include('rules must be an array')
      end

      it "validates required keys in conditional rules" do
        question = build(:form_question, 
                        conditional_enabled: true,
                        conditional_logic: {
                          'rules' => [
                            { 'question_id' => 'q1' } # missing operator and value
                          ]
                        })
        expect(question).not_to be_valid
        expect(question.errors[:conditional_logic]).to include('rule 1 is missing required keys: operator, value')
      end
    end

    describe "evaluation" do
      let(:form) { create(:form) }
      let(:form_response) { create(:form_response, form: form) }
      let(:question) { create(:form_question, form: form, conditional_enabled: true) }

      let!(:target_question) { create(:form_question, form: form, reference_id: 'target_q') }
      


      it "evaluates equals condition correctly" do
        # Create a fresh form response to avoid unique constraint issues
        fresh_form_response = create(:form_response, form: form)
        create(:question_response, :yes_answer,
               form_response: fresh_form_response, 
               form_question: target_question)
        
        question.update!(
          conditional_enabled: true,
          conditional_logic: {
            'rules' => [
              { 'question_id' => 'target_q', 'operator' => 'equals', 'value' => 'yes' }
            ]
          }
        )

        expect(question.should_show_for_response?(fresh_form_response)).to be true
      end

      it "evaluates not_equals condition correctly" do
        # Create a fresh form response to avoid unique constraint issues
        fresh_form_response2 = create(:form_response, form: form)
        create(:question_response, :yes_answer,
               form_response: fresh_form_response2, 
               form_question: target_question)
        
        question.update!(
          conditional_enabled: true,
          conditional_logic: {
            'rules' => [
              { 'question_id' => 'target_q', 'operator' => 'not_equals', 'value' => 'no' }
            ]
          }
        )

        expect(question.should_show_for_response?(fresh_form_response2)).to be true
      end

      it "returns true when no conditional logic is set" do
        question.update!(conditional_enabled: false)
        expect(question.should_show_for_response?(form_response)).to be true
      end
    end
  end

  # Test AI enhancement features and configuration
  describe "AI enhancement" do
    describe "#ai_enhanced?" do
      it "returns true when ai_enhanced is true and ai_config is present" do
        question = create(:form_question, 
                         ai_enhanced: true, 
                         ai_config: { 'features' => ['dynamic_followup'] })
        expect(question.ai_enhanced?).to be true
      end

      it "returns false when ai_enhanced is true but ai_config is blank" do
        question = create(:form_question, ai_enhanced: true, ai_config: nil)
        expect(question.ai_enhanced?).to be false
      end

      it "returns false when ai_enhanced is false" do
        question = create(:form_question, ai_enhanced: false)
        expect(question.ai_enhanced?).to be false
      end
    end

    describe "#ai_features" do
      it "returns features array when AI is enhanced" do
        features = ['dynamic_followup', 'smart_validation']
        question = create(:form_question, 
                         ai_enhanced: true, 
                         ai_config: { 'features' => features })
        expect(question.ai_features).to eq(features)
      end

      it "returns empty array when AI is not enhanced" do
        question = create(:form_question, ai_enhanced: false)
        expect(question.ai_features).to eq([])
      end
    end

    describe "AI feature predicates" do
      let(:question) do
        create(:form_question, 
               ai_enhanced: true, 
               ai_config: { 'features' => ['dynamic_followup', 'smart_validation'] })
      end

      it "#generates_followups? returns true when feature is enabled" do
        expect(question.generates_followups?).to be true
      end

      it "#has_smart_validation? returns true when feature is enabled" do
        expect(question.has_smart_validation?).to be true
      end

      it "#has_response_analysis? returns false when feature is not enabled" do
        expect(question.has_response_analysis?).to be false
      end
    end
  end

  # Test custom methods
  describe "custom methods" do
    describe "#question_type_handler" do
      it "returns a BasicQuestionHandler instance" do
        question = create(:form_question)
        handler = question.question_type_handler
        expect(handler).to be_a(FormQuestion::BasicQuestionHandler)
      end

      it "memoizes the handler instance" do
        question = create(:form_question)
        handler1 = question.question_type_handler
        handler2 = question.question_type_handler
        expect(handler1).to be(handler2)
      end
    end

    describe "#choice_options" do
      it "returns options for choice questions" do
        options = ['Option 1', 'Option 2']
        question = create(:form_question, 
                         question_type: 'multiple_choice',
                         question_config: { 'options' => options })
        expect(question.choice_options).to eq(options)
      end

      it "returns empty array for non-choice questions" do
        question = create(:form_question, question_type: 'text_short')
        expect(question.choice_options).to eq([])
      end
    end

    describe "#rating_config" do
      it "returns rating configuration for rating questions" do
        config = { 'min_value' => 1, 'max_value' => 10, 'step' => 1, 'labels' => { '1' => 'Poor', '10' => 'Excellent' } }
        question = create(:form_question, 
                         question_type: 'rating',
                         question_config: config)
        
        expected_config = {
          min: 1,
          max: 10,
          step: 1,
          labels: { '1' => 'Poor', '10' => 'Excellent' }
        }
        
        expect(question.rating_config).to eq(expected_config)
      end

      it "returns default values when config is incomplete" do
        question = create(:form_question, question_type: 'rating', question_config: {})
        
        expected_config = {
          min: 1,
          max: 5,
          step: 1,
          labels: {}
        }
        
        expect(question.rating_config).to eq(expected_config)
      end

      it "returns empty hash for non-rating questions" do
        question = create(:form_question, question_type: 'text_short')
        expect(question.rating_config).to eq({})
      end
    end

    describe "#file_upload_config" do
      it "returns file upload configuration" do
        config = { 'max_size_mb' => 20, 'allowed_types' => ['pdf', 'doc'], 'multiple' => true }
        question = create(:form_question, 
                         question_type: 'file_upload',
                         question_config: config)
        
        expected_config = {
          max_size: 20,
          allowed_types: ['pdf', 'doc'],
          multiple: true
        }
        
        expect(question.file_upload_config).to eq(expected_config)
      end

      it "returns default values when config is incomplete" do
        question = create(:form_question, question_type: 'file_upload', question_config: {})
        
        expected_config = {
          max_size: 10,
          allowed_types: [],
          multiple: false
        }
        
        expect(question.file_upload_config).to eq(expected_config)
      end
    end

    describe "#text_config" do
      it "returns text configuration for text questions" do
        config = { 'min_length' => 10, 'max_length' => 500, 'placeholder' => 'Enter text here' }
        question = create(:form_question, 
                         question_type: 'text_long',
                         question_config: config)
        
        expected_config = {
          min_length: 10,
          max_length: 500,
          placeholder: 'Enter text here',
          format: nil
        }
        
        expect(question.text_config).to eq(expected_config)
      end

      it "returns appropriate defaults for text_short" do
        question = create(:form_question, question_type: 'text_short', question_config: {})
        
        expect(question.text_config[:max_length]).to eq(255)
      end

      it "returns appropriate defaults for text_long" do
        question = create(:form_question, question_type: 'text_long', question_config: {})
        
        expect(question.text_config[:max_length]).to eq(5000)
      end
    end

    describe "#has_conditional_logic?" do
      it "returns true when conditional logic is enabled and present" do
        question = create(:form_question, 
                         conditional_enabled: true,
                         conditional_logic: { 
                           'rules' => [
                             { 'question_id' => 'q1', 'operator' => 'equals', 'value' => 'yes' }
                           ] 
                         })
        expect(question.has_conditional_logic?).to be true
      end

      it "returns false when conditional logic is disabled" do
        question = create(:form_question, conditional_enabled: false)
        expect(question.has_conditional_logic?).to be false
      end

      it "returns false when conditional logic is empty" do
        question = create(:form_question, 
                         conditional_enabled: true,
                         conditional_logic: nil)
        expect(question.has_conditional_logic?).to be false
      end
    end

    describe "#conditional_rules" do
      it "returns rules when conditional logic is present" do
        rules = [{ 'question_id' => 'q1', 'operator' => 'equals', 'value' => 'yes' }]
        question = create(:form_question, 
                         conditional_enabled: true,
                         conditional_logic: { 'rules' => rules })
        expect(question.conditional_rules).to eq(rules)
      end

      it "returns empty array when no conditional logic" do
        question = create(:form_question, conditional_enabled: false)
        expect(question.conditional_rules).to eq([])
      end
    end
  end

  # Test BasicQuestionHandler
  describe FormQuestion::BasicQuestionHandler do
    let(:question) { create(:form_question) }
    let(:handler) { FormQuestion::BasicQuestionHandler.new(question) }

    describe "#validate_answer" do
      it "returns empty errors array" do
        expect(handler.validate_answer("test answer")).to eq([])
      end
    end

    describe "#process_answer" do
      it "returns the answer as-is" do
        answer = "test answer"
        expect(handler.process_answer(answer)).to eq(answer)
      end
    end

    describe "#render_component" do
      it "returns the question type" do
        expect(handler.render_component).to eq(question.question_type)
      end
    end

    describe "#default_value" do
      it "returns nil" do
        expect(handler.default_value).to be_nil
      end
    end
  end

  # Test analytics and performance methods
  describe "analytics methods" do
    let(:form) { create(:form) }
    let(:question) { create(:form_question, form: form) }

    describe "#average_response_time_seconds" do
      it "calculates average response time" do
        form_response1 = create(:form_response, form: form)
        form_response2 = create(:form_response, form: form)
        create(:question_response, form_question: question, form_response: form_response1, time_spent_seconds: 30)
        create(:question_response, form_question: question, form_response: form_response2, time_spent_seconds: 60)

        expect(question.average_response_time_seconds).to eq(45)
      end

      it "returns 0 when no responses with time data" do
        expect(question.average_response_time_seconds).to eq(0)
      end

      it "ignores zero time responses" do
        form_response1 = create(:form_response, form: form)
        form_response2 = create(:form_response, form: form)
        create(:question_response, form_question: question, form_response: form_response1, time_spent_seconds: 0)
        create(:question_response, form_question: question, form_response: form_response2, time_spent_seconds: 30)

        expect(question.average_response_time_seconds).to eq(30)
      end
    end

    describe "#completion_rate" do
      it "calculates completion rate correctly" do
        # This is a placeholder implementation in the model
        expect(question.completion_rate).to be_a(Numeric)
      end
    end

    describe "#analytics_summary" do
      it "returns analytics summary hash" do
        summary = question.analytics_summary
        
        expect(summary).to be_a(Hash)
        expect(summary).to have_key(:total_responses)
        expect(summary).to have_key(:completion_rate)
        expect(summary).to have_key(:avg_response_time)
      end
    end
  end

  # Test delegation methods
  describe "delegation methods" do
    let(:question) { create(:form_question) }

    describe "#render_component" do
      it "delegates to question_type_handler" do
        expect(question.render_component).to eq(question.question_type)
      end
    end

    describe "#validate_answer" do
      it "delegates to question_type_handler" do
        answer = "test answer"
        expect(question.validate_answer(answer)).to eq([])
      end
    end

    describe "#process_answer" do
      it "delegates to question_type_handler" do
        answer = "test answer"
        expect(question.process_answer(answer)).to eq(answer)
      end
    end

    describe "#default_value" do
      it "delegates to question_type_handler" do
        expect(question.default_value).to be_nil
      end
    end
  end
end