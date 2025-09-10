# frozen_string_literal: true

module Forms
  # Service for handling form navigation logic including conditional flows,
  # question ordering, and multi-step form progression
  class NavigationService < ApplicationService
    attr_accessor :form_response, :current_question, :direction
    
    attr_reader :next_question, :previous_question, :navigation_context
    
    validates :form_response, presence: true
    validates :direction, inclusion: { in: %w[next previous first last] }
    
    def initialize(form_response:, current_question: nil, direction: 'next')
      @form_response = form_response
      @current_question = current_question
      @direction = direction
      @navigation_context = {}
      super()
    end
    
    def call
      return self unless valid?
      
      validate_service_inputs
      return self if failure?
      
      calculate_navigation
      build_navigation_context
      
      set_result({
        next_question: @next_question,
        previous_question: @previous_question,
        navigation_context: @navigation_context
      })
      
      self
    end
    
    # Get the first question in the form (respecting conditional logic)
    def first_question
      form_response.form.form_questions
                   .order(:position)
                   .find { |q| question_visible?(q) }
    end
    
    # Get the last answered question
    def last_answered_question
      answered_responses = form_response.question_responses
                                      .joins(:form_question)
                                      .where.not(answer_data: {})
                                      .order('form_questions.position DESC')
      
      answered_responses.first&.form_question
    end
    
    # Check if form can be completed (all required questions answered)
    def can_complete_form?
      required_questions = form_response.form.form_questions
                                       .where(required: true)
                                       .select { |q| question_visible?(q) }
      
      answered_required = form_response.question_responses
                                     .joins(:form_question)
                                     .where(form_questions: { required: true })
                                     .where.not(answer_data: {})
      
      required_questions.count == answered_required.count
    end
    
    # Get completion percentage considering conditional logic
    def completion_percentage
      visible_questions = form_response.form.form_questions
                                      .select { |q| question_visible?(q) }
      
      return 0.0 if visible_questions.empty?
      
      answered_questions = form_response.question_responses
                                       .joins(:form_question)
                                       .where.not(answer_data: {})
                                       .where(form_question: visible_questions)
      
      (answered_questions.count.to_f / visible_questions.count * 100).round(2)
    end
    
    # Get navigation breadcrumbs for multi-step forms
    def navigation_breadcrumbs
      visible_questions = form_response.form.form_questions
                                      .order(:position)
                                      .select { |q| question_visible?(q) }
      
      answered_question_ids = form_response.question_responses
                                          .where.not(answer_data: {})
                                          .pluck(:form_question_id)
      
      visible_questions.map.with_index(1) do |question, index|
        {
          position: index,
          question_id: question.id,
          title: question.title,
          status: breadcrumb_status(question, answered_question_ids),
          current: question == current_question
        }
      end
    end
    
    # Check if navigation is allowed in the given direction
    def navigation_allowed?(direction)
      case direction.to_s
      when 'next'
        @next_question.present?
      when 'previous'
        @previous_question.present?
      when 'first'
        first_question.present?
      when 'last'
        can_complete_form?
      else
        false
      end
    end
    
    # Get suggested navigation action based on form state
    def suggested_action
      return 'start' if form_response.question_responses.empty?
      return 'complete' if can_complete_form? && @next_question.nil?
      return 'continue' if @next_question.present?
      return 'review' if @next_question.nil? && !can_complete_form?
      
      'unknown'
    end
    
    private
    
    def validate_service_inputs
      if current_question && current_question.form_id != form_response.form_id
        add_error(:current_question, "does not belong to this form")
      end
      
      if direction == 'next' && current_question.nil?
        # For 'next' without current question, we'll find the appropriate starting point
        @current_question = last_answered_question || first_question
      end
    end
    
    def calculate_navigation
      case direction
      when 'next'
        calculate_next_question
      when 'previous'
        calculate_previous_question
      when 'first'
        @next_question = first_question
        @previous_question = nil
      when 'last'
        @next_question = nil
        @previous_question = last_answered_question
      end
    end
    
    def calculate_next_question
      if current_question.nil?
        @next_question = first_question
        @previous_question = nil
        return
      end
      
      # Find next visible question after current position
      next_questions = form_response.form.form_questions
                                   .where('position > ?', current_question.position)
                                   .order(:position)
      
      @next_question = next_questions.find { |q| question_visible?(q) }
      @previous_question = current_question
    end
    
    def calculate_previous_question
      if current_question.nil?
        @previous_question = last_answered_question
        @next_question = nil
        return
      end
      
      # Find previous visible question before current position
      previous_questions = form_response.form.form_questions
                                       .where('position < ?', current_question.position)
                                       .order(position: :desc)
      
      @previous_question = previous_questions.find { |q| question_visible?(q) }
      @next_question = current_question
    end
    
    def question_visible?(question)
      return true unless question.has_conditional_logic?
      
      question.should_show_for_response?(form_response)
    end
    
    def build_navigation_context
      @navigation_context = {
        current_position: current_question&.position,
        total_questions: form_response.form.form_questions.count,
        visible_questions_count: visible_questions_count,
        completion_percentage: completion_percentage,
        can_complete: can_complete_form?,
        suggested_action: suggested_action,
        navigation_allowed: {
          next: navigation_allowed?('next'),
          previous: navigation_allowed?('previous'),
          first: navigation_allowed?('first'),
          complete: navigation_allowed?('last')
        },
        breadcrumbs: navigation_breadcrumbs,
        form_flow_type: determine_flow_type
      }
    end
    
    def visible_questions_count
      form_response.form.form_questions.count { |q| question_visible?(q) }
    end
    
    def breadcrumb_status(question, answered_question_ids)
      if answered_question_ids.include?(question.id)
        'completed'
      elsif question == current_question
        'current'
      elsif question == @next_question
        'next'
      else
        'pending'
      end
    end
    
    def determine_flow_type
      form = form_response.form
      
      # Check form settings for flow type preference
      flow_type = form.form_settings&.dig('flow_type')
      return flow_type if flow_type.present?
      
      # Auto-detect based on form characteristics
      question_count = form.form_questions.count
      has_conditional_logic = form.form_questions.any?(&:has_conditional_logic?)
      
      if question_count <= 3
        'single_page'
      elsif has_conditional_logic
        'adaptive'
      elsif question_count <= 10
        'stepped'
      else
        'paginated'
      end
    end
    
    # Helper method to find question by various identifiers
    def find_question(identifier)
      case identifier
      when FormQuestion
        identifier
      when String
        form_response.form.form_questions.find_by(id: identifier) ||
          form_response.form.form_questions.find_by(reference_id: identifier)
      when Integer
        form_response.form.form_questions.find_by(id: identifier)
      else
        nil
      end
    end
    
    # Calculate optimal question order considering dependencies
    def calculate_question_dependencies
      dependencies = {}
      
      form_response.form.form_questions.each do |question|
        next unless question.has_conditional_logic?
        
        dependent_questions = question.conditional_rules.map { |rule| rule['question_id'] }
        dependencies[question.id] = dependent_questions
      end
      
      dependencies
    end
    
    # Validate navigation path for circular dependencies
    def validate_navigation_path
      dependencies = calculate_question_dependencies
      
      # Simple cycle detection - could be enhanced with more sophisticated algorithms
      dependencies.each do |question_id, deps|
        if deps.include?(question_id)
          add_error(:navigation, "Circular dependency detected for question #{question_id}")
        end
      end
    end
    
    # Get navigation statistics for analytics
    def navigation_statistics
      {
        total_steps: visible_questions_count,
        completed_steps: form_response.question_responses.where.not(answer_data: {}).count,
        skipped_questions: calculate_skipped_questions,
        backtrack_count: calculate_backtrack_count,
        average_time_per_question: calculate_average_time_per_question
      }
    end
    
    def calculate_skipped_questions
      # Questions that were visible but not answered due to navigation
      # This would require tracking navigation history
      0 # Placeholder - implement based on navigation tracking needs
    end
    
    def calculate_backtrack_count
      # Count how many times user went back
      # This would require tracking navigation history
      0 # Placeholder - implement based on navigation tracking needs
    end
    
    def calculate_average_time_per_question
      responses_with_time = form_response.question_responses
                                        .where.not(time_spent_seconds: [nil, 0])
      
      return 0 if responses_with_time.empty?
      
      responses_with_time.average(:time_spent_seconds).to_f.round(2)
    end
  end
end