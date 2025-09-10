# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormTemplate, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"
  
  it_behaves_like "a model with enum", :template_category, [
    :general, :lead_qualification, :customer_feedback, :job_application, 
    :event_registration, :survey, :contact_form
  ]
  
  it_behaves_like "a model with enum", :visibility, [:template_private, :template_public, :featured]

  # Associations
  describe "associations" do
    it { should belong_to(:creator).class_name('User').optional }
    it { should have_many(:form_instances).class_name('Form').with_foreign_key('template_id') }

    it "allows template without creator" do
      template = build(:form_template, :without_creator)
      expect(template).to be_valid
    end

    it "tracks form instances created from template" do
      template = create(:form_template)
      user = create(:user)
      
      form = template.instantiate_for_user(user)
      
      expect(template.form_instances).to include(form)
      expect(form.template_id).to eq(template.id)
    end
  end

  # Validations
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:template_data) }
  end

  # Scopes
  describe "scopes" do
    let!(:public_template) { create(:form_template, visibility: :template_public) }
    let!(:private_template) { create(:form_template, :private) }
    let!(:featured_template) { create(:form_template, :featured) }
    let!(:popular_template) { create(:form_template, usage_count: 100) }
    let!(:recent_template) { create(:form_template, created_at: 1.hour.ago) }
    let!(:old_template) { create(:form_template, created_at: 1.week.ago) }

    describe ".public_templates" do
      it "returns only public templates" do
        expect(FormTemplate.public_templates).to include(public_template)
        expect(FormTemplate.public_templates).not_to include(private_template, featured_template)
      end
    end

    describe ".featured" do
      it "returns only featured templates" do
        expect(FormTemplate.featured).to include(featured_template)
        expect(FormTemplate.featured).not_to include(public_template, private_template)
      end
    end

    describe ".by_category" do
      it "filters by category" do
        lead_template = create(:form_template, :lead_qualification)
        
        expect(FormTemplate.by_category(:lead_qualification)).to include(lead_template)
        expect(FormTemplate.by_category(:lead_qualification)).not_to include(public_template)
      end
    end

    describe ".popular" do
      it "orders by usage count descending" do
        results = FormTemplate.popular
        expect(results.first.usage_count).to be >= results.last.usage_count
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        results = FormTemplate.recent
        expect(results.first.created_at).to be >= results.last.created_at
      end
    end
  end

  # Callbacks
  describe "callbacks" do
    describe "before_save" do
      it "calculates estimated time based on questions" do
        template = build(:form_template, estimated_time_minutes: nil)
        template.save!
        
        expect(template.estimated_time_minutes).to be > 0
      end

      it "extracts features from template data" do
        template = build(:form_template, features: nil)
        template.save!
        
        expect(template.features).to be_present
        expect(template.features).to include('text_short', 'rating')
      end

      it "includes AI features when AI is enabled" do
        template = build(:form_template, :ai_enhanced, features: nil)
        template.save!
        
        expect(template.features).to include('ai_enhanced')
      end
    end
  end

  # Core Methods
  describe "#questions_config" do
    it "returns questions array from template data" do
      template = create(:form_template)
      questions = template.questions_config
      
      expect(questions).to be_an(Array)
      expect(questions.length).to eq(2)
      expect(questions.first['title']).to eq('What is your name?')
    end

    it "returns empty array when no questions" do
      template = create(:form_template, template_data: {})
      expect(template.questions_config).to eq([])
    end
  end

  describe "#form_settings_template" do
    it "returns settings hash from template data" do
      template = create(:form_template)
      settings = template.form_settings_template
      
      expect(settings).to be_a(Hash)
      expect(settings['multi_step']).to be false
      expect(settings['show_progress']).to be true
    end

    it "returns empty hash when no settings" do
      template = create(:form_template, template_data: {})
      expect(template.form_settings_template).to eq({})
    end
  end

  describe "#ai_configuration_template" do
    it "returns AI config from template data" do
      template = create(:form_template, :ai_enhanced)
      ai_config = template.ai_configuration_template
      
      expect(ai_config).to be_a(Hash)
      expect(ai_config['enabled']).to be true
    end

    it "returns empty hash when no AI config" do
      template = create(:form_template, template_data: { 'questions' => [] })
      expect(template.ai_configuration_template).to eq({})
    end
  end

  describe "#instantiate_for_user" do
    let(:template) { create(:form_template, :lead_qualification) }
    let(:user) { create(:user) }

    it "creates a new form based on template" do
      expect {
        template.instantiate_for_user(user)
      }.to change { Form.count }.by(1)
        .and change { FormQuestion.count }.by(3)
    end

    it "creates form with correct attributes" do
      form = template.instantiate_for_user(user)
      
      expect(form.name).to eq(template.name)
      expect(form.description).to eq(template.description)
      expect(form.category).to eq(template.template_category)
      expect(form.user).to eq(user)
      expect(form.template_id).to eq(template.id)
    end

    it "creates questions from template configuration" do
      form = template.instantiate_for_user(user)
      
      expect(form.form_questions.count).to eq(3)
      
      first_question = form.form_questions.first
      expect(first_question.title).to eq('What is your company name?')
      expect(first_question.question_type).to eq('text_short')
      expect(first_question.required).to be true
    end

    it "applies customizations when provided" do
      customizations = {
        name: 'Custom Form Name',
        description: 'Custom description',
        settings: { 'custom_setting' => true },
        questions: {
          0 => { title: 'Custom Question Title' }
        }
      }
      
      form = template.instantiate_for_user(user, customizations)
      
      expect(form.name).to eq('Custom Form Name')
      expect(form.description).to eq('Custom description')
      expect(form.form_questions.first.title).to eq('Custom Question Title')
    end

    it "increments usage count" do
      expect {
        template.instantiate_for_user(user)
      }.to change { template.reload.usage_count }.by(1)
    end
  end

  describe "#preview_data" do
    it "returns comprehensive preview information" do
      template = create(:form_template, :ai_enhanced)
      preview = template.preview_data
      
      expect(preview).to include(:id, :name, :description, :category, :visibility, :estimated_time, :features, :questions_count, :ai_enhanced, :usage_count, :creator, :created_at, :sample_questions)
      expect(preview[:ai_enhanced]).to be true
      expect(preview[:sample_questions]).to be_an(Array)
    end
  end

  describe "#ai_enhanced?" do
    it "returns true when AI configuration is present" do
      template = create(:form_template, :ai_enhanced)
      expect(template.ai_enhanced?).to be true
    end

    it "returns false when no AI configuration" do
      template = create(:form_template)
      template.template_data['ai_configuration'] = {}
      expect(template.ai_enhanced?).to be false
    end
  end

  describe "#sample_questions_preview" do
    it "returns limited preview of questions" do
      template = create(:form_template, :complex)
      preview = template.sample_questions_preview(2)
      
      expect(preview.length).to eq(2)
      expect(preview.first).to include(:title, :type, :required, :ai_enhanced)
    end

    it "returns all questions when limit is higher than count" do
      template = create(:form_template)
      preview = template.sample_questions_preview(10)
      
      expect(preview.length).to eq(2) # Template has 2 questions
    end
  end

  describe "#complexity_score" do
    it "calculates higher score for complex templates" do
      complex_template = create(:form_template, :complex)
      simple_template = create(:form_template)
      
      expect(complex_template.complexity_score).to be > simple_template.complexity_score
    end

    it "adds points for AI features" do
      ai_template = create(:form_template, :ai_enhanced)
      regular_template = create(:form_template)
      
      expect(ai_template.complexity_score).to be > regular_template.complexity_score
    end

    it "adds points for complex question types" do
      template = create(:form_template, :complex)
      score = template.complexity_score
      
      expect(score).to be > 20 # Should be higher due to matrix and file_upload questions
    end
  end

  describe "#duplicate_for_user" do
    let(:original_template) { create(:form_template, :featured, usage_count: 50) }
    let(:user) { create(:user) }

    it "creates a duplicate template" do
      expect {
        original_template.duplicate_for_user(user)
      }.to change { FormTemplate.count }.by(1)
    end

    it "sets correct attributes for duplicate" do
      duplicate = original_template.duplicate_for_user(user, 'My Custom Template')
      
      expect(duplicate.name).to eq('My Custom Template')
      expect(duplicate.creator).to eq(user)
      expect(duplicate.visibility).to eq('template_private')
      expect(duplicate.usage_count).to eq(0)
      expect(duplicate.template_data).to eq(original_template.template_data)
    end

    it "uses default name when none provided" do
      duplicate = original_template.duplicate_for_user(user)
      expect(duplicate.name).to eq("#{original_template.name} (Copy)")
    end
  end

  describe "#export_data" do
    it "returns exportable template data" do
      template = create(:form_template)
      export_data = template.export_data
      
      expect(export_data).to include(:template, :metadata)
      expect(export_data[:template]).to include(:name, :description, :category, :template_data)
      expect(export_data[:metadata]).to include(:version, :exported_at, :usage_count)
    end
  end

  # Class Methods
  describe ".import_from_data" do
    let(:user) { create(:user) }
    let(:import_data) do
      {
        'template' => {
          'name' => 'Imported Template',
          'description' => 'Imported from external source',
          'category' => 'survey',
          'template_data' => { 'questions' => [] },
          'estimated_time' => 5,
          'features' => ['text_short']
        }
      }
    end

    it "creates template from import data" do
      expect {
        FormTemplate.import_from_data(import_data, user)
      }.to change { FormTemplate.count }.by(1)
    end

    it "sets correct attributes from import data" do
      template = FormTemplate.import_from_data(import_data, user)
      
      expect(template.name).to eq('Imported Template')
      expect(template.description).to eq('Imported from external source')
      expect(template.template_category).to eq('survey')
      expect(template.creator).to eq(user)
      expect(template.visibility).to eq('template_private')
    end
  end

  describe ".popular_templates" do
    it "returns popular public templates" do
      popular_public = create(:form_template, visibility: :template_public, usage_count: 100)
      popular_private = create(:form_template, :private, usage_count: 200)
      
      results = FormTemplate.popular_templates(5)
      
      expect(results).to include(popular_public)
      expect(results).not_to include(popular_private)
    end

    it "limits results to specified count" do
      create_list(:form_template, 15, visibility: :template_public)
      
      results = FormTemplate.popular_templates(10)
      expect(results.count).to eq(10)
    end
  end

  describe ".featured_templates" do
    it "returns featured templates ordered by creation date" do
      old_featured = create(:form_template, :featured, created_at: 1.week.ago)
      new_featured = create(:form_template, :featured, created_at: 1.hour.ago)
      
      results = FormTemplate.featured_templates
      
      expect(results).to include(old_featured, new_featured)
      expect(results.first.created_at).to be <= results.last.created_at
    end
  end

  describe ".search" do
    let!(:template1) { create(:form_template, name: 'Customer Feedback Form') }
    let!(:template2) { create(:form_template, description: 'Lead qualification survey') }
    let!(:template3) { create(:form_template, features: ['lead_qualification', 'ai_enhanced']) }

    it "searches by name" do
      results = FormTemplate.search('Customer')
      expect(results).to include(template1)
      expect(results).not_to include(template2, template3)
    end

    it "searches by description" do
      results = FormTemplate.search('qualification')
      expect(results).to include(template2)
    end

    it "searches by features" do
      results = FormTemplate.search('lead_qualification')
      expect(results).to include(template3)
    end

    it "returns all templates for blank query" do
      results = FormTemplate.search('')
      expect(results.count).to eq(FormTemplate.count)
    end

    it "is case insensitive" do
      results = FormTemplate.search('CUSTOMER')
      expect(results).to include(template1)
    end
  end

  # Private Methods (tested through public interface)
  describe "time calculation" do
    it "calculates time based on question types" do
      template_data = {
        'questions' => [
          { 'question_type' => 'text_short' },    # 15 seconds
          { 'question_type' => 'text_long' },     # 45 seconds
          { 'question_type' => 'rating' },        # 5 seconds
          { 'question_type' => 'payment' }        # 60 seconds
        ]
      }
      
      template = build(:form_template, template_data: template_data)
      template.save!
      
      # Total: 125 seconds * 1.2 buffer = 150 seconds = 3 minutes (rounded up)
      expect(template.estimated_time_minutes).to eq(3)
    end

    it "adds time for AI features" do
      template_data = {
        'questions' => [
          { 'question_type' => 'text_short', 'ai_enhanced' => true },  # 15 + 5 = 20 seconds
          { 'question_type' => 'rating' }                              # 5 seconds
        ]
      }
      
      template = build(:form_template, template_data: template_data)
      template.save!
      
      # Total: 25 seconds * 1.2 buffer = 30 seconds = 1 minute (rounded up)
      expect(template.estimated_time_minutes).to eq(1)
    end
  end

  describe "feature extraction" do
    it "extracts question type features" do
      template = create(:form_template, :complex)
      
      expect(template.features).to include('text_short', 'matrix', 'file_upload', 'text_long')
    end

    it "extracts conditional logic features" do
      template = create(:form_template, :complex)
      
      expect(template.features).to include('conditional_logic')
    end

    it "extracts form-level features" do
      template = create(:form_template, :complex)
      
      expect(template.features).to include('multi_step', 'validation')
    end
  end

  # Payment validation methods
  describe "payment validation methods" do
    let(:template_with_payment) { create(:form_template, :with_payment_questions) }
    let(:template_without_payment) { create(:form_template) }

    describe "#payment_requirements" do
      it "returns analysis results for template with payment questions" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: {
            has_payment_questions: true,
            payment_questions: [{ question_type: 'payment' }],
            required_features: ['stripe_payments', 'premium_subscription'],
            setup_complexity: 'medium'
          })
        )

        requirements = template_with_payment.payment_requirements

        expect(requirements[:has_payment_questions]).to be true
        expect(requirements[:required_features]).to include('stripe_payments', 'premium_subscription')
        expect(requirements[:setup_complexity]).to eq('medium')
      end

      it "caches the analysis results" do
        expect(TemplateAnalysisService).to receive(:call).once.and_return(
          double(result: { has_payment_questions: false })
        )

        template_without_payment.payment_requirements
        template_without_payment.payment_requirements # Second call should use cache
      end
    end

    describe "#has_payment_questions?" do
      it "returns true when template has payment questions" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: { has_payment_questions: true })
        )

        expect(template_with_payment.has_payment_questions?).to be true
      end

      it "returns false when template has no payment questions" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: { has_payment_questions: false })
        )

        expect(template_without_payment.has_payment_questions?).to be false
      end

      it "returns false when payment_requirements is nil" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: {})
        )

        expect(template_without_payment.has_payment_questions?).to be false
      end
    end

    describe "#required_features" do
      it "returns required features array when payment questions exist" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: { required_features: ['stripe_payments', 'premium_subscription'] })
        )

        expect(template_with_payment.required_features).to eq(['stripe_payments', 'premium_subscription'])
      end

      it "returns empty array when no payment questions" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: { required_features: [] })
        )

        expect(template_without_payment.required_features).to eq([])
      end

      it "returns empty array when required_features is nil" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: {})
        )

        expect(template_without_payment.required_features).to eq([])
      end
    end

    describe "#setup_complexity" do
      it "returns complexity level for templates with payment questions" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: { setup_complexity: 'high' })
        )

        expect(template_with_payment.setup_complexity).to eq('high')
      end

      it "returns 'none' for templates without payment questions" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: { setup_complexity: 'none' })
        )

        expect(template_without_payment.setup_complexity).to eq('none')
      end

      it "returns 'none' when setup_complexity is nil" do
        allow(TemplateAnalysisService).to receive(:call).and_return(
          double(result: {})
        )

        expect(template_without_payment.setup_complexity).to eq('none')
      end
    end
  end
end