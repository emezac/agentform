# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicQuestion, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"

  # Associations
  describe "associations" do
    it { should belong_to(:form_response) }
    it { should belong_to(:generated_from_question).class_name('FormQuestion').optional }
  end

  # Validations
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_inclusion_of(:question_type).in_array(FormQuestion::QUESTION_TYPES) }
  end

  # Scopes
  describe "scopes" do
    let(:form_response) { create(:form_response) }
    let!(:answered_question) { create(:dynamic_question, :answered, form_response: form_response) }
    let!(:unanswered_question) { create(:dynamic_question, form_response: form_response) }
    let!(:high_confidence_question) { create(:dynamic_question, :with_high_confidence, form_response: form_response) }
    let!(:low_confidence_question) { create(:dynamic_question, :with_low_confidence, form_response: form_response) }

    describe ".answered" do
      it "returns questions with answer data" do
        expect(DynamicQuestion.answered).to include(answered_question)
        expect(DynamicQuestion.answered).not_to include(unanswered_question)
      end
    end

    describe ".unanswered" do
      it "returns questions without answer data" do
        expect(DynamicQuestion.unanswered).to include(unanswered_question)
        expect(DynamicQuestion.unanswered).not_to include(answered_question)
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        results = DynamicQuestion.recent
        expect(results.first.created_at).to be >= results.last.created_at
      end
    end

    describe ".by_confidence" do
      it "filters by minimum confidence level" do
        results = DynamicQuestion.by_confidence(0.8)
        expect(results).to include(high_confidence_question)
        expect(results).not_to include(low_confidence_question)
      end
    end
  end

  # Callbacks
  describe "callbacks" do
    describe "before_save" do
      it "ensures configuration defaults are set" do
        question = build(:dynamic_question, question_type: 'text_short', configuration: nil)
        question.save!
        
        expect(question.configuration).to be_present
        expect(question.configuration['max_length']).to eq(255)
      end

      it "sets rating configuration defaults" do
        question = build(:dynamic_question, question_type: 'rating', configuration: {})
        question.save!
        
        expect(question.configuration['min_value']).to eq(1)
        expect(question.configuration['max_value']).to eq(5)
      end

      it "sets scale configuration defaults" do
        question = build(:dynamic_question, question_type: 'scale', configuration: {})
        question.save!
        
        expect(question.configuration['min_value']).to eq(0)
        expect(question.configuration['max_value']).to eq(10)
      end

      it "ensures generation_context is set" do
        question = build(:dynamic_question, generation_context: nil)
        question.save!
        
        expect(question.generation_context).to eq({})
      end
    end
  end

  # Core Methods
  describe "#question_type_handler" do
    it "returns appropriate handler for question type" do
      question = build(:dynamic_question, question_type: 'text_short')
      
      # Mock the handler class
      handler_class = double('QuestionTypes::TextShort')
      handler_instance = double('handler_instance')
      
      allow(handler_class).to receive(:new).with(question).and_return(handler_instance)
      stub_const('QuestionTypes::TextShort', handler_class)
      
      expect(question.question_type_handler).to eq(handler_instance)
    end

    it "falls back to base handler for unknown types" do
      question = build(:dynamic_question, question_type: 'unknown_type')
      
      base_handler = double('QuestionTypes::Base')
      handler_instance = double('base_handler_instance')
      
      allow(base_handler).to receive(:new).with(question).and_return(handler_instance)
      stub_const('QuestionTypes::Base', base_handler)
      
      expect(question.question_type_handler).to eq(handler_instance)
    end
  end

  describe "#validate_answer" do
    it "delegates to question type handler" do
      question = create(:dynamic_question)
      handler = double('handler')
      answer = 'test answer'
      
      allow(question).to receive(:question_type_handler).and_return(handler)
      expect(handler).to receive(:validate_answer).with(answer).and_return(true)
      
      expect(question.validate_answer(answer)).to be true
    end
  end

  describe "#process_answer" do
    it "processes and stores answer data" do
      question = create(:dynamic_question, question_type: 'text_short')
      handler = double('handler')
      raw_answer = 'test answer'
      processed_answer = 'processed test answer'
      
      allow(question).to receive(:question_type_handler).and_return(handler)
      allow(handler).to receive(:process_answer).with(raw_answer).and_return(processed_answer)
      
      result = question.process_answer(raw_answer)
      
      expect(result).to eq(processed_answer)
      expect(question.answer_data['raw_answer']).to eq(raw_answer)
      expect(question.answer_data['processed_answer']).to eq(processed_answer)
      expect(question.answer_data['question_type']).to eq('text_short')
      expect(question.answer_data['answered_at']).to be_present
    end
  end

  describe "#generation_reasoning" do
    it "returns reasoning from generation context" do
      question = build(:dynamic_question, generation_context: { 'reasoning' => 'User mentioned specific concern' })
      expect(question.generation_reasoning).to eq('User mentioned specific concern')
    end

    it "returns default message when no reasoning provided" do
      question = build(:dynamic_question, generation_context: {})
      expect(question.generation_reasoning).to eq('No reasoning provided')
    end
  end

  describe "#was_answered?" do
    it "returns true when answer data is present" do
      question = create(:dynamic_question, :answered)
      expect(question.was_answered?).to be true
    end

    it "returns false when answer data is empty" do
      question = create(:dynamic_question, answer_data: {})
      expect(question.was_answered?).to be false
    end

    it "returns false when answer data is nil" do
      question = create(:dynamic_question, answer_data: nil)
      expect(question.was_answered?).to be false
    end
  end

  describe "#formatted_answer" do
    it "returns 'Not answered' for unanswered questions" do
      question = create(:dynamic_question)
      expect(question.formatted_answer).to eq('Not answered')
    end

    it "formats text answers" do
      question = create(:dynamic_question, question_type: 'text_short', answer_data: { 'processed_answer' => 'Simple text' })
      expect(question.formatted_answer).to eq('Simple text')
    end

    it "formats multiple choice answers" do
      question = create(:dynamic_question, question_type: 'multiple_choice', answer_data: { 'processed_answer' => ['Option A', 'Option B'] })
      expect(question.formatted_answer).to eq('Option A, Option B')
    end

    it "formats rating answers" do
      question = create(:dynamic_question, 
                       question_type: 'rating', 
                       configuration: { 'max_value' => 5 },
                       answer_data: { 'processed_answer' => 4 })
      expect(question.formatted_answer).to eq('4/5')
    end

    it "formats NPS answers" do
      question = create(:dynamic_question, question_type: 'nps_score', answer_data: { 'processed_answer' => 9 })
      expect(question.formatted_answer).to eq('9 (Promoter)')
    end

    it "formats date answers" do
      question = create(:dynamic_question, question_type: 'date', answer_data: { 'processed_answer' => '2023-12-25' })
      expect(question.formatted_answer).to eq('December 25, 2023')
    end
  end

  describe "#answer_text" do
    it "returns processed answer as string" do
      question = create(:dynamic_question, :answered)
      expect(question.answer_text).to eq('Dynamic answer')
    end

    it "returns empty string for unanswered questions" do
      question = create(:dynamic_question)
      expect(question.answer_text).to eq('')
    end
  end

  describe "#generation_metadata" do
    it "returns comprehensive metadata" do
      original_question = create(:form_question)
      question = create(:dynamic_question, 
                       generated_from_question: original_question,
                       generation_model: 'gpt-4',
                       ai_confidence: 0.85,
                       generation_prompt: 'Test prompt')
      
      metadata = question.generation_metadata
      
      expect(metadata[:generated_from]).to eq(original_question.title)
      expect(metadata[:generation_model]).to eq('gpt-4')
      expect(metadata[:ai_confidence]).to eq(0.85)
      expect(metadata[:generation_prompt]).to eq('Test prompt')
      expect(metadata[:created_at]).to be_present
    end
  end

  describe "#response_summary" do
    it "returns comprehensive response summary" do
      question = create(:dynamic_question, :answered, :with_high_confidence)
      summary = question.response_summary
      
      expect(summary).to include(:id, :title, :question_type, :answer, :was_answered, :response_time, :ai_confidence, :generation_metadata)
      expect(summary[:was_answered]).to be true
      expect(summary[:generation_metadata]).to be_a(Hash)
    end
  end

  describe "#similar_to_original?" do
    let(:original_question) { create(:form_question, title: 'What is your name?', question_type: 'text_short') }

    it "returns true for similar titles" do
      question = create(:dynamic_question, 
                       generated_from_question: original_question,
                       title: 'What is your full name?')
      expect(question.similar_to_original?).to be true
    end

    it "returns true for same question type" do
      question = create(:dynamic_question, 
                       generated_from_question: original_question,
                       title: 'Different title',
                       question_type: 'text_short')
      expect(question.similar_to_original?).to be true
    end

    it "returns false for dissimilar questions" do
      question = create(:dynamic_question, 
                       generated_from_question: original_question,
                       title: 'Completely different question',
                       question_type: 'rating')
      expect(question.similar_to_original?).to be false
    end

    it "returns false when no original question" do
      question = create(:dynamic_question, generated_from_question: nil)
      expect(question.similar_to_original?).to be false
    end
  end

  describe "#effectiveness_score" do
    it "calculates high score for answered question with high confidence and good timing" do
      question = create(:dynamic_question, :answered, :with_high_confidence, response_time_ms: 3000)
      score = question.effectiveness_score
      
      expect(score).to be > 0.8
      expect(score).to be <= 1.0
    end

    it "calculates low score for unanswered question" do
      question = create(:dynamic_question, :with_low_confidence)
      score = question.effectiveness_score
      
      expect(score).to be < 0.5
    end

    it "penalizes very fast responses as potentially careless" do
      question = create(:dynamic_question, :answered, response_time_ms: 500)
      score = question.effectiveness_score
      
      expect(score).to be < 0.7
    end

    it "penalizes very slow responses" do
      question = create(:dynamic_question, :answered, response_time_ms: 45000)
      score = question.effectiveness_score
      
      expect(score).to be < 0.7
    end
  end

  describe "#should_generate_followup?" do
    it "returns true for answered question with high confidence" do
      original_question = create(:form_question)
      question = create(:dynamic_question, :answered, :with_high_confidence, generated_from_question: original_question)
      
      # Mock the original question to support followups
      allow(original_question).to receive(:generates_followups?).and_return(true)
      
      expect(question.should_generate_followup?).to be true
    end

    it "returns false for unanswered questions" do
      question = create(:dynamic_question, :with_high_confidence)
      expect(question.should_generate_followup?).to be false
    end

    it "returns false for low confidence answers" do
      question = create(:dynamic_question, :answered, :with_low_confidence)
      expect(question.should_generate_followup?).to be false
    end

    it "returns true when answer suggests more information" do
      question = create(:dynamic_question, :answered, :with_high_confidence)
      question.answer_data['processed_answer'] = 'I like it because it helps me work faster'
      
      expect(question.should_generate_followup?).to be true
    end
  end

  describe "#next_followup_context" do
    it "returns context for followup generation" do
      original_question = create(:form_question, title: 'How do you like our product?')
      form_response = create(:form_response)
      question = create(:dynamic_question, 
                       :answered, 
                       :with_high_confidence,
                       generated_from_question: original_question,
                       form_response: form_response,
                       title: 'What specifically do you like?')
      
      allow(question).to receive(:should_generate_followup?).and_return(true)
      allow(form_response).to receive(:answers_hash).and_return({ 'name' => 'John Doe' })
      
      context = question.next_followup_context
      
      expect(context[:previous_question]).to eq('What specifically do you like?')
      expect(context[:previous_answer]).to be_present
      expect(context[:original_question]).to eq('How do you like our product?')
      expect(context[:form_context]).to eq({ 'name' => 'John Doe' })
      expect(context[:confidence_level]).to eq(0.95)
      expect(context[:suggested_direction]).to be_present
    end

    it "returns empty hash when followup should not be generated" do
      question = create(:dynamic_question)
      allow(question).to receive(:should_generate_followup?).and_return(false)
      
      expect(question.next_followup_context).to eq({})
    end
  end

  # Private method testing through public interface
  describe "followup direction suggestion" do
    it "suggests 'reasoning' direction for why/because answers" do
      question = create(:dynamic_question, :answered)
      question.answer_data['processed_answer'] = 'I chose this because it works better'
      
      allow(question).to receive(:should_generate_followup?).and_return(true)
      context = question.next_followup_context
      
      expect(context[:suggested_direction]).to eq('reasoning')
    end

    it "suggests 'methodology' direction for how answers" do
      question = create(:dynamic_question, :answered)
      question.answer_data['processed_answer'] = 'I do this by following a specific process'
      
      allow(question).to receive(:should_generate_followup?).and_return(true)
      context = question.next_followup_context
      
      expect(context[:suggested_direction]).to eq('methodology')
    end

    it "suggests 'timing' direction for when answers" do
      question = create(:dynamic_question, :answered)
      question.answer_data['processed_answer'] = 'I usually do this when I have time'
      
      allow(question).to receive(:should_generate_followup?).and_return(true)
      context = question.next_followup_context
      
      expect(context[:suggested_direction]).to eq('timing')
    end

    it "suggests 'elaboration' for general answers" do
      question = create(:dynamic_question, :answered)
      question.answer_data['processed_answer'] = 'It is good'
      
      allow(question).to receive(:should_generate_followup?).and_return(true)
      context = question.next_followup_context
      
      expect(context[:suggested_direction]).to eq('elaboration')
    end
  end

  describe "text similarity calculation" do
    it "calculates similarity correctly" do
      question = create(:dynamic_question)
      
      # Test through similar_to_original? method
      original_question = create(:form_question, title: 'What is your favorite color?')
      question.update!(generated_from_question: original_question, title: 'What color do you prefer?')
      
      expect(question.similar_to_original?).to be true
    end
  end
end