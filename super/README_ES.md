# SuperAgent 🤖

**Un framework de orquestación de flujos de trabajo de IA nativo de Rails para construir aplicaciones verdaderamente agénticas.**

SuperAgent unifica la orquestación de flujos de trabajo de IA complejos con las interacciones MVC nativas de Rails, permitiéndote crear aplicaciones SaaS potentes que van más allá de los simples chatbots.

[![Gem Version](https://badge.fury.io/rb/super_agent.svg)](https://badge.fury.io/rb/super_agent)
[![Build Status](https://github.com/superagent-rb/super_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/superagent-rb/super_agent/actions/workflows/ci.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/YOUR_BADGE_ID/maintainability)](https://codeclimate.com/github/superagent-rb/super_agent/maintainability)

---

## ¿Qué es SuperAgent?

SuperAgent es un framework diseñado para desarrolladores de Rails que desean integrar capacidades avanzadas de IA en sus aplicaciones. En lugar de realizar llamadas aisladas a una API de LLM, SuperAgent te permite definir, orquestar y ejecutar flujos de trabajo de varios pasos (workflows) que pueden interactuar con tus modelos de base de datos, enviar correos electrónicos, autorizar usuarios, realizar búsquedas web y mucho más.

Es la capa de lógica que conecta tus modelos de IA con el resto de tu aplicación Rails, permitiéndote construir sistemas complejos y autónomos.

## Conceptos Fundamentales

-   **Workflows (Flujos de trabajo):** El corazón de SuperAgent. Son definiciones de procesos de varios pasos escritos en un DSL (Lenguaje Específico de Dominio) de Ruby. Un workflow podría ser cualquier cosa, desde generar un artículo de blog (investigación → redacción → guardado) hasta calificar un lead de ventas (validación → enriquecimiento → análisis → acción).
-   **Tasks (Tareas):** Los bloques de construcción de un workflow. Cada `task` es un paso individual con un propósito específico. SuperAgent viene con una rica biblioteca de tareas predefinidas (LLM, ActiveRecord, ActionMailer, Pundit, etc.), y puedes crear las tuyas fácilmente.
-   **Agents (Agentes):** El puente entre tu aplicación Rails (p. ej., un controlador) y tus Workflows. Los agentes gestionan la creación del contexto inicial, la seguridad (como el usuario actual) y deciden qué workflow ejecutar.
-   **Context (Contexto):** Un objeto inmutable que transporta el estado a través de un workflow. La salida de una tarea se fusiona en el contexto, haciéndola disponible para las tareas posteriores.

## ✨ Características Principales

-   **DSL Fluido y Expresivo:** Define workflows complejos de manera legible y mantenible directamente en Ruby.
-   **Integración Profunda con Rails:**
    -   **ActiveRecord:** Consulta y encuentra registros de la base de datos como un paso nativo.
    -   **ActionMailer:** Envía correos electrónicos directamente desde un workflow.
    -   **Pundit:** Aplica políticas de autorización antes de ejecutar tareas.
    -   **Turbo Streams:** Envía actualizaciones a la UI en tiempo real a medida que el workflow progresa.
    -   **ActiveJob:** Ejecuta workflows de larga duración en segundo plano sin bloquear las solicitudes.
-   **Soporte Multi-Proveedor de LLM:** Cambia fácilmente entre **OpenAI**, **OpenRouter** y **Anthropic** sin cambiar la lógica de tu workflow.
-   **Biblioteca de Tareas Extensa:** Incluye tareas para llamadas a LLM, búsqueda web, generación de imágenes, operaciones de archivos (subida, búsqueda en RAG), gestión de Vector Stores, tareas programadas (cron) y más.
-   **Lógica Condicional y Manejo de Errores:** Controla el flujo de ejecución con `run_if` / `skip_if` y define políticas de reintento y manejadores de errores `on_error` a nivel de workflow o de tarea.
-   **Streaming en Tiempo Real:** Ofrece a tus usuarios una experiencia interactiva mostrando el progreso del workflow paso a paso.
-   **Generadores de Código:** Andamiaje rápido para nuevos workflows, agentes y recursos completos con `rails generate`.
-   **Observabilidad y Persistencia:** Registros detallados y un modelo `ExecutionModel` opcional para rastrear cada ejecución de workflow en tu base de datos.

## 🚀 Instalación

1.  Añade la gema a tu `Gemfile`:

    ```ruby
    gem 'super_agent'
    ```

2.  Instala la gema:

    ```bash
    bundle install
    ```

3.  Ejecuta el generador de instalación de SuperAgent:

    ```bash
    rails generate super_agent:install
    ```

    Esto creará los siguientes archivos:
    -   `config/initializers/super_agent.rb`
    -   `app/agents/application_agent.rb`
    -   `app/workflows/application_workflow.rb`

4.  (Opcional) Para persistir las ejecuciones de los workflows, genera y ejecuta la migración:
    ```bash
    rails generate super_agent:migration
    rails db:migrate
    ```

## ⚙️ Configuración

Abre `config/initializers/super_agent.rb` y configura tus claves de API. Como mínimo, necesitarás una para tu proveedor de LLM principal.

```ruby
# config/initializers/super_agent.rb

SuperAgent.configure do |config|
  # Elige tu proveedor de LLM principal: :openai, :open_router, :anthropic
  config.llm_provider = :openai

  # --- Configuración de OpenAI ---
  config.openai_api_key = ENV['OPENAI_API_KEY']

  # --- Configuración de OpenRouter ---
  config.open_router_api_key = ENV['OPENROUTER_API_KEY']

  # --- Configuración de Anthropic ---
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # Modelo de LLM por defecto
  config.default_llm_model = "gpt-4o-mini"

  # Asigna el logger de Rails
  config.logger = Rails.logger
end
```

## 🏁 Guía de Inicio Rápido

Vamos a crear un workflow simple que toma un texto, genera un resumen y determina su sentimiento.

**1. Crea el Workflow**

Usa el generador para crear un nuevo archivo de workflow:
```bash
rails generate super_agent:workflow TextAnalysis
```

Ahora, edita `app/workflows/text_analysis_workflow.rb`:

```ruby
# app/workflows/text_analysis_workflow.rb
class TextAnalysisWorkflow < ApplicationWorkflow
  workflow do
    # Paso 1: Generar un resumen usando un LLM
    llm :summarize_text do
      input :text_content # Espera :text_content del contexto inicial
      output :summary     # La salida se guardará como :summary en el contexto

      model "gpt-4o-mini"
      system_prompt "You are an expert in text summarization."
      # La plantilla usa llaves dobles para acceder a los datos del contexto
      prompt "Summarize the following text in one sentence: {{text_content}}"
    end

    # Paso 2: Analizar el sentimiento del resumen
    llm :analyze_sentiment do
      input :summarize_text # La entrada es la salida completa del paso anterior
      output :sentiment     # La salida será :sentiment

      system_prompt "You are an expert in sentiment analysis."
      prompt "What is the sentiment of the following text? (Positive, Negative, or Neutral): {{summarize_text}}"
    end

    # Paso 3: Formatear la salida final
    task :format_output do
      input :summarize_text, :analyze_sentiment

      # 'process' define un bloque de Ruby simple para ejecutar
      process do |summary, sentiment|
        {
          final_summary: summary.strip,
          detected_sentiment: sentiment.strip.downcase
        }
      end
    end
  end
end
```

**2. Crea el Agente**

```bash
rails generate super_agent:agent Text
```

Edita `app/agents/text_agent.rb` para llamar a nuestro nuevo workflow:

```ruby
# app/agents/text_agent.rb
class TextAgent < ApplicationAgent
  def analyze(text)
    # Ejecuta el workflow de forma síncrona, pasando el texto como entrada inicial
    run_workflow(TextAnalysisWorkflow, initial_input: { text_content: text })
  end
end
```

**3. Úsalo en un Controlador Rails**

```ruby
# app/controllers/texts_controller.rb
class TextsController < ApplicationController
  def analyze
    text_to_analyze = params[:text]
    agent = TextAgent.new(current_user: current_user) # Pasa el contexto de Rails al agente

    result = agent.analyze(text_to_analyze)

    if result.completed?
      render json: result.final_output
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end
end
```

¡Y eso es todo! Acabas de orquestar un workflow de IA de varios pasos completamente integrado en tu aplicación Rails.

## 📖 Guía de Uso

### Definiendo Workflows

El DSL `workflow` es el núcleo de SuperAgent. Aquí hay un desglose de sus capacidades:

```ruby
class MyWorkflow < ApplicationWorkflow
  workflow do
    # --- Configuración a nivel de Workflow ---
    timeout 60  # Timeout global en segundos
    retry_policy max_retries: 2, delay: 1 # Política de reintentos por defecto

    # --- Definición de Tareas ---

    # 1. Tarea de Ruby simple
    task :prepare_data do
      input :raw_data
      output :prepared_data
      process { |data| { processed: data.upcase } }
    end

    # 2. Tarea de LLM
    llm :generate_content do
      input :prepared_data
      model "gpt-4o-mini"
      temperature 0.7
      response_format :json # Parsea automáticamente la salida del LLM como JSON
      prompt "Generate content based on: {{prepared_data.processed}}"
    end

    # 3. Lógica Condicional
    task :notify_admin do
      # Solo se ejecuta si la condición es verdadera
      run_if { |context| context.get(:generate_content)["needs_review"] }

      # También disponible: skip_if, run_when(:key, value), skip_when(:key, value)

      process do |context|
        # ... lógica para enviar notificación
        { notified: true }
      end
    end

    # 4. Manejo de Errores
    on_error :generate_content do |error, context|
      # Este bloque se ejecuta si 'generate_content' falla
      Rails.logger.error "LLM falló: #{error.message}"
      { fallback_content: "Contenido no disponible." } # Devuelve un valor de respaldo
    end
  end
end
```

### Ejecución Asíncrona

Para tareas de larga duración, evita bloquear el ciclo de solicitud/respuesta de Rails ejecutando el workflow en segundo plano con ActiveJob.

```ruby
# en tu agente
class MyAgent < ApplicationAgent
  def perform_async(data)
    # Esto encola un trabajo y devuelve inmediatamente
    run_workflow_later(MyWorkflow, initial_input: { raw_data: data })
  end
end

# en tu controlador
def create
  agent = MyAgent.new
  agent.perform_async(params[:my_data])
  render json: { message: "El procesamiento ha comenzado en segundo plano." }, status: :accepted
end
```

### Tareas Disponibles

SuperAgent viene con una amplia gama de tipos de tareas listas para usar.

| Tipo de Tarea                 | Descripción                                                                 | Ejemplo de Uso                                                                                             |
| ----------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `task` (`:direct_handler`)    | Ejecuta un bloque de código Ruby.                                           | `task(:mi_logica) { process { ... } }`                                                                      |
| `llm` / `chat`                | Realiza una llamada a un LLM para completado de chat.                       | `llm(:resumir, "Resume: {{texto}}")`                                                                        |
| `validate`                    | Una tarea para la lógica de validación.                                     | `validate(:es_valido) { process { ... } }`                                                                  |
| `fetch` / `query`             | Consulta tu base de datos usando ActiveRecord.                              | `fetch(:get_user, "User") { find_by id: 1 }`                                                                |
| `email`                       | Envía un correo electrónico usando ActionMailer.                            | `email(:bienvenida, "UserMailer", "welcome")`                                                              |
| `stream`                      | Envía una actualización de Turbo Stream a la UI.                            | `stream(:actualizar_ui) { target "#mi_div" }`                                                              |
| `image`                       | Genera una imagen usando un modelo como DALL-E 3.                           | `image(:crear_logo, "Un logo para...")`                                                                     |
| `search`                      | Realiza una búsqueda web.                                                   | `search(:investigar, "Últimas noticias sobre IA")`                                                         |
| `upload_file`                 | Sube un archivo a OpenAI (para usar con Assistants/RAG).                    | `upload_file(:subir_doc, "path/to/doc.pdf")`                                                               |
| `vector_store_management`     | Crea o gestiona Vector Stores de OpenAI para RAG.                           | `task(:crear_vs, :vector_store_management)`                                                                |
| `file_search`                 | Realiza una búsqueda semántica dentro de tus Vector Stores.                 | `task(:buscar_en_docs, :file_search)`                                                                      |
| `:cron`                       | Programa un workflow para que se ejecute en un horario recurrente.          | `task(:reporte_diario, :cron, schedule: "0 9 * * *")`                                                       |
| `:pundit_policy`              | Verifica una política de Pundit antes de continuar.                         | `task(:autorizar, :pundit_policy, action: :update?)`                                                        |

### Generadores

Acelera tu desarrollo con los generadores de Rails:

-   `rails g super_agent:install`: Configura SuperAgent en tu aplicación.
-   `rails g super_agent:workflow [NombreWorkflow]`: Crea un nuevo workflow.
-   `rails g super_agent:agent [NombreAgente]`: Crea un nuevo agente.
-   `rails g super_agent:resource [NombreRecurso]`: Crea un workflow, un agente y archivos de prueba para un recurso CRUD.

### Pruebas (Testing)

Probar tus workflows es sencillo. Puedes probar la lógica del workflow de forma aislada, sin realizar llamadas reales a la API.

```ruby
# spec/workflows/text_analysis_workflow_spec.rb
require 'rails_helper'

RSpec.describe TextAnalysisWorkflow, type: :workflow do
  let(:context) { SuperAgent::Workflow::Context.new(text_content: "Este es un texto de prueba.") }
  let(:engine) { SuperAgent::WorkflowEngine.new }

  it "completa el workflow exitosamente" do
    # Simula la respuesta del LLM
    allow_any_instance_of(SuperAgent::Workflow::Tasks::LlmTask).to receive(:execute)
      .with(anything) # La primera llamada (resumen)
      .and_return("Resumen de prueba.")
      .once

    allow_any_instance_of(SuperAgent::Workflow::Tasks::LlmTask).to receive(:execute)
      .with(anything) # La segunda llamada (sentimiento)
      .and_return("Positive")
      .once

    result = engine.execute(TextAnalysisWorkflow, context)

    expect(result).to be_completed
    expect(result.final_output[:final_summary]).to eq("Resumen de prueba.")
    expect(result.final_output[:detected_sentiment]).to eq("positive")
  end
end
```

##  migrating?

Si vienes de otro framework como `ActiveAgent` o `rdawn`, consulta nuestra [Guía de Migración](examples/migration_guide.md) para facilitar la transición.

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Por favor, abre un issue para discutir cambios importantes o envía un pull request.

1.  Haz un fork del repositorio.
2.  Crea tu rama de funcionalidad (`git checkout -b mi-nueva-funcionalidad`).
3.  Haz commit de tus cambios (`git commit -am 'Añadir nueva funcionalidad'`).
4.  Empuja a la rama (`git push origin mi-nueva-funcionalidad`).
5.  Crea un nuevo Pull Request.

## 📜 Licencia

Este proyecto está licenciado bajo los términos de la licencia MIT. Consulta el archivo [LICENSE.txt](LICENSE.txt) para más detalles.
