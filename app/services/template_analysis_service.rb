# frozen_string_literal: true

class TemplateAnalysisService < ApplicationService
  include PaymentAnalyticsTrackable
  
  attribute :template, default: nil
  attribute :user, default: nil

  def call
    validate_service_inputs
    return self if failure?

    analyze_template_requirements
    track_template_interaction if user.present?
    self
  end
  
  def analyze_payment_requirements(template, user: nil)
    @template = template
    @user = user
    validate_service_inputs
    return {} if failure?

    analyze_template_requirements
    track_template_interaction if user.present?
    result
  end

  private

  def validate_service_inputs
    validate_required_attributes(:template)
    
    unless template.is_a?(FormTemplate)
      add_error(:template, 'must be a FormTemplate instance')
    end
  end

  def analyze_template_requirements
    payment_questions = detect_payment_questions
    required_features = determine_required_features(payment_questions)
    setup_complexity = calculate_setup_complexity(required_features)

    set_result({
      has_payment_questions: payment_questions.any?,
      payment_questions: payment_questions,
      required_features: required_features,
      setup_complexity: setup_complexity,
      template_id: template.id,
      template_name: template.name
    })

    set_context(:analysis_completed_at, Time.current)
    set_context(:questions_analyzed, template.questions_config.length)
  end

  def detect_payment_questions
    return [] unless template.questions_config.present?

    payment_questions = []
    
    template.questions_config.each_with_index do |question_config, index|
      if PaymentRequirementDetector.payment_question?(question_config)
        payment_questions << {
          position: index + 1,
          title: question_config['title'],
          question_type: question_config['question_type'],
          required: question_config['required'] || false,
          configuration: question_config['configuration'] || {}
        }
      end
    end

    payment_questions
  end

  def determine_required_features(payment_questions)
    return [] if payment_questions.empty?

    features = Set.new

    payment_questions.each do |question|
      question_features = PaymentRequirementDetector.required_features_for_question_type(
        question[:question_type]
      )
      features.merge(question_features)
    end

    features.to_a
  end

  def calculate_setup_complexity(required_features)
    return 'simple' if required_features.empty?

    complexity_score = 0
    
    # Base complexity for having payment features
    complexity_score += 1

    # Add complexity based on specific features
    feature_complexity = {
      'stripe_payments' => 1,
      'premium_subscription' => 1,
      'webhook_configuration' => 1,
      'tax_calculation' => 1,
      'subscription_management' => 2
    }

    required_features.each do |feature|
      complexity_score += feature_complexity[feature] || 1
    end

    case complexity_score
    when 0..2
      'simple'
    when 3..5
      'moderate'
    when 6..8
      'complex'
    else
      'very_complex'
    end
  end

  def track_template_interaction
    return unless template&.has_payment_questions?

    track_payment_event(
      'template_payment_interaction',
      user: user,
      context: {
        template_id: template.id,
        template_name: template.name,
        payment_questions_count: result[:payment_questions]&.length || 0,
        required_features: result[:required_features] || [],
        setup_complexity: result[:setup_complexity]
      }
    )
  end
end