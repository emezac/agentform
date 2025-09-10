# frozen_string_literal: true

module Forms
  class LeadScoringWorkflow < ApplicationWorkflow
    workflow do
      timeout 180
      
      # Step 1: Collect and validate response data
      task :collect_response_data do
        input :form_response_id
        description "Collect all response data for lead scoring analysis"
        
        process do |response_id|
          Rails.logger.info "Collecting response data for lead scoring: response_id=#{response_id}"
          
          validate_required_inputs(context, :form_response_id)
          
          result = safe_db_operation do
            form_response = FormResponse.includes(
              :form,
              :question_responses,
              :dynamic_questions,
              form: :user,
              question_responses: :form_question
            ).find(response_id)
            
            unless form_response.completed?
              raise ArgumentError, "Form response #{response_id} must be completed for lead scoring"
            end
            
            # Verify user has AI capabilities
            form = form_response.form
            unless form.user.can_use_ai_features?
              raise Pundit::NotAuthorizedError, "User does not have AI features available"
            end
            
            # Collect all response data
            answers_hash = form_response.answers_hash
            ai_analysis_data = form_response.ai_analysis_results || {}
            
            # Collect enriched data
            enriched_data = form_response.enriched_data || {}
            
            # Collect dynamic question responses
            dynamic_responses = form_response.dynamic_questions.includes(:responses).map do |dq|
              {
                question: dq.title,
                response: dq.responses.first&.answer_data,
                generation_context: dq.generation_context
              }
            end
            
            completion_time = nil
            if form_response.started_at && form_response.completed_at
              completion_time = ((form_response.completed_at - form_response.started_at) / 1.minute).round(2)
            end
            
            {
              form_response: form_response,
              form: form,
              user: form.user,
              answers: answers_hash,
              ai_analysis: ai_analysis_data,
              enriched_data: enriched_data,
              dynamic_responses: dynamic_responses,
              completion_time: completion_time,
              response_metadata: {
                user_agent: form_response.user_agent,
                referrer: form_response.referrer_url,
                ip_address: form_response.ip_address,
                submitted_at: form_response.created_at,
                completed_at: form_response.completed_at
              }
            }
          end
          
          if result[:error]
            Rails.logger.error "Failed to collect response data: #{result[:message]}"
            return format_error_result("Failed to collect response data", result[:type], result)
          end
          
          format_success_result({
            response_data: result,
            ready_for_scoring: true
          })
        end
      end
      
      # Step 2: Analyze lead quality indicators
      llm :analyze_lead_quality do
        input :collect_response_data
        run_if { |ctx| ctx.get(:collect_response_data)&.dig(:ready_for_scoring) }
        
        model "gpt-4o-mini"
        temperature 0.3
        max_tokens 800
        response_format :json
        
        system_prompt "You are an expert lead qualification specialist with deep knowledge of B2B and B2C sales processes. Analyze form responses to determine lead quality, intent, and readiness to purchase."
        
        prompt do |context|
          data_result = context.get(:collect_response_data)
          response_data = data_result[:response_data]
          
          # Format the prompt inline instead of using a separate method
          form = response_data[:form]
          answers = response_data[:answers]
          enriched_data = response_data[:enriched_data]
          ai_analysis = response_data[:ai_analysis]
          
          <<~PROMPT
            Analyze this form response as a lead qualification specialist. Score the lead quality from 0-100 and provide detailed insights.

            **Form Information:**
            - Name: "#{form.name}"
            - Category: #{form.category}
            - Purpose: #{form.form_settings&.dig('purpose') || 'Lead generation'}

            **Response Data:**
            #{answers.map { |k, v| "- #{k}: #{v}" }.join("\n")}

            **Enriched Data:**
            #{enriched_data.map { |k, v| "- #{k}: #{v}" }.join("\n") if enriched_data.present?}

            **AI Analysis:**
            #{ai_analysis.map { |k, v| "- #{k}: #{v}" }.join("\n") if ai_analysis.present?}

            **Analysis Requirements:**
            Return a JSON object with:
            {
              "quality_score": 0-100,
              "lead_tier": "hot|warm|lukewarm|cold",
              "quality_factors": [
                {
                  "factor": "specific quality indicator",
                  "score": 0-25,
                  "reasoning": "why this contributes to quality"
                }
              ],
              "risk_factors": [
                {
                  "factor": "potential concern",
                  "impact": "low|medium|high",
                  "reasoning": "why this might be a risk"
                }
              ],
              "qualification_notes": "detailed assessment of lead quality",
              "recommended_actions": [
                "specific action 1",
                "specific action 2"
              ],
              "estimated_value": "estimated deal value or importance",
              "confidence_level": 0-1.0,
              "buying_signals": [
                "specific indicators of purchase intent"
              ],
              "timing_indicators": {
                "urgency": "immediate|short_term|long_term",
                "budget_availability": "confirmed|likely|unknown",
                "decision_maker": "yes|no|influencer"
              },
              "next_best_action": "specific recommendation for follow-up"
            }

            **Scoring Guidelines:**
            - 80-100: Hot lead - immediate follow-up required
            - 60-79: Warm lead - follow-up within 24 hours
            - 40-59: Lukewarm lead - nurture campaign
            - 0-39: Cold lead - long-term nurture

            Consider:
            - Company size and industry (if enriched)
            - Response quality and detail level
            - Specific pain points mentioned
            - Timeline indicators
            - Budget indicators
            - Decision-making authority signals
            - Engagement level throughout form
          PROMPT
        end
      end
      
      # Step 3: Calculate lead score
      task :calculate_lead_score do
        input :analyze_lead_quality, :collect_response_data
        run_when :analyze_lead_quality
        
        process do |quality_analysis, data_result|
          Rails.logger.info "Calculating lead score based on quality analysis"
          
          response_data = data_result[:response_data]
          form_response = response_data[:form_response]
          
          # Track AI usage
          ai_cost = 0.035 # Estimated cost for lead scoring analysis
          track_ai_usage(context, ai_cost, 'lead_scoring')
          
          result = safe_db_operation do
            # Parse quality analysis
            lead_analysis = quality_analysis.is_a?(String) ? JSON.parse(quality_analysis) : quality_analysis
            
            # Calculate numerical score inline
            lead_score = if response_data[:form].ai_enhanced? && response_data[:form].ai_configuration&.dig('lead_scoring', 'enabled') == true
              # Multi-dimensional scoring
              dimensions = {
                technical_readiness: LeadScoringCalculator.calculate_technical_score(response_data),
                business_impact: LeadScoringCalculator.calculate_business_impact_score(lead_analysis, response_data),
                financial_capacity: LeadScoringCalculator.calculate_financial_score(response_data),
                urgency_factor: LeadScoringCalculator.calculate_urgency_score(lead_analysis, response_data),
                decision_authority: LeadScoringCalculator.calculate_authority_score(response_data),
                implementation_complexity: LeadScoringCalculator.calculate_complexity_score(response_data)
              }
              
              # Get industry-specific weights
              industry = response_data[:enriched_data]&.[](:industry)
              weights = LeadScoringCalculator.get_industry_weights(industry)
              
              # Calculate weighted score
              weighted_score = dimensions.sum { |dim, score| score * (weights[dim] || 1.0) }
              
              # Ensure score is between 0-100
              [[weighted_score, 0].max, 100].min.round
            else
              # Simple scoring
              base_score = 0
              
              # Score based on quality factors
              quality_score = lead_analysis['quality_score'] || 50
              base_score += quality_score
              
              # Bonus for company data enrichment
              base_score += 15 if response_data[:enriched_data].present?
              
              # Bonus for detailed responses
              detailed_responses = response_data[:answers].values.count { |ans| ans.to_s.length > 50 }
              base_score += [detailed_responses * 5, 20].min
              
              # Bonus for completion time (faster = better)
              completion_time = response_data[:completion_time]
              if completion_time && completion_time < 10
                base_score += 10
              elsif completion_time && completion_time > 30
                base_score -= 5
              end
              
              # Ensure score is between 0-100
              [[base_score, 0].max, 100].min.round
            end
            
            # Determine lead tier based on score
            lead_tier = case lead_score
            when 80..100 then 'hot'
            when 60..79 then 'warm'
            when 40..59 then 'lukewarm'
            else 'cold'
            end
            
            # Create lead scoring record
            lead_scoring = LeadScoring.create!(
              form_response: form_response,
              score: lead_score,
              tier: lead_tier,
              analysis_data: lead_analysis,
              quality_factors: lead_analysis['quality_factors'],
              risk_factors: lead_analysis['risk_factors'],
              qualification_notes: lead_analysis['qualification_notes'],
              recommended_actions: lead_analysis['recommended_actions'],
              estimated_value: lead_analysis['estimated_value'],
              confidence_level: lead_analysis['confidence_level'],
              scored_at: Time.current,
              ai_cost: ai_cost
            )
            
            # Update form response with scoring data
            form_response.update!(
              lead_score: lead_score,
              lead_tier: lead_tier,
              lead_scoring_id: lead_scoring.id
            )
            
            # Update user's AI credit usage
            user = response_data[:user]
            user.consume_ai_credit(ai_cost) if user.respond_to?(:consume_ai_credit)
            
            {
              lead_scoring: lead_scoring,
              score: lead_score,
              tier: lead_tier,
              analysis: lead_analysis,
              ai_cost: ai_cost
            }
          end
          
          if result[:error]
            Rails.logger.error "Failed to calculate lead score: #{result[:message]}"
            return format_error_result("Failed to calculate lead score", result[:type], result)
          end
          
          format_success_result({
            lead_scoring_id: result[:lead_scoring].id,
            score: result[:score],
            tier: result[:tier],
            analysis: result[:analysis],
            ai_cost: result[:ai_cost],
            scored_at: Time.current.iso8601
          })
        end
      end
      
      # Step 4: Route lead based on score
      task :route_lead do
        input :calculate_lead_score, :collect_response_data
        run_when :calculate_lead_score
        
        process do |scoring_result, data_result|
          Rails.logger.info "Routing lead based on score: #{scoring_result[:score]}"
          
          response_data = data_result[:response_data]
          form_response = response_data[:form_response]
          form = response_data[:form]
          
          # Get routing configuration
          routing_config = form.ai_configuration&.dig('lead_routing') || {}
          
          routing_actions = []
          
          # Route based on tier and score
          case scoring_result[:tier]
          when 'hot'
            routing_actions << {
              action: 'immediate_followup',
              priority: 'high',
              sla_hours: 1,
              assign_to: routing_config['hot_lead_assignee'] || 'sales_team',
              channels: ['email', 'phone', 'slack']
            }
          when 'warm'
            routing_actions << {
              action: 'scheduled_followup',
              priority: 'medium',
              sla_hours: 24,
              assign_to: routing_config['warm_lead_assignee'] || 'marketing_team',
              channels: ['email', 'slack']
            }
          when 'cold'
            routing_actions << {
              action: 'nurture_campaign',
              priority: 'low',
              sla_hours: 72,
              assign_to: routing_config['cold_lead_assignee'] || 'nurture_team',
              channels: ['email']
            }
          end
          
          # Check for specific routing rules - inline implementation
          custom_actions = []
          
          # Check for specific industry routing
          industry = response_data[:answers]['industry'] || response_data[:enriched_data]&.[](:industry)
          if industry
            industry_config = routing_config['industry_routing']&.[](industry)
            if industry_config
              custom_actions << {
                action: 'industry_specialist',
                priority: 'high',
                assign_to: industry_config['assignee'],
                channels: industry_config['channels'] || ['email']
              }
            end
          end
          
          # Check for high-value company routing
          company_size = response_data[:enriched_data]&.[](:company_size)
          if company_size && company_size > 1000
            custom_actions << {
              action: 'enterprise_specialist',
              priority: 'high',
              assign_to: routing_config['enterprise_assignee'] || 'enterprise_sales',
              channels: ['email', 'phone', 'slack']
            }
          end
          
          routing_actions.concat(custom_actions) if custom_actions.any?
          
          # Create routing record
          lead_routing = LeadRouting.create!(
            form_response: form_response,
            lead_scoring_id: scoring_result[:lead_scoring_id],
            routing_actions: routing_actions,
            status: 'pending',
            scheduled_at: Time.current,
            priority: routing_actions.first&.dig(:priority) || 'medium'
          )
          
          # Queue integration triggers for each routing action - inline implementation
          routing_actions.each do |action|
            case action[:action]
            when 'immediate_followup', 'scheduled_followup'
              Forms::IntegrationTriggerJob.perform_later(
                form_response.id,
                'lead_qualified',
                {
                  score: scoring_result[:score],
                  tier: scoring_result[:tier],
                  routing_action: action,
                  priority: action[:priority],
                  assign_to: action[:assign_to]
                }
              )
            when 'nurture_campaign'
              Forms::IntegrationTriggerJob.perform_later(
                form_response.id,
                'lead_nurture',
                {
                  score: scoring_result[:score],
                  tier: scoring_result[:tier],
                  campaign_type: 'nurture',
                  priority: action[:priority]
                }
              )
            end
          end
          
          {
            lead_routing: lead_routing,
            routing_actions: routing_actions,
            routing_config: routing_config
          }
        end
      end
      
      # Step 5: Trigger integrations based on routing
      stream :trigger_routing_integrations do
        input :route_lead, :calculate_lead_score, :collect_response_data
        run_when :route_lead
        
        target { |ctx| 
          data_result = ctx.get(:collect_response_data)
          form = data_result[:response_data][:form]
          "form_#{form.share_token}_lead_routing"
        }
        turbo_action :append
        partial "forms/lead_routing_status"
        
        locals do |ctx|
          routing_result = ctx.get(:route_lead)
          scoring_result = ctx.get(:calculate_lead_score)
          data_result = ctx.get(:collect_response_data)
          
          {
            lead_routing: routing_result[:lead_routing],
            routing_actions: routing_result[:routing_actions],
            score: scoring_result[:score],
            tier: scoring_result[:tier],
            form: data_result[:response_data][:form]
          }
        end
      end
    end
  end
end