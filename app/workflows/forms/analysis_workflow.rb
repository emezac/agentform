# frozen_string_literal: true

module Forms
  class AnalysisWorkflow < ApplicationWorkflow
    workflow do
      timeout 120
      
      # Step 1: Gather form data
      task :collect_form_data do
        input :form_id
        description "Collect all form responses and questions for analysis"
        
        process do |form_id|
          Rails.logger.info "Collecting form data for analysis: form_id=#{form_id}"
          
          # Validate required inputs
          validate_required_inputs(context, :form_id)
          
          # Execute data collection safely
          result = safe_db_operation do
            # Load form with associations
            form = Form.includes(
              :form_questions, 
              :form_responses, 
              :form_analytics,
              form_responses: :question_responses
            ).find(form_id)
            
            # Get form responses with completed status
            completed_responses = form.form_responses.completed
            total_responses = form.form_responses.count
            
            # Calculate basic metrics
            completion_rate = total_responses > 0 ? (completed_responses.count.to_f / total_responses * 100).round(2) : 0
            
            # Get question-level data
            questions_data = form.form_questions.order(:position).map do |question|
              question_responses = question.question_responses.joins(:form_response)
                                         .where(form_responses: { status: 'completed' })
              
              {
                question_id: question.id,
                title: question.title,
                question_type: question.question_type,
                position: question.position,
                required: question.required?,
                ai_enhanced: question.ai_enhanced?,
                responses_count: question_responses.count,
                completion_rate: total_responses > 0 ? (question_responses.count.to_f / total_responses * 100).round(2) : 0,
                avg_response_time: question_responses.average(:response_time_ms)&.to_f || 0,
                responses_data: question_responses.limit(100).pluck(:answer_data, :response_time_ms, :ai_analysis_results)
              }
            end
            
            # Get time-based analytics
            analytics_data = form.form_analytics.for_period(30.days.ago, Date.current)
                                .group(:date)
                                .sum(:completions_count, :views_count, :abandons_count)
            
            # Prepare comprehensive data structure
            {
              form: form,
              total_responses: total_responses,
              completed_responses_count: completed_responses.count,
              completion_rate: completion_rate,
              questions_data: questions_data,
              analytics_data: analytics_data,
              form_settings: form.form_settings,
              ai_configuration: form.ai_configuration,
              created_at: form.created_at,
              last_response_at: form.last_response_at
            }
          end
          
          # Handle database operation result
          if result[:error]
            Rails.logger.error "Failed to collect form data: #{result[:message]}"
            return format_error_result("Failed to collect form data", result[:type], result)
          end
          
          # Check if form has sufficient data for analysis
          if result[:total_responses] < 5
            Rails.logger.info "Insufficient responses for meaningful analysis: #{result[:total_responses]} responses"
            return format_success_result({
              insufficient_data: true,
              total_responses: result[:total_responses],
              minimum_required: 5,
              message: "Need at least 5 responses for meaningful analysis"
            })
          end
          
          Rails.logger.info "Successfully collected data for #{result[:total_responses]} responses across #{result[:questions_data].length} questions"
          
          format_success_result({
            form_data: result,
            has_sufficient_data: true,
            analysis_ready: true
          })
        end
      end
      
      # Step 2: Performance analysis
      llm :analyze_form_performance do
        input :collect_form_data
        run_if { |ctx| 
          form_data_result = ctx.get(:collect_form_data)
          form_data_result&.dig(:has_sufficient_data) && 
          form_data_result&.dig(:form_data, :total_responses) >= 10 
        }
        
        model "gpt-4o"
        temperature 0.2
        max_tokens 1000
        response_format :json
        
        system_prompt "You are an expert in form optimization and user experience analysis with deep knowledge of conversion optimization, user psychology, and data analysis."
        
        prompt do |context|
          form_data_result = context.get(:collect_form_data)
          form_data = form_data_result[:form_data]
          
          format_performance_analysis_prompt(form_data)
        end
      end
      
      # Step 3: Question-level analysis
      task :analyze_question_performance do
        input :collect_form_data
        run_if { |ctx| 
          form_data_result = ctx.get(:collect_form_data)
          form_data_result&.dig(:has_sufficient_data) && 
          form_data_result&.dig(:form_data, :total_responses) >= 10 
        }
        
        process do |form_data_result|
          Rails.logger.info "Analyzing individual question performance"
          
          form_data = form_data_result[:form_data]
          questions_data = form_data[:questions_data]
          
          # Analyze each question's performance
          question_analysis = questions_data.map do |question_data|
            analyze_single_question_performance(question_data, form_data)
          end
          
          # Identify bottlenecks and high performers
          bottlenecks = identify_bottlenecks(question_analysis)
          high_performers = identify_high_performers(question_analysis)
          
          # Calculate overall question flow metrics
          flow_metrics = calculate_flow_metrics(questions_data)
          
          Rails.logger.info "Question analysis complete: #{bottlenecks.length} bottlenecks, #{high_performers.length} high performers identified"
          
          format_success_result({
            question_analysis: question_analysis,
            bottlenecks: bottlenecks,
            high_performers: high_performers,
            flow_metrics: flow_metrics,
            total_questions_analyzed: question_analysis.length
          })
        end
      end
      
      # Step 4: Generate actionable insights
      llm :generate_optimization_plan do
        input :analyze_form_performance, :analyze_question_performance
        run_when :analyze_form_performance
        
        model "gpt-4o"
        temperature 0.3
        max_tokens 800
        response_format :json
        
        system_prompt "You are a conversion optimization expert who creates actionable, prioritized improvement plans for forms based on data analysis."
        
        prompt do |context|
          performance_analysis = context.get(:analyze_form_performance)
          question_analysis = context.get(:analyze_question_performance)
          form_data_result = context.get(:collect_form_data)
          
          format_optimization_plan_prompt(performance_analysis, question_analysis, form_data_result[:form_data])
        end
      end
      
      # Step 5: Save analysis results
      task :save_analysis_results do
        input :analyze_form_performance, :analyze_question_performance, :generate_optimization_plan
        
        process do |performance, questions, optimization|
          Rails.logger.info "Saving comprehensive analysis results"
          
          form_data_result = context.get(:collect_form_data)
          form = form_data_result[:form_data][:form]
          
          # Track AI usage for analysis
          ai_cost = 0.08 # Estimated cost for comprehensive analysis
          track_ai_usage(context, ai_cost, 'form_analysis')
          
          # Execute database operation safely
          result = safe_db_operation do
            # Create or update form analytics record
            analytics_record = FormAnalytic.find_or_create_by(
              form: form,
              date: Date.current,
              metric_type: 'comprehensive_analysis'
            )
            
            # Prepare analysis data
            analysis_data = {
              performance_analysis: performance,
              question_analysis: questions,
              optimization_plan: optimization,
              analysis_metadata: {
                analyzed_at: Time.current.iso8601,
                total_responses: form_data_result[:form_data][:total_responses],
                completion_rate: form_data_result[:form_data][:completion_rate],
                ai_cost: ai_cost,
                workflow_id: context.get(:workflow_id)
              }
            }
            
            # Update analytics record
            analytics_record.update!(
              ai_insights: analysis_data,
              optimization_suggestions: optimization.dig('recommendations') || [],
              behavioral_patterns: performance.dig('behavioral_patterns') || {},
              avg_quality_score: questions.dig('flow_metrics', 'avg_quality_score') || 0,
              updated_at: Time.current
            )
            
            # Update user's AI credit usage
            user = form.user
            user.consume_ai_credit(ai_cost) if user.respond_to?(:consume_ai_credit)
            
            {
              analytics_record: analytics_record,
              analysis_data: analysis_data,
              ai_cost: ai_cost
            }
          end
          
          if result[:error]
            Rails.logger.error "Failed to save analysis results: #{result[:message]}"
            return format_error_result("Failed to save analysis results", result[:type], result)
          end
          
          Rails.logger.info "Successfully saved analysis results for form #{form.name}"
          
          format_success_result({
            analytics_record_id: result[:analytics_record].id,
            analysis_data: result[:analysis_data],
            ai_cost: result[:ai_cost],
            saved_at: Time.current.iso8601
          })
        end
      end
    end
    
    private
    
    # Analyze individual question performance metrics
    def analyze_single_question_performance(question_data, form_data)
      total_form_responses = form_data[:total_responses]
      
      # Calculate drop-off rate for this question
      drop_off_rate = calculate_drop_off_rate(question_data, form_data)
      
      # Analyze response patterns
      answer_distribution = calculate_answer_distribution(question_data[:responses_data])
      
      # Calculate quality metrics
      avg_response_time = question_data[:avg_response_time] || 0
      response_time_category = categorize_response_time(avg_response_time, question_data[:question_type])
      
      # Determine performance indicators
      performance_score = calculate_question_performance_score(question_data, drop_off_rate, answer_distribution)
      
      # Identify specific issues
      issues = identify_question_issues(question_data, drop_off_rate, avg_response_time, answer_distribution)
      
      # Identify success factors
      success_factors = identify_question_success_factors(question_data, performance_score, answer_distribution)
      
      {
        question_id: question_data[:question_id],
        title: question_data[:title],
        position: question_data[:position],
        question_type: question_data[:question_type],
        completion_rate: question_data[:completion_rate],
        drop_off_rate: drop_off_rate,
        performance_score: performance_score,
        avg_response_time: avg_response_time,
        response_time_category: response_time_category,
        answer_distribution: answer_distribution,
        issues: issues,
        success_factors: success_factors,
        recommendations: generate_question_recommendations(question_data, issues, success_factors)
      }
    end
    
    # Identify questions that are causing significant user drop-off
    def identify_bottlenecks(question_analysis)
      bottlenecks = []
      
      question_analysis.each do |analysis|
        # High drop-off rate indicates a bottleneck
        if analysis[:drop_off_rate] > 15.0
          bottlenecks << {
            question_id: analysis[:question_id],
            title: analysis[:title],
            position: analysis[:position],
            drop_off_rate: analysis[:drop_off_rate],
            issue_type: 'high_drop_off',
            severity: analysis[:drop_off_rate] > 30.0 ? 'critical' : 'high',
            primary_issues: analysis[:issues].select { |issue| issue[:severity] == 'high' }
          }
        end
        
        # Low completion rate compared to previous questions
        if analysis[:completion_rate] < 70.0 && analysis[:position] > 1
          bottlenecks << {
            question_id: analysis[:question_id],
            title: analysis[:title],
            position: analysis[:position],
            completion_rate: analysis[:completion_rate],
            issue_type: 'low_completion',
            severity: analysis[:completion_rate] < 50.0 ? 'critical' : 'medium',
            primary_issues: analysis[:issues]
          }
        end
        
        # Unusually long response times
        if analysis[:response_time_category] == 'very_slow'
          bottlenecks << {
            question_id: analysis[:question_id],
            title: analysis[:title],
            position: analysis[:position],
            avg_response_time: analysis[:avg_response_time],
            issue_type: 'slow_response',
            severity: 'medium',
            primary_issues: analysis[:issues].select { |issue| issue[:type] == 'response_time' }
          }
        end
      end
      
      # Remove duplicates and sort by severity
      bottlenecks.uniq { |b| b[:question_id] }
                .sort_by { |b| [b[:severity] == 'critical' ? 0 : 1, -b[:drop_off_rate].to_f] }
    end
    
    # Identify questions that are performing exceptionally well
    def identify_high_performers(question_analysis)
      high_performers = []
      
      question_analysis.each do |analysis|
        # High completion rate with low drop-off
        if analysis[:completion_rate] > 85.0 && analysis[:drop_off_rate] < 5.0
          high_performers << {
            question_id: analysis[:question_id],
            title: analysis[:title],
            position: analysis[:position],
            completion_rate: analysis[:completion_rate],
            drop_off_rate: analysis[:drop_off_rate],
            success_factor: 'high_engagement',
            performance_score: analysis[:performance_score],
            key_strengths: analysis[:success_factors]
          }
        end
        
        # Fast response times with good completion
        if analysis[:response_time_category] == 'fast' && analysis[:completion_rate] > 80.0
          high_performers << {
            question_id: analysis[:question_id],
            title: analysis[:title],
            position: analysis[:position],
            avg_response_time: analysis[:avg_response_time],
            completion_rate: analysis[:completion_rate],
            success_factor: 'efficient_design',
            performance_score: analysis[:performance_score],
            key_strengths: analysis[:success_factors]
          }
        end
        
        # High performance score overall
        if analysis[:performance_score] > 85.0
          high_performers << {
            question_id: analysis[:question_id],
            title: analysis[:title],
            position: analysis[:position],
            performance_score: analysis[:performance_score],
            success_factor: 'overall_excellence',
            key_strengths: analysis[:success_factors]
          }
        end
      end
      
      # Remove duplicates and sort by performance score
      high_performers.uniq { |hp| hp[:question_id] }
                    .sort_by { |hp| -hp[:performance_score] }
    end
    
    # Calculate overall flow and user experience metrics
    def calculate_flow_metrics(questions_data)
      return {} if questions_data.empty?
      
      # Calculate completion rate progression
      completion_rates = questions_data.map { |q| q[:completion_rate] }
      avg_completion_rate = completion_rates.sum / completion_rates.length
      
      # Calculate drop-off progression
      drop_offs = questions_data.each_cons(2).map do |current, next_q|
        current[:completion_rate] - next_q[:completion_rate]
      end
      
      # Calculate response time metrics
      response_times = questions_data.map { |q| q[:avg_response_time] }.compact
      avg_response_time = response_times.empty? ? 0 : response_times.sum / response_times.length
      
      # Calculate quality indicators
      required_questions = questions_data.count { |q| q[:required] }
      ai_enhanced_questions = questions_data.count { |q| q[:ai_enhanced] }
      
      # Identify flow issues
      flow_issues = []
      
      # Check for steep drop-offs
      drop_offs.each_with_index do |drop_off, index|
        if drop_off > 20.0
          flow_issues << {
            type: 'steep_drop_off',
            location: "Between Q#{index + 1} and Q#{index + 2}",
            severity: drop_off > 35.0 ? 'critical' : 'high',
            drop_off_rate: drop_off
          }
        end
      end
      
      # Check for length issues
      if questions_data.length > 15
        flow_issues << {
          type: 'form_too_long',
          severity: 'medium',
          question_count: questions_data.length,
          recommendation: 'Consider breaking into multiple forms or removing non-essential questions'
        }
      end
      
      # Check for response time issues
      slow_questions = questions_data.select { |q| (q[:avg_response_time] || 0) > 60000 } # > 1 minute
      if slow_questions.any?
        flow_issues << {
          type: 'slow_response_times',
          severity: 'medium',
          affected_questions: slow_questions.length,
          avg_slow_time: slow_questions.sum { |q| q[:avg_response_time] } / slow_questions.length
        }
      end
      
      {
        total_questions: questions_data.length,
        avg_completion_rate: avg_completion_rate.round(2),
        avg_response_time: avg_response_time.round(2),
        total_drop_off: completion_rates.first - completion_rates.last,
        steepest_drop_off: drop_offs.max || 0,
        required_questions_count: required_questions,
        ai_enhanced_questions_count: ai_enhanced_questions,
        flow_issues: flow_issues,
        flow_quality_score: calculate_flow_quality_score(completion_rates, drop_offs, flow_issues),
        avg_quality_score: calculate_average_quality_score(questions_data)
      }
    end
    
    # Calculate drop-off rate for a specific question
    def calculate_drop_off_rate(question_data, form_data)
      current_position = question_data[:position]
      return 0.0 if current_position == 1 # First question has no drop-off
      
      # Find previous question
      previous_question = form_data[:questions_data].find { |q| q[:position] == current_position - 1 }
      return 0.0 unless previous_question
      
      # Calculate drop-off rate
      previous_completion = previous_question[:completion_rate]
      current_completion = question_data[:completion_rate]
      
      [previous_completion - current_completion, 0.0].max
    end
    
    # Analyze answer distribution patterns
    def calculate_answer_distribution(responses_data)
      return {} if responses_data.empty?
      
      # Extract answer values
      answers = responses_data.map { |response| response[0] } # answer_data is first element
      
      # Calculate distribution based on answer types
      distribution = {}
      
      # Count unique answers
      answer_counts = answers.compact.tally
      total_answers = answers.compact.length
      
      return {} if total_answers == 0
      
      # Calculate percentages
      answer_counts.each do |answer, count|
        percentage = (count.to_f / total_answers * 100).round(2)
        distribution[answer.to_s] = {
          count: count,
          percentage: percentage
        }
      end
      
      # Add summary statistics
      distribution[:summary] = {
        total_responses: total_answers,
        unique_answers: answer_counts.keys.length,
        most_common: answer_counts.max_by { |_, count| count }&.first,
        diversity_score: calculate_diversity_score(answer_counts, total_answers)
      }
      
      distribution
    end
    
    # Helper method to calculate diversity score for answers
    def calculate_diversity_score(answer_counts, total_answers)
      return 0.0 if total_answers == 0 || answer_counts.empty?
      
      # Calculate entropy-based diversity score
      entropy = answer_counts.values.sum do |count|
        probability = count.to_f / total_answers
        -probability * Math.log2(probability)
      end
      
      # Normalize to 0-100 scale
      max_entropy = Math.log2(answer_counts.keys.length)
      max_entropy > 0 ? (entropy / max_entropy * 100).round(2) : 0.0
    end
    
    # Categorize response time performance
    def categorize_response_time(avg_time_ms, question_type)
      return 'unknown' if avg_time_ms.nil? || avg_time_ms <= 0
      
      # Define thresholds based on question type (in milliseconds)
      thresholds = case question_type
                   when 'text_short', 'email', 'phone'
                     { fast: 15000, normal: 45000, slow: 90000 } # 15s, 45s, 90s
                   when 'text_long'
                     { fast: 30000, normal: 120000, slow: 300000 } # 30s, 2m, 5m
                   when 'multiple_choice', 'single_choice', 'rating'
                     { fast: 8000, normal: 25000, slow: 60000 } # 8s, 25s, 60s
                   when 'file_upload'
                     { fast: 45000, normal: 180000, slow: 600000 } # 45s, 3m, 10m
                   else
                     { fast: 20000, normal: 60000, slow: 120000 } # 20s, 60s, 2m
                   end
      
      case avg_time_ms
      when 0..thresholds[:fast]
        'fast'
      when thresholds[:fast]..thresholds[:normal]
        'normal'
      when thresholds[:normal]..thresholds[:slow]
        'slow'
      else
        'very_slow'
      end
    end
    
    # Calculate overall performance score for a question
    def calculate_question_performance_score(question_data, drop_off_rate, answer_distribution)
      # Base score from completion rate
      completion_score = question_data[:completion_rate]
      
      # Penalty for high drop-off rate
      drop_off_penalty = [drop_off_rate * 2, 30].min # Max 30 point penalty
      
      # Bonus for good response time
      time_bonus = case categorize_response_time(question_data[:avg_response_time], question_data[:question_type])
                   when 'fast' then 5
                   when 'normal' then 0
                   when 'slow' then -5
                   when 'very_slow' then -15
                   else 0
                   end
      
      # Bonus for answer diversity (indicates engagement)
      diversity_bonus = if answer_distribution.dig(:summary, :diversity_score)
                          [answer_distribution[:summary][:diversity_score] / 10, 10].min
                        else
                          0
                        end
      
      # Calculate final score
      score = completion_score - drop_off_penalty + time_bonus + diversity_bonus
      
      # Ensure score is between 0 and 100
      [[score, 0].max, 100].min.round(2)
    end
    
    # Identify specific issues with a question
    def identify_question_issues(question_data, drop_off_rate, avg_response_time, answer_distribution)
      issues = []
      
      # High drop-off rate
      if drop_off_rate > 15.0
        issues << {
          type: 'high_drop_off',
          severity: drop_off_rate > 30.0 ? 'high' : 'medium',
          description: "#{drop_off_rate.round(1)}% of users abandon the form at this question",
          impact: 'conversion_rate'
        }
      end
      
      # Slow response time
      time_category = categorize_response_time(avg_response_time, question_data[:question_type])
      if time_category == 'slow' || time_category == 'very_slow'
        issues << {
          type: 'response_time',
          severity: time_category == 'very_slow' ? 'high' : 'medium',
          description: "Average response time of #{(avg_response_time / 1000).round(1)}s is #{time_category}",
          impact: 'user_experience'
        }
      end
      
      # Low answer diversity (may indicate confusion or poor options)
      if answer_distribution.dig(:summary, :diversity_score) && answer_distribution[:summary][:diversity_score] < 20
        issues << {
          type: 'low_diversity',
          severity: 'low',
          description: "Low answer diversity may indicate limited options or user confusion",
          impact: 'data_quality'
        }
      end
      
      # Low completion rate for non-first questions
      if question_data[:position] > 1 && question_data[:completion_rate] < 60.0
        issues << {
          type: 'low_completion',
          severity: question_data[:completion_rate] < 40.0 ? 'high' : 'medium',
          description: "Only #{question_data[:completion_rate]}% of users complete this question",
          impact: 'data_collection'
        }
      end
      
      issues
    end
    
    # Identify success factors for high-performing questions
    def identify_question_success_factors(question_data, performance_score, answer_distribution)
      factors = []
      
      # High completion rate
      if question_data[:completion_rate] > 85.0
        factors << {
          type: 'high_completion',
          description: "Excellent completion rate of #{question_data[:completion_rate]}%",
          strength: 'user_engagement'
        }
      end
      
      # Fast response time
      time_category = categorize_response_time(question_data[:avg_response_time], question_data[:question_type])
      if time_category == 'fast'
        factors << {
          type: 'fast_response',
          description: "Users respond quickly (#{(question_data[:avg_response_time] / 1000).round(1)}s average)",
          strength: 'question_clarity'
        }
      end
      
      # Good answer diversity
      if answer_distribution.dig(:summary, :diversity_score) && answer_distribution[:summary][:diversity_score] > 70
        factors << {
          type: 'high_diversity',
          description: "High answer diversity indicates good engagement and clear options",
          strength: 'question_design'
        }
      end
      
      # AI enhancement success
      if question_data[:ai_enhanced] && performance_score > 80.0
        factors << {
          type: 'ai_enhancement',
          description: "AI enhancement contributes to strong performance",
          strength: 'technology_integration'
        }
      end
      
      factors
    end
    
    # Generate specific recommendations for question improvement
    def generate_question_recommendations(question_data, issues, success_factors)
      recommendations = []
      
      issues.each do |issue|
        case issue[:type]
        when 'high_drop_off'
          recommendations << {
            type: 'reduce_drop_off',
            priority: issue[:severity] == 'high' ? 'critical' : 'high',
            action: 'Simplify question wording and reduce cognitive load',
            details: 'Consider breaking complex questions into simpler parts or providing better context'
          }
        when 'response_time'
          recommendations << {
            type: 'improve_response_time',
            priority: 'medium',
            action: 'Optimize question design for faster completion',
            details: 'Consider using choice-based questions, better UI, or clearer instructions'
          }
        when 'low_completion'
          recommendations << {
            type: 'increase_completion',
            priority: 'high',
            action: 'Review question necessity and positioning',
            details: 'Consider making optional, moving earlier in form, or improving motivation'
          }
        end
      end
      
      # Add recommendations based on success factors from other questions
      if success_factors.any? { |f| f[:type] == 'ai_enhancement' } && !question_data[:ai_enhanced]
        recommendations << {
          type: 'add_ai_enhancement',
          priority: 'medium',
          action: 'Consider adding AI enhancement to this question',
          details: 'AI-enhanced questions show better performance in this form'
        }
      end
      
      recommendations
    end
    
    # Calculate overall flow quality score
    def calculate_flow_quality_score(completion_rates, drop_offs, flow_issues)
      return 0.0 if completion_rates.empty?
      
      # Base score from average completion rate
      base_score = completion_rates.sum / completion_rates.length
      
      # Penalty for steep drop-offs
      drop_off_penalty = drop_offs.sum { |drop| drop > 15.0 ? drop * 0.5 : 0 }
      
      # Penalty for flow issues
      issue_penalty = flow_issues.sum do |issue|
        case issue[:severity]
        when 'critical' then 20
        when 'high' then 10
        when 'medium' then 5
        else 2
        end
      end
      
      # Calculate final score
      score = base_score - drop_off_penalty - issue_penalty
      
      # Ensure score is between 0 and 100
      [[score, 0].max, 100].min.round(2)
    end
    
    # Calculate average quality score across all questions
    def calculate_average_quality_score(questions_data)
      return 0.0 if questions_data.empty?
      
      quality_scores = questions_data.map do |question|
        # Simple quality calculation based on completion rate and response count
        completion_weight = question[:completion_rate] || 0
        response_weight = question[:responses_count] > 10 ? 10 : (question[:responses_count] * 5)
        
        (completion_weight + response_weight) / 2
      end
      
      (quality_scores.sum / quality_scores.length).round(2)
    end
    
    def format_performance_analysis_prompt(form_data)
      form = form_data[:form]
      questions_data = form_data[:questions_data]
      
      # Prepare question summary for analysis
      questions_summary = questions_data.map do |q|
        "#{q[:position]}. #{q[:title]} (#{q[:question_type]}) - #{q[:completion_rate]}% completion, #{q[:responses_count]} responses"
      end.join("\n")
      
      # Calculate drop-off points
      drop_off_analysis = questions_data.each_cons(2).map do |current, next_q|
        drop_off = current[:completion_rate] - next_q[:completion_rate]
        "Q#{current[:position]} → Q#{next_q[:position]}: #{drop_off.round(1)}% drop-off"
      end.join("\n")
      
      <<~PROMPT
        Analyze this form's performance and provide comprehensive insights in JSON format.

        **Form Overview:**
        - Name: "#{form.name}"
        - Category: #{form.category}
        - Total Responses: #{form_data[:total_responses]}
        - Completion Rate: #{form_data[:completion_rate]}%
        - Created: #{form_data[:created_at].strftime('%Y-%m-%d')}
        - Last Response: #{form_data[:last_response_at]&.strftime('%Y-%m-%d') || 'Never'}

        **Questions Performance:**
        #{questions_summary}

        **Drop-off Analysis:**
        #{drop_off_analysis}

        **Form Configuration:**
        - AI Enhanced: #{form.ai_enhanced?}
        - Question Count: #{questions_data.length}
        - Required Questions: #{questions_data.count { |q| q[:required] }}

        **Analysis Required:**
        Please analyze this form's performance and return a JSON object with the following structure:

        {
          "overall_performance": {
            "score": 0-100,
            "grade": "A|B|C|D|F",
            "summary": "Brief overall assessment"
          },
          "completion_analysis": {
            "completion_rate_assessment": "excellent|good|average|poor|critical",
            "benchmark_comparison": "above_average|average|below_average",
            "completion_factors": ["factor1", "factor2", "factor3"]
          },
          "user_experience": {
            "flow_quality": 0-100,
            "question_clarity": 0-100,
            "length_appropriateness": 0-100,
            "mobile_friendliness": 0-100
          },
          "behavioral_patterns": {
            "common_drop_off_points": [
              {
                "question_position": 3,
                "drop_off_rate": 25.5,
                "likely_reasons": ["reason1", "reason2"]
              }
            ],
            "engagement_indicators": {
              "high_engagement_questions": [1, 2, 5],
              "low_engagement_questions": [3, 7],
              "avg_time_per_question": 45.2
            }
          },
          "conversion_insights": {
            "strengths": ["strength1", "strength2"],
            "weaknesses": ["weakness1", "weakness2"],
            "quick_wins": ["improvement1", "improvement2"],
            "major_improvements": ["major_change1", "major_change2"]
          },
          "technical_performance": {
            "response_time_analysis": "fast|average|slow",
            "error_indicators": ["indicator1", "indicator2"],
            "data_quality_score": 0-100
          }
        }

        **Guidelines:**
        - Be specific and actionable in your recommendations
        - Consider industry benchmarks for form performance
        - Focus on user experience and conversion optimization
        - Identify both quick wins and strategic improvements
        - Consider the form's purpose and target audience
        - Provide data-driven insights based on the metrics provided
      PROMPT
    end
    
    def format_optimization_plan_prompt(performance_analysis, question_analysis, form_data)
      form = form_data[:form]
      bottlenecks = question_analysis[:bottlenecks] || []
      high_performers = question_analysis[:high_performers] || []
      
      # Prepare bottleneck summary
      bottleneck_summary = bottlenecks.map do |b|
        "- Q#{b[:position]}: #{b[:title]} (#{b[:issue_type]}: #{b[:severity]})"
      end.join("\n")
      
      # Prepare high performer summary
      high_performer_summary = high_performers.map do |hp|
        "- Q#{hp[:position]}: #{hp[:title]} (#{hp[:success_factor]})"
      end.join("\n")
      
      <<~PROMPT
        Create a prioritized optimization plan based on the form analysis results.

        **Form Context:**
        - Name: "#{form.name}"
        - Category: #{form.category}
        - Overall Performance Score: #{performance_analysis.dig('overall_performance', 'score') || 'N/A'}
        - Completion Rate: #{form_data[:completion_rate]}%

        **Performance Analysis Summary:**
        - Overall Grade: #{performance_analysis.dig('overall_performance', 'grade') || 'N/A'}
        - Flow Quality: #{performance_analysis.dig('user_experience', 'flow_quality') || 'N/A'}/100
        - Main Strengths: #{performance_analysis.dig('conversion_insights', 'strengths')&.join(', ') || 'None identified'}
        - Main Weaknesses: #{performance_analysis.dig('conversion_insights', 'weaknesses')&.join(', ') || 'None identified'}

        **Identified Bottlenecks:**
        #{bottleneck_summary.present? ? bottleneck_summary : "No major bottlenecks identified"}

        **High-Performing Elements:**
        #{high_performer_summary.present? ? high_performer_summary : "No standout performers identified"}

        **Quick Wins Identified:**
        #{performance_analysis.dig('conversion_insights', 'quick_wins')&.join(', ') || 'None identified'}

        **Instructions:**
        Create a comprehensive, prioritized optimization plan that addresses the identified issues and leverages successful elements.

        **Response Format (JSON):**
        {
          "executive_summary": {
            "current_state": "Brief assessment of current performance",
            "improvement_potential": "Estimated improvement potential",
            "priority_focus": "Primary area to focus optimization efforts"
          },
          "recommendations": [
            {
              "id": "rec_001",
              "title": "Clear, actionable recommendation title",
              "description": "Detailed explanation of the recommendation",
              "category": "question_optimization|flow_improvement|ux_enhancement|technical_fix",
              "priority": "critical|high|medium|low",
              "effort": "low|medium|high",
              "impact": "low|medium|high",
              "estimated_improvement": "5-15% completion rate increase",
              "implementation_steps": [
                "Step 1: Specific action",
                "Step 2: Specific action"
              ],
              "success_metrics": ["metric1", "metric2"],
              "timeline": "immediate|1-2_weeks|1_month|ongoing"
            }
          ],
          "implementation_roadmap": {
            "phase_1_immediate": ["rec_001", "rec_003"],
            "phase_2_short_term": ["rec_002", "rec_005"],
            "phase_3_long_term": ["rec_004", "rec_006"]
          },
          "success_tracking": {
            "key_metrics": ["completion_rate", "avg_time_per_response", "user_satisfaction"],
            "measurement_plan": "How to track improvement success",
            "review_schedule": "When to review and adjust the plan"
          },
          "risk_assessment": {
            "implementation_risks": ["risk1", "risk2"],
            "mitigation_strategies": ["strategy1", "strategy2"]
          }
        }

        **Guidelines:**
        - Prioritize recommendations by impact vs effort
        - Provide specific, actionable steps
        - Consider the form's business purpose and user context
        - Balance quick wins with strategic improvements
        - Include measurable success criteria
        - Consider technical feasibility and resource requirements
        - Focus on user experience and conversion optimization
      PROMPT
    end
  end
end