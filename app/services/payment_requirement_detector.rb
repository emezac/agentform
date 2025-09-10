class PaymentRequirementDetector
  PAYMENT_QUESTION_TYPES = %w[payment subscription donation].freeze
  
  def self.detect_in_template(template)
    return false unless template.respond_to?(:questions_config)
    
    template.questions_config.any? { |question| payment_question?(question) }
  end
  
  def self.payment_question?(question_config)
    return false unless question_config.is_a?(Hash)
    
    question_type = question_config['question_type'] || question_config[:question_type]
    PAYMENT_QUESTION_TYPES.include?(question_type)
  end
  
  def self.required_features_for_questions(questions)
    features = Set.new
    
    questions.each do |question|
      question_features = required_features_for_question_type(question['question_type'])
      features.merge(question_features)
    end
    
    features.to_a
  end
  
  def self.required_features_for_question_type(question_type)
    case question_type
    when 'payment'
      ['stripe_payments', 'premium_subscription']
    when 'subscription'
      ['stripe_payments', 'premium_subscription', 'recurring_payments']
    when 'donation'
      ['stripe_payments', 'donation_processing']
    else
      []
    end
  end
end