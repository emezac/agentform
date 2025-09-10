# frozen_string_literal: true

module Ai
  class DatabaseOptimizationService
    def self.create_form_with_questions_optimized(user, form_data, questions_data)
      ActiveRecord::Base.transaction do
        # Create the form
        form = user.forms.create!(form_data)
        
        # Create questions in batch
        questions = questions_data.map.with_index do |question_data, index|
          form.form_questions.create!(
            title: question_data['title'],
            question_type: question_data['type'],
            required: question_data['required'] || false,
            position: index + 1,
            question_config: question_data['config'] || {}
          )
        end
        
        {
          form: form,
          questions: questions
        }
      end
    end
  end
end