UI Design Specifications for mydialogform
This document outlines the comprehensive UI/UX design system for the mydialogform application. It is based on the visual and interactive patterns established in the provided UI mockups.
1. Visual Design Language
Color Palette
The mydialogform palette combines a professional, cool-toned neutral base with a vibrant purple-to-indigo gradient for primary actions and AI-related features. Semantic colors are used for status and feedback.
code
Scss
// Primary & AI-related Colors
$ai-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
$primary-indigo: #6366f1;
$primary-purple: #8b5cf6;

// Semantic Colors
$success: #10b981;
$warning: #f59e0b; // Amber
$danger: #ef4444; // Red
$info: #3b82f6; // Blue

// Light Theme Neutrals (Tailwind Scale)
$gray-50: #f8fafc;   // Lightest backgrounds (Detail Panels)
$gray-100: #f1f5f9;  // Default light backgrounds
$gray-200: #e5e7eb;  // Borders
$gray-500: #6b7280;  // Muted text
$gray-700: #334155;  // Body text
$gray-900: #0f172a;  // Headings

// Dark Theme Neutrals (Response List)
$dark-bg-darker: #0f172a; // slate-900
$dark-bg-dark: #1e293b;   // slate-800
$dark-border: #334155;    // slate-700
$dark-text-light: #f1f5f9; // slate-100
$dark-text-muted: #94a3b8; // slate-400
Typography System
The design uses the 'Inter' font family for its clean and modern readability across all screen sizes.
code
Css
/* Base Font */
body { font-family: 'Inter', sans-serif; }

/* Headings */
h1 { font-size: 28px; font-weight: 700; color: $gray-900; } /* text-2xl font-bold */
h2 { font-size: 24px; font-weight: 700; color: $gray-900; } /* text-xl font-bold */
h3 { font-size: 20px; font-weight: 600; color: $gray-900; } /* text-lg font-semibold */
h4 { font-size: 16px; font-weight: 600; color: $gray-900; } /* text-base font-semibold */

/* Body Text */
.text-base { font-size: 16px; font-weight: 400; color: $gray-700; }
.text-sm { font-size: 14px; font-weight: 400; color: $gray-600; }
.text-xs { font-size: 12px; font-weight: 400; color: $gray-500; }

/* Special Text Styles */
.metric-value { font-size: 32px; font-weight: 800; color: $gray-900; }
.score-badge { font-weight: 600; color: white; }
.ai-enhanced-text { font-weight: 500; color: $primary-purple; }
Spacing & Layout Grid
A consistent 4px-based spacing scale is used, aligning with Tailwind CSS defaults. Layouts are clean, spacious, and adaptive.
code
Yaml
Spacing Scale (Tailwind mapping):
  - 4px (spacing-1)
  - 8px (spacing-2)
  - 16px (spacing-4)
  - 24px (spacing-6)
  - 32px (spacing-8)
  - 48px (spacing-12)

Container Widths:
  - Form Builder: 1024px (max-w-4xl)
  - Dashboards: 1280px (max-w-7xl)
  - Centered Forms: 768px (max-w-2xl)

Grid System:
  - Standard 12-column grid for complex layouts.
  - Frequent use of 2, 3, and 4-column grids for cards and metrics.
Component Library
Card Components
Cards are the primary way information is grouped and displayed.
Question Card (Form Builder)
code
Code
┌───────────────────────────────────┐
│ #  ⋮⋮  Question Title             │
│        [Type] [Required] [🤖 AI]  │
└───────────────────────────────────┘
Visuals: White background, soft shadow on hover, 8px radius, border-left (4px) color indicates status ($gray-200 default, $primary-purple for AI-enhanced, $primary-indigo for selected).
Interaction: Draggable, clickable to open configuration sidebar.
Agent/Template Card (Gallery View)
code
Code
┌───────────────────────────────────┐
│ ICON   Agent/Template Name        │
│        Description of the agent...│
├───────────────────────────────────┤
│ [Tag 1] [Tag 2]                   │
├───────────────────────────────────┤
│ AI Intensity: High    Integrations│
├───────────────────────────────────┤
│ [Preview Button] [Use Agent Button]│
└───────────────────────────────────┘
Visuals: White background, 1px border, 12px radius, pronounced shadow on hover.
Interaction: Hover causes a translateY(-4px) effect. Buttons provide clear actions.
AI Insight Card
code
Code
┌───────────────────────────────────┐
│ ✨ AI Summary & Recommendation    │
│                                   │
│ Lead de alto valor, CEO en una... │
└───────────────────────────────────┘
Visuals: Light violet/blue gradient background (#f5f3ff to #eff6ff), 1px subtle border, border-left (3px) in $primary-purple.
Use: Displaying summaries, recommendations, and actionable insights generated by AI.
Plan Card (Pricing Page)
code
Code
┌───────────────────────────────────┐
│           [RECOMMENDED]           │
│ Plan Name (e.g., Pro)             │
│ Description...                    │
│ $35 / month                       │
│ [Upgrade Button]                  │
│ ✓ Feature 1                       │
│ ✓ Feature 2                       │
│ ✓ Feature 3                       │
└───────────────────────────────────┘
Visuals: White background, shadow, 12px radius. Recommended plan has a thicker border in $primary-indigo and a label.
Button Styles
Primary Button
Visual: $ai-gradient background, white text, 8px or 12px radius.
Use: For the main call-to-action (e.g., "Deploy Workflow", "Continue", "Finalizar").
Interaction: Hover has 90% opacity and subtle shadow/glow.
Secondary Button
Visual: White background, $gray-300 border, $gray-700 text.
Use: For secondary actions (e.g., "Preview", "Reiniciar").
Interaction: Hover changes background to $gray-50.
Filter Button (Gallery View)
Visual: Pill-shaped, white background, gray border.
Active State: Solid $primary-indigo background with white text.
Workflow & Agent Nodes
Node Component (Visual Editor)
code
Code
┌───────────────────────────────────┐
│ ICON  Task Name (e.g., llm :analyze) │
│       Task Type (e.g., Score & ... │
└───────────────────────────────────┘
```- **Visuals:** White background, 12px radius, shadow, border-left (4px) color-coded by task type:
  - **Purple:** LLM Task
  - **Green:** Validation Task
  - **Amber:** Email Task
  - **Red:** Webhook Task
  - **Indigo:** Conditional Task
- **Interaction:** Clickable to select and open properties in a sidebar.

## Page Layouts

### Dashboard / Editor Layout
This is the main layout for authenticated users, featuring a persistent navigation element and a main content area.
┌────────────────────────────────────────────────────────┐
│ HEADER / NAV (64px) │
├──────────────────┬─────────────────────────────────────┤
│ │ │
│ SIDEBAR │ MAIN CONTENT AREA │
│ (256px - 384px) │ │
│ e.g. Task Palette│ e.g. Form Builder, Workflow Canvas │
│ or Config Panel │ or Analytics Dashboard │
│ │ │
└──────────────────┴─────────────────────────────────────┘
code
Code
### Centered Form Layout (Public View)
Used for the end-user form-filling experience. It's focused and distraction-free.
┌────────────────────────────────────────────────────────┐
│ PREVIEW HEADER (Optional) │
├────────────────────────────────────────────────────────┤
│ │
│ │
│ ┌──────────────────────────┐ │
│ │ │ │
│ │ FORM STEP CONTENT │ │
│ │ (Centered, max-w-2xl) │ │
│ │ │ │
│ └──────────────────────────┘ │
│ │
│ │
└────────────────────────────────────────────────────────┘
code
Code
## Interaction Patterns & Animations

### Animations
The design uses clean, purposeful animations to enhance the user experience.
```css
/* Defined in style tags */
@keyframes slideInUp { from { opacity: 0; transform: translateY(15px); } to { opacity: 1; transform: translateY(0); } }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.7; } }
@keyframes shimmer { to { left: 100%; } } /* For loading skeletons */
slideInUp: Used for loading cards and page content.
fadeIn: Used for subtle appearance of new elements.
pulse: Used on status indicators to show activity.
Micro-interactions
Hover Effects: Cards and buttons lift (translateY(-2px) to -4px) and gain a more prominent shadow.
Loading States: A shimmer/skeleton effect (.ai-thinking) is used to indicate that content is being loaded or AI is processing.
Progress Bars: Fill animates smoothly (transition: width 0.6s ease;).
Conversational Bubbles (Forms): AI and user responses appear with a subtle slide-in animation, mimicking a chat interface.
Special UI Elements
AI "Thinking" Indicator
A pulsing three-dot animation is used to show when the AI agent is actively processing information, often accompanied by text like "Analyzing response..."
Status Indicators
Small colored dots are used to convey status at a glance:
Green: Active, Completed, Healthy
Amber/Yellow: Processing, In Progress
Red: Error, Failed
Notification Toasts
Position: Top-right corner of the viewport.
Animation: Slide in from the right.
Auto-dismiss: 5 seconds.
Visuals: Icon indicating type (success, info, error), a message, and a close button.
Implementation Guidelines
Tailwind CSS Configuration
A centralized tailwind.config.js should be created to store the design system tokens.
code
JavaScript
// tailwind.config.js
const colors = require('tailwindcss/colors');

module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
  ],
  theme: {
    extend: {
      colors: {
        // Primary & AI
        indigo: { DEFAULT: '#6366f1', ...colors.indigo },
        purple: { DEFAULT: '#8b5cf6', ...colors.purple },
        // Semantic
        success: '#10b981',
        warning: '#f59e0b',
        danger: '#ef4444',
        info: '#3b82f6',
        // Dark Theme
        'dark-bg': '#1e293b',
        'dark-surface': '#0f172a',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      keyframes: {
        slideInUp: { /* ... */ },
        fadeIn: { /* ... */ },
        pulse: { /* ... */ },
        shimmer: { /* ... */ },
      },
      animation: {
        'slide-in-up': 'slideInUp 0.5s ease-out forwards',
        'fade-in': 'fadeIn 0.4s ease-out forwards',
        'pulse-slow': 'pulse 2s ease-in-out infinite',
        'shimmer': 'shimmer 2s infinite',
      },
      boxShadow: {
        'card-hover': '0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
      },
      backgroundImage: {
        'ai-gradient': 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
  ],
}
Component Structure Example (ERB + Stimulus)
This example shows how the Question Card could be implemented.
code
Erb
<!-- app/views/components/_question_card.html.erb -->
<%
  card_classes = "question-card bg-white rounded-xl p-4 shadow-sm group transition-all duration-200"
  card_classes += " ai-enhanced" if question.ai_enhanced?
  card_classes += " selected" if is_selected
%>

<div class="<%= card_classes %>"
     data-controller="question-card"
     data-action="click->question-card#select"
     data-question-card-id-value="<%= question.id %>">

  <div class="flex items-start space-x-3">
    <div class="flex items-center space-x-2 text-gray-400">
      <span class="question-number ..."><%= question.position %></span>
      <svg class="w-4 h-4 cursor-grab" data-action="drag->sortable#start">...</svg>
    </div>
    <div class="flex-1">
      <h3 class="font-medium text-gray-900 mb-1"><%= question.title %></h3>
      <div class="flex items-center space-x-2">
        <span class="question-type ..."><%= question.type.humanize %></span>
        <% if question.required? %>
          <span class="text-xs text-red-600 font-medium">Required</span>
        <% end %>
        <% if question.ai_enhanced? %>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-purple-500 rounded-full"></div>
            <span class="text-xs text-purple-600 font-medium">AI Enhanced</span>
          </div>
        <% end %>
      </div>
    </div>
    <div class="flex items-center space-x-1 opacity-0 group-hover:opacity-100">
      <button data-action="click->question-card#delete" class="p-1 text-gray-400 hover:text-red-600">
        <svg><!-- trash icon --></svg>
      </button>
    </div>
  </div>
</div>
