# mydialogform 🚀

**Intelligent AI-Powered Form Builder & Response Analytics Platform**

mydialogform is a sophisticated Ruby on Rails application that combines traditional form building capabilities with cutting-edge AI agents to create dynamic, intelligent, and highly engaging forms. Built with modern web technologies, it provides a complete solution for creating, managing, and analyzing form responses with AI enhancement.

## 🎯 Core Features

### Form Builder & Management
- **Drag-and-Drop Interface**: Intuitive form builder with real-time preview
- **25+ Question Types**: From basic text inputs to advanced rating scales, file uploads, and matrix questions
- **Conditional Logic**: Show/hide questions based on previous responses
- **AI Enhancement**: Auto-generate questions and improve existing ones with AI
- **Form Templates**: Pre-built templates for common use cases
- **Real-time Collaboration**: Multiple users can build forms simultaneously

### AI-Powered Intelligence
- **Dynamic Question Generation**: AI creates follow-up questions based on responses
- **Sentiment Analysis**: Analyze response tone and emotional indicators
- **Lead Scoring**: Automatically qualify leads based on responses
- **Response Analysis**: AI insights into response patterns and quality
- **Smart Validation**: AI-powered validation rules
- **Workflow Automation**: Trigger actions based on AI analysis

### Response Collection & Analytics
- **Multi-Channel Distribution**: Share via URL, embed codes, or direct links
- **Progress Tracking**: Real-time response progress monitoring
- **Advanced Analytics**: Completion rates, drop-off points, response times
- **Export Capabilities**: CSV, JSON, Excel formats
- **GDPR Compliance**: Built-in consent management and data privacy
- **Mobile Responsive**: Optimized for all devices

## 🏗️ Architecture

### Backend (Ruby on Rails 8.0)
- **Database**: PostgreSQL with UUID primary keys
- **Authentication**: Devise with JWT API tokens
- **Authorization**: Pundit for fine-grained access control
- **Background Processing**: Sidekiq with Redis
- **Caching**: Redis for performance optimization
- **File Storage**: Active Storage for uploads
- **API**: RESTful JSON API with versioning

### Frontend (Hotwire Stack)
- **Stimulus.js**: Modular JavaScript controllers
- **Turbo**: Fast page navigation and form submissions
- **Tailwind CSS**: Utility-first styling
- **Heroicons**: Beautiful icon system
- **Sortable.js**: Drag-and-drop functionality

### AI Integration
- **SuperAgent Framework**: Custom AI agent system
- **OpenAI Integration**: GPT-4, GPT-4o-mini support
- **Custom Workflows**: AI-driven form processing pipelines
- **Real-time Analysis**: Live response processing

## 🗄️ Database Schema

### Core Models

#### **Form**
- `name`, `description`, `category`, `status`
- `share_token` (unique public URL)
- `ai_enabled`, `ai_configuration`
- `form_settings`, `style_configuration`
- `workflow_class` (AI agent integration)
- Analytics counters: `views_count`, `responses_count`, `completion_count`

#### **FormQuestion**
- `title`, `description`, `question_type` (25+ types)
- `position`, `required`, `hidden`, `read_only`
- `question_config` (JSON for type-specific settings)
- `conditional_logic` (JSON for dynamic visibility)
- `ai_enhanced`, `ai_config`, `ai_prompt`

#### **FormResponse**
- `session_id`, `status` (in_progress, completed, abandoned, paused)
- `ip_address`, `user_agent`, `referrer_url` (analytics)
- `utm_parameters`, `location_data`
- `ai_analysis`, `quality_score`, `sentiment_score`
- `completion_data`, `draft_data`

#### **QuestionResponse**
- Individual answers to specific questions
- `answer_data` (JSON storage)
- `response_time_ms`, `time_spent_seconds`
- `ai_analysis`, `confidence_score`
- Interaction tracking: `focus_time`, `blur_count`, `keystrokes`

#### **DynamicQuestion**
- AI-generated follow-up questions
- `generated_from_question_id` (relationship tracking)
- `generation_context`, `generation_prompt`
- `ai_confidence`, `response_time_ms`

#### **FormAnalytics**
- Daily/weekly/monthly analytics aggregation
- `views_count`, `responses_count`, `completion_rate`
- `conversion_rate`, `abandonment_rate`
- Geographic and demographic breakdowns
- Device/browser analytics

## 🚀 Getting Started

### Prerequisites
- Ruby 3.2+
- PostgreSQL 14+
- Redis 6+
- Node.js 18+
- Yarn/npm

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/your-org/mydialogform.git
cd mydialogform
```

2. **Install dependencies**
```bash
bundle install
yarn install
```

3. **Setup database**
```bash
rails db:create db:migrate db:seed
```

4. **Configure environment**
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. **Start services**
```bash
# Terminal 1: Start Redis
redis-server

# Terminal 2: Start Sidekiq
bundle exec sidekiq

# Terminal 3: Start Rails server
rails server
```

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost/mydialogform_development

# Redis
REDIS_URL=redis://localhost:6379/0

# AI Services
OPENAI_API_KEY=your_openai_api_key
SUPER_AGENT_API_KEY=your_super_agent_key

# Email (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# File Storage (optional)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_S3_BUCKET=your_bucket_name
```

## 🎯 Usage Guide

### Creating Your First Form

1. **Access the Dashboard**
   - Navigate to `http://localhost:3000`
   - Sign up for a new account or log in

2. **Create a New Form**
   - Click "Create New Agent"
   - Choose a template or start from scratch
   - Configure basic settings (name, description, category)

3. **Add Questions**
   - Use the drag-and-drop builder
   - Select from 25+ question types
   - Configure validation rules and conditional logic
   - Enable AI enhancement for smart features

4. **Enable AI Features**
   - Toggle "AI Enhanced" in form settings
   - Configure AI model preferences
   - Set up response analysis workflows
   - Define lead scoring criteria

5. **Publish & Share**
   - Click "Publish" to make the form live
   - Share via unique URL: `https://yoursite.com/f/[share_token]`
   - Embed in your website with provided code
   - Distribute via email campaigns

### Response Collection

#### Public Forms
```
GET /f/:share_token - Access public form
POST /f/:share_token/answer - Submit answers
GET /f/:share_token/thank-you - Completion page
```

#### API Integration
```bash
# Create form via API
curl -X POST https://api.yoursite.com/v1/forms \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "form": {
      "name": "Customer Feedback Survey",
      "description": "Help us improve our service",
      "category": "customer_feedback",
      "ai_enabled": true
    }
  }'

# Get responses
curl -X GET https://api.yoursite.com/v1/forms/FORM_ID/responses \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Analytics & Insights

#### Real-time Dashboard
- **Response Overview**: Live response counts and completion rates
- **Question Analytics**: Individual question performance metrics
- **Drop-off Analysis**: Identify where users abandon the form
- **Response Quality**: AI-scored response quality metrics

#### Export Capabilities
```bash
# Export responses
curl -X GET "https://api.yoursite.com/v1/forms/FORM_ID/responses/export?format=csv" \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

#### AI Analytics
- **Sentiment Trends**: Track emotional patterns over time
- **Lead Qualification**: Automated lead scoring and routing
- **Response Patterns**: Identify common themes and insights
- **Predictive Analytics**: Forecast completion rates and engagement

## 🛠️ Development

### Project Structure
```
mydialogform/
├── app/
│   ├── controllers/          # Application controllers
│   │   ├── api/v1/          # API endpoints
│   │   └── forms_controller.rb
│   ├── models/              # ActiveRecord models
│   ├── views/               # ERB templates
│   ├── javascript/          # Stimulus controllers
│   ├── services/            # Business logic
│   ├── policies/            # Authorization rules
│   └── workflows/           # AI agent definitions
├── config/                  # Application configuration
├── db/                      # Database migrations
├── spec/                    # RSpec tests
└── lib/                     # Custom libraries
```

### Key Controllers

#### **FormsController** (`app/controllers/forms_controller.rb`)
- Full CRUD operations for forms
- Publishing/unpublishing functionality
- Analytics and export endpoints
- AI feature testing

#### **ResponsesController** (`app/controllers/responses_controller.rb`)
- Public form responses (no authentication)
- Session-based response tracking
- Real-time progress updates
- Conditional question logic

#### **API Controllers** (`app/controllers/api/v1/`)
- RESTful JSON API
- Token-based authentication
- Rate limiting and versioning
- Comprehensive error handling

### Frontend Controllers

#### **FormBuilderController** (`app/javascript/controllers/form_builder_controller.js`)
- Drag-and-drop question management
- Real-time auto-save
- AI enhancement integration
- Preview mode switching

#### **FormResponseController** (`app/javascript/controllers/form_response_controller.js`)
- Multi-step form navigation
- Auto-save functionality
- Real-time validation
- Progress tracking

### AI Integration

#### **SuperAgent Integration**
- Custom AI agents for form processing
- Dynamic question generation
- Response analysis and scoring
- Lead qualification workflows

#### **AI Features Available**
1. **Response Analysis**: Sentiment, quality, and insights
2. **Dynamic Questions**: AI-generated follow-ups
3. **Lead Scoring**: Automated qualification
4. **Smart Validation**: AI-powered validation rules
5. **Predictive Analytics**: Completion forecasting

### Testing

#### **Run Tests**
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/form_spec.rb

# Run system tests
bundle exec rspec spec/system/

# Run with coverage
bundle exec rspec --format documentation
```

#### **Test Coverage**
- **Models**: 95%+ coverage
- **Controllers**: 90%+ coverage
- **System Tests**: End-to-end user flows
- **API Tests**: All endpoints covered

## 📊 Analytics & Monitoring

### Built-in Analytics
- **Form Performance**: Views, starts, completions, abandonment
- **Question Analytics**: Response rates, completion times, skip rates
- **Response Quality**: AI-scored response quality metrics
- **Geographic Data**: Location-based insights
- **Device Analytics**: Mobile vs desktop performance

### Custom Events
```javascript
// Track custom events
window.agentFormAnalytics.track('form_submitted', {
  formId: 'your-form-id',
  completionTime: 120,
  score: 85
})
```

### Monitoring Setup
- **Error Tracking**: Sentry integration ready
- **Performance**: New Relic/Skylight support
- **Uptime**: Health check endpoint at `/up`
- **Background Jobs**: Sidekiq web interface

## 🔒 Security & Privacy

### Security Features
- **CSRF Protection**: All forms protected
- **SQL Injection**: Parameterized queries
- **XSS Prevention**: HTML sanitization
- **Rate Limiting**: API endpoint protection
- **File Uploads**: Virus scanning ready

### Privacy Compliance
- **GDPR Ready**: Consent management built-in
- **Data Portability**: Export user data
- **Right to be Forgotten**: Data deletion endpoints
- **Audit Trail**: All data changes tracked
- **Encryption**: Sensitive data encrypted at rest

## 🚀 Deployment

### Production Setup

#### **Docker Deployment**
```bash
# Build and run with Docker
docker-compose up --build
```

#### **Heroku Deployment**
```bash
# One-click deploy
heroku create your-app-name
git push heroku main

# Add required add-ons
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini
```

#### **Self-Hosted**
```bash
# Using Kamal (Rails 8)
kamal deploy
```

### Environment Variables for Production
```bash
# Required
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key
DATABASE_URL=your_production_db_url
REDIS_URL=your_redis_url

# Optional but recommended
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
```

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Code Style
- **Ruby**: Follows [RuboCop](https://rubocop.org/) guidelines
- **JavaScript**: Standard JS style
- **CSS**: Tailwind CSS best practices

### Testing Requirements
- All new features require tests
- Maintain 90%+ test coverage
- Include both unit and system tests

## 📈 Performance

### Optimization Features
- **Database Indexing**: Optimized queries with proper indexes
- **Caching**: Redis-based caching for analytics and forms
- **CDN Ready**: Asset pipeline configured for CDN
- **Lazy Loading**: Progressive enhancement approach
- **Database Query Optimization**: N+1 query prevention

### Scaling Considerations
- **Horizontal Scaling**: Stateless application design
- **Database Sharding**: Ready for multi-tenant architecture
- **Background Processing**: Sidekiq for heavy operations
- **API Rate Limiting**: Built-in throttling

## 🎨 Customization

### Theming
- **Tailwind CSS**: Easy theme customization
- **Component Library**: Reusable UI components
- **Custom Branding**: Logo, colors, fonts configurable
- **White-label Ready**: Remove mydialogform branding option

### Extending Functionality
- **Custom Question Types**: Add new question types
- **AI Agents**: Create custom AI workflows
- **Integrations**: Webhook support for external systems
- **Plugins**: Modular architecture for extensions

## 📞 Support

### Documentation
- **API Docs**: Available at `/api/docs`
- **User Guide**: In-app help system
- **Video Tutorials**: Available on YouTube

### Community
- **GitHub Issues**: Bug reports and feature requests
- **Discord Community**: Real-time chat support
- **Email Support**: support@mydialogform.com

### Commercial Support
- **Enterprise Plans**: Advanced features and support
- **Custom Development**: Tailored solutions
- **Training & Consulting**: Team onboarding

---

**mydialogform** - Where intelligent forms meet powerful analytics. Built with ❤️ for modern teams who demand more from their data collection tools.

[Visit our website](https://mydialogform.com) | [Star on GitHub](https://github.com/your-org/mydialogform) | [Join our community](https://discord.gg/mydialogform)


rails users:create_superadmin
