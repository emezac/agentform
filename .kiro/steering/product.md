# Product Document: mydialogform

## 1. Product Vision & Purpose

**Vision:** To be the **"Agentic Pioneer"** in form building, redefining data capture by transforming it into an AI-driven intelligence platform.

**Core Purpose:** mydialogform transforms the creation of static forms into the development of intelligent, conversational applications. Our goal is to move beyond simple data collection to offer a robust platform that orchestrates complex workflows, analyzes responses in real-time, and automates critical business processes through the native integration of the **SuperAgent** framework.

## 2. Product Strategy

Our go-to-market strategy is the **"Reliable Disruptor"**:

1.  **Phase 1 (Adoption):** Attract a solid user base by offering the generosity and unlimited features of competitors like Youform, combined with the design quality and user experience of Typeform in our free tier.
2.  **Phase 2 (Differentiation):** Rapidly evolve into a form intelligence platform. Our competitive advantage will not be just form building, but the unique capabilities of our **AI Agents** to qualify leads (BANT/CHAMP), analyze feedback, generate dynamic questions, and automate complex actions.
3.  **Phase 3 (Platform Leadership):** Solidify our position as a developer-centric platform with an "API-first" approach, allowing mydialogform to become the intelligent data capture engine for any application or service.

## 3. Key Objectives & Value Proposition

mydialogform solves problems for three primary audiences with distinct value propositions:

*   **For Form Creators (Marketing, HR, Ops):**
    *   **Value:** Stop building "dumb" forms and start building intelligent "agents" that work for you.
    *   **Objectives:**
        *   Enable the creation of dynamic, conversational forms without writing code.
        *   Automate lead qualification, feedback analysis, and response segmentation.
        *   Deliver actionable, AI-generated insights and optimization suggestions directly in the analytics dashboard.

*   **For Form Responders (Customers, Candidates):**
    *   **Value:** A seamless, personalized, and respectful experience that feels more like a conversation than an interrogation.
    *   **Objectives:**
        *   Reduce form fatigue with one-question-at-a-time flows and smart conditional logic.
        *   Provide an enriched interaction with AI-generated follow-up questions that show the system "understands" their answers.
        *   Ensure a flawless and accessible mobile experience.

*   **For Developers & Technical Teams:**
    *   **Value:** A robust and extensible platform for integrating intelligent data capture into any application.
    *   **Objectives:**
        *   Provide a comprehensive RESTful API and, eventually, a GraphQL API for total flexibility.
        *   Offer multi-language SDKs (JavaScript, Python, Ruby) to accelerate development.
        *   Expose SuperAgent's A2A (Agent-to-Agent) protocol for advanced interoperability between systems.

## 4. Target Audience & Personas

We have defined three primary user archetypes that align with our pricing plans:

1.  **Paul the Creator (Creator Plan):**
    *   **Role:** Freelancer, student, early-stage startup founder.
    *   **Needs:** Requires powerful, professional-looking tools for personal projects or idea validation on a limited budget. Values the generosity of the free plan (unlimited forms & responses).
    *   **Use Case:** Creating a contact form for his portfolio, a survey for a university project, or a waitlist signup form.

2.  **Maria the Marketing Manager (Pro Plan):**
    *   **Role:** Marketing Manager or team lead at a growing SME.
    *   **Needs:** Needs to qualify leads efficiently, gather customer feedback, remove mydialogform branding, and collaborate with her team. Values advanced analytics, CRM integrations, and A/B testing capabilities.
    *   **Use Case:** Building a lead qualification form that syncs with HubSpot, a Net Promoter Score (NPS) survey, and a webinar registration form with a payment gateway.

3.  **David the Solutions Architect (Agent Plan):**
    *   **Role:** Sales Engineer, Solutions Architect, or Product Lead at a mid-to-large enterprise.
    *   **Needs:** Seeks to automate complex, high-value business processes. Requires deep native integrations (Salesforce), full API access, and the ability to build complex interactive apps (ROI calculators, customer onboarding).
    *   **Use Case:** Implementing a BANT sales qualification agent, connecting it directly to Salesforce, and notifying the sales team in Slack. Using the API to feed a real-time internal dashboard.

## 5. Core Product Principles

These principles must guide every design and engineering decision we make:

1.  **AI at the Core, Not as an Add-on:** Every facet of the product, from form building to analytics, must be enhanced by AI. This is not about adding "AI features," but about building a fundamentally intelligent platform.
2.  **Superior User Experience:** The interface must be clean, intuitive, and aesthetically pleasing. The complexity of AI should be invisible to the user, manifesting as simplicity and power. We are inspired by the quality of Typeform.
3.  **Platform, Not Just a Tool:** We build for extensibility. Everything doable in the UI must be possible via the API. We foster an ecosystem of integrations.
4.  **Spec-Driven Development:** We embrace the Kiro methodology. Clarity in requirements, design, and tasks is paramount to building a robust and maintainable product.
5.  **Enterprise-Grade Reliability:** From day one, we build with the mindset that our agents will run mission-critical processes for our customers. This demands a rigorous focus on testing (95%+ coverage), monitoring, security, and performance.

## 6. Tech Stack & Architecture Summary

*   **Core Tech Stack:**
    *   **Framework:** Rails 7.1+
    *   **Database:** PostgreSQL
    *   **AI/Agent Framework:** SuperAgent
    *   **Frontend:** Tailwind CSS & Turbo Streams
    *   **Background Processing:** Sidekiq with Redis

*   **Core Architecture Pattern:** Logic flows in a predictable, scalable pattern:
    **Controllers → Agents → Workflows → Tasks (LLM/DB/Stream) → Services**

This document will serve as the source of truth for the vision and direction of mydialogform, ensuring that Kiro and the entire development team build consistently toward a unified goal.
