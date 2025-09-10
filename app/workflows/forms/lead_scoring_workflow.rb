# frozen_string_literal: true

class LeadScoringCalculator
  class << self
    def calculate_technical_score(response_data)
      answers = response_data[:answers]
      technical_score = 0
      
      # Technical maturity indicators
      tech_maturity = answers['technical_maturity_score']&.to_i || 5
      ai_experience = answers['ai_experience']&.downcase || 'none'
      current_infrastructure = answers['current_infrastructure']&.downcase || 'basic'
      
      # Scoring based on technical readiness
      technical_score += (tech_maturity * 2)  # 0-20 points
      
      case ai_experience
      when 'experto', 'advanced'
        technical_score += 20
      when 'intermedio', 'intermediate'
        technical_score += 15
      when 'básico', 'basic'
        technical_score += 10
      else
        technical_score += 5
      end
      
      case current_infrastructure
      when 'cloud-native', 'modern'
        technical_score += 15
      when 'hybrid', 'moderate'
        technical_score += 10
      when 'legacy', 'basic'
        technical_score += 5
      else
        technical_score += 8
      end
      
      [[technical_score, 0].max, 50].min
    end

    def calculate_business_impact_score(analysis, response_data)
      answers = response_data[:answers]
      impact_score = 0
      
      # Business impact indicators
      use_case_clarity = answers['ai_use_cases']&.length || 0
      strategic_alignment = answers['strategic_alignment']&.downcase || 'neutral'
      pain_points = answers['main_challenge']&.length || 0
      
      # Scoring based on business impact potential
      impact_score += [use_case_clarity * 2, 20].min  # 0-20 points
      impact_score += [pain_points / 10, 15].min      # 0-15 points
      
      case strategic_alignment
      when 'high', 'critical'
        impact_score += 20
      when 'medium', 'important'
        impact_score += 15
      when 'low', 'nice_to_have'
        impact_score += 10
      else
        impact_score += 12
      end
      
      # Bonus for specific business impact indicators
      business_impact_keywords = ['revenue', 'cost', 'efficiency', 'competitive', 'growth']
      challenge_text = answers['main_challenge']&.downcase || ''
      business_impact_keywords.each { |kw| impact_score += 3 if challenge_text.include?(kw) }
      
      [[impact_score, 0].max, 55].min
    end

    def calculate_financial_score(response_data)
      answers = response_data[:answers]
      financial_score = 0
      
      # Financial capacity indicators
      budget_amount = extract_budget_numeric(answers['budget_amount'])
      company_size = response_data[:enriched_data]&.[](:company_size) || 0
      
      # Budget-based scoring
      if budget_amount
        case budget_amount
        when 100000..Float::INFINITY
          financial_score += 25
        when 50000..99999
          financial_score += 20
        when 20000..49999
          financial_score += 15
        when 5000..19999
          financial_score += 10
        else
          financial_score += 5
        end
      end
      
      # Company size-based scoring
      case company_size
      when 1000..Float::INFINITY
        financial_score += 20
      when 100..999
        financial_score += 15
      when 50..99
        financial_score += 10
      when 10..49
        financial_score += 8
      else
        financial_score += 5
      end
      
      [[financial_score, 0].max, 45].min
    end

    def calculate_urgency_score(analysis, response_data)
      answers = response_data[:answers]
      urgency_score = 0
      
      # Timeline-based urgency
      timeline = answers['timeline']&.downcase || 'long_term'
      case timeline
      when 'immediately', '1-3 meses'
        urgency_score += 25
      when '3-6 meses', 'short_term'
        urgency_score += 20
      when '6-12 meses', 'medium_term'
        urgency_score += 15
      when '12+ meses', 'long_term'
        urgency_score += 10
      else
        urgency_score += 12
      end
      
      # Sentiment-based urgency
      sentiment_score = analysis.dig('sentiment_analysis', 'sentiment_score') || 0
      urgency_score += 15 if sentiment_score < -0.3  # Negative sentiment = urgency
      
      # Keyword-based urgency
      urgent_keywords = ['urgente', 'crisis', 'competencia', 'perdiendo', 'inmediato']
      challenge_text = answers['main_challenge']&.downcase || ''
      urgent_keywords.each { |kw| urgency_score += 5 if challenge_text.include?(kw) }
      
      [[urgency_score, 0].max, 40].min
    end

    def calculate_authority_score(response_data)
      answers = response_data[:answers]
      authority_score = 0
      
      # Role-based authority
      role = answers['role']&.downcase || 'unknown'
      case role
      when 'ceo', 'cto', 'founder', 'director', 'vp'
        authority_score += 25
      when 'manager', 'head', 'lead'
        authority_score += 20
      when 'senior', 'specialist'
        authority_score += 15
      else
        authority_score += 10
      end
      
      # Decision authority
      decision_authority = answers['decision_authority']&.downcase || 'unknown'
      case decision_authority
      when 'tengo autoridad completa', 'complete authority'
        authority_score += 20
      when 'tengo influencia significativa', 'significant influence'
        authority_score += 15
      when 'tengo influencia limitada', 'limited influence'
        authority_score += 10
      else
        authority_score += 5
      end
      
      [[authority_score, 0].max, 45].min
    end

    def calculate_complexity_score(response_data)
      answers = response_data[:answers]
      complexity_score = 0
      
      # Implementation complexity indicators
      integration_needs = answers['integration_needs']&.downcase || 'simple'
      compliance_needs = answers['compliance_needs']&.downcase || 'none'
      change_management = answers['change_management']&.downcase || 'minimal'
      
      # Complexity scoring (lower complexity = higher score)
      case integration_needs
      when 'simple', 'standalone'
        complexity_score += 20
      when 'moderate', 'some_integration'
        complexity_score += 15
      when 'complex', 'heavy_integration'
        complexity_score += 10
      else
        complexity_score += 12
      end
      
      case compliance_needs
      when 'none'
        complexity_score += 15
      when 'basic', 'standard'
        complexity_score += 10
      when 'strict', 'regulated'
        complexity_score += 5
      else
        complexity_score += 10
      end
      
      case change_management
      when 'minimal'
        complexity_score += 15
      when 'moderate'
        complexity_score += 10
      when 'significant'
        complexity_score += 5
      else
        complexity_score += 10
      end
      
      [[complexity_score, 0].max, 50].min
    end

    def get_industry_weights(industry)
      return default_weights unless industry
      
      industry_weights = {
        'technology' => {
          technical_readiness: 1.2,
          business_impact: 1.1,
          financial_capacity: 1.0,
          urgency_factor: 1.0,
          decision_authority: 1.0,
          implementation_complexity: 0.9
        },
        'healthcare' => {
          technical_readiness: 0.8,
          business_impact: 1.3,
          financial_capacity: 1.1,
          urgency_factor: 1.2,
          decision_authority: 0.9,
          implementation_complexity: 1.3
        },
        'financial_services' => {
          technical_readiness: 1.1,
          business_impact: 1.2,
          financial_capacity: 1.2,
          urgency_factor: 1.1,
          decision_authority: 1.1,
          implementation_complexity: 1.2
        },
        'manufacturing' => {
          technical_readiness: 0.9,
          business_impact: 1.1,
          financial_capacity: 1.0,
          urgency_factor: 0.9,
          decision_authority: 1.0,
          implementation_complexity: 1.1
        },
        'retail' => {
          technical_readiness: 1.0,
          business_impact: 1.2,
          financial_capacity: 0.9,
          urgency_factor: 1.1,
          decision_authority: 1.0,
          implementation_complexity: 1.0
        }
      }
      
      industry_weights[industry.downcase] || industry_weights[industry] || default_weights
    end

    private

    def default_weights
      {
        technical_readiness: 1.0,
        business_impact: 1.0,
        financial_capacity: 1.0,
        urgency_factor: 1.0,
        decision_authority: 1.0,
        implementation_complexity: 1.0
      }
    end

    def extract_budget_numeric(budget_string)
      return nil unless budget_string
      
      # Extract numeric value from budget string
      budget_string.scan(/[\d,]+/).first&.gsub(',', '')&.to_i
    end
  end
end