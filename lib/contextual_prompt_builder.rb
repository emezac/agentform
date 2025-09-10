# frozen_string_literal: true

class ContextualPromptBuilder
  def initialize(context, template_config)
    @context = context
    @template_config = template_config
  end

  def build_system_prompt
    base_prompt = @template_config['system'] || "You are a helpful AI assistant for form interactions."
    interpolate_variables(base_prompt)
  end

  def build_user_prompt
    base_prompt = @template_config['user_prompt'] || "Generate a relevant follow-up question."
    
    # Add context variables explicitly if configured
    context_vars = @template_config['context_variables'] || []
    context_section = build_context_section(context_vars)
    
    full_prompt = context_section.present? ? "#{context_section}\n\n#{base_prompt}" : base_prompt
    interpolate_variables(full_prompt)
  end

  def build_context_section(context_variables)
    return "" if context_variables.empty?
    
    context_lines = context_variables.map do |var_definition|
      interpolate_variables(var_definition)
    end.compact.reject(&:blank?)
    
    return "" if context_lines.empty?
    
    "Context:\n" + context_lines.map { |line| "- #{line}" }.join("\n")
  end

  def build_full_prompt_with_examples
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt
    examples = build_examples_section
    
    full_prompt = [
      system_prompt,
      examples,
      user_prompt
    ].compact.reject(&:blank?).join("\n\n")
    
    full_prompt
  end

  private

  def interpolate_variables(text)
    return text unless text.is_a?(String)
    
    # Replace context variables using dot notation
    text.gsub(/\{\{([^}]+)\}\}/) do |match|
      variable_path = $1.strip
      get_context_value(variable_path) || match
    end
  end

  def get_context_value(path)
    parts = path.split('.')
    value = parts.reduce(@context) { |obj, part| obj&.dig(part) || obj&.[](part) }
    
    # Format values based on their type
    case value
    when Float
      value.round(2)
    when Hash, Array
      value.inspect
    when Time, DateTime, Date
      value.strftime('%Y-%m-%d %H:%M:%S')
    when NilClass
      nil
    else
      value.to_s
    end
  rescue StandardError => e
    Rails.logger.error "Error getting context value for path '#{path}': #{e.message}"
    nil
  end

  def build_examples_section
    examples = @template_config['examples'] || []
    return "" if examples.empty?
    
    examples_text = examples.map do |example|
      if example.is_a?(Hash)
        "Input: #{example['input']}\nOutput: #{example['output']}"
      else
        example.to_s
      end
    end
    
    "Examples:\n" + examples_text.join("\n\n")
  end

  # Advanced context extraction methods
  
  def extract_form_context
    {
      name: @context.dig(:form, :name),
      category: @context.dig(:form, :category),
      description: @context.dig(:form, :description),
      total_questions: @context.dig(:form, :total_questions),
      completion_rate: calculate_form_completion_rate
    }
  end

  def extract_response_context
    {
      completion_percentage: @context.dig(:response, :completion_percentage),
      duration_minutes: @context.dig(:response, :duration_minutes),
      quality_score: @context.dig(:response, :quality_score),
      pattern: @context.dig(:user, :response_pattern)
    }
  end

  def extract_user_insights
    {
      engagement_level: calculate_engagement_level,
      sentiment_trend: calculate_sentiment_trend,
      response_consistency: calculate_response_consistency
    }
  end

  def calculate_form_completion_rate
    return 0.0 unless @context.dig(:response, :completion_percentage)
    @context.dig(:response, :completion_percentage)
  end

  def calculate_engagement_level
    score = @context.dig(:user, :engagement_score) || 0.0
    
    case score
    when 0..30 then 'low'
    when 30..70 then 'medium'
    else 'high'
    end
  end

  def calculate_sentiment_trend
    sentiment = @context.dig(:answer, :sentiment_score) || 0.0
    
    case sentiment
    when -1.0..-0.3 then 'negative'
    when -0.3..0.3 then 'neutral'
    else 'positive'
    end
  end

  def calculate_response_consistency
    pattern = @context.dig(:user, :response_pattern)
    
    case pattern
    when 'consistent' then 'reliable'
    when 'rushed' then 'hasty'
    when 'hesitant' then 'uncertain'
    else 'unknown'
    end
  end

  # Specialized builders for different question types
  
  def build_budget_optimization_prompt
    budget = @context.dig(:answer, :numeric_value)
    return nil unless budget > 0
    
    {
      system: "You are a budget optimization specialist helping users maximize their AI investment.",
      user_prompt: "The user has a budget of $#{budget} for AI projects. Generate a strategic follow-up question that helps them prioritize their investment and understand the best approach within their budget constraints.",
      context_variables: [
        "Budget: $#{budget}",
        "Form category: #{@context.dig(:form, :category)}",
        "Completion progress: #{@context.dig(:response, :completion_percentage)}%"
      ]
    }
  end

  def build_sentiment_analysis_prompt
    sentiment = @context.dig(:answer, :sentiment_score)
    text = @context.dig(:answer, :text_content)
    
    if sentiment < -0.3
      {
        system: "You are an empathetic customer success specialist focused on understanding user pain points.",
        user_prompt: "The user expressed negative sentiment (score: #{sentiment}). Generate a caring, supportive follow-up question that helps them express their concerns and shows genuine interest in resolving their issues.",
        context_variables: [
          "Sentiment score: #{sentiment}",
          "Response content: #{text.truncate(100)}",
          "Engagement level: #{calculate_engagement_level}"
        ]
      }
    elsif sentiment > 0.3
      {
        system: "You are an enthusiastic consultant helping users build on their positive experience.",
        user_prompt: "The user expressed positive sentiment (score: #{sentiment}). Generate an engaging follow-up question that explores their excitement and helps them maximize their positive experience.",
        context_variables: [
          "Sentiment score: #{sentiment}",
          "Response content: #{text.truncate(100)}",
          "Engagement level: #{calculate_engagement_level}"
        ]
      }
    else
      {
        system: "You are a curious consultant seeking to understand user needs better.",
        user_prompt: "The user provided neutral feedback. Generate an exploratory follow-up question that helps uncover deeper insights about their needs and expectations.",
        context_variables: [
          "Sentiment score: #{sentiment}",
          "Response content: #{text.truncate(100)}",
          "Engagement level: #{calculate_engagement_level}"
        ]
      }
    end
  end

  def build_lead_qualification_prompt
    {
      system: "You are a lead qualification expert using the #{@context.dig(:form, :qualification_framework) || 'BANT'} framework.",
      user_prompt: "Based on the current response context, generate a targeted qualifying question that helps assess this lead's potential using the appropriate qualification framework.",
      context_variables: [
        "Qualification framework: #{@context.dig(:form, :qualification_framework) || 'BANT'}",
        "Current question: #{@context.dig(:question, :title)}",
        "Response: #{@context.dig(:answer, :text_content).truncate(100)}",
        "Completion: #{@context.dig(:response, :completion_percentage)}%"
      ]
    }
  end

  def validate_prompt
    errors = []
    
    # Check for required fields
    if @template_config['system'].blank? && @template_config['user_prompt'].blank?
      errors << "At least system or user prompt must be provided"
    end
    
    # Check for valid JSON structure in examples
    if @template_config['examples']
      unless @template_config['examples'].is_a?(Array)
        errors << "Examples must be an array"
      end
    end
    
    # Check for valid context variables
    if @template_config['context_variables']
      unless @template_config['context_variables'].is_a?(Array)
        errors << "Context variables must be an array"
      end
    end
    
    # Check for placeholder validity
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt
    
    if system_prompt.include?('{{') || user_prompt.include?('{{')
      errors << "Some placeholders could not be resolved"
    end
    
    {
      valid: errors.empty?,
      errors: errors,
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      estimated_tokens: estimate_tokens(system_prompt + user_prompt)
    }
  end

  def estimate_tokens(text)
    # Rough estimation: 1 token ≈ 4 characters
    (text.length / 4.0).ceil
  end
end