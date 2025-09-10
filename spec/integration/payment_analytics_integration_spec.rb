# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment Analytics Integration', type: :request do
  let(:user) { create(:user, :premium) }
  let(:form) { create(:form, user: user) }
  let(:template) { create(:form_template, :with_payment_questions) }

  before do
    sign_in user
  end

  describe 'Template interaction tracking' do
    it 'tracks template payment interactions' do
      expect {
        # Simulate template analysis with analytics
        TemplateAnalysisService.new(template: template, user: user).call
      }.to change(PaymentAnalytic, :count).by(1)

      analytic = PaymentAnalytic.last
      expect(analytic.event_type).to eq('template_payment_interaction')
      expect(analytic.user).to eq(user)
      expect(analytic.context['template_id']).to eq(template.id)
    end

    it 'includes template metadata in analytics' do
      TemplateAnalysisService.new(template: template, user: user).call

      analytic = PaymentAnalytic.last
      expect(analytic.context).to include(
        'template_name' => template.name,
        'payment_questions_count',
        'required_features',
        'setup_complexity'
      )
    end
  end

  describe 'Payment setup tracking' do
    context 'when user starts setup' do
      it 'tracks setup started event' do
        expect {
          PaymentSetupValidationService.new(
            user: user,
            required_features: ['stripe_payments']
          ).call
        }.to change(PaymentAnalytic, :count).by(1)

        analytic = PaymentAnalytic.last
        expect(analytic.event_type).to eq('payment_setup_started')
      end
    end

    context 'when user completes setup' do
      let(:configured_user) { create(:user, :premium, :stripe_configured) }

      it 'tracks setup completed event' do
        expect {
          PaymentSetupValidationService.new(
            user: configured_user,
            required_features: ['stripe_payments', 'premium_subscription']
          ).call
        }.to change(PaymentAnalytic, :count).by(1)

        analytic = PaymentAnalytic.last
        expect(analytic.event_type).to eq('payment_setup_completed')
      end
    end

    context 'when user abandons setup' do
      it 'tracks abandonment via controller' do
        form_with_payments = create(:form, :with_payment_questions, user: user)

        expect {
          post track_setup_abandonment_form_path(form_with_payments), params: {
            abandonment_point: 'form_editor',
            time_spent: 300
          }
        }.to change(PaymentAnalytic, :count).by(1)

        analytic = PaymentAnalytic.last
        expect(analytic.event_type).to eq('payment_setup_abandoned')
        expect(analytic.context['abandonment_point']).to eq('form_editor')
        expect(analytic.context['time_spent']).to eq(300)
      end
    end
  end

  describe 'Form publishing tracking' do
    context 'when form is successfully published' do
      let(:configured_user) { create(:user, :premium, :stripe_configured) }
      let(:publishable_form) { create(:form, :with_payment_questions, user: configured_user) }

      it 'tracks form published event' do
        expect {
          FormPublishValidationService.new(form: publishable_form).call
        }.to change(PaymentAnalytic, :count).by(1)

        analytic = PaymentAnalytic.last
        expect(analytic.event_type).to eq('payment_form_published')
        expect(analytic.context['form_id']).to eq(publishable_form.id)
      end
    end

    context 'when form publishing fails validation' do
      let(:unpublishable_form) { create(:form, :with_payment_questions, user: user) }

      it 'tracks validation errors' do
        expect {
          FormPublishValidationService.new(form: unpublishable_form).call
        }.to change(PaymentAnalytic, :count).by_at_least(1)

        error_analytics = PaymentAnalytic.where(event_type: 'payment_validation_errors')
        expect(error_analytics).to be_present

        error_analytic = error_analytics.first
        expect(error_analytic.context['error_type']).to be_present
        expect(error_analytic.context['form_id']).to eq(unpublishable_form.id)
      end
    end
  end

  describe 'Background job processing' do
    it 'processes analytics jobs asynchronously' do
      expect {
        PaymentAnalyticsJob.perform_async(
          'template_payment_interaction',
          user.id,
          { template_id: template.id }
        )
      }.to change(PaymentAnalyticsJob.jobs, :size).by(1)
    end

    it 'handles job failures gracefully' do
      # Simulate job failure
      allow_any_instance_of(PaymentAnalyticsService).to receive(:track_event)
        .and_raise(StandardError.new('Database error'))

      expect {
        PaymentAnalyticsJob.new.perform(
          'payment_setup_started',
          user.id,
          { action: 'test' }
        )
      }.to raise_error(StandardError, 'Database error')
    end
  end

  describe 'Dashboard metrics calculation' do
    before do
      # Create test data for metrics
      create(:payment_analytic, :setup_started, user: user, timestamp: 2.days.ago)
      create(:payment_analytic, :setup_completed, user: user, timestamp: 1.day.ago)
      create(:payment_analytic, :template_interaction, user: user, timestamp: 1.day.ago)
      create(:payment_analytic, :validation_error, user: user, timestamp: 1.day.ago)
    end

    it 'calculates comprehensive metrics' do
      service = PaymentAnalyticsService.new
      metrics = service.get_dashboard_metrics(date_range: 7.days.ago..Time.current)

      expect(metrics).to include(
        :setup_completion_rate,
        :common_failure_points,
        :template_interaction_stats,
        :job_performance_metrics,
        :error_resolution_paths
      )

      expect(metrics[:setup_completion_rate]).to eq(100.0) # 1 started, 1 completed
      expect(metrics[:template_interaction_stats][:total_interactions]).to eq(1)
      expect(metrics[:common_failure_points]).to be_a(Hash)
    end
  end

  describe 'Admin dashboard access' do
    let(:admin_user) { create(:user, :admin) }

    before do
      sign_in admin_user
      create_list(:payment_analytic, 3, :template_interaction, user: user)
    end

    it 'displays analytics dashboard' do
      get admin_payment_analytics_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Payment Analytics Dashboard')
    end

    it 'exports analytics data as CSV' do
      get admin_payment_analytics_path(format: :csv)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.body).to include('Event Type,User ID,User Tier,Timestamp,Context')
    end

    it 'exports analytics data as JSON' do
      get admin_payment_analytics_path(format: :json)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')

      json_response = JSON.parse(response.body)
      expect(json_response).to include('setup_completion_rate', 'template_interaction_stats')
    end
  end

  describe 'Privacy and data handling' do
    it 'anonymizes IP addresses' do
      PaymentAnalyticsService.new.track_event(
        'payment_setup_started',
        user: user,
        context: { ip_address: '192.168.1.100' }
      )

      analytic = PaymentAnalytic.last
      expect(analytic.ip_address).to eq('192.168.1.0')
    end

    it 'sanitizes sensitive context data' do
      PaymentAnalyticsService.new.track_event(
        'template_payment_interaction',
        user: user,
        context: {
          template_id: template.id,
          password: 'secret123',
          api_key: 'sk_test_123',
          safe_data: 'visible'
        }
      )

      analytic = PaymentAnalytic.last
      expect(analytic.context).to include('safe_data' => 'visible')
      expect(analytic.context).not_to have_key('password')
      expect(analytic.context).not_to have_key('api_key')
    end

    it 'limits context data size' do
      large_context = { data: 'x' * 2000 }

      PaymentAnalyticsService.new.track_event(
        'payment_setup_completed',
        user: user,
        context: large_context
      )

      analytic = PaymentAnalytic.last
      expect(analytic.context.to_json.length).to be <= 1000
    end
  end

  describe 'Error handling and resilience' do
    it 'continues operation when analytics fails' do
      allow(PaymentAnalytic).to receive(:create!).and_raise(StandardError.new('DB error'))

      # Main operation should still work
      expect {
        result = PaymentAnalyticsService.new.track_event(
          'payment_setup_started',
          user: user,
          context: {}
        )
        expect(result).to be_failure
      }.not_to raise_error
    end

    it 'logs analytics errors appropriately' do
      allow(PaymentAnalytic).to receive(:create!).and_raise(StandardError.new('DB error'))

      expect(Rails.logger).to receive(:error).with(/PaymentAnalyticsService error/)

      PaymentAnalyticsService.new.track_event(
        'payment_setup_started',
        user: user,
        context: {}
      )
    end
  end
end