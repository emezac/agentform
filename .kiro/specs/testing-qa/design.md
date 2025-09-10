# Design Document: Testing & Quality Assurance

## Overview

This document outlines the comprehensive testing architecture for AgentForm, designed to achieve 95%+ code coverage while ensuring reliability, performance, and security. The testing framework leverages RSpec, FactoryBot, and specialized tools for SuperAgent workflow testing.

## Architecture

### Testing Pyramid Structure

```
                    E2E/System Tests
                   /                 \
              Integration Tests    API Tests
             /                                \
        Unit Tests                      Performance Tests
       /         \                     /                    \
   Models    Controllers         Security Tests      Workflow Tests
```

### Test Categories

1. **Unit Tests**: Individual component testing (models, services, helpers)
2. **Integration Tests**: Component interaction testing
3. **System Tests**: End-to-end user journey testing
4. **API Tests**: REST API endpoint testing
5. **Workflow Tests**: SuperAgent workflow and agent testing
6. **Performance Tests**: Load and benchmark testing
7. **Security Tests**: Vulnerability and penetration testing

## Components and Interfaces

### Core Testing Infrastructure

#### RSpec Configuration
```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
  config.include WorkflowHelpers
  config.include ApiHelpers
  config.include AuthenticationHelpers
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

#### Test Database Configuration
```yaml
# config/database.yml (test environment)
test:
  adapter: postgresql
  database: agentform_test
  pool: 5
  timeout: 5000
  variables:
    statement_timeout: 15s
    lock_timeout: 10s
```

### Model Testing Framework

#### Base Model Test Structure
```ruby
# spec/support/shared_examples/model_examples.rb
RSpec.shared_examples "a timestamped model" do
  it { should have_db_column(:created_at).of_type(:datetime) }
  it { should have_db_column(:updated_at).of_type(:datetime) }
end

RSpec.shared_examples "a uuid model" do
  it { should have_db_column(:id).of_type(:uuid) }
end

RSpec.shared_examples "an encryptable model" do
  it "encrypts sensitive fields" do
    # Test encryption behavior
  end
end
```

#### Model Test Categories
1. **Validation Tests**: All validation rules and edge cases
2. **Association Tests**: Relationship integrity and cascading
3. **Callback Tests**: Before/after hook execution
4. **Method Tests**: Custom business logic methods
5. **Scope Tests**: Named scope behavior
6. **Enum Tests**: Enum values and state transitions

### Controller Testing Framework

#### Authentication Test Helpers
```ruby
# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in_user(user = nil)
    user ||= create(:user)
    sign_in user
    user
  end
  
  def sign_in_admin
    admin = create(:user, :admin)
    sign_in admin
    admin
  end
  
  def api_headers(token = nil)
    token ||= create(:api_token)
    { 'Authorization' => "Bearer #{token.token}" }
  end
end
```

#### Controller Test Structure
```ruby
# Example: spec/controllers/forms_controller_spec.rb
RSpec.describe FormsController, type: :controller do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  
  before { sign_in user }
  
  describe "GET #index" do
    context "when user has forms" do
      # Test successful response
    end
    
    context "when user has no forms" do
      # Test empty state
    end
  end
  
  describe "POST #create" do
    context "with valid parameters" do
      # Test successful creation
    end
    
    context "with invalid parameters" do
      # Test validation errors
    end
  end
end
```

### SuperAgent Testing Framework

#### Workflow Test Helpers
```ruby
# spec/support/workflow_helpers.rb
module WorkflowHelpers
  def mock_llm_response(response_data)
    allow(SuperAgent::LLM).to receive(:call).and_return(response_data)
  end
  
  def expect_workflow_step(workflow, step_name)
    expect(workflow).to receive(:execute_step).with(step_name)
  end
  
  def simulate_workflow_execution(workflow_class, inputs = {})
    workflow = workflow_class.new(inputs)
    workflow.execute
    workflow
  end
end
```

#### Agent Test Structure
```ruby
# spec/agents/forms/management_agent_spec.rb
RSpec.describe Forms::ManagementAgent do
  let(:agent) { described_class.new }
  let(:form) { create(:form) }
  
  describe "#create_form_workflow" do
    it "generates appropriate workflow for form type" do
      workflow = agent.create_form_workflow(form)
      expect(workflow).to be_a(Forms::ResponseProcessingWorkflow)
    end
  end
  
  describe "#analyze_form_performance" do
    before { mock_llm_response(analysis_data) }
    
    it "triggers analysis workflow" do
      expect { agent.analyze_form_performance(form) }
        .to change { Forms::AnalysisJob.jobs.size }.by(1)
    end
  end
end
```

#### Workflow Test Structure
```ruby
# spec/workflows/forms/response_processing_workflow_spec.rb
RSpec.describe Forms::ResponseProcessingWorkflow do
  let(:form_response) { create(:form_response) }
  let(:workflow) { described_class.new(form_response: form_response) }
  
  describe "#execute" do
    context "with valid response data" do
      before { mock_llm_response(valid_analysis) }
      
      it "completes all workflow steps" do
        expect(workflow.execute).to be_successful
        expect(workflow.steps_completed).to eq(7)
      end
    end
    
    context "with invalid response data" do
      it "fails at validation step" do
        expect(workflow.execute).to be_failed
        expect(workflow.failed_step).to eq(:validate_response_data)
      end
    end
  end
end
```

### API Testing Framework

#### API Test Helpers
```ruby
# spec/support/api_helpers.rb
module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end
  
  def expect_json_response(status, structure = {})
    expect(response).to have_http_status(status)
    expect(response.content_type).to eq('application/json; charset=utf-8')
    
    structure.each do |key, type|
      expect(json_response[key.to_s]).to be_a(type)
    end
  end
  
  def api_post(path, params = {}, headers = {})
    post path, params: params.to_json, 
         headers: { 'Content-Type' => 'application/json' }.merge(headers)
  end
end
```

#### API Test Structure
```ruby
# spec/requests/api/v1/forms_spec.rb
RSpec.describe "API V1 Forms", type: :request do
  let(:user) { create(:user) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(api_token) }
  
  describe "GET /api/v1/forms" do
    context "with valid authentication" do
      it "returns user's forms" do
        create_list(:form, 3, user: user)
        
        get "/api/v1/forms", headers: headers
        
        expect_json_response(:ok, {
          forms: Array,
          meta: Hash
        })
        expect(json_response['forms'].size).to eq(3)
      end
    end
    
    context "without authentication" do
      it "returns unauthorized" do
        get "/api/v1/forms"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

### Integration Testing Framework

#### System Test Structure
```ruby
# spec/system/form_creation_spec.rb
RSpec.describe "Form Creation", type: :system do
  let(:user) { create(:user) }
  
  before do
    sign_in user
    visit forms_path
  end
  
  scenario "User creates a new form with questions" do
    click_button "New Form"
    
    fill_in "Form Title", with: "Customer Feedback"
    fill_in "Description", with: "We value your feedback"
    
    click_button "Add Question"
    select "Text (Short)", from: "Question Type"
    fill_in "Question Title", with: "What's your name?"
    
    click_button "Save Form"
    
    expect(page).to have_content("Form created successfully")
    expect(page).to have_content("Customer Feedback")
    expect(page).to have_content("What's your name?")
  end
end
```

### Performance Testing Framework

#### Performance Test Structure
```ruby
# spec/performance/form_submission_spec.rb
RSpec.describe "Form Submission Performance", type: :performance do
  let(:form) { create(:form_with_questions, question_count: 10) }
  
  it "processes form submissions within acceptable time" do
    benchmark = Benchmark.measure do
      100.times do
        create(:form_response, form: form)
      end
    end
    
    expect(benchmark.real).to be < 5.0 # 5 seconds max
  end
  
  it "handles concurrent submissions" do
    threads = []
    
    10.times do
      threads << Thread.new do
        create(:form_response, form: form)
      end
    end
    
    threads.each(&:join)
    expect(form.form_responses.count).to eq(10)
  end
end
```

### Security Testing Framework

#### Security Test Structure
```ruby
# spec/security/authentication_spec.rb
RSpec.describe "Authentication Security", type: :security do
  describe "password requirements" do
    it "enforces strong password policy" do
      weak_passwords = ["123", "password", "abc123"]
      
      weak_passwords.each do |password|
        user = build(:user, password: password)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present
      end
    end
  end
  
  describe "session security" do
    it "expires sessions after inactivity" do
      user = create(:user)
      sign_in user
      
      travel 2.hours do
        get forms_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
```

## Data Models

### Factory Definitions

#### User Factory
```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "SecurePassword123!" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { :user }
    
    trait :admin do
      role { :admin }
    end
    
    trait :premium do
      role { :premium }
      ai_credits { 1000 }
    end
    
    trait :with_forms do
      after(:create) do |user|
        create_list(:form, 3, user: user)
      end
    end
  end
end
```

#### Form Factory
```ruby
# spec/factories/forms.rb
FactoryBot.define do
  factory :form do
    association :user
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    status { :draft }
    
    trait :published do
      status { :published }
      published_at { Time.current }
    end
    
    trait :with_questions do
      after(:create) do |form|
        create_list(:form_question, 5, form: form)
      end
    end
    
    factory :form_with_questions, traits: [:with_questions]
  end
end
```

### Test Data Scenarios

#### Complex Form Scenarios
```ruby
# spec/factories/scenarios.rb
FactoryBot.define do
  factory :customer_feedback_form, parent: :form do
    title { "Customer Feedback Survey" }
    category { :feedback }
    
    after(:create) do |form|
      create(:form_question, :rating, form: form, title: "Rate our service")
      create(:form_question, :text_long, form: form, title: "Additional comments")
      create(:form_question, :multiple_choice, form: form, title: "How did you hear about us?")
    end
  end
  
  factory :lead_qualification_form, parent: :form do
    title { "Lead Qualification" }
    category { :lead_generation }
    ai_enhanced { true }
    
    after(:create) do |form|
      create(:form_question, :text_short, form: form, title: "Company name")
      create(:form_question, :email, form: form, title: "Business email")
      create(:form_question, :number, form: form, title: "Annual revenue")
    end
  end
end
```

## Error Handling

### Test Error Scenarios

#### Model Error Testing
```ruby
# spec/models/form_spec.rb
describe "error handling" do
  context "when validation fails" do
    it "provides clear error messages" do
      form = build(:form, title: "")
      expect(form).not_to be_valid
      expect(form.errors[:title]).to include("can't be blank")
    end
  end
  
  context "when database constraints are violated" do
    it "handles unique constraint violations gracefully" do
      user = create(:user)
      create(:form, user: user, slug: "test-form")
      
      duplicate_form = build(:form, user: user, slug: "test-form")
      expect { duplicate_form.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
```

#### Workflow Error Testing
```ruby
# spec/workflows/error_handling_spec.rb
describe "workflow error handling" do
  context "when LLM service is unavailable" do
    before do
      allow(SuperAgent::LLM).to receive(:call).and_raise(SuperAgent::ServiceError)
    end
    
    it "gracefully handles service errors" do
      workflow = Forms::AnalysisWorkflow.new(form_response: form_response)
      result = workflow.execute
      
      expect(result).to be_failed
      expect(result.error_type).to eq(:service_unavailable)
    end
  end
end
```

## Testing Strategy

### Test Execution Strategy

#### Parallel Test Execution
```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = false
  
  config.before(:suite) do
    if config.use_transactional_fixtures?
      raise "Transactional fixtures must be disabled for parallel tests"
    end
    
    DatabaseCleaner.strategy = :truncation
  end
  
  config.before(:each) do
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
  end
end
```

#### Test Categories and Timing
- **Unit Tests**: < 0.1s per test, run on every commit
- **Integration Tests**: < 1s per test, run on pull requests
- **System Tests**: < 10s per test, run on deployment
- **Performance Tests**: Variable timing, run nightly
- **Security Tests**: < 5s per test, run on security-related changes

### Coverage Requirements

#### Coverage Targets by Component
- **Models**: 98% coverage (critical business logic)
- **Controllers**: 95% coverage (HTTP interface reliability)
- **Services**: 97% coverage (complex business operations)
- **Workflows**: 95% coverage (AI integration points)
- **Jobs**: 90% coverage (background processing)
- **Helpers**: 85% coverage (view logic support)

#### Coverage Exclusions
- Generated code (migrations, schema)
- Third-party integrations (mocked in tests)
- Development/test-only code
- Deprecated code marked for removal

### Continuous Integration Integration

#### GitHub Actions Workflow
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Setup Database
        run: |
          bundle exec rails db:create
          bundle exec rails db:migrate
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/agentform_test
      
      - name: Run Tests
        run: |
          bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/rspec.xml
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/agentform_test
          REDIS_URL: redis://localhost:6379/1
      
      - name: Generate Coverage Report
        run: bundle exec simplecov
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/coverage.xml
```

This comprehensive testing design ensures robust quality assurance across all layers of the AgentForm application, with particular attention to the unique challenges of testing AI-powered workflows and maintaining high performance standards.