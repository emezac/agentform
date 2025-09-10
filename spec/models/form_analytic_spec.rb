# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormAnalytic, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"

  # Associations
  describe "associations" do
    it { should belong_to(:form) }
  end

  # Validations
  describe "validations" do
    it { should validate_presence_of(:date) }
    it { should validate_presence_of(:period_type) }
  end

  # Scopes
  describe "scopes" do
    let(:form) { create(:form) }
    let!(:daily_analytic) { create(:form_analytic, form: form, period_type: 'daily', date: Date.current) }
    let!(:weekly_analytic) { create(:form_analytic, form: form, period_type: 'weekly', date: Date.current) }
    let!(:monthly_analytic) { create(:form_analytic, form: form, period_type: 'monthly', date: Date.current) }
    let!(:old_analytic) { create(:form_analytic, form: form, date: 1.week.ago) }

    describe ".for_period" do
      it "returns analytics within date range" do
        start_date = 3.days.ago
        end_date = Date.current
        
        results = FormAnalytic.for_period(start_date, end_date)
        
        expect(results).to include(daily_analytic, weekly_analytic, monthly_analytic)
        expect(results).not_to include(old_analytic)
      end
    end

    describe ".by_period_type" do
      it "filters by period type" do
        expect(FormAnalytic.by_period_type('daily')).to include(daily_analytic)
        expect(FormAnalytic.by_period_type('daily')).not_to include(weekly_analytic)
      end
    end

    describe ".recent" do
      it "orders by date descending" do
        results = FormAnalytic.recent
        expect(results.first.date).to be >= results.last.date
      end
    end

    describe ".daily" do
      it "returns only daily analytics" do
        expect(FormAnalytic.daily).to include(daily_analytic)
        expect(FormAnalytic.daily).not_to include(weekly_analytic, monthly_analytic)
      end
    end

    describe ".weekly" do
      it "returns only weekly analytics" do
        expect(FormAnalytic.weekly).to include(weekly_analytic)
        expect(FormAnalytic.weekly).not_to include(daily_analytic, monthly_analytic)
      end
    end

    describe ".monthly" do
      it "returns only monthly analytics" do
        expect(FormAnalytic.monthly).to include(monthly_analytic)
        expect(FormAnalytic.monthly).not_to include(daily_analytic, weekly_analytic)
      end
    end
  end

  # Class Methods
  describe ".aggregate_for_period" do
    let(:form) { create(:form) }
    let!(:analytic1) { create(:form_analytic, form: form, date: Date.current, views_count: 100, started_responses_count: 80, completed_responses_count: 60, abandoned_responses_count: 20, avg_completion_time: 120) }
    let!(:analytic2) { create(:form_analytic, form: form, date: Date.yesterday, views_count: 150, started_responses_count: 120, completed_responses_count: 90, abandoned_responses_count: 30, avg_completion_time: 180) }

    it "aggregates metrics for the specified period" do
      start_date = Date.yesterday
      end_date = Date.current
      
      result = FormAnalytic.aggregate_for_period(form, start_date, end_date)
      
      expect(result[:total_views]).to eq(250)
      expect(result[:total_starts]).to eq(200)
      expect(result[:total_completions]).to eq(150)
      expect(result[:total_abandons]).to eq(50)
      expect(result[:avg_completion_time]).to eq(150.0)
    end

    it "returns zero values when no analytics exist" do
      other_form = create(:form)
      result = FormAnalytic.aggregate_for_period(other_form, Date.current, Date.current)
      
      expect(result[:total_views]).to eq(0)
      expect(result[:total_starts]).to eq(0)
      expect(result[:total_completions]).to eq(0)
      expect(result[:total_abandons]).to eq(0)
      expect(result[:avg_completion_time]).to eq(0.0)
    end
  end

  describe ".create_daily_snapshot" do
    let(:form) { create(:form) }
    let!(:completed_response) { create(:form_response, form: form, status: :completed, created_at: Date.current.beginning_of_day + 2.hours, completed_at: Date.current.beginning_of_day + 2.hours + 5.minutes) }
    let!(:abandoned_response) { create(:form_response, form: form, status: :abandoned, created_at: Date.current.beginning_of_day + 4.hours) }

    before do
      # Mock form views count
      allow(form).to receive(:views_count).and_return(50)
    end

    it "creates a daily snapshot with calculated metrics" do
      expect {
        FormAnalytic.create_daily_snapshot(form, Date.current)
      }.to change { FormAnalytic.count }.by(1)

      analytic = FormAnalytic.last
      expect(analytic.form).to eq(form)
      expect(analytic.date).to eq(Date.current)
      expect(analytic.period_type).to eq('daily')
      expect(analytic.views_count).to eq(50)
      expect(analytic.started_responses_count).to eq(2)
      expect(analytic.completed_responses_count).to eq(1)
      expect(analytic.abandoned_responses_count).to eq(1)
      expect(analytic.avg_completion_time).to be > 0
    end

    it "updates existing snapshot if one exists for the same date" do
      existing_analytic = create(:form_analytic, form: form, date: Date.current, period_type: 'daily')
      
      expect {
        FormAnalytic.create_daily_snapshot(form, Date.current)
      }.not_to change { FormAnalytic.count }

      existing_analytic.reload
      expect(existing_analytic.started_responses_count).to eq(2)
    end
  end

  # Instance Methods
  describe "#calculated_completion_rate" do
    it "calculates completion rate correctly" do
      analytic = build(:form_analytic, started_responses_count: 100, completed_responses_count: 75)
      expect(analytic.calculated_completion_rate).to eq(75.0)
    end

    it "returns 0 when no responses started" do
      analytic = build(:form_analytic, started_responses_count: 0, completed_responses_count: 0)
      expect(analytic.calculated_completion_rate).to eq(0.0)
    end
  end

  describe "#calculated_abandonment_rate" do
    it "calculates abandonment rate correctly" do
      analytic = build(:form_analytic, started_responses_count: 100, abandoned_responses_count: 25)
      expect(analytic.calculated_abandonment_rate).to eq(25.0)
    end

    it "returns 0 when no responses started" do
      analytic = build(:form_analytic, started_responses_count: 0, abandoned_responses_count: 0)
      expect(analytic.calculated_abandonment_rate).to eq(0.0)
    end
  end

  describe "#performance_score" do
    it "calculates performance score for high-performing form" do
      analytic = build(:form_analytic, :high_performance)
      score = analytic.performance_score
      
      expect(score).to be > 80.0
      expect(score).to be <= 100.0
    end

    it "calculates performance score for low-performing form" do
      analytic = build(:form_analytic, :low_performance)
      score = analytic.performance_score
      
      expect(score).to be < 50.0
      expect(score).to be >= 0.0
    end

    it "handles zero completion time gracefully" do
      analytic = build(:form_analytic, avg_completion_time: 0)
      expect { analytic.performance_score }.not_to raise_error
    end
  end

  describe "#trend_direction" do
    let(:form) { create(:form) }

    it "returns 'improving' when performance increases significantly" do
      create(:form_analytic, form: form, date: Date.yesterday, views_count: 100, started_responses_count: 50, completed_responses_count: 25)
      current_analytic = create(:form_analytic, form: form, date: Date.current, views_count: 100, started_responses_count: 80, completed_responses_count: 70)
      
      expect(current_analytic.trend_direction).to eq('improving')
    end

    it "returns 'declining' when performance decreases significantly" do
      create(:form_analytic, form: form, date: Date.yesterday, views_count: 100, started_responses_count: 80, completed_responses_count: 70)
      current_analytic = create(:form_analytic, form: form, date: Date.current, views_count: 100, started_responses_count: 50, completed_responses_count: 25)
      
      expect(current_analytic.trend_direction).to eq('declining')
    end

    it "returns 'stable' when performance changes are minimal" do
      create(:form_analytic, form: form, date: Date.yesterday, views_count: 100, started_responses_count: 75, completed_responses_count: 60)
      current_analytic = create(:form_analytic, form: form, date: Date.current, views_count: 100, started_responses_count: 77, completed_responses_count: 62)
      
      expect(current_analytic.trend_direction).to eq('stable')
    end

    it "returns 'neutral' when no previous analytic exists" do
      analytic = create(:form_analytic, form: form)
      expect(analytic.trend_direction).to eq('neutral')
    end
  end

  describe "#conversion_funnel" do
    it "returns conversion funnel data" do
      analytic = build(:form_analytic, views_count: 1000, started_responses_count: 800, completed_responses_count: 600, abandoned_responses_count: 200)
      funnel = analytic.conversion_funnel
      
      expect(funnel[:views]).to eq(1000)
      expect(funnel[:starts]).to eq(800)
      expect(funnel[:completions]).to eq(600)
      expect(funnel[:abandons]).to eq(200)
      expect(funnel[:view_to_start_rate]).to eq(80.0)
      expect(funnel[:start_to_completion_rate]).to eq(75.0)
      expect(funnel[:abandonment_rate]).to eq(25.0)
    end

    it "handles zero views gracefully" do
      analytic = build(:form_analytic, :with_zero_views)
      funnel = analytic.conversion_funnel
      
      expect(funnel[:view_to_start_rate]).to eq(0.0)
    end
  end

  describe "#time_metrics" do
    it "returns formatted time metrics" do
      analytic = build(:form_analytic, avg_completion_time: 125, avg_time_per_question: 2500)
      metrics = analytic.time_metrics
      
      expect(metrics[:avg_completion_time_seconds]).to eq(125)
      expect(metrics[:avg_completion_time_formatted]).to eq("2m 5s")
      expect(metrics[:avg_response_time_ms]).to eq(2500)
      expect(metrics[:avg_response_time_formatted]).to eq("2500ms")
    end
  end

  describe "#summary" do
    it "returns comprehensive summary data" do
      analytic = create(:form_analytic)
      summary = analytic.summary
      
      expect(summary).to include(:date, :period_type, :performance_score, :trend, :completion_rate, :abandonment_rate, :funnel, :timing)
      expect(summary[:funnel]).to be_a(Hash)
      expect(summary[:timing]).to be_a(Hash)
    end
  end

  # Private Methods (tested through public interface)
  describe "duration formatting" do
    it "formats short durations correctly" do
      analytic = build(:form_analytic, avg_completion_time: 45)
      metrics = analytic.time_metrics
      expect(metrics[:avg_completion_time_formatted]).to eq("45s")
    end

    it "formats minute durations correctly" do
      analytic = build(:form_analytic, avg_completion_time: 125)
      metrics = analytic.time_metrics
      expect(metrics[:avg_completion_time_formatted]).to eq("2m 5s")
    end

    it "formats hour durations correctly" do
      analytic = build(:form_analytic, avg_completion_time: 3725)
      metrics = analytic.time_metrics
      expect(metrics[:avg_completion_time_formatted]).to eq("1h 2m")
    end

    it "handles zero duration" do
      analytic = build(:form_analytic, avg_completion_time: 0)
      metrics = analytic.time_metrics
      expect(metrics[:avg_completion_time_formatted]).to eq("0s")
    end

    it "handles nil duration" do
      analytic = build(:form_analytic, avg_completion_time: nil)
      metrics = analytic.time_metrics
      expect(metrics[:avg_completion_time_formatted]).to eq("0s")
    end
  end
end