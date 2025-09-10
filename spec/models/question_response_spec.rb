# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionResponse, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"
  
  it_behaves_like "a model with validations", {
    answer_data: :presence
  }
  
  it_behaves_like "a model with associations", {
    form_response: :belongs_to,
    form_question: :belongs_to
  }
  
  it_behaves_like "a model with callbacks", {
    before_save: [:process_answer_data, :calculate_response_time],
    after_create: [:trigger_ai_analysis, :update_question_analytics]
  }
  
  it_behaves_like "a model with scopes", {
    skipped: { matching_attributes: { skipped: true, answer_data: { 'skipped' => true } }, non_matching_attributes: { skipped: false } },
    recent: { matching_attributes: { created_at: 1.hour.ago }, non_matching_attributes: { created_at: 1.week.ago } }
  }

  # Test data setup
  let(:form) { create(:form) }
  let(:form_response) { create(:form_response, form: form) }
  let(:form_question) { create(:form_question, form: form) }
  let(:question_response) { create(:question_response, form_response: form_response, form_question: form_question) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(question_response).to be_valid
    end

    it "is invalid without answer_data" do
      question_response.answer_data = nil
      expect(question_response).not_to be_valid
      expect(question_response.errors[:answer_data]).to include("can't be blank")
    end

    it "is valid with empty hash answer_data for skipped questions" do
      skipped_response = build(:question_response, :skipped, answer_data: { 'skipped' => true })
      expect(skipped_response).to be_valid
    end
  end

  describe "callbacks" do
    describe "#process_answer_data" do
      it "converts string answer to hash format" do
        response = build(:question_response, answer_data: "Simple text answer")
        response.save!
        
        expect(response.answer_data).to be_a(Hash)
        expect(response.answer_data['value']).to eq("Simple text answer")
      end

      it "adds processing metadata" do
        response = create(:question_response)
        
        expect(response.answer_data['processed_at']).to be_present
        expect(response.answer_data['question_type']).to eq(response.form_question.question_type)
      end

      it "preserves existing hash structure" do
        original_data = { 'value' => 'test', 'custom_field' => 'custom_value' }
        response = build(:question_response, answer_data: original_data)
        response.save!
        
        expect(response.answer_data['value']).to eq('test')
        expect(response.answer_data['custom_field']).to eq('custom_value')
      end
    end

    describe "#calculate_response_time" do
      it "calculates response time from timestamps" do
        started_time = 30.seconds.ago
        completed_time = Time.current
        
        answer_data = {
          'value' => 'test',
          'started_at' => started_time.iso8601,
          'completed_at' => completed_time.iso8601
        }
        
        response = build(:question_response, answer_data: answer_data)
        response.save!
        
        expect(response.response_time_ms).to be_within(1000).of(30000) # 30 seconds in ms
      end

      it "handles missing timestamps gracefully" do
        response = create(:question_response, answer_data: { 'value' => 'test' })
        expect(response.response_time_ms).to be_nil
      end
    end

    describe "#trigger_ai_analysis" do
      let(:ai_question) { create(:form_question, :ai_enhanced, form: form) }
      
      it "triggers AI analysis for AI-enhanced questions" do
        expect_any_instance_of(QuestionResponse).to receive(:trigger_ai_analysis!)
        create(:question_response, form_question: ai_question, form_response: form_response)
      end

      it "does not trigger AI analysis for regular questions" do
        expect_any_instance_of(QuestionResponse).not_to receive(:trigger_ai_analysis!)
        create(:question_response, form_question: form_question, form_response: form_response)
      end
    end

    describe "#update_question_analytics" do
      it "clears relevant caches after creation" do
        expect(Rails.cache).to receive(:delete).with("question_analytics/#{form_question.id}")
        expect(Rails.cache).to receive(:delete_matched).with("form/#{form.id}/*")
        
        create(:question_response, form_question: form_question, form_response: form_response)
      end
    end
  end

  describe "answer processing by question type" do
    describe "#processed_answer_data" do
      context "for text questions" do
        let(:text_question) { create(:form_question, question_type: 'text_short', form: form) }
        let(:text_response) { create(:question_response, form_question: text_question, answer_data: { 'value' => '  Test Answer  ' }) }

        it "processes text answers" do
          expect(text_response.processed_answer_data).to eq('Test Answer')
        end
      end

      context "for multiple choice questions" do
        let(:choice_question) { create(:form_question, question_type: 'multiple_choice', form: form, question_config: { 'options' => ['Option 1', 'Option 2'] }) }
        let(:choice_response) { create(:question_response, form_question: choice_question, answer_data: { 'value' => 'Option 1' }) }

        it "converts single choice to array" do
          expect(choice_response.processed_answer_data).to eq(['Option 1'])
        end

        it "preserves array choices" do
          choice_response.answer_data = { 'value' => ['Option 1', 'Option 2'] }
          choice_response.save!
          expect(choice_response.processed_answer_data).to eq(['Option 1', 'Option 2'])
        end
      end

      context "for rating questions" do
        let(:rating_question) { create(:form_question, question_type: 'rating', form: form) }
        let(:rating_response) { create(:question_response, form_question: rating_question, answer_data: { 'value' => '4' }) }

        it "converts rating to numeric" do
          expect(rating_response.processed_answer_data).to eq(4.0)
        end
      end

      context "for email questions" do
        let(:email_question) { create(:form_question, question_type: 'email', form: form) }
        let(:email_response) { create(:question_response, form_question: email_question, answer_data: { 'value' => '  TEST@EXAMPLE.COM  ' }) }

        it "normalizes email format" do
          expect(email_response.processed_answer_data).to eq('test@example.com')
        end
      end

      context "for phone questions" do
        let(:phone_question) { create(:form_question, question_type: 'phone', form: form) }
        let(:phone_response) { create(:question_response, form_question: phone_question, answer_data: { 'value' => '(555) 123-4567' }) }

        it "removes formatting from phone numbers" do
          expect(phone_response.processed_answer_data).to eq('5551234567')
        end
      end

      context "for file upload questions" do
        let(:file_question) { create(:form_question, question_type: 'file_upload', form: form) }
        let(:file_data) { { 'filename' => 'test.pdf', 'size' => 1024, 'content_type' => 'application/pdf', 'url' => '/uploads/test.pdf' } }
        let(:file_response) { create(:question_response, form_question: file_question, answer_data: { 'value' => file_data }) }

        it "structures file data properly" do
          processed = file_response.processed_answer_data
          expect(processed).to be_an(Array)
          expect(processed.first.keys.map(&:to_s)).to include('filename', 'size', 'content_type', 'url')
        end
      end
    end

    describe "#formatted_answer" do
      context "for choice questions" do
        let(:choice_question) { create(:form_question, question_type: 'multiple_choice', form: form, question_config: { 'options' => ['Option 1', 'Option 2'] }) }
        let(:choice_response) { create(:question_response, form_question: choice_question, answer_data: { 'value' => ['Option 1', 'Option 2'] }) }

        it "formats multiple choices as comma-separated string" do
          expect(choice_response.formatted_answer).to eq('Option 1, Option 2')
        end
      end

      context "for rating questions" do
        let(:rating_question) { create(:form_question, question_type: 'rating', form: form, question_config: { 'max' => 5 }) }
        let(:rating_response) { create(:question_response, form_question: rating_question, answer_data: { 'value' => 4 }) }

        it "formats rating with scale" do
          expect(rating_response.formatted_answer).to eq('4/5')
        end
      end

      context "for NPS questions" do
        let(:nps_question) { create(:form_question, question_type: 'nps_score', form: form) }
        let(:nps_response) { create(:question_response, form_question: nps_question, answer_data: { 'value' => 9 }) }

        it "formats NPS score with category" do
          expect(nps_response.formatted_answer).to eq('9 (Promoter)')
        end

        it "categorizes detractors correctly" do
          nps_response.answer_data = { 'value' => 5 }
          nps_response.save!
          expect(nps_response.formatted_answer).to eq('5 (Detractor)')
        end

        it "categorizes passives correctly" do
          nps_response.answer_data = { 'value' => 7 }
          nps_response.save!
          expect(nps_response.formatted_answer).to eq('7 (Passive)')
        end
      end

      context "for date questions" do
        let(:date_question) { create(:form_question, question_type: 'date', form: form) }
        let(:date_response) { create(:question_response, form_question: date_question, answer_data: { 'value' => '2024-03-15' }) }

        it "formats date in readable format" do
          expect(date_response.formatted_answer).to eq('March 15, 2024')
        end
      end

      context "for file upload questions" do
        let(:file_question) { create(:form_question, question_type: 'file_upload', form: form) }
        let(:file_data) { [{ 'filename' => 'doc1.pdf', 'size' => 1024 }, { 'filename' => 'doc2.pdf', 'size' => 2048 }] }
        let(:file_response) { create(:question_response, form_question: file_question, answer_data: { 'value' => file_data }) }

        it "formats file list" do
          expect(file_response.formatted_answer).to eq('2 file(s): doc1.pdf, doc2.pdf')
        end
      end
    end
  end

  describe "AI analysis methods" do
    describe "#trigger_ai_analysis!" do
      let(:ai_question) { create(:form_question, :ai_enhanced, form: form) }
      let(:ai_response) { create(:question_response, form_question: ai_question, form_response: form_response) }

      it "updates ai_analysis_requested_at" do
        expect {
          ai_response.trigger_ai_analysis!
        }.to change { ai_response.ai_analysis_requested_at }.from(nil)
      end

      it "returns false for non-AI questions" do
        result = question_response.trigger_ai_analysis!
        expect(result).to be false
      end
    end

    describe "#should_trigger_ai_analysis?" do
      let(:ai_question) { create(:form_question, :ai_enhanced, form: form) }
      let(:ai_response) { create(:question_response, form_question: ai_question, form_response: form_response) }

      it "returns true for AI-enhanced questions with answers" do
        expect(ai_response.send(:should_trigger_ai_analysis?)).to be true
      end

      it "returns false for skipped questions" do
        ai_response.update!(skipped: true)
        expect(ai_response.send(:should_trigger_ai_analysis?)).to be false
      end

      it "returns false for questions without AI enhancement" do
        expect(question_response.send(:should_trigger_ai_analysis?)).to be false
      end
    end

    describe "#ai_sentiment" do
      it "returns sentiment from AI analysis" do
        response = create(:question_response, :with_ai_analysis)
        expect(response.ai_sentiment).to eq('positive')
      end

      it "returns 'neutral' when no analysis exists" do
        expect(question_response.ai_sentiment).to eq('neutral')
      end
    end

    describe "#ai_confidence_score" do
      it "returns confidence score from AI analysis" do
        response = create(:question_response, :with_ai_analysis)
        expect(response.ai_confidence_score).to eq(0.9)
      end

      it "returns 0.0 when no analysis exists" do
        expect(question_response.ai_confidence_score).to eq(0.0)
      end
    end

    describe "#needs_followup?" do
      it "returns true when AI suggests followup" do
        response = create(:question_response, ai_analysis_results: {
          'insights' => [{ 'type' => 'followup_suggested', 'message' => 'Need more details' }],
          'confidence_score' => 0.8
        })
        expect(response.needs_followup?).to be true
      end

      it "returns true when confidence is low" do
        response = create(:question_response, ai_analysis_results: {
          'insights' => [],
          'confidence_score' => 0.5
        })
        expect(response.needs_followup?).to be true
      end

      it "returns false when confidence is high and no followup suggested" do
        response = create(:question_response, ai_analysis_results: {
          'insights' => [],
          'confidence_score' => 0.8
        })
        expect(response.needs_followup?).to be false
      end
    end
  end

  describe "validation methods" do
    describe "#answer_valid?" do
      it "returns true when no validation errors exist" do
        valid_response = create(:question_response, :email_answer)
        expect(valid_response.answer_valid?).to be true
      end

      it "returns false when validation errors exist" do
        invalid_email_question = create(:form_question, question_type: 'email', form: form)
        invalid_response = create(:question_response, 
          form_question: invalid_email_question, 
          answer_data: { 'value' => 'invalid-email' }
        )
        expect(invalid_response.answer_valid?).to be false
      end
    end

    describe "#validation_errors" do
      context "for required questions" do
        let(:required_question) { create(:form_question, required: true, form: form) }

        it "returns error for blank required answers" do
          blank_response = create(:question_response, 
            form_question: required_question, 
            answer_data: { 'value' => '' }
          )
          expect(blank_response.validation_errors).to include('Answer is required')
        end

        it "returns no error for answered required questions" do
          answered_response = create(:question_response, 
            form_question: required_question, 
            answer_data: { 'value' => 'Valid answer' }
          )
          expect(answered_response.validation_errors).to be_empty
        end
      end

      context "for email questions" do
        let(:email_question) { create(:form_question, question_type: 'email', form: form) }

        it "validates email format" do
          invalid_response = create(:question_response, 
            form_question: email_question, 
            answer_data: { 'value' => 'invalid-email' }
          )
          expect(invalid_response.validation_errors).to include('Invalid email format')
        end

        it "accepts valid email format" do
          valid_response = create(:question_response, 
            form_question: email_question, 
            answer_data: { 'value' => 'test@example.com' }
          )
          expect(valid_response.validation_errors).to be_empty
        end
      end

      context "for phone questions" do
        let(:phone_question) { create(:form_question, question_type: 'phone', form: form) }

        it "validates phone format" do
          invalid_response = create(:question_response, 
            form_question: phone_question, 
            answer_data: { 'value' => '123' }
          )
          expect(invalid_response.validation_errors).to include('Invalid phone format')
        end

        it "accepts valid phone format" do
          valid_response = create(:question_response, 
            form_question: phone_question, 
            answer_data: { 'value' => '+1 (555) 123-4567' }
          )
          expect(valid_response.validation_errors).to be_empty
        end
      end

      context "for number questions" do
        let(:number_question) { create(:form_question, question_type: 'number', form: form) }

        it "validates numeric format" do
          invalid_response = create(:question_response, 
            form_question: number_question, 
            answer_data: { 'value' => 'not-a-number' }
          )
          expect(invalid_response.validation_errors).to include('Must be a valid number')
        end

        it "accepts valid numbers" do
          valid_response = create(:question_response, 
            form_question: number_question, 
            answer_data: { 'value' => '42.5' }
          )
          expect(valid_response.validation_errors).to be_empty
        end
      end

      context "for URL questions" do
        let(:url_question) { create(:form_question, question_type: 'url', form: form) }

        it "validates URL format" do
          invalid_response = create(:question_response, 
            form_question: url_question, 
            answer_data: { 'value' => 'not-a-url' }
          )
          expect(invalid_response.validation_errors).to include('Invalid URL format')
        end

        it "accepts valid URLs" do
          valid_response = create(:question_response, 
            form_question: url_question, 
            answer_data: { 'value' => 'https://example.com' }
          )
          expect(valid_response.validation_errors).to be_empty
        end
      end

      context "with custom validation rules" do
        let(:text_question) { create(:form_question, 
          question_type: 'text_short', 
          form: form,
          validation_rules: { 'min_length' => 5, 'max_length' => 50 }
        ) }

        it "validates minimum length" do
          short_response = create(:question_response, 
            form_question: text_question, 
            answer_data: { 'value' => 'Hi' }
          )
          expect(short_response.validation_errors).to include('Answer must be at least 5 characters')
        end

        it "validates maximum length" do
          long_response = create(:question_response, 
            form_question: text_question, 
            answer_data: { 'value' => 'A' * 60 }
          )
          expect(long_response.validation_errors).to include('Answer must be no more than 50 characters')
        end

        it "accepts valid length" do
          valid_response = create(:question_response, 
            form_question: text_question, 
            answer_data: { 'value' => 'Valid answer' }
          )
          expect(valid_response.validation_errors).to be_empty
        end
      end
    end
  end

  describe "quality and performance indicators" do
    describe "#quality_indicators" do
      let(:quality_response) { create(:question_response, :with_ai_analysis, :with_time_data) }

      it "returns comprehensive quality metrics" do
        indicators = quality_response.quality_indicators
        
        expect(indicators).to include(
          :completeness,
          :response_time,
          :ai_confidence,
          :validation_passed,
          :needs_review
        )
      end

      it "calculates completeness score" do
        indicators = quality_response.quality_indicators
        expect(indicators[:completeness]).to be_between(0, 1)
      end
    end

    describe "#response_time_category" do
      it "categorizes very fast responses" do
        fast_response = create(:question_response, response_time_ms: 1500)
        expect(fast_response.response_time_category).to eq('very_fast')
      end

      it "categorizes fast responses" do
        fast_response = create(:question_response, response_time_ms: 3000)
        expect(fast_response.response_time_category).to eq('fast')
      end

      it "categorizes normal responses" do
        normal_response = create(:question_response, response_time_ms: 10000)
        expect(normal_response.response_time_category).to eq('normal')
      end

      it "categorizes slow responses" do
        slow_response = create(:question_response, response_time_ms: 30000)
        expect(slow_response.response_time_category).to eq('slow')
      end

      it "categorizes very slow responses" do
        very_slow_response = create(:question_response, response_time_ms: 150000)
        expect(very_slow_response.response_time_category).to eq('very_slow')
      end

      it "returns 'unknown' for nil response time" do
        response = create(:question_response, response_time_ms: nil)
        expect(response.response_time_category).to eq('unknown')
      end
    end

    describe "#unusually_fast?" do
      it "returns true for responses under 1 second" do
        fast_response = create(:question_response, response_time_ms: 500)
        expect(fast_response.unusually_fast?).to be true
      end

      it "returns false for normal response times" do
        normal_response = create(:question_response, response_time_ms: 5000)
        expect(normal_response.unusually_fast?).to be false
      end
    end

    describe "#unusually_slow?" do
      it "returns true for responses over 2 minutes" do
        slow_response = create(:question_response, response_time_ms: 150000)
        expect(slow_response.unusually_slow?).to be true
      end

      it "returns false for normal response times" do
        normal_response = create(:question_response, response_time_ms: 30000)
        expect(normal_response.unusually_slow?).to be false
      end
    end

    describe "#needs_human_review?" do
      it "returns true for unusually fast responses" do
        fast_response = create(:question_response, response_time_ms: 500)
        expect(fast_response.needs_human_review?).to be true
      end

      it "returns true for unusually slow responses" do
        slow_response = create(:question_response, response_time_ms: 150000)
        expect(slow_response.needs_human_review?).to be true
      end

      it "returns true for low AI confidence" do
        low_confidence_response = create(:question_response, ai_analysis_results: { 'confidence_score' => 0.3 })
        expect(low_confidence_response.needs_human_review?).to be true
      end

      it "returns true for invalid answers" do
        email_question = create(:form_question, question_type: 'email', form: form)
        invalid_response = create(:question_response, 
          form_question: email_question, 
          answer_data: { 'value' => 'invalid-email' }
        )
        expect(invalid_response.needs_human_review?).to be true
      end

      it "returns false for good quality responses" do
        good_response = create(:question_response, 
          response_time_ms: 10000,
          ai_analysis_results: { 'confidence_score' => 0.9 }
        )
        expect(good_response.needs_human_review?).to be false
      end
    end

    describe "#calculate_completeness_score" do
      it "returns 0.0 for blank answers" do
        blank_response = create(:question_response, answer_data: { 'value' => '' })
        expect(blank_response.send(:calculate_completeness_score)).to eq(0.0)
      end

      it "gives higher scores for longer text answers" do
        short_response = create(:question_response, answer_data: { 'value' => 'Hi' })
        long_response = create(:question_response, answer_data: { 'value' => 'This is a much longer and more detailed answer' })
        
        expect(long_response.send(:calculate_completeness_score)).to be > short_response.send(:calculate_completeness_score)
      end

      it "gives full points for choice questions" do
        choice_question = create(:form_question, question_type: 'multiple_choice', form: form, question_config: { 'options' => ['Option 1', 'Option 2'] })
        choice_response = create(:question_response, 
          form_question: choice_question,
          answer_data: { 'value' => ['Option 1'] }
        )
        
        score = choice_response.send(:calculate_completeness_score)
        expect(score).to be >= 0.9 # Base + choice bonus
      end

      it "includes AI confidence bonus" do
        high_confidence_response = create(:question_response, 
          ai_analysis_results: { 'confidence_score' => 0.9 }
        )
        
        score = high_confidence_response.send(:calculate_completeness_score)
        expect(score).to be > 0.5 # Should include AI bonus
      end
    end
  end

  describe "#response_summary" do
    let(:summary_response) { create(:question_response, :with_ai_analysis, :with_time_data) }

    it "returns comprehensive summary hash" do
      summary = summary_response.response_summary
      
      expect(summary).to include(
        :question_title,
        :question_type,
        :answer,
        :response_time,
        :quality_score,
        :ai_confidence,
        :needs_review
      )
    end

    it "includes question information" do
      summary = summary_response.response_summary
      
      expect(summary[:question_title]).to eq(summary_response.form_question.title)
      expect(summary[:question_type]).to eq(summary_response.form_question.question_type)
    end
  end

  describe "scopes" do
    let!(:answered_response) { create(:question_response, answer_data: { 'value' => 'test answer' }) }
    let!(:skipped_response) { create(:question_response, :skipped, answer_data: { 'skipped' => true }) }
    let!(:old_response) { create(:question_response, created_at: 1.week.ago) }

    describe ".answered" do
      it "includes responses with non-empty answer_data" do
        expect(QuestionResponse.answered).to include(answered_response)
        expect(QuestionResponse.answered).not_to include(skipped_response)
      end
    end

    describe ".skipped" do
      it "includes only skipped responses" do
        expect(QuestionResponse.skipped).to include(skipped_response)
        expect(QuestionResponse.skipped).not_to include(answered_response)
      end
    end

    describe ".recent" do
      it "orders by created_at desc" do
        results = QuestionResponse.recent.limit(2)
        expect(results.first.created_at).to be >= results.second.created_at
      end
    end
  end

  describe "data integrity" do
    it "maintains referential integrity with form_response" do
      response_id = question_response.form_response_id
      question_response.destroy
      
      expect(FormResponse.find(response_id)).to be_present # Should not be affected
    end

    it "maintains referential integrity with form_question" do
      question_id = question_response.form_question_id
      question_response.destroy
      
      expect(FormQuestion.find(question_id)).to be_present # Should not be affected
    end

    it "handles orphaned responses gracefully" do
      question_response.form_response.destroy
      
      expect { question_response.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "edge cases and error handling" do
    describe "with malformed answer_data" do
      it "handles nil values gracefully" do
        response = build(:question_response, answer_data: nil)
        expect { response.valid? }.not_to raise_error
      end

      it "handles empty arrays" do
        response = create(:question_response, answer_data: { 'value' => [] })
        expect(response.send(:answer_blank?)).to be true
      end

      it "handles nested hash structures" do
        complex_data = {
          'value' => 'test',
          'metadata' => { 'source' => 'web', 'version' => '1.0' }
        }
        response = create(:question_response, answer_data: complex_data)
        expect(response.raw_answer).to eq('test')
      end
    end

    describe "with invalid timestamps" do
      it "handles invalid date strings in answer_data" do
        invalid_date_data = {
          'value' => 'test',
          'started_at' => 'invalid-date',
          'completed_at' => 'also-invalid'
        }
        
        response = build(:question_response, answer_data: invalid_date_data)
        expect { response.save! }.not_to raise_error
        expect(response.response_time_ms).to be_nil
      end
    end

    describe "with missing question configuration" do
      it "handles missing rating configuration" do
        rating_question = create(:form_question, question_type: 'rating', form: form, question_config: {})
        rating_response = create(:question_response, form_question: rating_question, answer_data: { 'value' => 4 })
        
        expect(rating_response.formatted_answer).to eq('4/5') # Uses default max
      end
    end
  end
end