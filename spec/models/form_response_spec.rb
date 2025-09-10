# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormResponse, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"
  
  it_behaves_like "a model with enum", :status, %w[in_progress completed abandoned paused]
  
  it_behaves_like "a model with validations", {
    session_id: :presence,
    form: :presence
  }
  
  it_behaves_like "a model with associations", {
    form: :belongs_to,
    question_responses: { type: :has_many, dependent: :destroy },
    dynamic_questions: { type: :has_many, dependent: :destroy }
  }
  
  it_behaves_like "a model with callbacks", {
    before_create: [:set_started_at],
    before_save: [:update_last_activity]
  }
  
  it_behaves_like "a model with scopes", {
    recent: { matching_attributes: { created_at: 1.hour.ago }, non_matching_attributes: { created_at: 1.week.ago } },
    this_week: { matching_attributes: { created_at: 3.days.ago }, non_matching_attributes: { created_at: 2.weeks.ago } },
    this_month: { matching_attributes: { created_at: 2.weeks.ago }, non_matching_attributes: { created_at: 2.months.ago } }
  }

  # Test data setup
  let(:form) { create(:form, :with_questions) }
  let(:form_response) { create(:form_response, form: form) }
  let(:completed_response) { create(:form_response, :completed, form: form) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(form_response).to be_valid
    end

    it "is invalid without a session_id" do
      form_response.session_id = nil
      expect(form_response).not_to be_valid
      expect(form_response.errors[:session_id]).to include("can't be blank")
    end

    it "is invalid without a form" do
      form_response.form = nil
      expect(form_response).not_to be_valid
      expect(form_response.errors[:form]).to include("can't be blank")
    end
  end

  describe "status transitions" do
    it "starts with in_progress status" do
      expect(form_response.status).to eq('in_progress')
    end

    it "can transition to completed" do
      form_response.status = :completed
      expect(form_response).to be_valid
      expect(form_response.completed?).to be true
    end

    it "can transition to abandoned" do
      form_response.status = :abandoned
      expect(form_response).to be_valid
      expect(form_response.abandoned?).to be true
    end

    it "can transition to paused" do
      form_response.status = :paused
      expect(form_response).to be_valid
      expect(form_response.paused?).to be true
    end

    it "provides predicate methods for each status" do
      expect(form_response).to respond_to(:in_progress?)
      expect(form_response).to respond_to(:completed?)
      expect(form_response).to respond_to(:abandoned?)
      expect(form_response).to respond_to(:paused?)
    end
  end

  describe "callbacks" do
    describe "#set_started_at" do
      it "sets started_at on creation" do
        new_response = build(:form_response, started_at: nil)
        expect { new_response.save! }.to change { new_response.started_at }.from(nil)
      end

      it "does not override existing started_at" do
        existing_time = 1.hour.ago
        new_response = build(:form_response, started_at: existing_time)
        new_response.save!
        expect(new_response.started_at).to be_within(1.second).of(existing_time)
      end
    end

    describe "#update_last_activity" do
      it "updates last_activity_at on save" do
        original_time = form_response.last_activity_at
        sleep 0.01 # Ensure time difference
        form_response.touch
        expect(form_response.last_activity_at).to be > original_time
      end

      it "sets last_activity_at on creation" do
        new_response = create(:form_response)
        expect(new_response.last_activity_at).to be_present
      end
    end
  end

  describe "#progress_percentage" do
    let(:form_with_questions) { create(:form) }
    let!(:questions) { create_list(:form_question, 5, form: form_with_questions) }
    let(:response) { create(:form_response, form: form_with_questions) }

    it "returns 0.0 when no questions exist" do
      empty_form = create(:form)
      empty_response = create(:form_response, form: empty_form)
      expect(empty_response.progress_percentage).to eq(0.0)
    end

    it "returns 0.0 when no questions are answered" do
      expect(response.progress_percentage).to eq(0.0)
    end

    it "calculates correct percentage with some answers" do
      # Answer 2 out of 5 questions
      create(:question_response, form_response: response, form_question: questions[0])
      create(:question_response, form_response: response, form_question: questions[1])
      
      expect(response.progress_percentage).to eq(40.0)
    end

    it "returns 100.0 when all questions are answered" do
      questions.each do |question|
        create(:question_response, form_response: response, form_question: question)
      end
      
      expect(response.progress_percentage).to eq(100.0)
    end

    it "ignores skipped questions" do
      create(:question_response, :skipped, form_response: response, form_question: questions[0])
      create(:question_response, form_response: response, form_question: questions[1])
      
      expect(response.progress_percentage).to eq(20.0)
    end
  end

  describe "#duration_minutes" do
    it "returns 0 when started_at is nil" do
      response = build(:form_response, started_at: nil)
      expect(response.duration_minutes).to eq(0)
    end

    it "calculates duration from started_at to completed_at" do
      started_time = 30.minutes.ago
      completed_time = 10.minutes.ago
      response = build(:form_response, started_at: started_time, completed_at: completed_time)
      
      expect(response.duration_minutes).to eq(20.0)
    end

    it "calculates duration from started_at to current time when not completed" do
      started_time = 15.minutes.ago
      response = build(:form_response, started_at: started_time, completed_at: nil)
      
      expect(response.duration_minutes).to be_within(1.0).of(15.0)
    end
  end

  describe "#time_since_last_activity" do
    it "returns 0 when last_activity_at is nil" do
      response = build(:form_response, last_activity_at: nil)
      expect(response.time_since_last_activity).to eq(0)
    end

    it "calculates time since last activity" do
      last_activity = 10.minutes.ago
      response = build(:form_response, last_activity_at: last_activity)
      
      expect(response.time_since_last_activity).to be_within(60).of(600) # 10 minutes in seconds
    end
  end

  describe "#is_stale?" do
    it "returns false when last_activity_at is nil" do
      response = build(:form_response, last_activity_at: nil)
      expect(response.is_stale?).to be false
    end

    it "returns false when activity is recent" do
      response = build(:form_response, last_activity_at: 10.minutes.ago)
      expect(response.is_stale?).to be false
    end

    it "returns true when activity is older than 30 minutes" do
      response = build(:form_response, last_activity_at: 45.minutes.ago)
      expect(response.is_stale?).to be true
    end
  end

  describe "#answers_hash" do
    let(:question1) { create(:form_question, form: form, title: "Name") }
    let(:question2) { create(:form_question, form: form, title: "Email") }

    it "returns empty hash when no answers exist" do
      expect(form_response.answers_hash).to eq({})
    end

    it "returns hash of question titles to formatted answers" do
      create(:question_response, form_response: form_response, form_question: question1, answer_data: { 'value' => 'John Doe' })
      create(:question_response, form_response: form_response, form_question: question2, answer_data: { 'value' => 'john@example.com' })
      
      expected_hash = {
        "Name" => "John Doe",
        "Email" => "john@example.com"
      }
      
      expect(form_response.answers_hash).to eq(expected_hash)
    end
  end

  describe "#get_answer" do
    let(:question) { create(:form_question, form: form, title: "Test Question") }
    let!(:question_response) { create(:question_response, form_response: form_response, form_question: question, answer_data: { 'value' => 'Test Answer' }) }

    it "retrieves answer by question title" do
      expect(form_response.get_answer("Test Question")).to eq("Test Answer")
    end

    it "retrieves answer by question ID" do
      expect(form_response.get_answer(question.id)).to eq("Test Answer")
    end

    it "returns nil for non-existent question" do
      expect(form_response.get_answer("Non-existent")).to be_nil
    end

    it "returns nil when no answer exists" do
      unanswered_question = create(:form_question, form: form, title: "Unanswered")
      expect(form_response.get_answer("Unanswered")).to be_nil
    end
  end

  describe "#set_answer" do
    let(:question) { create(:form_question, form: form, title: "Test Question") }

    it "creates new question response" do
      expect {
        form_response.set_answer(question, { 'value' => 'New Answer' })
      }.to change { form_response.question_responses.count }.by(1)
    end

    it "updates existing question response" do
      existing_response = create(:question_response, form_response: form_response, form_question: question)
      
      expect {
        form_response.set_answer(question, { 'value' => 'Updated Answer' })
      }.not_to change { form_response.question_responses.count }
      
      expect(existing_response.reload.answer_data['value']).to eq('Updated Answer')
    end

    it "accepts question title as identifier" do
      result = form_response.set_answer("Test Question", { 'value' => 'Answer by title' })
      expect(result).to be true
    end

    it "returns false for invalid question" do
      result = form_response.set_answer("Invalid Question", { 'value' => 'Answer' })
      expect(result).to be false
    end
  end

  describe "AI analysis methods" do
    describe "#trigger_ai_analysis!" do
      let(:ai_form) { create(:form, ai_enabled: true) }
      let(:ai_response) { create(:form_response, form: ai_form) }

      it "updates ai_analysis_requested_at for AI-enhanced forms" do
        expect {
          ai_response.trigger_ai_analysis!
        }.to change { ai_response.reload.ai_analysis }.from({})
      end

      it "returns false for non-AI-enhanced forms" do
        result = form_response.trigger_ai_analysis!
        expect(result).to be false
      end
    end

    describe "#ai_sentiment" do
      it "returns sentiment from AI analysis results" do
        response = create(:form_response, ai_analysis: { 'sentiment' => 'positive' })
        expect(response.ai_sentiment).to eq('positive')
      end

      it "returns 'neutral' when no AI analysis exists" do
        expect(form_response.ai_sentiment).to eq('neutral')
      end
    end

    describe "#ai_confidence" do
      it "returns confidence score from AI analysis results" do
        response = create(:form_response, ai_analysis: { 'confidence_score' => 0.85 })
        expect(response.ai_confidence).to eq(0.85)
      end

      it "returns 0.0 when no AI analysis exists" do
        expect(form_response.ai_confidence).to eq(0.0)
      end
    end

    describe "#needs_human_review?" do
      it "returns false when no AI analysis exists" do
        expect(form_response.needs_human_review?).to be false
      end

      it "returns true when confidence is low" do
        low_confidence_response = create(:form_response, ai_analysis: { 'confidence_score' => 0.5 })
        expect(low_confidence_response.needs_human_review?).to be true
      end

      it "returns true when risk indicators exist" do
        risky_response = create(:form_response, ai_analysis: { 'confidence_score' => 0.9, 'risk_indicators' => ['spam'] })
        expect(risky_response.needs_human_review?).to be true
      end

      it "returns false when confidence is high and no risks" do
        good_response = create(:form_response, ai_analysis: { 'confidence_score' => 0.9, 'risk_indicators' => [] })
        expect(good_response.needs_human_review?).to be false
      end
    end
  end

  describe "quality and sentiment scoring" do
    describe "#calculate_quality_score!" do
      let(:response_with_answers) { create(:form_response, form: form) }
      
      before do
        # Create some answered questions
        questions = create_list(:form_question, 4, form: form)
        questions.each do |question|
          create(:question_response, form_response: response_with_answers, form_question: question)
        end
        
        response_with_answers.update!(
          started_at: 20.minutes.ago,
          ai_analysis: { 'confidence_score' => 0.8 }
        )
      end

      it "calculates and saves quality score" do
        expect {
          response_with_answers.calculate_quality_score!
        }.to change { response_with_answers.quality_score }.from(nil)
        
        expect(response_with_answers.quality_score).to be_between(0, 1)
      end

      it "returns the calculated quality score" do
        score = response_with_answers.calculate_quality_score!
        expect(score).to eq(response_with_answers.quality_score)
      end
    end

    describe "#calculate_sentiment_score!" do
      it "calculates score for very_positive sentiment" do
        response = create(:form_response, ai_analysis: { 'sentiment' => 'very_positive' })
        score = response.calculate_sentiment_score!
        expect(score).to eq(1.0)
        expect(response.sentiment_score).to eq(1.0)
      end

      it "calculates score for positive sentiment" do
        response = create(:form_response, ai_analysis: { 'sentiment' => 'positive' })
        score = response.calculate_sentiment_score!
        expect(score).to eq(0.75)
      end

      it "calculates score for neutral sentiment" do
        response = create(:form_response, ai_analysis: { 'sentiment' => 'neutral' })
        score = response.calculate_sentiment_score!
        expect(score).to eq(0.5)
      end

      it "returns 0.0 when no AI analysis exists" do
        score = form_response.calculate_sentiment_score!
        expect(score).to eq(0.0)
      end
    end
  end

  describe "lifecycle management" do
    describe "#mark_completed!" do
      let(:completable_response) { create(:form_response, form: form) }
      
      before do
        # Create required questions and answers
        required_question = create(:form_question, form: form, required: true)
        create(:question_response, form_response: completable_response, form_question: required_question)
      end

      it "marks response as completed" do
        expect {
          completable_response.mark_completed!
        }.to change { completable_response.status }.to('completed')
      end

      it "sets completed_at timestamp" do
        expect {
          completable_response.mark_completed!
        }.to change { completable_response.completed_at }.from(nil)
      end

      it "accepts completion data" do
        completion_data = { 'source' => 'web', 'final_score' => 85 }
        completable_response.mark_completed!(completion_data)
        expect(completable_response.completion_data).to eq(completion_data)
      end

      it "returns true on successful completion" do
        result = completable_response.mark_completed!
        expect(result).to be true
      end

      it "returns false when response cannot be completed" do
        incomplete_response = create(:form_response, form: form)
        create(:form_question, form: form, required: true) # Required question without answer
        
        result = incomplete_response.mark_completed!
        expect(result).to be false
      end
    end

    describe "#mark_abandoned!" do
      it "marks response as abandoned" do
        expect {
          form_response.mark_abandoned!('user_closed_tab')
        }.to change { form_response.status }.to('abandoned')
      end

      it "sets abandoned_at timestamp" do
        expect {
          form_response.mark_abandoned!
        }.to change { form_response.abandoned_at }.from(nil)
      end

      it "stores abandonment reason" do
        form_response.mark_abandoned!('timeout')
        expect(form_response.abandonment_reason).to eq('timeout')
      end
    end

    describe "#pause!" do
      it "marks response as paused" do
        expect {
          form_response.pause!({ 'reason' => 'user_request' })
        }.to change { form_response.status }.to('paused')
      end

      it "sets paused_at timestamp" do
        expect {
          form_response.pause!
        }.to change { form_response.paused_at }.from(nil)
      end

      it "stores pause context" do
        context = { 'reason' => 'user_request', 'current_step' => 3 }
        form_response.pause!(context)
        expect(form_response.metadata['pause_context']).to eq(context)
      end
    end

    describe "#resume!" do
      let(:paused_response) { create(:form_response, :paused) }

      it "resumes paused response" do
        expect {
          paused_response.resume!
        }.to change { paused_response.status }.to('in_progress')
      end

      it "sets resumed_at timestamp" do
        expect {
          paused_response.resume!
        }.to change { paused_response.resumed_at }.from(nil)
      end

      it "returns false for non-paused responses" do
        result = form_response.resume!
        expect(result).to be false
      end

      it "returns true for successful resume" do
        result = paused_response.resume!
        expect(result).to be true
      end
    end
  end

  describe "navigation and completion logic" do
    let(:form_with_questions) { create(:form) }
    let!(:question1) { create(:form_question, form: form_with_questions, position: 1, required: true) }
    let!(:question2) { create(:form_question, form: form_with_questions, position: 2, required: false) }
    let!(:question3) { create(:form_question, form: form_with_questions, position: 3, required: true) }
    let(:response) { create(:form_response, form: form_with_questions) }

    describe "#current_question_position" do
      it "returns 1 when no questions are answered" do
        expect(response.current_question_position).to eq(1)
      end

      it "returns next position after answered questions" do
        create(:question_response, form_response: response, form_question: question1)
        expect(response.current_question_position).to eq(2)
      end

      it "handles non-sequential answering" do
        create(:question_response, form_response: response, form_question: question1)
        create(:question_response, form_response: response, form_question: question3)
        expect(response.current_question_position).to eq(4) # After the last answered question
      end
    end

    describe "#can_be_completed?" do
      it "returns false when required questions are not answered" do
        expect(response.can_be_completed?).to be false
      end

      it "returns true when all required questions are answered" do
        create(:question_response, form_response: response, form_question: question1)
        create(:question_response, form_response: response, form_question: question3)
        expect(response.can_be_completed?).to be true
      end

      it "ignores optional questions" do
        create(:question_response, form_response: response, form_question: question1)
        create(:question_response, form_response: response, form_question: question3)
        # question2 is optional and not answered
        expect(response.can_be_completed?).to be true
      end
    end

    describe "#next_question" do
      it "returns first question when none are answered" do
        expect(response.next_question).to eq(question1)
      end

      it "returns next question after current position" do
        create(:question_response, form_response: response, form_question: question1)
        expect(response.next_question).to eq(question2)
      end

      it "returns nil when all questions are answered" do
        [question1, question2, question3].each do |q|
          create(:question_response, form_response: response, form_question: q)
        end
        expect(response.next_question).to be_nil
      end
    end

    describe "#previous_question" do
      it "returns nil when at first question" do
        expect(response.previous_question).to be_nil
      end

      it "returns previous question" do
        create(:question_response, form_response: response, form_question: question1)
        create(:question_response, form_response: response, form_question: question2)
        expect(response.previous_question).to eq(question2)
      end
    end
  end

  describe "#workflow_context" do
    let(:response_with_data) { create(:form_response, ai_analysis: { 'sentiment' => 'positive' }, form: form) }

    it "returns comprehensive context hash" do
      context = response_with_data.workflow_context
      
      expect(context).to include(
        :form_id,
        :response_id,
        :session_id,
        :status,
        :progress,
        :current_question,
        :answers,
        :ai_analysis,
        :visitor_info
      )
    end

    it "includes visitor information" do
      context = response_with_data.workflow_context
      visitor_info = context[:visitor_info]
      
      expect(visitor_info).to include(:ip_address, :user_agent, :referrer)
    end
  end

  describe "#response_summary" do
    it "returns summary hash with key metrics" do
      summary = completed_response.response_summary
      
      expect(summary).to include(
        :id,
        :form_name,
        :status,
        :progress,
        :duration,
        :quality_score,
        :sentiment_score,
        :created_at,
        :completed_at
      )
    end
  end

  describe "data integrity and cascade deletion" do
    let(:response_with_data) { create(:form_response, form: form) }
    let!(:question_responses) { create_list(:question_response, 3, form_response: response_with_data) }
    let!(:dynamic_questions) { create_list(:dynamic_question, 2, form_response: response_with_data) }

    it "destroys associated question_responses when destroyed" do
      expect {
        response_with_data.destroy
      }.to change { QuestionResponse.count }.by(-3)
    end

    it "destroys associated dynamic_questions when destroyed" do
      expect {
        response_with_data.destroy
      }.to change { DynamicQuestion.count }.by(-2)
    end

    it "maintains referential integrity" do
      question_response_ids = question_responses.map(&:id)
      response_with_data.destroy
      
      question_response_ids.each do |id|
        expect(QuestionResponse.find_by(id: id)).to be_nil
      end
    end
  end

  describe "scopes" do
    let!(:old_response) { create(:form_response, created_at: 2.weeks.ago) }
    let!(:recent_response) { create(:form_response, created_at: 1.hour.ago) }
    let!(:this_week_response) { create(:form_response, created_at: 3.days.ago) }

    describe ".recent" do
      it "orders by created_at desc" do
        results = FormResponse.recent.limit(2)
        expect(results.first.created_at).to be > results.second.created_at
      end
    end

    describe ".this_week" do
      it "includes responses from this week" do
        expect(FormResponse.this_week).to include(this_week_response, recent_response)
        expect(FormResponse.this_week).not_to include(old_response)
      end
    end

    describe ".this_month" do
      it "includes responses from this month" do
        expect(FormResponse.this_month).to include(this_week_response, recent_response)
        # old_response might be included depending on when tests run
      end
    end
  end
end