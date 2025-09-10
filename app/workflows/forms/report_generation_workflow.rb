# frozen_string_literal: true

module Forms
  class ReportGenerationWorkflow < ApplicationWorkflow
    workflow do
      # Step 1: Collect and structure all data
      task :collect_comprehensive_data do
        input :form_response_id
        description "Collect all response data, AI analysis, and context"
        
        process do |response_id|
          Rails.logger.info "Collecting comprehensive data for report generation: #{response_id}"
          
          result = safe_db_operation do
            form_response = FormResponse.includes(
              :form,
              :question_responses,
              :dynamic_questions,
              :lead_scoring,
              form: [:user, :form_questions],
              question_responses: :form_question
            ).find(response_id)
            
            # Collect basic data
            basic_data = {
              form: {
                name: form_response.form.name,
                category: form_response.form.category,
                created_at: form_response.form.created_at
              },
              response: {
                id: form_response.id,
                session_id: form_response.session_id,
                completed_at: form_response.completed_at,
                duration_minutes: calculate_completion_duration(form_response),
                ip_address: form_response.ip_address&.slice(0, 3) + ".*.*.*" # Privacy
              }
            }
            
            # Collect structured responses
            structured_responses = build_structured_responses(form_response)
            
            # Collect existing AI analyses
            ai_analyses = collect_ai_analyses(form_response)
            
            # Collect enrichment data
            enrichment_data = form_response.enrichment_data || {}
            
            # Collect lead scoring
            lead_scoring = form_response.lead_scoring
            scoring_data = lead_scoring ? {
              overall_score: lead_scoring.score,
              tier: lead_scoring.tier,
              quality_factors: lead_scoring.quality_factors,
              risk_factors: lead_scoring.risk_factors,
              estimated_value: lead_scoring.estimated_value,
              confidence_level: lead_scoring.confidence_level
            } : nil
            
            # Recopilar preguntas dinámicas
            dynamic_questions_data = collect_dynamic_questions_data(form_response)
            
            {
              basic_data: basic_data,
              structured_responses: structured_responses,
              ai_analyses: ai_analyses,
              enrichment_data: enrichment_data,
              scoring_data: scoring_data,
              dynamic_questions: dynamic_questions_data,
              metadata: {
                total_questions: form_response.form.form_questions.count,
                answered_questions: form_response.question_responses.count,
                completion_rate: calculate_completion_percentage(form_response),
                quality_indicators: calculate_response_quality_indicators(form_response)
              }
            }
          end
          
          if result[:error]
            return format_error_result("Failed to collect comprehensive data", result[:type], result)
          end
          
          format_success_result({
            comprehensive_data: result,
            ready_for_analysis: true
          })
        end
      end
      
      # Step 2: Análisis estratégico con IA
      llm :strategic_analysis do
        input :collect_comprehensive_data
        run_if { |ctx| ctx.get(:collect_comprehensive_data)&.dig(:ready_for_analysis) }
        
        model "gpt-4o"
        temperature 0.2
        max_tokens 1500
        response_format :json
        
        system_prompt "You are a senior strategic consultant specializing in digital transformation with AI. Your task is to analyze business evaluation data and generate deep strategic insights, actionable recommendations, and an implementation roadmap."
        
        prompt do |context|
          data_result = context.get(:collect_comprehensive_data)
          comprehensive_data = data_result[:comprehensive_data]
          
          format_strategic_analysis_prompt(comprehensive_data)
        end
      end
      
      # Step 3: Generar recomendaciones técnicas
      llm :technical_recommendations do
        input :collect_comprehensive_data, :strategic_analysis
        run_when :strategic_analysis
        
        model "gpt-4o"
        temperature 0.3
        max_tokens 1200
        response_format :json
        
        system_prompt "You are an AI solutions architect with enterprise implementation experience. Analyze technical and business data to generate specific recommendations for architecture, technologies, and implementation."
        
        prompt do |context|
          data_result = context.get(:collect_comprehensive_data)
          strategic_result = context.get(:strategic_analysis)
          
          format_technical_recommendations_prompt(
            data_result[:comprehensive_data], 
            strategic_result
          )
        end
      end
      
      # Step 4: Análisis de riesgos y mitigación
      llm :risk_analysis do
        input :collect_comprehensive_data, :strategic_analysis, :technical_recommendations
        run_when :technical_recommendations
        
        model "gpt-4o-mini"
        temperature 0.4
        max_tokens 800
        response_format :json
        
        system_prompt "You are a specialist in technology risk management and digital transformation. Identify potential risks, adoption barriers, and mitigation strategies."
        
        prompt do |context|
          data_result = context.get(:collect_comprehensive_data)
          strategic_result = context.get(:strategic_analysis)
          technical_result = context.get(:technical_recommendations)
          
          format_risk_analysis_prompt(
            data_result[:comprehensive_data],
            strategic_result,
            technical_result
          )
        end
      end
      
      # Step 5: Generar el reporte MD final
      llm :generate_markdown_report do
        input :collect_comprehensive_data, :strategic_analysis, :technical_recommendations, :risk_analysis
        run_when :risk_analysis
        
        model "gpt-4o"
        temperature 0.1
        max_tokens 3000
        response_format :text # Para generar markdown directamente
        
        system_prompt "Eres un consultor senior que debe crear un reporte ejecutivo profesional en formato Markdown. El reporte debe ser comprehensivo, bien estructurado y accionable para ejecutivos de nivel C."
        
        prompt do |context|
          data_result = context.get(:collect_comprehensive_data)
          strategic_result = context.get(:strategic_analysis)
          technical_result = context.get(:technical_recommendations)
          risk_result = context.get(:risk_analysis)
          
          format_final_report_prompt(
            data_result[:comprehensive_data],
            strategic_result,
            technical_result,
            risk_result
          )
        end
      end
      
      # Step 6: Guardar y distribuir el reporte
      task :save_and_distribute_report do
        input :generate_markdown_report, :collect_comprehensive_data
        run_when :generate_markdown_report
        
        process do |markdown_content, data_result|
          Rails.logger.info "Saving and distributing final report"
          
          comprehensive_data = data_result[:comprehensive_data]
          form_response = FormResponse.find(comprehensive_data[:basic_data][:response][:id])
          
          # Track AI usage
          total_ai_cost = 0.15 # Estimated total cost for comprehensive analysis
          track_ai_usage(context, total_ai_cost, 'comprehensive_report_generation')
          
          result = safe_db_operation do
            # Crear registro del reporte
            report = AnalysisReport.create!(
              form_response: form_response,
              report_type: 'comprehensive_strategic_analysis',
              markdown_content: markdown_content,
              metadata: {
                generated_at: Time.current.iso8601,
                ai_models_used: ['gpt-4o', 'gpt-4o-mini'],
                total_ai_cost: total_ai_cost,
                analysis_depth: 'comprehensive',
                sections_included: [
                  'executive_summary',
                  'strategic_analysis', 
                  'technical_recommendations',
                  'risk_assessment',
                  'implementation_roadmap',
                  'financial_projections'
                ]
              },
              status: 'completed'
            )
            
            # Generar archivo MD para descarga
            filename = generate_report_filename(form_response, 'strategic_analysis')
            file_path = generate_downloadable_report(markdown_content, filename)
            
            # Actualizar form_response con el reporte
            form_response.update!(
              analysis_report_id: report.id,
              final_analysis_completed_at: Time.current
            )
            
            # Actualizar créditos de IA del usuario
            user = form_response.form.user
            user.consume_ai_credit(total_ai_cost) if user.respond_to?(:consume_ai_credit)
            
            {
              report: report,
              file_path: file_path,
              filename: filename,
              download_url: "/reports/#{report.id}/download",
              ai_cost: total_ai_cost
            }
          end
          
          if result[:error]
            return format_error_result("Failed to save report", result[:type], result)
          end
          
          format_success_result({
            report_id: result[:report].id,
            download_url: result[:download_url],
            filename: result[:filename],
            file_size: markdown_content.bytesize,
            ai_cost: result[:ai_cost],
            completed_at: Time.current.iso8601
          })
        end
      end
    end
    
    # Los métodos privados van FUERA del bloque workflow
    private
    
    def calculate_completion_duration(form_response)
      return 0 unless form_response.started_at && form_response.completed_at
      ((form_response.completed_at - form_response.started_at) / 1.minute).round(2)
    end
    
    def build_structured_responses(form_response)
      responses = {}
      
      form_response.question_responses.includes(:form_question).each do |qr|
        question = qr.form_question
        responses[question.title] = {
          value: qr.answer_data['value'],
          question_type: question.question_type,
          response_time_ms: qr.response_time_ms,
          ai_analysis: qr.ai_analysis_results,
          position: question.position
        }
      end
      
      responses
    end
    
    def collect_ai_analyses(form_response)
      analyses = {
        sentiment_scores: [],
        quality_indicators: [],
        confidence_levels: [],
        key_insights: []
      }
      
      form_response.question_responses.each do |qr|
        if qr.ai_analysis_results.present?
          analysis = qr.ai_analysis_results
          analyses[:sentiment_scores] << analysis['sentiment'] if analysis['sentiment']
          analyses[:quality_indicators] << analysis['quality_indicators'] if analysis['quality_indicators']
          analyses[:confidence_levels] << analysis['confidence_score'] if analysis['confidence_score']
          
          if analysis['insights']
            analyses[:key_insights].concat(analysis['insights'])
          end
        end
      end
      
      analyses
    end
    
    def collect_dynamic_questions_data(form_response)
      dynamic_data = []
      
      form_response.dynamic_questions.includes(:responses).each do |dq|
        dynamic_data << {
          title: dq.title,
          question_type: dq.question_type,
          generation_context: dq.generation_context,
          ai_confidence: dq.ai_confidence,
          answered: dq.responses.any?,
          answer: dq.responses.first&.answer_data,
          generated_from: dq.generated_from_question&.title
        }
      end
      
      dynamic_data
    end
    
    def calculate_completion_percentage(form_response)
      total_questions = form_response.form.form_questions.count
      answered_questions = form_response.question_responses.count
      return 0 if total_questions.zero?
      
      (answered_questions.to_f / total_questions * 100).round(2)
    end
    
    def calculate_response_quality_indicators(form_response)
      responses = form_response.question_responses
      return {} if responses.empty?
      
      {
        avg_response_time: responses.average(:response_time_ms)&.to_f || 0,
        detailed_responses_count: responses.joins(:form_question)
                                          .where(form_questions: { question_type: ['text_long', 'text_short'] })
                                          .count { |qr| qr.answer_data['value'].to_s.length > 50 },
        total_text_length: responses.sum { |qr| qr.answer_data['value'].to_s.length },
        ai_confidence_avg: responses.where.not(ai_confidence_score: nil)
                                  .average(:ai_confidence_score)&.to_f || 0
      }
    end
    
    def format_strategic_analysis_prompt(comprehensive_data)
      responses = comprehensive_data[:structured_responses]
      metadata = comprehensive_data[:metadata]
      enrichment = comprehensive_data[:enrichment_data]
      scoring = comprehensive_data[:scoring_data]
      
      <<~PROMPT
        Analyze the following business evaluation data and provide a deep strategic analysis.
        
        **DATOS DE LA EMPRESA:**
        #{format_company_data(enrichment)}
        
        **RESPUESTAS DEL FORMULARIO:**
        #{format_responses_for_analysis(responses)}
        
        **MÉTRICAS DE CALIDAD:**
        - Porcentaje de Completitud: #{metadata[:completion_rate]}%
        - Tiempo Promedio por Respuesta: #{metadata[:quality_indicators][:avg_response_time]&.to_i || 0}ms
        - Respuestas Detalladas: #{metadata[:quality_indicators][:detailed_responses_count]}
        
        **PUNTUACIÓN DE LEAD (si disponible):**
        #{scoring ? format_scoring_data(scoring) : 'No disponible'}
        
        **ANÁLISIS REQUERIDO (JSON):**
        {
          "executive_summary": "Resumen ejecutivo de máximo 3 párrafos",
          "strategic_positioning": {
            "current_state": "Evaluación del estado actual",
            "ai_readiness_level": "beginner|intermediate|advanced",
            "competitive_advantages": ["ventaja1", "ventaja2"],
            "strategic_gaps": ["gap1", "gap2"]
          },
          "business_impact_assessment": {
            "primary_value_drivers": ["driver1", "driver2"],
            "estimated_roi_range": "Rango de ROI estimado",
            "timeline_to_value": "3-6 months|6-12 months|12+ months",
            "success_metrics": ["métrica1", "métrica2"]
          },
          "transformation_priority": {
            "urgency_level": "low|medium|high|critical",
            "complexity_assessment": "simple|moderate|complex|highly_complex",
            "resource_requirements": "Evaluación de recursos necesarios",
            "change_management_needs": "Evaluación de gestión del cambio"
          },
          "next_steps_recommendation": [
            "Paso inmediato 1",
            "Paso inmediato 2",
            "Paso inmediato 3"
          ]
        }
        
        **INSTRUCCIONES:**
        - Be specific and actionable in all recommendations
        - Considera el contexto de la industria y tamaño de empresa
        - Evaluate both opportunities and risks
        - Proporciona estimaciones realistas de tiempo y recursos
      PROMPT
    end
    
    def format_technical_recommendations_prompt(comprehensive_data, strategic_analysis)
      responses = comprehensive_data[:structured_responses]
      enrichment = comprehensive_data[:enrichment_data]
      
      <<~PROMPT
        Based on the strategic analysis and technical data, generate specific technical recommendations.
        
        **ANÁLISIS ESTRATÉGICO PREVIO:**
        #{strategic_analysis['strategic_positioning']&.to_json || 'No disponible'}
        
        **DATOS TÉCNICOS DISPONIBLES:**
        #{extract_technical_responses(responses)}
        
        **CONTEXTO DE LA EMPRESA:**
        #{format_company_technical_context(enrichment)}
        
        **RECOMENDACIONES TÉCNICAS REQUERIDAS (JSON):**
        {
          "architecture_recommendations": {
            "deployment_model": "cloud|hybrid|on_premise",
            "recommended_platforms": ["platform1", "platform2"],
            "integration_approach": "Estrategia de integración",
            "scalability_considerations": "Consideraciones de escalabilidad"
          },
          "technology_stack": {
            "ai_frameworks": ["framework1", "framework2"],
            "data_infrastructure": ["tool1", "tool2"],
            "development_tools": ["tool1", "tool2"],
            "monitoring_solutions": ["solution1", "solution2"]
          },
          "implementation_phases": [
            {
              "phase": "Phase 1: Foundation",
              "duration": "2-3 months",
              "deliverables": ["deliverable1", "deliverable2"],
              "success_criteria": ["criteria1", "criteria2"]
            }
          ],
          "resource_requirements": {
            "technical_team_size": "Número recomendado",
            "skill_requirements": ["skill1", "skill2"],
            "external_support_needed": "Tipo de soporte externo",
            "budget_considerations": "Consideraciones presupuestarias"
          },
          "data_requirements": {
            "data_sources_needed": ["source1", "source2"],
            "data_quality_requirements": "Requisitos de calidad",
            "privacy_compliance": ["GDPR", "CCPA", "etc"],
            "governance_framework": "Marco de gobernanza recomendado"
          }
        }
      PROMPT
    end
    
    def format_risk_analysis_prompt(comprehensive_data, strategic_analysis, technical_recommendations)
      <<~PROMPT
        Perform a comprehensive risk analysis based on all available data.
        
        **ANÁLISIS DE RIESGOS REQUERIDO (JSON):**
        {
          "technical_risks": [
            {
              "risk": "Descripción del riesgo técnico",
              "probability": "low|medium|high",
              "impact": "low|medium|high|critical",
              "mitigation_strategies": ["estrategia1", "estrategia2"]
            }
          ],
          "business_risks": [
            {
              "risk": "Descripción del riesgo de negocio",
              "probability": "low|medium|high",
              "impact": "low|medium|high|critical",
              "mitigation_strategies": ["estrategia1", "estrategia2"]
            }
          ],
          "organizational_risks": [
            {
              "risk": "Descripción del riesgo organizacional",
              "probability": "low|medium|high",
              "impact": "low|medium|high|critical",
              "mitigation_strategies": ["estrategia1", "estrategia2"]
            }
          ],
          "financial_risks": [
            {
              "risk": "Descripción del riesgo financiero",
              "probability": "low|medium|high",
              "impact": "low|medium|high|critical",
              "mitigation_strategies": ["estrategia1", "estrategia2"]
            }
          ],
          "overall_risk_assessment": {
            "risk_level": "low|medium|high|critical",
            "key_risk_factors": ["factor1", "factor2"],
            "recommended_risk_tolerance": "conservative|moderate|aggressive",
            "contingency_planning": "Plan de contingencia recomendado"
          }
        }
      PROMPT
    end
    
    def format_final_report_prompt(comprehensive_data, strategic_analysis, technical_recommendations, risk_analysis)
      basic_data = comprehensive_data[:basic_data]
      
      <<~PROMPT
        Generate a comprehensive executive report in Markdown format using ALL previous analyses.
        
        **ESTRUCTURA REQUERIDA DEL REPORTE:**
        
        # Reporte de Evaluación Estratégica: Transformación Digital con IA
        
        **Cliente:** [Extraer de datos]
        **Fecha:** #{Date.current.strftime('%d de %B, %Y')}
        **ID de Evaluación:** #{basic_data[:response][:id]}
        
        ## Resumen Ejecutivo
        [3-4 párrafos que resuman los hallazgos clave, recomendaciones principales y próximos pasos]
        
        ## 1. Análisis de la Situación Actual
        ### 1.1 Perfil de la Organización
        [Información de la empresa basada en datos enriquecidos]
        
        ### 1.2 Estado de Madurez en IA
        [Evaluación del nivel actual]
        
        ### 1.3 Desafíos Identificados
        [Principales pain points]
        
        ## 2. Análisis Estratégico
        ### 2.1 Oportunidades de Valor
        [Drivers de valor identificados]
        
        ### 2.2 Posicionamiento Competitivo
        [Análisis competitivo]
        
        ### 2.3 Alineación Estratégica
        [Alineación con objetivos de negocio]
        
        ## 3. Recomendaciones Técnicas
        ### 3.1 Arquitectura Propuesta
        [Arquitectura técnica recomendada]
        
        ### 3.2 Stack Tecnológico
        [Tecnologías específicas]
        
        ### 3.3 Consideraciones de Implementación
        [Detalles de implementación]
        
        ## 4. Análisis de Riesgos y Mitigación
        ### 4.1 Matriz de Riesgos
        [Tabla de riesgos con probabilidad e impacto]
        
        ### 4.2 Estrategias de Mitigación
        [Estrategias específicas]
        
        ## 5. Roadmap de Implementación
        ### 5.1 Fases de Implementación
        [Cronograma detallado por fases]
        
        ### 5.2 Hitos y Entregables
        [Hitos clave y entregables]
        
        ### 5.3 Recursos Requeridos
        [Recursos humanos y técnicos]
        
        ## 6. Proyecciones Financieras
        ### 6.1 Inversión Estimada
        [Costos por fase]
        
        ### 6.2 ROI Proyectado
        [Retorno de inversión esperado]
        
        ### 6.3 Modelo de Financiamiento
        [Opciones de financiamiento]
        
        ## 7. Próximos Pasos Recomendados
        ### 7.1 Acciones Inmediatas (0-30 días)
        [Pasos inmediatos]
        
        ### 7.2 Planificación a Corto Plazo (1-3 meses)
        [Planificación corto plazo]
        
        ### 7.3 Visión a Largo Plazo (6-12 meses)
        [Visión largo plazo]
        
        ## 8. Conclusiones
        [Conclusiones finales y recomendación general]
        
        ---
        
        **Nota:** Este reporte ha sido generado mediante análisis de IA basado en la información proporcionada durante la evaluación. Las recomendaciones deben ser validadas con el contexto específico de su organización.
        
        **INSTRUCCIONES PARA LA GENERACIÓN:**
        1. Usa TODOS los datos de los análisis previos
        2. Mantén un tono profesional y ejecutivo
        3. Incluye datos específicos y métricas cuando estén disponibles
        4. Haz referencias cruzadas entre secciones cuando sea relevante
        5. Asegúrate de que el reporte sea accionable y específico
        6. Incluye tablas en formato Markdown cuando sea apropiado
        7. El reporte debe tener entre 2500-4000 palabras
        8. Cada sección debe ser sustantiva y detallada
      PROMPT
    end
    
    # Helper methods for formatting data
    def format_company_data(enrichment)
      return "No hay datos de empresa disponibles" if enrichment.blank?
      
      [
        "- Empresa: #{enrichment[:company_name] || 'No especificada'}",
        "- Industria: #{enrichment[:industry] || 'No especificada'}",
        "- Tamaño: #{enrichment[:company_size] || 'No especificado'}",
        "- Ubicación: #{enrichment[:location] || 'No especificada'}",
        "- Website: #{enrichment[:website] || 'No especificado'}"
      ].join("\n")
    end
    
    def format_responses_for_analysis(responses)
      responses.map do |question, data|
        "- #{question}: #{data[:value]} (Tipo: #{data[:question_type]})"
      end.join("\n")
    end
    
    def format_scoring_data(scoring)
      [
        "- Puntuación General: #{scoring[:overall_score]}/100",
        "- Tier: #{scoring[:tier]}",
        "- Nivel de Confianza: #{scoring[:confidence_level]}",
        "- Valor Estimado: #{scoring[:estimated_value]}"
      ].join("\n")
    end
    
    def extract_technical_responses(responses)
      technical_questions = responses.select do |question, data|
        question.downcase.include?('tecnolog') || 
        question.downcase.include?('sistem') ||
        question.downcase.include?('plataform') ||
        data[:question_type].in?(['multiple_choice', 'checkbox'])
      end
      
      if technical_questions.any?
        technical_questions.map { |q, d| "- #{q}: #{d[:value]}" }.join("\n")
      else
        "No hay información técnica específica disponible"
      end
    end
    
    def format_company_technical_context(enrichment)
      return "No hay contexto técnico disponible" if enrichment.blank?
      
      tech_info = []
      tech_info << "- Tecnologías identificadas: #{enrichment[:technologies]&.join(', ')}" if enrichment[:technologies]
      tech_info << "- Industria: #{enrichment[:industry]}" if enrichment[:industry]
      tech_info << "- Tamaño de empresa: #{enrichment[:company_size]}" if enrichment[:company_size]
      
      tech_info.any? ? tech_info.join("\n") : "Contexto técnico limitado"
    end
    
    def generate_report_filename(form_response, report_type)
      company_name = form_response.enrichment_data&.[](:company_name) || 'Unknown_Company'
      sanitized_name = company_name.gsub(/[^a-zA-Z0-9]/, '_')
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      
      "#{sanitized_name}_#{report_type}_#{timestamp}.md"
    end
    
    def generate_downloadable_report(content, filename)
      # Crear directorio si no existe
      reports_dir = Rails.root.join('tmp', 'reports')
      FileUtils.mkdir_p(reports_dir)
      
      # Escribir archivo
      file_path = reports_dir.join(filename)
      File.write(file_path, content)
      
      file_path.to_s
    end
  end
end