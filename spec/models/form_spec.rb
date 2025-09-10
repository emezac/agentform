# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"
  
  it_behaves_like "a model with enum", :status, [:draft, :published, :archived, :template]
  it_behaves_like "a model with enum", :category, [
    :general, :lead_qualification, :customer_feedback, :job_application, 
    :event_registration, :survey, :contact_form
  ]

  # Associations
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:form_questions).dependent(:destroy) }
    it { should have_many(:form_responses).dependent(:destroy) }
    it { should have_many(:form_analytics).dependent(:destroy) }
    it { should have_many(:dynamic_questions).through(:form_responses) }

    it "orders form_questions by position" do
      form = create(:form)
      question3 = create(:form_question, form: form, position: 3)
      question1 = create(:form_question, form: form, position: 1)
      question2 = create(:form_question, form: form, position: 2)

      expect(form.form_questions).to eq([question1, question2, question3])
    end

    it "destroys dependent records when form is destroyed" do
      form = create(:form, :with_questions)
      create(:form_response, form: form)

      expect { form.destroy }.to change { FormQuestion.count }.by(-3)
        .and change { FormResponse.count }.by(-1)
    end
  end

  # Validations
  describe "validations" do
    subject { build(:form) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:share_token) }

    it "allows blank share_token" do
      form = build(:form, share_token: nil)
      expect(form).to be_valid
    end

    it "validates uniqueness of share_token when present" do
      existing_form = create(:form)
      duplicate_form = build(:form, share_token: existing_form.share_token)
      
      expect(duplicate_form).not_to be_valid
      expect(duplicate_form.errors[:share_token]).to include("has already been taken")
    end
  end

  # Enums
  describe "enums" do
    describe "status" do
      it "defines correct status values" do
        expect(Form.statuses).to eq({
          'draft' => 'draft',
          'published' => 'published', 
          'archived' => 'archived',
          'template' => 'template'
        })
      end

      it "provides predicate methods" do
        form = create(:form, status: :published)
        
        expect(form.published?).to be true
        expect(form.draft?).to be false
        expect(form.archived?).to be false
        expect(form.template?).to be false
      end

      it "allows status transitions" do
        form = create(:form, status: :draft)
        
        form.published!
        expect(form.status).to eq('published')
        
        form.archived!
        expect(form.status).to eq('archived')
      end
    end

    describe "category" do
      it "defines correct category values" do
        expected_categories = {
          'general' => 'general',
          'lead_qualification' => 'lead_qualification',
          'customer_feedback' => 'customer_feedback',
          'job_application' => 'job_application',
          'event_registration' => 'event_registration',
          'survey' => 'survey',
          'contact_form' => 'contact_form'
        }
        
        expect(Form.categories).to eq(expected_categories)
      end

      it "provides predicate methods for categories" do
        form = create(:form, category: :lead_qualification)
        
        expect(form.lead_qualification?).to be true
        expect(form.general?).to be false
      end
    end
  end

  # Callbacks
  describe "callbacks" do
    describe "before_create :generate_share_token" do
      it "generates a share_token before creation" do
        form = build(:form, share_token: nil)
        expect(form.share_token).to be_nil
        
        form.save!
        expect(form.share_token).to be_present
        expect(form.share_token.length).to eq(16) # urlsafe_base64(12) generates 16 chars
      end

      it "doesn't override existing share_token" do
        custom_token = "custom_token_123"
        form = build(:form)
        form.share_token = custom_token
        
        form.save!
        expect(form.share_token).to eq(custom_token)
      end

      it "ensures share_token uniqueness" do
        existing_form = create(:form)
        
        # Mock SecureRandom to return existing token first, then unique one
        allow(SecureRandom).to receive(:urlsafe_base64)
          .and_return(existing_form.share_token, "unique_token_456")
        
        new_form = create(:form)
        expect(new_form.share_token).to eq("unique_token_456")
      end
    end

    describe "before_save :set_workflow_class_name" do
      it "sets workflow_class_name when AI is enabled and workflow_class_name is blank" do
        form = build(:form, :ai_enabled, workflow_class: nil)
        
        form.save!
        expect(form.workflow_class_name).to be_present
        expect(form.workflow_class_name).to start_with("Forms::Form")
        expect(form.workflow_class_name).to end_with("Workflow")
      end

      it "doesn't set workflow_class_name when AI is disabled" do
        form = build(:form, ai_enabled: false, workflow_class: nil)
        
        form.save!
        expect(form.workflow_class_name).to be_nil
      end

      it "doesn't override existing workflow_class_name" do
        existing_class = "Forms::CustomWorkflow"
        form = build(:form, :ai_enabled, workflow_class: existing_class)
        
        form.save!
        expect(form.workflow_class_name).to eq(existing_class)
      end
    end

    describe "before_save :update_form_cache" do
      it "calls update_form_cache method on save" do
        form = create(:form)
        
        expect(form).to receive(:update_form_cache)
        
        form.update!(name: "Updated Name")
      end

      it "clears specific form cache when persisted" do
        form = create(:form)
        
        # Test the method directly
        expect(Rails.cache).to receive(:delete_matched).with("form/#{form.id}/*")
        
        form.send(:update_form_cache)
      end

      it "doesn't clear cache for non-persisted records" do
        form = build(:form)
        
        # Test the method directly
        expect(Rails.cache).not_to receive(:delete_matched)
        
        form.send(:update_form_cache)
      end
    end
  end

  # Custom Methods
  describe "custom methods" do
    describe "#workflow_class" do
      it "returns constantized workflow class when workflow_class_name is present" do
        # Mock a workflow class
        stub_const("Forms::TestWorkflow", Class.new)
        form = create(:form, workflow_class: "Forms::TestWorkflow")
        
        expect(form.workflow_class).to eq(Forms::TestWorkflow)
      end

      it "returns nil when workflow_class_name is blank" do
        form = create(:form, workflow_class: nil)
        
        expect(form.workflow_class).to be_nil
      end

      it "returns nil when workflow_class_name is invalid" do
        form = create(:form, workflow_class: "NonExistentClass")
        
        expect(form.workflow_class).to be_nil
      end
    end

    describe "#create_workflow_class!" do
      it "generates a workflow class name based on form ID" do
        form = create(:form)
        workflow_class_name = form.create_workflow_class!
        
        expect(workflow_class_name).to start_with("Forms::Form")
        expect(workflow_class_name).to end_with("Workflow")
        expect(workflow_class_name).to include(form.id.to_s.gsub('-', '').first(8).capitalize)
      end
    end

    describe "#regenerate_workflow!" do
      it "regenerates and saves workflow_class_name" do
        form = create(:form)
        original_workflow_class = form.workflow_class_name
        
        form.regenerate_workflow!
        
        expect(form.workflow_class_name).to be_present
        expect(form.workflow_class_name).not_to eq(original_workflow_class)
        expect(form.reload.workflow_class_name).to eq(form.workflow_class_name)
      end
    end

    describe "#ai_enhanced?" do
      it "returns true when AI is enabled and configuration is present" do
        form = create(:form, :ai_enabled)
        
        expect(form.ai_enhanced?).to be true
      end

      it "returns false when AI is disabled" do
        form = create(:form, ai_enabled: false, ai_configuration: { features: ['test'] })
        
        expect(form.ai_enhanced?).to be false
      end

      it "returns false when AI configuration is blank" do
        form = create(:form, ai_enabled: true, ai_configuration: {})
        
        expect(form.ai_enhanced?).to be false
      end
    end

    describe "#ai_features_enabled" do
      it "returns features array when AI is enhanced" do
        features = ['response_analysis', 'sentiment_analysis']
        form = create(:form, :ai_enabled)
        form.ai_configuration['features'] = features
        
        expect(form.ai_features_enabled).to eq(features)
      end

      it "returns empty array when AI is not enhanced" do
        form = create(:form, ai_enabled: false)
        
        expect(form.ai_features_enabled).to eq([])
      end
    end

    describe "#estimated_ai_cost_per_response" do
      it "returns 0.0 when AI is not enhanced" do
        form = create(:form, ai_enabled: false)
        
        expect(form.estimated_ai_cost_per_response).to eq(0.0)
      end

      it "calculates cost based on features when AI is enhanced" do
        form = create(:form, :ai_enabled)
        form.ai_configuration['features'] = ['feature1', 'feature2']
        
        expected_cost = 0.01 + (2 * 0.005) # base + (features * multiplier)
        expect(form.estimated_ai_cost_per_response).to eq(expected_cost)
      end
    end

    describe "#completion_rate" do
      it "returns 0.0 when no responses" do
        form = create(:form, responses_count: 0)
        
        expect(form.completion_rate).to eq(0.0)
      end

      it "calculates completion rate correctly" do
        form = create(:form, responses_count: 100, completion_count: 75)
        
        expect(form.completion_rate).to eq(75.0)
      end

      it "rounds to 2 decimal places" do
        form = create(:form, responses_count: 3, completion_count: 1)
        
        expect(form.completion_rate).to eq(33.33)
      end
    end

    describe "#questions_ordered" do
      it "returns questions ordered by position" do
        form = create(:form)
        question3 = create(:form_question, form: form, position: 3)
        question1 = create(:form_question, form: form, position: 1)
        question2 = create(:form_question, form: form, position: 2)
        
        expect(form.questions_ordered).to eq([question1, question2, question3])
      end
    end

    describe "#next_question_position" do
      it "returns 1 when no questions exist" do
        form = create(:form)
        
        expect(form.next_question_position).to eq(1)
      end

      it "returns next position after highest existing position" do
        form = create(:form)
        create(:form_question, form: form, position: 5)
        create(:form_question, form: form, position: 2)
        
        expect(form.next_question_position).to eq(6)
      end
    end

    describe "#public_url" do
      it "generates public URL with share_token" do
        form = create(:form)
        
        expect(form.public_url).to include(form.share_token)
        expect(form.public_url).to include("/f/")
      end

      it "falls back to path when host is not configured" do
        form = create(:form)
        
        # Test the fallback behavior by stubbing the method to simulate the error
        allow(form).to receive(:public_url).and_call_original
        
        # Stub the url_helpers methods
        url_helpers = Rails.application.routes.url_helpers
        allow(url_helpers).to receive(:public_form_url)
          .with(form.share_token)
          .and_raise(ActionController::UrlGenerationError.new("Missing host"))
        
        allow(url_helpers).to receive(:public_form_path)
          .with(form.share_token)
          .and_return("/f/#{form.share_token}")
        
        result = form.public_url
        expect(result).to eq("/f/#{form.share_token}")
        expect(result).to include(form.share_token)
      end
    end

    describe "#embed_code" do
      it "generates iframe embed code with default dimensions" do
        form = create(:form)
        embed_code = form.embed_code
        
        expect(embed_code).to include('<iframe')
        expect(embed_code).to include(form.public_url)
        expect(embed_code).to include('width="100%"')
        expect(embed_code).to include('height="600px"')
        expect(embed_code).to include('frameborder="0"')
      end

      it "accepts custom dimensions" do
        form = create(:form)
        embed_code = form.embed_code(width: '800px', height: '400px')
        
        expect(embed_code).to include('width="800px"')
        expect(embed_code).to include('height="400px"')
      end
    end

    describe "#analytics_summary" do
      let(:form) { create(:form, views_count: 1000) }
      
      before do
        # Create responses in different time periods
        create(:form_response, form: form, created_at: 10.days.ago, completed_at: 10.days.ago, time_spent_seconds: 120)
        create(:form_response, form: form, created_at: 40.days.ago, completed_at: 40.days.ago, time_spent_seconds: 180)
        create(:form_response, form: form, created_at: 5.days.ago, completed_at: nil) # incomplete
      end

      it "returns analytics for specified period" do
        summary = form.analytics_summary(period: 30.days)
        
        expect(summary[:period]).to eq(30.days)
        expect(summary[:views]).to eq(1000)
        expect(summary[:responses]).to eq(2) # 2 responses in last 30 days
        expect(summary[:completions]).to eq(1) # 1 completion in last 30 days
        expect(summary[:avg_time]).to eq(120) # average of completed responses
      end

      it "uses default period of 30 days" do
        summary = form.analytics_summary
        
        expect(summary[:period]).to eq(30.days)
      end

      it "handles forms with no responses" do
        empty_form = create(:form)
        summary = empty_form.analytics_summary
        
        expect(summary[:responses]).to eq(0)
        expect(summary[:completions]).to eq(0)
        expect(summary[:avg_time]).to eq(0)
      end
    end

    describe "#cached_analytics_summary" do
      it "caches analytics summary" do
        form = create(:form)
        
        # Mock the cache to avoid the nested cached_completion_rate call
        allow(form).to receive(:cached_completion_rate).and_return(75.0)
        
        expect(Rails.cache).to receive(:fetch)
          .with("form/#{form.id}/analytics/#{30.days.to_i}", expires_in: 1.hour)
          .and_call_original
        
        form.cached_analytics_summary
      end

      it "accepts custom period" do
        form = create(:form)
        
        # Mock the cache to avoid the nested cached_completion_rate call
        allow(form).to receive(:cached_completion_rate).and_return(75.0)
        
        expect(Rails.cache).to receive(:fetch)
          .with("form/#{form.id}/analytics/#{7.days.to_i}", expires_in: 1.hour)
          .and_call_original
        
        form.cached_analytics_summary(period: 7.days)
      end
    end

    describe "#cached_completion_rate" do
      it "caches completion rate" do
        form = create(:form)
        
        expect(Rails.cache).to receive(:fetch)
          .with("form/#{form.id}/completion_rate", expires_in: 30.minutes)
          .and_call_original
        
        form.cached_completion_rate
      end
    end

    describe "#ai_enabled?" do
      it "returns value from ai_enabled column when present" do
        form = create(:form, ai_enabled: true)
        
        expect(form.ai_enabled?).to be true
      end

      it "falls back to configuration when column is nil" do
        form = create(:form)
        form.update_column(:ai_enabled, nil) # Bypass validation to set nil
        form.ai_configuration = { 'enabled' => true }
        
        expect(form.ai_enabled?).to be true
      end

      it "returns false when both column and config are false/nil" do
        form = create(:form, ai_enabled: false, ai_configuration: {})
        
        expect(form.ai_enabled?).to be false
      end
    end

    describe "#ai_model" do
      it "returns model from configuration" do
        form = create(:form, :ai_enabled)
        form.ai_configuration['model'] = 'gpt-4'
        
        expect(form.ai_model).to eq('gpt-4')
      end

      it "returns default model when not configured" do
        form = create(:form, :ai_enabled)
        form.ai_configuration.delete('model')
        
        expect(form.ai_model).to eq('gpt-4o-mini')
      end
    end
  end

  # Caching behavior
  describe "caching behavior" do
    it "includes Cacheable concern" do
      expect(Form.ancestors).to include(Cacheable)
    end

    it "generates proper cache keys" do
      form = create(:form)
      cache_key = form.cache_key
      
      expect(cache_key).to include("forms")
      expect(cache_key).to include(form.id.to_s)
    end
  end

  # Payment validation methods
  describe "payment validation methods" do
    let(:premium_user) { create(:user, :premium, :stripe_configured) }
    let(:basic_user) { create(:user) }
    let(:form_with_payment) { create(:form, :with_payment_questions, user: premium_user) }
    let(:form_without_payment) { create(:form, user: premium_user) }

    describe "#payment_setup_complete?" do
      it "returns true for forms without payment questions" do
        expect(form_without_payment.payment_setup_complete?).to be true
      end

      it "returns true when user has Stripe configured and Premium subscription" do
        expect(form_with_payment.payment_setup_complete?).to be true
      end

      it "returns false when user lacks Stripe configuration" do
        form_with_payment.user.update!(stripe_enabled: false)
        expect(form_with_payment.payment_setup_complete?).to be false
      end

      it "returns false when user lacks Premium subscription" do
        form_with_payment.user.update!(subscription_tier: 'basic')
        expect(form_with_payment.payment_setup_complete?).to be false
      end

      it "returns false when user lacks both Stripe and Premium" do
        form = create(:form, :with_payment_questions, user: basic_user)
        expect(form.payment_setup_complete?).to be false
      end
    end

    describe "#payment_setup_requirements" do
      it "returns empty array for forms without payment questions" do
        expect(form_without_payment.payment_setup_requirements).to eq([])
      end

      it "returns empty array when setup is complete" do
        expect(form_with_payment.payment_setup_requirements).to eq([])
      end

      it "returns stripe_configuration when Stripe is not configured" do
        form_with_payment.user.update!(stripe_enabled: false)
        expect(form_with_payment.payment_setup_requirements).to include('stripe_configuration')
      end

      it "returns premium_subscription when user is not Premium" do
        form_with_payment.user.update!(subscription_tier: 'basic')
        expect(form_with_payment.payment_setup_requirements).to include('premium_subscription')
      end

      it "returns both requirements when both are missing" do
        form = create(:form, :with_payment_questions, user: basic_user)
        requirements = form.payment_setup_requirements
        
        expect(requirements).to include('stripe_configuration', 'premium_subscription')
        expect(requirements.length).to eq(2)
      end
    end

    describe "#can_publish_with_payments?" do
      it "returns true for forms without payment questions" do
        expect(form_without_payment.can_publish_with_payments?).to be true
      end

      it "returns true when payment setup is complete" do
        expect(form_with_payment.can_publish_with_payments?).to be true
      end

      it "returns false when payment setup is incomplete" do
        form_with_payment.user.update!(stripe_enabled: false)
        expect(form_with_payment.can_publish_with_payments?).to be false
      end

      it "returns false when user lacks Premium subscription" do
        form_with_payment.user.update!(subscription_tier: 'basic')
        expect(form_with_payment.can_publish_with_payments?).to be false
      end
    end
  end

  # Edge cases and error handling
  describe "edge cases" do
    it "handles very long names gracefully" do
      long_name = "a" * 1000
      form = build(:form, name: long_name)
      
      # Should be valid (assuming no length validation on name)
      expect(form).to be_valid
    end

    it "handles special characters in share_token" do
      form = create(:form)
      
      # share_token should be URL-safe
      expect(form.share_token).to match(/\A[A-Za-z0-9_-]+\z/)
    end

    it "handles nil ai_configuration gracefully" do
      form = create(:form, ai_configuration: nil)
      
      expect(form.ai_enhanced?).to be false
      expect(form.ai_features_enabled).to eq([])
      expect(form.ai_model).to eq('gpt-4o-mini')
    end

    it "handles empty ai_configuration gracefully" do
      form = create(:form, ai_configuration: {})
      
      expect(form.ai_enhanced?).to be false
      expect(form.ai_features_enabled).to eq([])
    end
  end
end