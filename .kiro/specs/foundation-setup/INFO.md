Kiro: Un editor de código de IA de Amazon
25 sources
Los textos abordan Kiro, una nueva interfaz de desarrollo integrado (IDE) asistida por IA de Amazon, que busca superar a competidores como Cursor y Claude Code mediante un flujo de trabajo de desarrollo impulsado por especificaciones. Kiro permite a los usuarios definir requisitos, diseños y tareas detalladas antes de la implementación, utilizando modelos de lenguaje grandes como Claude Sonnet. Aunque es elogiada por su enfoque estructurado, manejo de contexto y capacidad para integrar herramientas externas (MCP), los usuarios en la fase de vista previa reportan problemas de lentitud, límites de uso frecuentes y errores al reintentar tareas, lo que a veces compromete su usabilidad. Kiro también ofrece ganchos para la automatización de tareas y "steering" para guiar la IA con reglas y contexto específicos del proyecto, lo que la hace atractiva para prácticas de ingeniería maduras y para escalar el desarrollo de software.

Dada la informacion necesito los documentos MD necesarios para crear la app en Kiro, considera tambien los txt que son las interfaz de UI necesarios para el proyecto

Para crear una aplicación en Kiro utilizando su enfoque de desarrollo impulsado por especificaciones (spec-driven development), necesitarías principalmente los siguientes documentos Markdown (.md), que son fundamentales en el flujo de trabajo de Kiro:
1. Archivos de "Steering": Estos documentos en Markdown son cruciales para proporcionarle a Kiro un conocimiento persistente sobre tu proyecto, incluyendo las convenciones, librerías y estándares de tu equipo. Se almacenan en la carpeta .kiro/steering/. Kiro puede generar documentos de steering iniciales que cubren:
    ◦ El propósito y los objetivos de tu producto (product.md).
    ◦ La pila tecnológica y los frameworks utilizados (tech.md), como Python, Terraform, AWS serverless.
    ◦ La estructura del proyecto y las convenciones (structure.md).
    ◦ Principios de desarrollo de productos, pautas de arquitectura y software de la empresa. Estos archivos aseguran una generación de código consistente, reducen la repetición y alinean a todos los desarrolladores con los mismos estándares.
2. requirements.md: Este archivo define los requisitos de la aplicación en forma de historias de usuario con criterios de aceptación, a menudo utilizando la notación EARS (Easy Approach to Requirements Syntax). En esta fase, describes qué quieres lograr y qué problemas resolverá la aplicación, sin detallar cómo se resolverá. Kiro te guía en la estructuración de estos requisitos.
3. design.md: Basándose en los requisitos definidos y el contexto de los archivos de steering, Kiro genera este documento que detalla el diseño técnico y el enfoque de implementación. Puede incluir diagramas de secuencia (como los de Mermaid) y ejemplos de código para ilustrar la arquitectura y el flujo de trabajo. Este es el paso donde se define cómo se abordará la solución.
4. tasks.md: Una vez que el diseño es satisfactorio, Kiro genera un listado de tareas discretas y rastreables para la implementación. Cada tarea representa un paso específico en el proceso de construcción, y Kiro puede ejecutarlas una por una.
Respecto a los archivos .txt como interfaz de usuario (UI): Las fuentes proporcionadas no mencionan explícitamente el uso de archivos .txt para definir interfaces de usuario. Kiro es un IDE impulsado por IA que transforma tus objetivos en requisitos, diseños y código generado. La interfaz de usuario de Kiro se describe como "más pulcra" y menos propensa a errores que la de otros editores.
En Kiro, puedes:
• Proporcionar entradas multimodales, como imágenes de diseños de UI o fotos de sesiones de arquitectura, para guiar la implementación.
• Kiro generará código funcional para la UI, como lo demostró al crear un juego de Tetris retro con un menú funcional y estilos que coincidían con el tema retro descrito.
• El documento UX.md discute principios de diseño UX/UI para aplicaciones SaaS, enfocándose en elementos como la claridad, el diseño centrado en el usuario, la consistencia y la accesibilidad, lo que implica que la UI se construye a través de la codificación y el diseño, no a partir de descripciones en archivos de texto plano.
En resumen, los documentos .md (steering, requirements, design, tasks) son el corazón del proceso de Kiro para estructurar el desarrollo, y la UI se construye a partir de las especificaciones y el código generado por la IA, no mediante archivos .txt como definición de interfaz.
OK dame entonces el product.md dada la informacion ingestada

Basándome en la información proporcionada, el archivo product.md es un documento crucial dentro de la carpeta .kiro/steering/. Este archivo forma parte de la dirección (steering) que le das a Kiro, proporcionándole un conocimiento persistente sobre tu proyecto.
Aunque los fuentes no ofrecen un ejemplo completo de un product.md, sí describen su propósito y el tipo de contenido que debe incluir:
• Propósito del Producto y Objetivos: Define el propósito del producto y sus objetivos. Se centra en el contexto y los principios comunes del desarrollo del producto.
• Contexto General de la Aplicación: Documenta la aplicación y su propósito, tal como se menciona en el ejemplo de la aplicación de pronóstico del tiempo, donde la sección de "Introducción" del requirements.md establece que la especificación creará una aplicación de pronóstico del tiempo para ser desplegada con Terraform en infraestructura sin servidor de AWS. Esto implica que el product.md podría establecer el propósito general de la aplicación antes de entrar en requisitos detallados.
• Principios de Desarrollo de Productos y Pautas Empresariales: Incluye principios de desarrollo de productos, pautas de arquitectura y software de la empresa. Esto es información crucial para que Kiro genere resultados que coincidan con las preferencias de la compañía y el equipo.
• Conocimiento Escalaable del Proyecto: Actúa como documentación que crece con tu base de código, capturando decisiones y patrones a medida que el proyecto evoluciona.
• Consistencia y Alineación del Equipo: Asegura que Kiro siga consistentemente los patrones y estándares establecidos de tu equipo, reduciendo la necesidad de explicarlos en cada conversación y alineando a todos los desarrolladores.
En el contexto de la aplicación "AgentForm", si tuviéramos que crear un product.md basándonos en la información disponible (especialmente los documentos TODO_BLUEPRINT.md y TODO_FINAL.md), incluiría la visión, la estrategia y los objetivos generales del producto, así como los principios clave que guían su desarrollo.
Un posible esquema del product.md para AgentForm podría ser:
# Documento del Producto: AgentForm

## 1. Visión y Propósito del Producto

**Visión:** "Agentic Pioneer" - Redefinir la construcción de formularios con un enfoque centrado en la IA y la integración de SuperAgent [5].

**Propósito Principal:** Transformar el desarrollo de formularios con capacidades impulsadas por IA, moviéndose de prototipos a sistemas de producción, y ofrecer una plataforma robusta para la creación de aplicaciones de IA [6, 7].

## 2. Estrategia de Producto

**Estrategia Inicial ("Reliable Disruptor"):** Comenzar ofreciendo la generosidad de Youform (posiblemente refiriéndose a funciones gratuitas o ilimitadas) y la calidad de Typeform [5].

**Evolución:** Convertirse en una plataforma de inteligencia de formularios impulsada por IA [5].

## 3. Objetivos Clave y Propuesta de Valor

*   **Creación de Formularios Mejorada por IA:** Permitir la creación de formularios inteligentes con análisis de IA, generación dinámica de preguntas y optimización [5, 8, 9].
*   **Integración de Flujos de Trabajo Agénticos:** Utilizar el framework SuperAgent para orquestar la lógica del formulario, el procesamiento de respuestas y las integraciones [5, 10].
*   **Experiencia de Usuario Superior:** Proporcionar una interfaz de usuario limpia, pulida e intuitiva [11-15].
*   **Capacidades de Desarrollo Estructurado:** Fomentar un flujo de trabajo de desarrollo impulsado por especificaciones para asegurar claridad en los requisitos, el diseño y las tareas [7, 16-20].
*   **Enfoque en la Preparación para la Producción:** Ir más allá de los prototipos para ofrecer aplicaciones de IA escalables, con memoria persistente, integraciones ricas y soporte completo de despliegue [6, 19, 21].

## 4. Pila Tecnológica y Principios Arquitectónicos (Resumen)

*   **Marco de Trabajo Principal:** Rails 7.1+ con PostgreSQL [5, 10].
*   **Estilo:** Tailwind CSS para el diseño [5, 10].
*   **Actualizaciones en Tiempo Real:** Turbo Streams [5, 10].
*   **Procesamiento en Segundo Plano:** Sidekiq con Redis para caching y sesiones [5, 10].
*   **Modelo de Arquitectura Central:** Controladores → Agentes → Flujos de Trabajo → Tareas (LLM/DB/Stream) → Servicios [5, 10].
*   **Preferencias de Kiro:** Fomentar el uso de archivos Markdown para la dirección (steering) y especificaciones, garantizando un conocimiento persistente sobre el proyecto [1, 2, 22].

## 5. Principios de Diseño UX/UI (Aplicables a AgentForm)

*   **Claridad y Simplicidad:** Interfaz funcional y estética sin abrumar al usuario [15].
*   **Diseño Centrado en el Usuario (UCD):** Priorizar las necesidades y comportamientos del usuario [15].
*   **Consistencia:** Uniformidad en el diseño a través de diseños, colores, fuentes y terminología estandarizados [15].
*   **Accesibilidad y Diseño Responsivo:** Funcionar perfectamente en varios dispositivos y tamaños de pantalla, con un enfoque mobile-first [15].
*   **Rendimiento y Velocidad:** Optimizar para tiempos de carga rápidos y una experiencia fluida [15].
*   **Manejo de Errores:** Proporcionar mensajes claros, accionables y empáticos para la recuperación del usuario [15].
*   **Personalización:** Utilizar datos del usuario e IA para experiencias hiperpersonalizadas y predictivas [15].

Este `product.md` actuaría como la base para que Kiro entienda la dirección general de la aplicación AgentForm, permitiéndole generar requisitos, diseños y código más alineados con la visión del producto [20, 23].
Ok dame el tech.md, considerando que sera la gema super_agent, rails, postgres y talwind

Aquí tienes el documento tech.md para tu proyecto AgentForm, basado en la información proporcionada y considerando el uso de la gema SuperAgent, Rails, PostgreSQL y Tailwind CSS como elementos centrales. Este documento, almacenado en .kiro/steering/, le proporcionará a Kiro un conocimiento persistente sobre las bases técnicas de tu proyecto, asegurando una generación de código consistente.
# Pila Tecnológica del Proyecto: AgentForm

Este documento describe la fundación técnica y las herramientas para el proyecto AgentForm, guiando a Kiro en la generación de código consistente y alineado con los estándares del equipo [1, 3].

## 1. Pila Tecnológica Principal

*   **Framework de Desarrollo:** Rails 7.1+ [4, 5].
*   **Base de Datos:** PostgreSQL [4, 5].
*   **Framework de IA/Agentes:** SuperAgent workflow framework [4, 5].
*   **Estilizado (CSS):** Tailwind CSS [4, 5].
*   **Actualizaciones en Tiempo Real:** Turbo Streams [4].
*   **Procesamiento en Segundo Plano:** Sidekiq [4, 6].
*   **Caché y Sesiones:** Redis [4, 6].

## 2. Arquitectura de la Aplicación

*   **Patrón de Arquitectura Central:** Controladores → Agentes → Flujos de Trabajo (Workflows) → Tareas (LLM/DB/Stream) → Servicios [4, 5].
*   **Base de Clases:** Se implementarán clases base para todas las capas de la arquitectura [5].
*   **Manejo de Errores y Logging:** Configuración robusta para manejo de errores y logging [5].
*   **Serialización:** Se definirán estándares para la serialización de solicitudes y respuestas [5].

## 3. Base de Datos

*   **Configuración:** Configuración de la base de datos PostgreSQL [5].
*   **Extensiones:** Habilitación de la extensión UUID y `pgcrypto` para identificadores únicos [5, 7].
*   **Esquema de Tablas Clave:**
    *   `Users`: Tabla de usuarios con roles, preferencias y configuración de IA [5, 8].
    *   `Forms`: Tabla de formularios con configuraciones JSON, tokens para compartir y referencia de usuario [5, 8].
    *   `FormQuestions`, `FormResponses`, `QuestionResponses`, `FormAnalytics`, `DynamicQuestions` [5].

## 4. Procesamiento en Segundo Plano

*   **Configuración de Redis:** Redis para caché y sesiones [6].
*   **Configuración de Sidekiq:** Sidekiq con múltiples colas: `default`, `ai_processing`, `integrations`, `analytics` [6].
*   **Políticas de Trabajos (Jobs):** Políticas de reintento y manejo de errores para trabajos en segundo plano [6].
*   **Monitoreo de Colas:** Configuración para monitoreo y alertas de colas [6].

## 5. Autenticación y Autorización

*   **Sistema de Autenticación:** Configuración de Devise con un modelo de usuario personalizado [6].
*   **Roles:** Permisos basados en roles (usuario, premium, admin) [6].
*   **Autenticación de API:** Sistema de autenticación con tokens de API [6].
*   **Gestión de Sesiones:** Manejo seguro de sesiones [6].

## 6. Construcción y Herramientas (Build System & Tools)

*   **CI/CD:** Se implementará una pipeline de CI/CD para [9]:
    *   Ejecución de pruebas unitarias y de integración.
    *   Chequeos de calidad de código (ej. RuboCop).
    *   Escaneo de vulnerabilidades de seguridad.
    *   Benchmarking de rendimiento.
    *   Reportes de cobertura de pruebas.
    *   Automatización de despliegue [9].
*   **Docker & Contenedores:** Multi-stage Docker build, imágenes basadas en Alpine para optimización de tamaño, health checks, monitoreo, configuración de usuario no-root y escaneo de seguridad [10]. Se usará Docker Compose para el entorno de desarrollo con PostgreSQL, Redis y contenedores de Sidekiq [10].

## 7. Observabilidad y Monitoreo

*   **Registro (Logging):** Configuración de un sistema centralizado de logging [5], idealmente integrado con AWS CloudWatch Logs si el despliegue es en AWS [11].
*   **Seguimiento de Errores:** Integración con Sentry para seguimiento de errores con filtrado personalizado, alertas y contexto de errores [12, 13].
*   **Monitoreo de Rendimiento:** Integración con herramientas como New Relic o Datadog para métricas personalizadas de SuperAgent workflows, rendimiento de consultas de DB, tiempos de respuesta de API y detección de fugas de memoria [13].
*   **Métricas y Dashboards:** Creación de dashboards con métricas clave para fiabilidad, rendimiento, costos y solicitudes fallidas [12, 14].
*   **Alertas:** Configuración de alertas para errores, rendimiento y cumplimiento de presupuestos [6, 12, 13].
*   **Health Checks:** Endpoints para monitoreo de salud básicos y detallados de componentes (DB, Redis, proveedores de IA, colas de trabajos en segundo plano) [12, 15].

## 8. Gestión de Costos (Relacionado con IA y AWS)

*   **Cálculos de Costo:** Se realizarán cálculos precisos de los costos de infraestructura y de operaciones de IA [16, 17].
*   **Presupuestos y Alertas:** Despliegue de presupuestos específicos de la solución basados en etiquetas de servicio con alertas para prevenir cargos inesperados [16, 17].
*   **Optimización de Costos de IA:** Caching inteligente de respuestas de IA, detección de consultas similares, optimización de selección de modelos y estrategias de procesamiento por lotes [17-19].

## 9. Documentación

*   **Formato:** Toda la documentación seguirá el formato Markdown y se almacenará en el directorio `docs/` [14].
*   **Claridad:** Preferencia por documentación simple y fácil de usar, sin sobrecomplicaciones [14].
*   **Diagramas:** Uso de herramientas para generar diagramas de arquitectura, flujo y secuencia, incluidos en el `README.md` principal [14]. Si se utiliza AWS, se aprovechará el AWS Labs Diagram MCP server para generar diagramas con íconos oficiales de AWS [14, 20].
*   **Análisis de Costos:** Documentación de análisis de costos con desgloses detallados, proyecciones y recomendaciones de optimización [14]. El AWS Labs Pricing MCP server se utilizará para cálculos de costos [14, 20].
*   **Guías:** Incluir guías de despliegue, solución de problemas y runbooks operacionales [14].
*   **TL;DR y Resumen Ejecutivo:** Proporcionar secciones `TL;DR` para facilitar el rápido entendimiento de los desarrolladores y un resumen ejecutivo para los interesados del proyecto [16].

## 10. Principios de Desarrollo

*   **Simplicidad:** Favorecer KISS (Keep It Simple, Stupid) sobre la complejidad, y la simplicidad sobre la comprensibilidad [16].
*   **Patrones de Arquitectura:** Respetar y adoptar patrones de arquitectura e integración basados en la nube bien conocidos [16].
*   **Diseño Centrado en el Usuario (UCD):** Priorizar las necesidades, comportamientos y preferencias del usuario durante todo el proceso de diseño [21].
*   **Consistencia:** Mantener la uniformidad en el diseño a través de diseños, colores, fuentes y terminología estandarizados en toda la plataforma, apoyándose en un sistema de diseño con Tailwind CSS [21].
*   **Accesibilidad y Diseño Responsivo:** Asegurarse de que la plataforma sea accesible siguiendo los estándares WCAG y funcione perfectamente en varios dispositivos (desktop, móvil, tablet) con un enfoque mobile-first [21].
*   **Rendimiento y Velocidad:** Optimizar el rendimiento de la plataforma para garantizar tiempos de carga rápidos y una experiencia fluida [21].
*   **Manejo de Errores:** Anticipar y prevenir errores humanos, y proporcionar mensajes claros, accionables y empáticos para la recuperación del usuario [21].
*   **Personalización:** Utilizar la recopilación de datos del usuario y capacidades de IA para sugerir contenido y adaptar la interfaz a los intereses y comportamiento individual, impulsando experiencias hiperpersonalizadas y predictivas [21].
AHora dame el structure.md considerando la informacion provista y que es un proyecto rails

¡Excelente! Para asegurar que Kiro tenga un conocimiento persistente y granular sobre la organización de tu proyecto AgentForm, aquí tienes el documento structure.md. Este archivo, ubicado en .kiro/steering/, detallará la estructura de directorios y archivos, alineándose con las convenciones de Rails y los componentes tecnológicos que hemos definido.
# Estructura del Proyecto: AgentForm

Este documento define la organización de archivos y directorios del proyecto AgentForm, siguiendo las convenciones de Ruby on Rails y detallando la ubicación de los componentes clave para la gema SuperAgent, PostgreSQL, Sidekiq, Redis y Tailwind CSS. Esta estructura es crucial para que Kiro genere código de manera consistente y comprenda dónde se encuentran y cómo interactúan los diferentes módulos.

## 1. Directorios Raíz de Rails

El proyecto seguirá la estructura estándar de Rails, con algunas adiciones para los componentes específicos:

*   `.kiro/`: Contiene archivos de configuración y *steering* para Kiro.
    *   `steering/`: Archivos Markdown para guiar el comportamiento de la IA [1-4].
        *   `tech.md`: (Ya definido) Pila tecnológica y principios generales [5, 6].
        *   `structure.md`: (Este documento) Estructura de archivos y directorios.
        *   `product.md`: Contexto y principios de desarrollo de producto [3].
        *   `principles.md`: Principios generales de desarrollo (ej. KISS, patrones de arquitectura) [7].
        *   `testing.md`: Enfoque y estándares de pruebas [8].
        *   `costs.md`: Estrategias de gestión de costos.
    *   `specs/`: Documentación generada por Kiro para el desarrollo dirigido por especificaciones (Requirements, Design, Tasks) [9-11].
        *   `[nombre-de-la-feature]/`: Directorio por cada especificación.
            *   `requirements.md`: Requisitos de la feature en formato EARS [10-13].
            *   `design.md`: Documento de diseño técnico [14, 15].
            *   `tasks.md`: Lista de tareas de implementación generadas [15, 16].
*   `app/`: Código principal de la aplicación.
*   `bin/`: Scripts ejecutables.
*   `config/`: Archivos de configuración de la aplicación.
*   `db/`: Esquemas y migraciones de la base de datos.
*   `docs/`: Documentación del proyecto (manuales, guías, etc.) [17].
*   `lib/`: Módulos de código personalizados que no encajan en `app/`.
*   `log/`: Archivos de registro.
*   `public/`: Archivos estáticos servidos directamente.
*   `tmp/`: Archivos temporales.
*   `vendor/`: Dependencias de terceros no gestionadas por Gems.
*   `test/` o `spec/`: Archivos de pruebas (dependiendo del framework de pruebas elegido, ej. Minitest o RSpec).
*   `Gemfile`, `Gemfile.lock`: Gestión de dependencias de Ruby.
*   `README.md`: Descripción general del proyecto.

## 2. Estructura del Directorio `app/`

El directorio `app/` contendrá la lógica principal del negocio, siguiendo el patrón de arquitectura **Controladores → Agentes → Flujos de Trabajo (Workflows) → Tareas (LLM/DB/Stream) → Servicios** [18, 19].

*   `app/assets/`:
    *   `stylesheets/`:
        *   `application.tailwind.css`: Archivo principal de Tailwind CSS.
        *   `_variables.css`, `_components.css`: Archivos personalizados de Tailwind.
    *   `javascripts/`:
        *   `controllers/`: Controladores de Stimulus para la interactividad del frontend [20].
            *   `form_builder_controller.js`, `question_editor_controller.js` [20].
            *   `form_response_controller.js`, `question_type_controllers.js` [20].
        *   `application.js`: Punto de entrada de JavaScript.
*   `app/channels/`: Para WebSockets y Turbo Streams.
*   `app/controllers/`: Controladores web.
    *   `application_controller.rb`: Clase base para controladores [19].
    *   `api/`: Controladores para la API REST/GraphQL.
        *   `api_base_controller.rb`: Clase base para controladores de API con autenticación y manejo de errores [21].
        *   `v1/`: Versionado de la API.
            *   `forms_controller.rb`, `form_responses_controller.rb` [22].
    *   `forms_controller.rb`, `users_controller.rb`: Controladores principales.
    *   `sessions_controller.rb`, `registrations_controller.rb` (Devise).
*   `app/helpers/`: Módulos con funciones de ayuda para las vistas.
*   `app/jobs/`: Trabajos en segundo plano de Sidekiq.
    *   `application_job.rb`: Clase base para jobs.
    *   `forms/`: Jobs específicos para formularios.
        *   `workflow_generation_job.rb`, `workflow_regeneration_job.rb` [23].
        *   `response_analysis_job.rb`, `dynamic_question_generation_job.rb`, `ai_insight_generation_job.rb` [24].
        *   `integration_trigger_job.rb`, `completion_workflow_job.rb` [25].
        *   `analytics_processing_job.rb`, `insight_generation_job.rb` [26, 27].
*   `app/mailers/`: Clases para el envío de correos electrónicos.
*   `app/models/`: Modelos de ActiveRecord y preocupaciones (concerns).
    *   `application_record.rb`: Clase base.
    *   `user.rb`: Modelo de usuario con roles y configuración de IA [28-30].
        *   `concerns/`: Módulos de lógica reutilizable.
            *   `encryptable.rb` [29].
    *   `form.rb`: Modelo de formulario con configuraciones JSON y tokens de compartir [28, 30, 31].
        *   `concerns/`:
            *   `cacheable.rb` [31].
    *   `form_question.rb`: Preguntas de formulario con lógica condicional [19, 32].
    *   `form_response.rb`: Respuestas del formulario con análisis de IA [28, 33].
    *   `question_response.rb`: Respuestas individuales a preguntas [28, 33].
    *   `form_analytic.rb`: Métricas de rendimiento y análisis [28].
    *   `dynamic_question.rb`: Preguntas generadas por IA [28].
    *   `api_token.rb`: Tokens para autenticación de API [29].
    *   `form_template.rb` (opcional) [31].
*   `app/policies/`: (Si se usa Pundit o similar para autorización).
*   `app/services/`: Clases de servicio para la lógica de negocio compleja, siguiendo la arquitectura propuesta [19].
    *   `application_service.rb`: Clase base para servicios.
    *   `forms/`: Servicios relacionados con formularios.
        *   `answer_processing_service.rb`, `navigation_service.rb`, `workflow_generator_service.rb` [25].
        *   `ai_enhancement_service.rb`, `analytics_service.rb` [34].
        *   `data_export_service.rb`, `cache_service.rb` [34].
        *   `data_privacy_service.rb`, `security_service.rb`, `backup_service.rb` [21, 27].
        *   `a2a_service.rb`: Para la generación de Agent Cards [35].
    *   `forms/integrations/`: Servicios para integraciones externas.
        *   `salesforce_service.rb`, `hubspot_service.rb` [36].
        *   `mailchimp_service.rb` [37].
    *   `forms/ai_usage_tracker.rb`: Seguimiento de costos de IA [37].
*   `app/agents/`: Clases para la gema SuperAgent.
    *   `application_agent.rb`: Clase base.
    *   `forms_management_agent.rb` [38].
    *   `forms_response_agent.rb` [39].
*   `app/workflows/`: Clases para los flujos de trabajo de SuperAgent.
    *   `application_workflow.rb`: Clase base con configuraciones comunes [40].
    *   `form_response_processing_workflow.rb` [41].
    *   `ai_analysis_workflow.rb` [42].
    *   `dynamic_question_generation_workflow.rb` [38].
    *   `form_optimization_workflow.rb` [36].
    *   `lead_qualification_workflow.rb` [36].
*   `app/views/`:
    *   `layouts/`: Plantillas de diseño.
    *   `forms/`, `users/`: Vistas específicas de recursos.
    *   `shared/`: Vistas parciales reutilizables.
    *   `components/`: Componentes reutilizables (ej. con ViewComponents).
*   `app/validators/`: Validadores personalizados (ej. `email_validator.rb`).

## 3. Estructura del Directorio `config/`

*   `config/application.rb`: Configuración global de Rails.
*   `config/routes.rb`: Definición de rutas.
*   `config/database.yml`: Configuración de PostgreSQL [19].
*   `config/environments/`: Configuraciones por entorno (`development.rb`, `production.rb`, `test.rb`) [19].
*   `config/initializers/`: Archivos de inicialización.
    *   `super_agent.rb`: Configuración de la gema SuperAgent (ej. proveedor LLM, timeout) [43, 44].
    *   `devise.rb`: Configuración de Devise para autenticación [44].
    *   `sidekiq.rb`: Configuración de Sidekiq (colas, Redis) [44].
    *   `redis.rb`: Configuración de conexión a Redis [44].
    *   `tailwind.rb`: Posible configuración específica de Tailwind.
*   `config/locales/`: Archivos para internacionalización.
*   `config/tailwind.config.js`: Configuración personalizada de Tailwind CSS [19].

## 4. Estructura del Directorio `db/`

*   `db/migrate/`: Archivos de migración de la base de datos.
    *   `001_enable_uuid_extension.rb`: Habilita `pgcrypto` para UUIDs [19, 43].
    *   `002_create_users.rb`: Crea la tabla `users` [19, 28].
    *   `003_create_forms.rb`: Crea la tabla `forms` [19, 28].
    *   `004_create_form_questions.rb`, `005_create_form_responses.rb`, etc. [19].
*   `db/schema.rb`: Esquema actual de la base de datos.
*   `db/seeds.rb`: Datos iniciales para la base de datos.

## 5. Pruebas

*   `test/` o `spec/`:
    *   `models/`, `controllers/`, `services/`, `jobs/`, `agents/`, `workflows/`: Pruebas unitarias, de integración y de rendimiento para cada componente [45, 46].
    *   `system/`: Pruebas de sistema/end-to-end.
    *   `support/`: Archivos de configuración y utilidades para pruebas.

Esta estructura proporciona una base sólida para el desarrollo, facilitando la colaboración, el mantenimiento y, lo más importante, permitiendo que Kiro opere con una comprensión profunda y coherente del proyecto AgentForm.
Ahora genera el requirements.md

¡Claro! Aquí tienes el documento requirements.md para la fase inicial de "Fundación y Configuración Central" del proyecto AgentForm. Este archivo se ubicará en .kiro/steering/specs/foundation-setup/requirements.md y guiará a Kiro en la comprensión de los objetivos funcionales de esta etapa.
# Documento de Requisitos: Fundación y Configuración Central de AgentForm

## Introducción

Este documento especifica los requisitos iniciales para la configuración fundamental y los modelos centrales de la aplicación AgentForm, enfocándose en la infraestructura clave, la arquitectura, el diseño de la base de datos y la integración de componentes esenciales como SuperAgent, Sidekiq y Redis. Los requisitos están definidos como historias de usuario con criterios de aceptación en notación EARS (Easy Approach to Requirements Syntax).

### Requisito 1

**Historia de Usuario:** Como desarrollador, necesito un entorno de aplicación Rails moderno y bien configurado para construir AgentForm, que me permita enfocarme en la lógica de negocio.

#### Criterios de Aceptación

1.  **WHEN** se configura la aplicación Rails **THEN** el sistema **SHALL** usar Rails 7.1+ con PostgreSQL como base de datos [1, 2].
2.  **WHEN** se configura la aplicación **THEN** el sistema **SHALL** integrar Tailwind CSS con una configuración personalizada para el estilizado [1, 2].
3.  **WHEN** se integra la funcionalidad de IA **THEN** el sistema **SHALL** incluir y configurar la gema SuperAgent [2, 3].
4.  **WHEN** se implementa el frontend **THEN** el sistema **SHALL** utilizar Turbo Streams para actualizaciones de interfaz en tiempo real [1].
5.  **WHEN** se prepara la aplicación para diferentes etapas de desarrollo **THEN** el sistema **SHALL** tener configuraciones específicas para los entornos de desarrollo, staging y producción [2].

### Requisito 2

**Historia de Usuario:** Como desarrollador, necesito una arquitectura de aplicación clara y escalable que soporte el desarrollo basado en agentes y facilite la construcción de funcionalidades complejas.

#### Criterios de Aceptación

1.  **WHEN** se define la arquitectura **THEN** el sistema **SHALL** seguir el patrón Controladores → Agentes → Workflows → Tareas (LLM/DB/Stream) → Servicios [1, 2].
2.  **WHEN** se inicializa la aplicación **THEN** el sistema **SHALL** establecer clases base para cada capa arquitectónica (Controladores, Agentes, Workflows, Tareas, Servicios) [2].
3.  **WHEN** ocurren errores **THEN** el sistema **SHALL** implementar un mecanismo centralizado de manejo de errores y logging [2].
4.  **WHEN** se procesan datos **THEN** el sistema **SHALL** aplicar un esquema de serialización de solicitudes y respuestas consistente [2].

### Requisito 3

**Historia de Usuario:** Como desarrollador, necesito un esquema de base de datos robusto y flexible para almacenar y gestionar eficientemente todos los datos de la aplicación.

#### Criterios de Aceptación

1.  **WHEN** se inicializa la base de datos **THEN** el sistema **SHALL** habilitar la extensión `pgcrypto` para soportar UUIDs como identificadores primarios [2, 3].
2.  **WHEN** se gestionan usuarios **THEN** el sistema **SHALL** incluir una tabla `Users` con campos para email, contraseña encriptada, nombre, apellido, rol (user, admin, premium), preferencias y configuración de IA [2, 4].
3.  **WHEN** se crean formularios **THEN** el sistema **SHALL** incluir una tabla `Forms` con nombre, descripción, estado, categoría, un `share_token` único, referencia al usuario, y campos JSON para configuraciones (ej. `form_settings`, `ai_configuration`, `style_configuration`, `integration_settings`) [2, 4].
4.  **WHEN** se diseñan preguntas de formulario **THEN** el sistema **SHALL** incluir una tabla `FormQuestions` que soporte la posición y la lógica condicional [2].
5.  **WHEN** se recopilan respuestas de formularios **THEN** el sistema **SHALL** incluir una tabla `FormResponses` con campos para almacenar y analizar las respuestas asistidas por IA [2].
6.  **WHEN** se almacenan respuestas a preguntas individuales **THEN** el sistema **SHALL** incluir una tabla `QuestionResponses` para un seguimiento granular de metadatos [2].
7.  **WHEN** se monitorea el rendimiento de los formularios **THEN** el sistema **SHALL** incluir una tabla `FormAnalytics` para almacenar métricas de rendimiento [2].
8.  **WHEN** se generan preguntas dinámicas por IA **THEN** el sistema **SHALL** incluir una tabla `DynamicQuestions` para gestionar estas preguntas de seguimiento [2].

### Requisito 4

**Historia de Usuario:** Como desarrollador, necesito que la aplicación AgentForm utilice la gema SuperAgent y gestione las tareas en segundo plano de manera eficiente y confiable.

#### Criterios de Aceptación

1.  **WHEN** se configura SuperAgent **THEN** el sistema **SHALL** especificar el proveedor LLM (ej. `openai`), el modelo LLM por defecto (ej. `gpt-4o-mini`), el tiempo de espera del workflow (`workflow_timeout`) y si el servidor A2A está habilitado (`a2a_server_enabled` y `a2a_server_port`) [3, 5].
2.  **WHEN** se procesan tareas asíncronas **THEN** el sistema **SHALL** utilizar Sidekiq con múltiples colas dedicadas (ej. `default`, `ai_processing`, `integrations`, `analytics`) [5].
3.  **WHEN** se requiere persistencia de datos o un intermediario para tareas asíncronas **THEN** el sistema **SHALL** configurar Redis para caching y sesiones [1, 5].
4.  **WHEN** un trabajo en segundo plano falla **THEN** el sistema **SHALL** aplicar políticas de reintento y un manejo robusto de errores para los trabajos de Sidekiq [5].
5.  **WHEN** se gestionan las tareas en segundo plano **THEN** el sistema **SHALL** implementar monitoreo y alertas para el estado de las colas de Sidekiq [5].

### Requisito 5

**Historia de Usuario:** Como usuario y administrador, necesito un sistema de autenticación y autorización seguro y flexible para controlar el acceso a la aplicación.

#### Criterios de Aceptación

1.  **WHEN** un usuario se registra o inicia sesión **THEN** el sistema **SHALL** utilizar Devise para la autenticación, integrado con el modelo de usuario personalizado [5].
2.  **WHEN** se gestionan los permisos de usuario **THEN** el sistema **SHALL** implementar una autorización basada en roles (user, premium, admin) [5].
3.  **WHEN** se accede a la API **THEN** el sistema **SHALL** soportar un sistema de autenticación basado en tokens de API [5].
4.  **WHEN** se establecen sesiones de usuario **THEN** el sistema **SHALL** implementar una gestión segura de sesiones [5].

Esta estructura ayudará a Kiro a entender los requisitos de alto nivel y a generar un diseño e implementación que se ajusten a tus expectativas para la base de AgentForm.
Ok ahora genera el tasks.md

¡Excelente! Aquí tienes el documento tasks.md para la fase de "Fundación y Configuración Central" del proyecto AgentForm. Este archivo detalla los pasos de implementación basados en los requisitos que definimos, guiando a Kiro a través de las acciones concretas necesarias.
Este archivo se ubicará en .kiro/steering/specs/foundation-setup/tasks.md.
# Plan de Implementación: Fundación y Configuración Central de AgentForm

Este documento desglosa los requisitos de la fase de "Fundación y Configuración Central" en tareas discretas y accionables. Cada tarea está asociada con los criterios de aceptación específicos de los requisitos para asegurar una implementación estructurada y verificable.

## 1. Configuración de la Aplicación Rails

- [ ] **1.1 Configurar la aplicación Rails 7.1+ con PostgreSQL.**
    - Crear una nueva aplicación Rails 7.1+.
    - Configurar `database.yml` para usar PostgreSQL.
    - _Requisitos: 1.1_

- [ ] **1.2 Integrar y configurar Tailwind CSS.**
    - Añadir las gemas necesarias para Tailwind CSS.
    - Configurar `tailwind.config.js` con una configuración personalizada.
    - _Requisitos: 1.2_

- [ ] **1.3 Integrar y configurar la gema SuperAgent.**
    - Añadir la gema `super_agent` al `Gemfile`.
    - Crear `config/initializers/super_agent.rb` con la configuración inicial (proveedor LLM, modelo por defecto, timeouts).
    - _Requisitos: 1.3, 4.1_

- [ ] **1.4 Implementar Turbo Streams para actualizaciones en tiempo real.**
    - Asegurar que Hotwire (Turbo y Stimulus) esté configurado por defecto en Rails 7.1+.
    - _Requisitos: 1.4_

- [ ] **1.5 Establecer configuraciones específicas para entornos de desarrollo, staging y producción.**
    - Crear y/o ajustar `config/environments/development.rb`, `config/environments/staging.rb` y `config/environments/production.rb`.
    - _Requisitos: 1.5_

## 2. Implementación de la Arquitectura Central

- [ ] **2.1 Definir y establecer las clases base para la arquitectura Controladores → Agentes → Workflows → Tareas → Servicios.**
    - Crear módulos o clases base en `app/controllers`, `app/agents`, `app/workflows`, `app/tasks`, `app/services` según el patrón.
    - _Requisitos: 2.1, 2.2_

- [ ] **2.2 Implementar un mecanismo centralizado de manejo de errores y logging.**
    - Configurar un `ApplicationError` o similar y un interceptor de errores global.
    - Configurar las opciones de logging de Rails y, si es necesario, integrar una gema de logging.
    - _Requisitos: 2.3_

- [ ] **2.3 Aplicar un esquema de serialización de solicitudes y respuestas consistente.**
    - Definir un formato estándar para las respuestas JSON (ej. usando Jbuilder o una gema de serialización).
    - _Requisitos: 2.4_

## 3. Diseño e Implementación del Esquema de Base de Datos

- [ ] **3.1 Habilitar la extensión `pgcrypto` para UUIDs.**
    - Crear una migración `db/migrate/001_enable_uuid_extension.rb` que habilite `pgcrypto`.
    - _Requisitos: 3.1_

- [ ] **3.2 Crear la tabla `Users`.**
    - Generar una migración para la tabla `users` con campos para email, contraseña encriptada, nombre, apellido, rol, preferencias y configuración de IA. Usar UUID como `id` primario.
    - _Requisitos: 3.2_

- [ ] **3.3 Crear la tabla `Forms`.**
    - Generar una migración para la tabla `forms` con nombre, descripción, estado, categoría, `share_token` único, referencia al usuario y campos JSON para configuraciones. Usar UUID como `id` primario.
    - _Requisitos: 3.3_

- [ ] **3.4 Crear la tabla `FormQuestions`.**
    - Generar una migración para `form_questions` incluyendo posición y un campo JSON para lógica condicional. Usar UUID como `id` primario.
    - _Requisitos: 3.4_

- [ ] **3.5 Crear la tabla `FormResponses`.**
    - Generar una migración para `form_responses` con campos para almacenar y analizar respuestas asistidas por IA. Usar UUID como `id` primario.
    - _Requisitos: 3.5_

- [ ] **3.6 Crear la tabla `QuestionResponses`.**
    - Generar una migración para `question_responses` para un seguimiento granular de metadatos. Usar UUID como `id` primario.
    - _Requisitos: 3.6_

- [ ] **3.7 Crear la tabla `FormAnalytics`.**
    - Generar una migración para `form_analytics` para almacenar métricas de rendimiento. Usar UUID como `id` primario.
    - _Requisitos: 3.7_

- [ ] **3.8 Crear la tabla `DynamicQuestions`.**
    - Generar una migración para `dynamic_questions` para gestionar preguntas de seguimiento generadas por IA. Usar UUID como `id` primario.
    - _Requisitos: 3.8_

## 4. Configuración de SuperAgent, Sidekiq y Redis

- [ ] **4.1 Configurar los parámetros de SuperAgent.**
    - Asegurar que `config/initializers/super_agent.rb` contenga la configuración para `llm_provider`, `default_llm_model`, `workflow_timeout`, `a2a_server_enabled` y `a2a_server_port`.
    - _Requisitos: 4.1_

- [ ] **4.2 Configurar Redis para caching y sesiones.**
    - Instalar y configurar Redis.
    - Configurar Rails para usar Redis como cache store y session store.
    - _Requisitos: 4.3_

- [ ] **4.3 Configurar Sidekiq con múltiples colas dedicadas.**
    - Añadir la gema `sidekiq` al `Gemfile`.
    - Configurar `config/sidekiq.yml` con colas como `default`, `ai_processing`, `integrations`, `analytics`.
    - _Requisitos: 4.2_

- [ ] **4.4 Implementar políticas de reintento y manejo de errores robusto para Sidekiq.**
    - Configurar las opciones de reintento de Sidekiq y manejar excepciones comunes en los jobs.
    - _Requisitos: 4.4_

- [ ] **4.5 Implementar monitoreo y alertas para el estado de las colas de Sidekiq.**
    - Integrar un panel de monitoreo (ej. Sidekiq Web UI) y configurar alertas básicas.
    - _Requisitos: 4.5_

## 5. Implementación de Autenticación y Autorización

- [ ] **5.1 Configurar Devise con el modelo de usuario personalizado.**
    - Añadir la gema `devise` al `Gemfile`.
    - Configurar Devise e integrarlo con el modelo `User` existente.
    - _Requisitos: 5.1_

- [ ] **5.2 Implementar autorización basada en roles (user, premium, admin).**
    - Utilizar la columna `role` en la tabla `Users` para definir permisos.
    - Implementar lógica de autorización (ej. con Pundit o CanCanCan) para controlar el acceso a recursos.
    - _Requisitos: 5.2_

- [ ] **5.3 Soportar un sistema de autenticación basado en tokens de API.**
    - Crear una tabla para `ApiTokens` y generar tokens únicos para los usuarios para acceso a la API.
    - Implementar un mecanismo para validar estos tokens en las solicitudes de la API.
    - _Requisitos: 5.3_

- [ ] **5.4 Implementar gestión segura de sesiones.**
    - Asegurar que la configuración de sesiones de Rails sea segura (cookies HTTP-only, secure, etc.).
    - _Requisitos: 5.4_

