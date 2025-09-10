class BlogsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  skip_after_action :verify_policy_scoped, only: [:index, :show], unless: :skip_authorization?
  skip_after_action :verify_authorized, only: [:index, :show], unless: :skip_authorization?
  
  def index
    @articles = [
      {
        id: 1,
        title: "How to Create Marketing Forms That Actually Convert",
        slug: "formularios-marketing-conversion",
        description: "Learn strategies and best practices for creating marketing forms that generate quality leads.",
        category: "Marketing",
        read_time: "6 min",
        author: "AgentForm Team",
        date: Date.current,
        content: content_marketing_forms
      },
      {
        id: 2,
        title: "Market Research: Forms That Reveal Valuable Insights",
        slug: "investigacion-mercados-formularios",
        description: "Discover how to design effective forms for collecting market data and better understanding your audience.",
        category: "Research",
        read_time: "8 min",
        author: "AgentForm Team",
        date: Date.current - 1.day,
        content: content_research_forms
      },
      {
        id: 3,
        title: "The 7 Essential Elements of Successful Forms",
        slug: "elementos-formulario-exitoso",
        description: "Conoce los componentes clave que todo formulario exitoso debe tener para maximizar las respuestas.",
        category: "Mejores Prácticas",
        read_time: "5 min",
        author: "AgentForm Team",
        date: Date.current - 2.days,
        content: content_essential_elements
      },
      {
        id: 4,
        title: "Formularios de Feedback: Cómo Medir la Satisfacción del Cliente",
        slug: "formularios-feedback-satisfaccion",
        description: "Guía completa para crear formularios de feedback que te ayuden a mejorar tu producto o servicio.",
        category: "Feedback",
        read_time: "7 min",
        author: "AgentForm Team",
        date: Date.current - 3.days,
        content: content_feedback_forms
      },
      {
        id: 5,
        title: "Technical Guide to Creating Effective Surveys with AgentForm",
        slug: "technical-guide-creating-effective-surveys-agentform",
        description: "Comprehensive technical guide for designing, implementing, and analyzing surveys using AgentForm platform.",
        category: "Technical Guide",
        read_time: "12 min",
        author: "AgentForm Team",
        date: Date.current - 4.days,
        content: content_technical_surveys
      }
    ]
  end
  
  def show
    @article = [
      {
        id: 1,
        title: "How to Create Marketing Forms That Actually Convert",
        slug: "formularios-marketing-conversion",
        description: "Learn strategies and best practices for creating marketing forms that generate quality leads.",
        category: "Marketing",
        read_time: "6 min",
        author: "AgentForm Team",
        date: Date.current,
        content: content_marketing_forms
      },
      {
        id: 2,
        title: "Market Research: Forms That Reveal Valuable Insights",
        slug: "investigacion-mercados-formularios",
        description: "Discover how to design effective forms for collecting market data and better understanding your audience.",
        category: "Research",
        read_time: "8 min",
        author: "AgentForm Team",
        date: Date.current - 1.day,
        content: content_research_forms
      },
      {
        id: 3,
        title: "The 7 Essential Elements of Successful Forms",
        slug: "elementos-formulario-exitoso",
        description: "Conoce los componentes clave que todo formulario exitoso debe tener para maximizar las respuestas.",
        category: "Mejores Prácticas",
        read_time: "5 min",
        author: "AgentForm Team",
        date: Date.current - 2.days,
        content: content_essential_elements
      },
      {
        id: 4,
        title: "Formularios de Feedback: Cómo Medir la Satisfacción del Cliente",
        slug: "formularios-feedback-satisfaccion",
        description: "Guía completa para crear formularios de feedback que te ayuden a mejorar tu producto o servicio.",
        category: "Feedback",
        read_time: "7 min",
        author: "AgentForm Team",
        date: Date.current - 3.days,
        content: content_feedback_forms
      },
      {
        id: 5,
        title: "Technical Guide to Creating Effective Surveys with AgentForm",
        slug: "technical-guide-creating-effective-surveys-agentform",
        description: "Comprehensive technical guide for designing, implementing, and analyzing surveys using AgentForm platform.",
        category: "Technical Guide",
        read_time: "12 min",
        author: "AgentForm Team",
        date: Date.current - 4.days,
        content: content_technical_surveys
      }
    ].find { |article| article[:slug] == params[:id] }
    
    redirect_to blogs_path, alert: "Article not found" unless @article
  end
  
  private
  
  def content_marketing_forms
    {
      introduction: "Marketing forms are powerful tools for capturing leads and converting visitors into potential customers. However, many forms fail in their main objective.",
      sections: [
        {
          title: "1. Define Your Objective Clearly",
          content: "Before creating your form, identify exactly what information you need to collect. Is it for a newsletter? For demos? For content downloads?"
        },
        {
          title: "2. Keep It Simple and Concise",
          content: "Each additional field reduces conversions. Only ask for essential information: name, email, and maybe company."
        },
        {
          title: "3. Use Smart Fields",
          content: "Implement conditional fields that only appear when relevant. This improves the experience and increases completion rates."
        },
        {
          title: "4. Provide Immediate Value",
          content: "Clearly explain what the user will get by completing the form: exclusive access, premium content, or free consultation."
        },
        {
          title: "5. Optimize for Mobile",
          content: "Over 60% of forms are completed on mobile devices. Make sure your form is fully responsive."
        }
      ],
      tips: [
        "Use descriptive placeholders instead of long labels",
        "Add real-time validation to avoid frustration",
        "Include a clear confirmation message after submission",
        "Test different versions with A/B testing"
      ]
    }
  end
  
  def content_research_forms
    {
      introduction: "Market research forms are fundamental for understanding your audience's needs, preferences, and behaviors.",
      sections: [
        {
          title: "1. Segment Your Audience",
          content: "Create specific forms for different segments. Questions for B2C consumers should be different from B2B questions."
        },
        {
          title: "2. Structure Your Research",
          content: "Divide your form into clear sections: demographic information, behavior, preferences, and specific feedback."
        },
        {
          title: "3. Use Response Scales",
          content: "Implement Likert scales (1-5) to measure attitudes and preferences quantitatively."
        },
        {
          title: "4. Include Open Questions",
          content: "Open-ended questions provide valuable qualitative insights you wouldn't get with closed options."
        },
        {
          title: "5. Incentivize Participation",
          content: "Offer incentives like discounts, exclusive access, or raffles to increase response rates."
        }
      ],
      tips: [
        "Keep the form between 5-10 minutes duration",
        "Test your form with a small group first",
        "Ensure compliance with privacy regulations",
        "Analyze data in real-time to adjust questions"
      ]
    }
  end
  
  def content_essential_elements
    {
      introduction: "A successful form combines design, functionality, and user psychology to maximize responses.",
      elements: [
        {
          name: "Attractive Title",
          description: "A clear and persuasive title that indicates exactly what to expect from the form."
        },
        {
          name: "Clear Instructions",
          description: "Brief explanation of why information is being collected and how it will be used."
        },
        {
          name: "Clean Visual Design",
          description: "Proper spacing, consistent colors, and readable typography."
        },
        {
          name: "Relevant Fields",
          description: "Only essential questions that provide real value to the process."
        },
        {
          name: "Smart Validation",
          description: "Friendly error messages and real-time validation."
        },
        {
          name: "Visible Progress",
          description: "Progress indicators for long forms."
        },
        {
          name: "Compelling CTA",
          description: "Clear and persuasive submit button with specific text."
        }
      ]
    }
  end
  
  def content_feedback_forms
    {
      introduction: "Feedback forms are essential tools for continuously improving your product or service.",
      sections: [
        {
          title: "1. Define the Purpose of Feedback",
          content: "Are you looking to improve a specific product, evaluate customer service, or measure overall satisfaction?"
        },
        {
          title: "2. Use Satisfaction Scales",
          content: "Implement 1-5 or 1-10 scales to measure satisfaction quantitatively."
        },
        {
          title: "3. Questions about Specific Experience",
          content: "Ask about concrete aspects: ease of use, product quality, response time."
        },
        {
          title: "4. Close with Action",
          content: "Ask if they would recommend your product and if they'd like to be contacted for more information."
        }
      ],
      questions: [
        "How satisfied are you with our product/service?",
        "What feature did you like the most?",
        "What would you improve?",
        "How likely are you to recommend our product?",
        "Would you like us to contact you?"
      ]
    }
  end
  
  def content_technical_surveys
    {
      introduction: "In today's dynamic business and organizational environment, the ability to understand consumers, employees, and the market as a whole is crucial for success. Surveys are a fundamental market research tool that allows collecting data from various aspects for subsequent interpretation and strategic decision-making. Whether it's to understand purchase intentions, evaluate job satisfaction, or understand customer preferences, a well-designed survey using AgentForm is an invaluable compass.",
      sections: [
        {
          title: "1. Planning and Survey Design (General Principles)",
          content: "The effectiveness of a survey lies in its planning, development, and direction. With AgentForm, you can implement these principles efficiently."
        },
        {
          title: "1.1 Decide if a Survey is the Right Tool",
          content: "Before starting, evaluate whether a survey is the most appropriate method for your situation. AgentForm provides templates to help you determine the best approach. Advantages include precision (5% margin of error), classification capabilities, valuable conclusions, easy result management, and immediate reception. Disadvantages include cost, expertise requirements, limited information, selection bias, potential errors, and fraud vulnerability."
        },
        {
          title: "1.2 Define Research Objectives",
          content: "This is the first and most crucial step. AgentForm's guided setup helps you formulate research problems correctly. Establish clear objectives using SMART framework (Specific, Measurable, Achievable, Relevant, Time-based). Analyze the situation including macro-environment, competition, and consumer profile."
        },
        {
          title: "1.3 Define Universe and Sample",
          content: "AgentForm's audience targeting features help you define representative samples. Universe is the total population for survey conclusions. Sample size can be estimated using built-in statistical tools, balancing cost with confidence level and expected error rate. For category classification, minimum sample should be 30 per category."
        },
        {
          title: "1.4 Questionnaire Design",
          content: "AgentForm's form builder provides templates for effective questionnaires. Scope your information needs, establish question order to avoid bias, use appropriate question types (closed for quantitative data, open for detailed insights), keep surveys short (under 30 questions), ensure clarity and neutrality, optimize for mobile, conduct pilot testing, guarantee confidentiality, and run awareness campaigns."
        },
        {
          title: "2. Segmentation for Effective Surveys",
          content: "AgentForm's advanced targeting features enable precise segmentation. Segmentation is creating subsets based on demographics, needs, priorities, common interests, and behavioral criteria. Benefits include reduced marketing costs, greater attention, better product development, and more satisfied customers."
        },
        {
          title: "2.1 Types of Segmentation",
          content: "Demographic (age, gender, income), Geographic (location-based), Behavioral (purchase habits, brand loyalty), Psychographic (attitudes, values, interests), Firmographic (B2B industry, size), and Technographic (technology usage). AgentForm allows you to implement all these segmentation types through custom fields and conditional logic."
        },
        {
          title: "2.2 Segmentation Mistakes to Avoid",
          content: "Avoid segmenting based on instincts rather than concrete data, using limited data, using 'dirty data', ignoring communication channels, not considering engagement timing, and not tracking segment performance over time. AgentForm's analytics help you avoid these pitfalls."
        },
        {
          title: "3. Survey Types and Specific Applications",
          content: "Different types of market research with distinct purposes that can be implemented using AgentForm."
        },
        {
          title: "3.1 Market Research Surveys",
          content: "AgentForm excels at market research helping understand purchase intentions, market growth, price estimation, and consumer behavior. Objectives include administrative (planning), social (customer needs), and economic (business success). Types include exploratory, descriptive, and explanatory research."
        },
        {
          title: "3.2 Customer Satisfaction Surveys (CX)",
          content: "AgentForm provides built-in NPS, CES, and satisfaction metrics. Essential metrics include Net Promoter Score (NPS), Customer Satisfaction Index, Customer Effort Score, Customer Health Score, churn rate, and customer reviews. AgentForm automatically calculates these metrics from your survey responses."
        },
        {
          title: "3.3 Employee Satisfaction Surveys (EX)",
          content: "AgentForm offers specialized templates for employee satisfaction including eNPS, ESI, happiness scales, pulse surveys, and 360-degree evaluations. Features include confidentiality controls, real-time reporting, and action plan creation based on results."
        },
        {
          title: "4. Data Collection and Analysis",
          content: "AgentForm's integrated analytics transform raw data into actionable insights. Define needed information before choosing methods. Collection methods include online surveys (AgentForm's primary strength), interviews, and observation. Data sources include sales data, web analytics, email marketing, CRM integration, and social media analytics."
        },
        {
          title: "4.1 Data Processing and Analysis",
          content: "AgentForm automatically processes and analyzes your survey data. Features include data cleaning, quantitative analysis with statistics, qualitative analysis of open responses, integration with statistical software, identification of improvement areas, and creation of SMART action plans."
        },
        {
          title: "5. Results Interpretation and Presentation",
          content: "AgentForm's reporting features help you interpret data and present results clearly. Generate reports and presentations highlighting key findings, use data visualization with charts and graphs, apply storytelling techniques, contextualize results with business objectives, and ensure follow-up with personalized action plans."
        },
        {
          title: "6. Recommended Tools and Integration",
          content: "AgentForm integrates with leading tools for comprehensive survey solutions. Recommended integrations include Google Analytics for user segmentation, CRM systems for customer data, email marketing platforms for distribution, and data visualization tools for advanced reporting. AgentForm serves as the central hub for all survey activities."
        }
      ],
      elements: [
        {
          name: "Smart Question Design",
          description: "Use AgentForm's AI-powered question suggestions to create effective, unbiased questions that yield actionable insights."
        },
        {
          name: "Mobile-First Approach",
          description: "AgentForm automatically optimizes all surveys for mobile devices, ensuring high completion rates across all platforms."
        },
        {
          name: "Real-Time Analytics",
          description: "Monitor responses as they come in with AgentForm's live dashboard, allowing immediate insights and quick adjustments."
        },
        {
          name: "Advanced Segmentation",
          description: "Leverage AgentForm's conditional logic and custom fields to create highly targeted surveys for specific audience segments."
        },
        {
          name: "Integration Capabilities",
          description: "Connect AgentForm with your existing tools through webhooks, API, and native integrations for seamless data flow."
        },
        {
          name: "Privacy and Security",
          description: "Ensure data protection with AgentForm's built-in privacy controls, GDPR compliance, and secure data handling."
        },
        {
          name: "Automated Follow-up",
          description: "Set up automated thank you messages, follow-up surveys, and action triggers based on responses using AgentForm workflows."
        }
      ],
      questions: [
        "How can AgentForm help reduce survey bias and improve data quality?",
        "What segmentation strategies work best with AgentForm's targeting features?",
        "How do I integrate AgentForm survey data with my existing CRM system?",
        "What are the best practices for mobile survey design using AgentForm?",
        "How can I use AgentForm's analytics to create actionable business insights?",
        "What privacy considerations should I implement when using AgentForm for sensitive surveys?"
      ],
      tips: [
        "Start with AgentForm's pre-built templates and customize them for your specific needs",
        "Use AgentForm's A/B testing features to optimize question wording and survey flow",
        "Implement progressive profiling with AgentForm to build customer profiles over time",
        "Leverage AgentForm's branching logic to create personalized survey experiences",
        "Set up automated reporting in AgentForm to share insights with stakeholders regularly",
        "Use AgentForm's collaboration features to involve team members in survey design and analysis"
      ]
    }
  end
end