# FacturaCircular Cliente - Automated Test Implementation Plan

# How to Test FacturaCircular Cliente

This guide explains how to run tests for the FacturaCircular Cliente web application.

## Prerequisites

- Docker and Docker Compose installed
- Ruby 3.4.5 (if running tests locally)
- Node.js 20+ (for JavaScript testing)
- Chrome/Chromium (for feature tests)
- Git

## Test Environment Overview

The FacturaCircular Cliente is a Rails web application that consumes the FacturaCircular API. Testing requires:
- The client application (this project)
- Mock API responses (using WebMock/VCR)
- Optional: Running API server for E2E tests

## Running Tests with Docker (Recommended)

### 1. Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd facturaCircularCliente

# Build Docker image
docker-compose build

# Install test dependencies
docker-compose run --rm web bundle add rspec-rails factory_bot_rails faker \
  webmock vcr capybara selenium-webdriver database_cleaner-active_record \
  shoulda-matchers simplecov --group test

# Generate RSpec configuration
docker-compose run --rm web rails generate rspec:install
```

### 2. Start Services

```bash
# Start the application
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 3. Run All Tests

```bash
# Run complete test suite
docker-compose exec web bundle exec rspec

# Run with documentation format (verbose)
docker-compose exec web bundle exec rspec --format documentation

# Run with coverage report
docker-compose exec -e COVERAGE=true web bundle exec rspec
```

### 4. Run Specific Test Categories

```bash
# Unit Tests - Services
docker-compose exec web bundle exec rspec spec/services

# Unit Tests - Helpers
docker-compose exec web bundle exec rspec spec/helpers

# Controller/Request Tests
docker-compose exec web bundle exec rspec spec/requests

# Integration/Feature Tests
docker-compose exec web bundle exec rspec spec/features

# System/E2E Tests
docker-compose exec web bundle exec rspec spec/system

# JavaScript Tests
docker-compose exec web yarn test
```

### 5. Run Specific Test Files

```bash
# Test a specific service
docker-compose exec web bundle exec rspec spec/services/invoice_service_spec.rb

# Test a specific controller
docker-compose exec web bundle exec rspec spec/requests/invoices_spec.rb

# Run a specific test (by line number)
docker-compose exec web bundle exec rspec spec/services/invoice_service_spec.rb:42

# Run tests matching a pattern
docker-compose exec web bundle exec rspec -e "creates invoice"
```

## Test Helper Script

Create a convenient test runner script:

```bash
# Create test runner
cat > test.sh << 'EOF'
#!/bin/bash
# FacturaCircular Cliente Test Runner

# Default to running all tests
TEST_PATH=${1:-"spec"}

# Check if running specific categories
case "$1" in
  unit)
    TEST_PATH="spec/services spec/helpers"
    ;;
  integration)
    TEST_PATH="spec/requests"
    ;;
  e2e)
    TEST_PATH="spec/features spec/system"
    ;;
  services)
    TEST_PATH="spec/services"
    ;;
  *)
    TEST_PATH="$@"
    ;;
esac

# Run tests with proper environment
docker-compose exec \
  -e RAILS_ENV=test \
  -e API_BASE_URL=http://localhost:3001/api/v1 \
  web bundle exec rspec $TEST_PATH
EOF

chmod +x test.sh

# Usage examples:
./test.sh                    # Run all tests
./test.sh unit              # Run unit tests
./test.sh integration       # Run integration tests
./test.sh e2e              # Run E2E tests
./test.sh spec/services    # Run service tests
```

## Running Tests Locally (Alternative)

### 1. Install Dependencies

```bash
# Ruby dependencies
bundle install

# JavaScript dependencies
npm install

# Install Chrome driver for Selenium
brew install chromedriver  # macOS
# or
sudo apt-get install chromium-chromedriver  # Ubuntu
```

### 2. Configure Test Environment

```bash
# Copy test environment configuration
cp .env.example .env.test

# Edit .env.test
API_BASE_URL=http://localhost:3001/api/v1
```

### 3. Run Tests

```bash
# All tests
RAILS_ENV=test bundle exec rspec

# With coverage
COVERAGE=true RAILS_ENV=test bundle exec rspec

# JavaScript tests
npm test
```

## Test Structure

```
spec/
├── services/              # Service object unit tests
│   ├── api_service_spec.rb
│   ├── auth_service_spec.rb
│   ├── invoice_service_spec.rb
│   ├── company_service_spec.rb
│   ├── workflow_service_spec.rb
│   └── tax_service_spec.rb
├── helpers/               # Helper method tests
│   └── application_helper_spec.rb
├── requests/              # Controller/Request tests
│   ├── sessions_spec.rb
│   ├── dashboard_spec.rb
│   ├── companies_spec.rb
│   ├── invoices_spec.rb
│   ├── workflows_spec.rb
│   └── tax_calculations_spec.rb
├── features/              # Feature/Integration tests
│   ├── authentication_flow_spec.rb
│   ├── invoice_management_spec.rb
│   ├── company_management_spec.rb
│   ├── workflow_transitions_spec.rb
│   └── tax_calculator_spec.rb
├── system/                # E2E system tests
│   └── complete_invoice_workflow_spec.rb
├── javascript/            # JavaScript unit tests
│   └── controllers/
│       ├── invoice_form_controller_spec.js
│       ├── tax_calculator_controller_spec.js
│       └── tabs_controller_spec.js
├── support/               # Test helpers and configuration
│   ├── api_helper.rb
│   ├── authentication_helper.rb
│   ├── session_helper.rb
│   └── shared_examples/
├── factories/             # FactoryBot factories
│   ├── api_responses.rb
│   └── users.rb
├── cassettes/            # VCR recordings
└── rails_helper.rb       # Rails test configuration
```

## Testing Patterns

### 1. API Mocking

All API calls are mocked using WebMock:

```ruby
# spec/support/api_helper.rb
stub_api_request(:get, '/invoices', {
  invoices: [...],
  total: 10
})
```

### 2. Authentication

Use helpers to simulate logged-in state:

```ruby
# In request specs
before { login_as }

# In feature specs
before { login_via_ui }
```

### 3. JavaScript Testing

Tests use Capybara with Cuprite (headless Chrome):

```ruby
# Feature specs with JS
scenario 'dynamic form interaction', js: true do
  # Test JavaScript behavior
end
```

## Common Test Commands

```bash
# Run tests in parallel (faster)
docker-compose exec web bundle exec parallel_rspec

# Run only failing tests from last run
docker-compose exec web bundle exec rspec --only-failures

# Run tests with specific tag
docker-compose exec web bundle exec rspec --tag focus

# Run tests and stop on first failure
docker-compose exec web bundle exec rspec --fail-fast

# Profile slow tests
docker-compose exec web bundle exec rspec --profile 10

# Run with specific seed (for debugging random failures)
docker-compose exec web bundle exec rspec --seed 12345
```

## Debugging Tests

### Interactive Debugging

Add debugging breakpoint:

```ruby
it 'does something' do
  binding.pry  # or debugger
  expect(result).to eq(expected)
end
```

Run test interactively:

```bash
docker-compose exec -it web bundle exec rspec spec/services/invoice_service_spec.rb
```

### View Test Logs

```bash
# Rails test log
docker-compose exec web tail -f log/test.log

# View test output
docker-compose logs -f web
```

### Check VCR Cassettes

```bash
# List recorded API interactions
docker-compose exec web ls -la spec/cassettes/

# Clear cassettes to re-record
docker-compose exec web rm -rf spec/cassettes/*
```

## Continuous Integration

### GitHub Actions Configuration

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.5
          bundler-cache: true
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 20
          cache: 'npm'
      
      - name: Install dependencies
        run: |
          bundle install
          npm install
      
      - name: Run tests
        env:
          RAILS_ENV: test
          API_BASE_URL: http://localhost:3001/api/v1
        run: |
          bundle exec rspec --format progress --format RspecJunitFormatter --out rspec.xml
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

## Test Coverage Metrics

### Current Coverage Goals

- **Overall**: ≥ 90%
- **Services**: ≥ 95%
- **Controllers**: ≥ 90%
- **Helpers**: ≥ 85%
- **JavaScript**: ≥ 80%

### View Coverage Report

```bash
# Generate coverage
docker-compose exec -e COVERAGE=true web bundle exec rspec

# Open coverage report (local)
open coverage/index.html

# Copy from Docker
docker cp facturacircularcliente-web-1:/rails/coverage ./coverage
```

## Test Data Management

### Using Factories

```ruby
# Create test data
company = build(:company_response)
invoice = build(:invoice_response, company: company)
```

### API Response Stubs

```ruby
# Stub successful response
stub_api_request(:get, '/companies/1', company)

# Stub error response
stub_api_request(:get, '/companies/999', { error: 'Not found' }, 404)
```

## Troubleshooting

### WebMock Blocking Real Requests

```ruby
# Allow localhost for Capybara
WebMock.disable_net_connect!(allow_localhost: true)
```

### JavaScript Tests Failing

```bash
# Run with visible browser (debugging)
docker-compose exec -e HEADLESS=false web bundle exec rspec spec/features
```

### Flaky Tests

```bash
# Run test multiple times to detect flakiness
docker-compose exec web bundle exec rspec-retry spec/features
```

### VCR Cassette Mismatches

```bash
# Re-record cassettes
docker-compose exec -e VCR_RECORD=all web bundle exec rspec
```

## Performance Testing

```bash
# Benchmark specific endpoints
docker-compose exec web bundle exec rspec spec/performance

# Memory profiling
docker-compose exec -e MEMORY_PROFILE=true web bundle exec rspec
```

## Writing New Tests

### Test Naming Convention

```ruby
# Good test descriptions
describe 'GET /invoices' do
  context 'with valid filters' do
    it 'returns filtered invoices' do
```

### Test Organization

1. **Arrange**: Set up test data
2. **Act**: Perform the action
3. **Assert**: Verify the result

```ruby
it 'creates invoice with line items' do
  # Arrange
  invoice_params = build(:invoice_params)
  stub_api_request(:post, '/invoices', invoice_response)
  
  # Act
  post invoices_path, params: invoice_params
  
  # Assert
  expect(response).to redirect_to(invoice_path(1))
  expect(flash[:notice]).to include('created')
end
```

## Test Phases Coverage


## Quick Reference

```bash
# Most common commands
docker-compose exec web bundle exec rspec              # Run all tests
docker-compose exec web bundle exec rspec --fail-fast  # Stop on first failure
docker-compose exec web bundle exec rspec spec/services # Run service tests
docker-compose exec web bundle exec rspec --only-failures # Re-run failures
docker-compose exec -e COVERAGE=true web bundle exec rspec # With coverage
```

## Additional Resources

- [RSpec Documentation](https://rspec.info/)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [WebMock Documentation](https://github.com/bblimke/webmock)
- [VCR Documentation](https://github.com/vcr/vcr)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)

## Overview

This document provides a comprehensive plan for implementing automated tests using RSpec, covering unit tests, integration tests, functional tests, and end-to-end tests for the FacturaCircular Cliente application.

## TO UNDERSTAND HOW TO TEST

Read HOW_TO_TEST.md

  Admin user:
  - Email: admin@example.com
  - Password: password123

  Manager user:
  - Email: manager@example.com
  - Password: password123

  Regular user:
  - Email: user@example.com
  - Password: password123

  Service account (for API access):
  - Email: service@example.com
  - Password: ServicePass123!
  - Also has API key/secret generated for direct API access

## Test Types and When to Use Them

### Test Pyramid Strategy

```
         /\
        /E2E\        (5%) - Critical user journeys
       /------\
      /Feature \     (15%) - UI interactions
     /----------\
    /Integration \   (25%) - API & controller flows
   /--------------\
  /   Unit Tests   \ (55%) - Services, helpers, models
 /------------------\
```

### 1. Unit Tests (55% of tests)

**Purpose:** Test individual components in isolation with mocked dependencies.

**Use for:**
- Service objects (API clients)
- Helper methods
- Utility classes
- Data transformations
- Business logic
- Validators

**Characteristics:**
- Fast execution (< 0.1s per test)
- No external dependencies
- Fully mocked
- High code coverage
- Run frequently during development

**Examples:**
```ruby
# spec/services/invoice_service_spec.rb
describe InvoiceService do
  it 'calculates tax correctly' do
    # Test pure business logic
  end
end

# spec/helpers/application_helper_spec.rb
describe ApplicationHelper do
  it 'formats currency' do
    # Test formatting logic
  end
end
```

**When NOT to use:**
- Testing framework code
- Testing external libraries
- Testing integration between components

### 2. Contract Tests (10% of tests)

**Purpose:** Verify API contracts between client and server.

**Use for:**
- API request/response formats
- Data structure validation
- Schema compliance
- Breaking change detection

**Characteristics:**
- Uses VCR cassettes or contract definitions
- Validates against API documentation
- Catches integration issues early
- Medium speed (0.1-0.3s per test)

**Examples:**
```ruby
# spec/contracts/invoice_api_contract_spec.rb
describe 'Invoice API Contract' do
  it 'matches expected request format' do
    # Verify request structure
  end
  
  it 'returns expected response schema' do
    # Validate response against schema
  end
end
```

**When NOT to use:**
- Testing business logic
- Testing UI behavior
- Testing performance

### 3. Integration Tests (25% of tests)

**Purpose:** Test interaction between multiple components with some real dependencies.

**Use for:**
- Controller actions (request specs)
- API client integration
- Authentication flows
- Data flow through layers
- Error handling across boundaries

**Characteristics:**
- Some mocked dependencies
- Tests multiple components together
- Medium speed (0.3-0.5s per test)
- Uses test database if needed

**Examples:**
```ruby
# spec/requests/invoices_spec.rb
describe 'Invoices', type: :request do
  it 'creates invoice through controller' do
    # Test controller + service integration
    post invoices_path, params: { invoice: attributes }
    expect(response).to redirect_to(invoice_path)
  end
end
```

**When NOT to use:**
- Testing individual methods
- Testing UI interactions
- Testing external services directly

### 4. Feature Tests (15% of tests)

**Purpose:** Test user interactions with the UI using browser automation.

**Use for:**
- Form submissions
- JavaScript interactions
- Dynamic UI behavior
- Multi-step workflows
- User navigation paths

**Characteristics:**
- Uses Capybara with headless browser
- Tests JavaScript behavior
- Slower execution (1-2s per test)
- More brittle than unit tests

**Examples:**
```ruby
# spec/features/invoice_creation_spec.rb
feature 'Invoice Creation', js: true do
  scenario 'user creates invoice with line items' do
    visit new_invoice_path
    fill_in 'Description', with: 'Service'
    click_button 'Add Line Item'
    # Test dynamic form behavior
  end
end
```

**When NOT to use:**
- Testing business logic
- Testing data transformations
- Testing API responses

### 5. End-to-End Tests (5% of tests)

**Purpose:** Test complete user journeys through the entire system.

**Use for:**
- Critical business flows
- User acceptance scenarios
- Smoke tests for deployments
- Cross-system integration

**Characteristics:**
- No mocking (uses real API if possible)
- Very slow (2-10s per test)
- Most brittle
- Run less frequently

**Examples:**
```ruby
# spec/system/complete_invoice_workflow_spec.rb
describe 'Complete Invoice Workflow', type: :system do
  it 'completes invoice from creation to payment' do
    # 1. Login
    # 2. Create company
    # 3. Create invoice
    # 4. Send invoice
    # 5. Mark as paid
    # Full business flow
  end
end
```

**When NOT to use:**
- Testing edge cases
- Testing error conditions
- Testing individual features
- During TDD cycles

## Test Selection Decision Tree

```
Is it testing business logic in isolation?
├─ YES → Unit Test
└─ NO
   │
   Is it testing API contract/schema?
   ├─ YES → Contract Test
   └─ NO
      │
      Is it testing component interaction?
      ├─ YES → Integration Test
      └─ NO
         │
         Is it testing UI/JavaScript behavior?
         ├─ YES → Feature Test
         └─ NO
            │
            Is it testing critical user journey?
            ├─ YES → E2E Test
            └─ NO → Reconsider if test is needed
```

## Test Coverage by Component

### Services (API Clients)
- **Primary:** Unit Tests (90%)
- **Secondary:** Contract Tests (10%)
- **Focus:** Business logic, error handling, data transformation

### Controllers
- **Primary:** Integration Tests (80%)
- **Secondary:** Unit Tests (20%)
- **Focus:** Request/response flow, authentication, authorization

### Helpers
- **Primary:** Unit Tests (100%)
- **Focus:** Pure functions, formatting, utilities

### JavaScript (Stimulus Controllers)
- **Primary:** Unit Tests (60%)
- **Secondary:** Feature Tests (40%)
- **Focus:** DOM manipulation, event handling, calculations

### Forms & Validations
- **Primary:** Feature Tests (70%)
- **Secondary:** Integration Tests (30%)
- **Focus:** User input, validation messages, dynamic behavior

### Workflows
- **Primary:** Integration Tests (60%)
- **Secondary:** E2E Tests (40%)
- **Focus:** State transitions, business rules, multi-step processes

## Test Implementation Priority

### ✅ Phase 1: Foundation (COMPLETED)
1. ✅ **Unit Tests for Services** - Critical for API interaction
   - ✅ ApiService (14 tests)
   - ✅ AuthService (10 tests) 
   - ✅ InvoiceService (11 tests)
2. ✅ **Unit Tests for Helpers** - Support functions
   - ✅ ApplicationHelper (44 tests)
3. ✅ **Test Environment Setup** - RSpec, WebMock, VCR, FactoryBot

### ✅ Phase 2: Test Structure (COMPLETED)
1. ✅ **Integration Test Structure** - Ready for controllers
   - ✅ Authentication flow tests (`spec/features/authentication_flow_spec.rb`)
   - ✅ Session helper utilities (`spec/support/session_helper.rb`)
2. ✅ **Request Spec Structure** - Ready for controllers
   - ✅ Sessions controller tests (`spec/requests/sessions_spec.rb`)
   - ✅ Dashboard controller tests (`spec/requests/dashboard_spec.rb`) 
   - ✅ Companies controller tests (`spec/requests/companies_spec.rb`)
   - ✅ Invoices controller tests (`spec/requests/invoices_spec.rb`)
3. ✅ **Feature Test Structure** - Ready for forms
   - ✅ Invoice form interaction tests (`spec/features/invoice_form_spec.rb`)

### Phase 3: Controller Implementation
1. **Implement Controllers** - Sessions, Dashboard, Companies, Invoices
2. **Execute Integration Tests** - Run request specs once controllers exist
3. **Execute Feature Tests** - Run form interaction tests

### Phase 3: Complete Coverage (PLANNED)
1. **Feature Tests for JavaScript** - Dynamic behavior
2. **E2E Tests for Critical Paths** - Business flows
3. **Performance Tests** - Response times

### Phase 4: Maintenance (Ongoing)
1. **Regression Tests** - Bug fixes
2. **Smoke Tests** - Deployment validation
3. **Exploratory Tests** - Edge cases

## Test Execution Strategy

### Local Development
```bash
Check [How to test](HOW_TO_TEST.md)
```

### CI Pipeline
```yaml
stages:
  - unit_tests      # 2 min - Run on every commit
  - integration     # 5 min - Run on every commit
  - feature_tests   # 10 min - Run on PR
  - e2e_tests      # 15 min - Run on main branch
```

### Pre-Production
- Full test suite
- Performance tests
- Security tests
- Accessibility tests

## Test Maintenance Guidelines

### Keep Tests Fast
- Mock external dependencies in unit tests
- Use factories instead of fixtures
- Parallelize test execution
- Profile and optimize slow tests

### Keep Tests Reliable
- Avoid time-dependent tests
- Clear test data between runs
- Use explicit waits for async operations
- Isolate tests from each other

### Keep Tests Maintainable
- Follow AAA pattern (Arrange, Act, Assert)
- Use descriptive test names
- Extract common setup to helpers
- Keep tests focused on one behavior

## Anti-Patterns to Avoid

### ❌ Testing Implementation Details
```ruby
# Bad
it 'calls calculate_tax method' do
  expect(invoice).to receive(:calculate_tax)
end

# Good
it 'includes tax in total' do
  expect(invoice.total).to eq(base_amount + tax)
end
```

### ❌ Over-Mocking
```ruby
# Bad - Mocking everything
allow(Invoice).to receive(:find).and_return(mock_invoice)
allow(mock_invoice).to receive(:calculate).and_return(100)

# Good - Mock external dependencies only
stub_api_request(:get, '/invoices/1', invoice_data)
```

### ❌ Brittle Selectors
```ruby
# Bad
find('.container > div:nth-child(2) > span').click

# Good
click_button 'Submit Invoice'
within '[data-test="invoice-form"]' do
  fill_in 'Amount', with: 100
end
```

### ❌ Testing Framework Code
```ruby
# Bad
it 'renders with Tailwind classes' do
  expect(page).to have_css('.bg-blue-500')
end

# Good
it 'displays success message' do
  expect(page).to have_content('Invoice created successfully')
end
```

## Test Environment Setup

### 1. Add Testing Dependencies

```ruby
# Gemfile
group :development, :test do
  # Debugging
  gem 'pry-rails'
  gem 'pry-byebug'
  
  # Testing framework
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails'
  gem 'faker'
  
  # Code quality
  gem 'rubocop-rspec'
end

group :test do
  # Test coverage
  gem 'simplecov', require: false
  gem 'simplecov-lcov', require: false
  
  # API mocking
  gem 'webmock'
  gem 'vcr'
  
  # Browser testing
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'cuprite' # Headless Chrome driver
  
  # Cleaning database
  gem 'database_cleaner-active_record'
  
  # Time helpers
  gem 'timecop'
  
  # Matchers
  gem 'shoulda-matchers'
  gem 'rspec-json_expectations'
  
  # Performance testing
  gem 'rspec-benchmark'
  
  # Request specs
  gem 'rack-test'
  
  # JavaScript testing
  gem 'rspec-rails-examples'
end
```

### 2. RSpec Configuration

```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Rails is running in production!") if Rails.env.production?
require 'rspec/rails'
require 'webmock/rspec'
require 'vcr'
require 'capybara/rspec'
require 'capybara/cuprite'

# Configure Capybara
Capybara.javascript_driver = :cuprite
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, {
    window_size: [1920, 1080],
    browser_options: { 'no-sandbox': nil },
    inspector: ENV['INSPECTOR'] == 'true',
    headless: ENV['HEADLESS'] != 'false'
  })
end

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<JWT_TOKEN>') { |interaction|
    interaction.request.headers['Authorization']&.first
  }
end

# Configure DatabaseCleaner
RSpec.configure do |config|
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

# Include helpers
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = Rails.root.join('spec/fixtures')
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include custom helpers
  config.include AuthenticationHelper, type: :request
  config.include ApiHelper
  config.include SessionHelper, type: :feature
end
```

### 3. Test Helpers

```ruby
# spec/support/authentication_helper.rb
module AuthenticationHelper
  def login_as(user = nil)
    user ||= create(:user)
    token = generate_jwt_token(user)
    session[:access_token] = token[:access_token]
    session[:refresh_token] = token[:refresh_token]
    session[:user_id] = user.id
    user
  end
  
  def generate_jwt_token(user)
    {
      access_token: JWT.encode(
        { user_id: user.id, exp: 1.hour.from_now.to_i },
        Rails.application.secret_key_base
      ),
      refresh_token: JWT.encode(
        { user_id: user.id, exp: 7.days.from_now.to_i },
        Rails.application.secret_key_base
      )
    }
  end
end

# spec/support/api_helper.rb
module ApiHelper
  def stub_api_request(method, endpoint, response_body, status = 200)
    stub_request(method, "#{ENV['API_BASE_URL']}#{endpoint}")
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_successful_login
    stub_api_request(:post, '/auth/login', {
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      user: { id: 1, email: 'test@example.com', name: 'Test User' }
    })
  end
end
```

---

## ✅ Completed Unit Tests (Phase 1)

### Current Test Suite Status

**Total Tests Implemented: 79 Unit Tests (ALL PASSING ✅) + Integration Test Structure**

#### ✅ Unit Tests (79 tests - EXECUTABLE)
- ✅ **ApiService** (14 tests) - HTTP client with error handling
  - GET/POST/PUT/PATCH/DELETE operations
  - Authentication, NotFound, Validation error handling
  - Network error handling
  - Query parameters and request headers

- ✅ **AuthService** (10 tests) - Authentication flows
  - Login with valid/invalid credentials
  - Remember me functionality
  - Token refresh handling
  - Logout operations
  - Token validation

- ✅ **InvoiceService** (11 tests) - Invoice operations
  - List invoices with/without filters
  - CRUD operations (create, find, update, delete)
  - Invoice actions (freeze, send_email)
  - PDF/XML file downloads

- ✅ **ApplicationHelper** (44 tests) - UI formatting and utilities
  - Number formatting with delimiters
  - Currency formatting (€ symbol)
  - Percentage formatting
  - Date formatting (long/short formats)
  - Status badge CSS classes
  - Flash message styling
  - Flash message icons (SVG)
  - Breadcrumb navigation

#### ✅ Integration Test Structure (READY - PENDING CONTROLLERS)
- **Authentication Flow Tests**: Complete user login/logout scenarios
- **Request Specs**: Sessions, Dashboard, Companies, Invoices (81 tests written)
- **Feature Tests**: Form interactions and JavaScript behavior
- **Test Helpers**: Session management, API stubbing, authentication

### Test Coverage Metrics
- **Unit Tests Line Coverage**: 9.57% (112/1170 lines)
- **Test Distribution**: 
  - Services: 44% (35/79 executable tests)
  - Helpers: 56% (44/79 executable tests)
  - Integration: 81 tests written, pending controller implementation

### Test Infrastructure Completed
- ✅ RSpec testing framework configured
- ✅ WebMock for API mocking and request stubbing
- ✅ VCR for API interaction recording
- ✅ FactoryBot for test data generation
- ✅ SimpleCov for code coverage reporting
- ✅ Shoulda matchers for model validations
- ✅ Capybara for feature testing (configured)
- ✅ Docker-based test execution environment

### Key Implementation Features
- **API Mocking**: All external API calls properly stubbed with WebMock
- **Error Handling**: Comprehensive error scenario testing (401, 404, 422, 500)
- **Authentication**: JWT token handling and refresh logic
- **Data Formatting**: Spanish localization (€ symbol, dates, tax rates)
- **File Downloads**: Special handling for binary content (PDF/XML)
- **Test Helpers**: Reusable authentication, session, and API stubbing utilities
- **Admin Credentials**: Tests configured with admin@example.com / password123

### Example Test Structure

```ruby
# Comprehensive service testing
RSpec.describe ApiService do
  describe '.get' do
    context 'when request is successful' do
      it 'returns parsed JSON response' do
        # Test implementation
      end
    end
    
    context 'when request returns 401' do
      it 'raises AuthenticationError' do
        # Error handling test
      end
    end
  end
end

# Helper method testing
RSpec.describe ApplicationHelper do
  describe '#format_currency' do
    it 'formats amount with euro symbol' do
      expect(helper.format_currency(1234.56)).to eq('1,234.56 €')
    end
  end
end
```

---

## Controller Tests

### 1. Request Specs (Functional Tests)

```ruby
# spec/requests/sessions_spec.rb
require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  describe 'GET /login' do
    it 'renders login form' do
      get login_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sign in to your account')
    end
    
    context 'when already logged in' do
      before { login_as }
      
      it 'redirects to dashboard' do
        get login_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
  
  describe 'POST /login' do
    let(:login_params) do
      { email: 'test@example.com', password: 'password123' }
    end
    
    context 'with valid credentials' do
      before { stub_successful_login }
      
      it 'logs user in and redirects to dashboard' do
        post login_path, params: login_params
        
        expect(session[:access_token]).to be_present
        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(response.body).to include('Dashboard')
      end
      
      it 'sets remember me cookie when checked' do
        post login_path, params: login_params.merge(remember_me: '1')
        
        expect(cookies[:remember_token]).to be_present
      end
    end
    
    context 'with invalid credentials' do
      before do
        stub_api_request(:post, '/auth/login', 
          { error: 'Invalid credentials' }, 401)
      end
      
      it 'renders login form with error' do
        post login_path, params: login_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email or password')
        expect(session[:access_token]).to be_nil
      end
    end
  end
  
  describe 'DELETE /logout' do
    before { login_as }
    
    it 'logs user out and clears session' do
      delete logout_path
      
      expect(session[:access_token]).to be_nil
      expect(session[:refresh_token]).to be_nil
      expect(response).to redirect_to(login_path)
    end
  end
end

# spec/requests/companies_spec.rb
require 'rails_helper'

RSpec.describe 'Companies', type: :request do
  before { login_as }
  let(:token) { session[:access_token] }
  
  describe 'GET /companies' do
    before do
      stub_api_request(:get, '/companies', {
        companies: [
          { id: 1, name: 'Company A', tax_id: 'A12345678' },
          { id: 2, name: 'Company B', tax_id: 'B87654321' }
        ],
        total: 2,
        page: 1
      })
    end
    
    it 'displays list of companies' do
      get companies_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Company A', 'Company B')
      expect(response.body).to include('A12345678', 'B87654321')
    end
    
    context 'with search params' do
      it 'filters companies' do
        stub_request(:get, "#{ApiService::BASE_URL}/companies")
          .with(query: { search: 'test' })
          .to_return(
            status: 200,
            body: { companies: [], total: 0 }.to_json
          )
        
        get companies_path, params: { search: 'test' }
        expect(response).to have_http_status(:ok)
      end
    end
  end
  
  describe 'GET /companies/new' do
    it 'renders new company form' do
      get new_company_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Company')
      expect(response.body).to include('name="company[name]"')
    end
  end
  
  describe 'POST /companies' do
    let(:company_params) do
      {
        company: {
          name: 'Test Company',
          tax_id: 'B12345678',
          email: 'test@company.com',
          phone: '+34 900 123 456'
        }
      }
    end
    
    context 'with valid params' do
      before do
        stub_api_request(:post, '/companies', {
          id: 1,
          name: 'Test Company',
          tax_id: 'B12345678'
        }, 201)
      end
      
      it 'creates company and redirects' do
        post companies_path, params: company_params
        
        expect(response).to redirect_to(company_path(1))
        expect(flash[:notice]).to eq('Company was successfully created.')
      end
    end
    
    context 'with invalid params' do
      before do
        stub_api_request(:post, '/companies',
          { errors: ['Tax ID is invalid'] }, 422)
      end
      
      it 'renders form with errors' do
        post companies_path, params: company_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Tax ID is invalid')
      end
    end
  end
end

# spec/requests/invoices_spec.rb
require 'rails_helper'

RSpec.describe 'Invoices', type: :request do
  before { login_as }
  
  describe 'GET /invoices' do
    before do
      stub_api_request(:get, '/invoices', {
        invoices: [
          {
            id: 1,
            invoice_number: 'INV-001',
            status: 'draft',
            total: 121.00,
            company: { name: 'Test Co' }
          }
        ],
        statistics: {
          total_count: 1,
          total_amount: 121.00,
          status_counts: { draft: 1 }
        }
      })
    end
    
    it 'displays invoices with statistics' do
      get invoices_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('INV-001')
      expect(response.body).to include('€121.00')
      expect(response.body).to include('Test Co')
    end
  end
  
  describe 'POST /invoices' do
    let(:invoice_params) do
      {
        invoice: {
          company_id: 1,
          invoice_type: 'standard',
          date: Date.current,
          due_date: 30.days.from_now,
          invoice_lines_attributes: {
            '0' => {
              description: 'Service',
              quantity: 10,
              unit_price: 100,
              tax_rate: 21,
              discount_percentage: 0
            }
          }
        }
      }
    end
    
    before do
      stub_api_request(:post, '/invoices', {
        id: 1,
        invoice_number: 'INV-001',
        status: 'draft',
        total: 1210.00
      }, 201)
    end
    
    it 'creates invoice with line items' do
      post invoices_path, params: invoice_params
      
      expect(response).to redirect_to(invoice_path(1))
      expect(flash[:notice]).to include('successfully created')
    end
  end
end
```

### 2. Controller Concerns Tests

```ruby
# spec/controllers/concerns/authentication_concern_spec.rb
require 'rails_helper'

RSpec.describe 'AuthenticationConcern', type: :controller do
  controller(ApplicationController) do
    def index
      render plain: 'OK'
    end
  end
  
  describe '#authenticate_user!' do
    context 'without session' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(login_path)
      end
    end
    
    context 'with valid session' do
      before do
        session[:access_token] = 'valid_token'
        session[:user_id] = 1
      end
      
      it 'allows access' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
    
    context 'with expired token' do
      before do
        session[:access_token] = 'expired_token'
        session[:refresh_token] = 'refresh_token'
        
        # Stub refresh endpoint
        stub_api_request(:post, '/auth/refresh', {
          access_token: 'new_token',
          refresh_token: 'new_refresh'
        })
      end
      
      it 'refreshes token automatically' do
        get :index
        expect(session[:access_token]).to eq('new_token')
      end
    end
  end
end
```

---

## Integration Tests

### 1. Feature Specs (E2E Tests)

```ruby
# spec/features/authentication_flow_spec.rb
require 'rails_helper'

RSpec.describe 'Authentication Flow', type: :feature, js: true do
  describe 'User login journey' do
    before { stub_successful_login }
    
    scenario 'User logs in successfully' do
      visit root_path
      expect(page).to have_current_path(login_path)
      
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Password', with: 'password123'
      check 'Remember me'
      
      click_button 'Sign in'
      
      expect(page).to have_current_path(dashboard_path)
      expect(page).to have_content('Dashboard')
      expect(page).to have_content('test@example.com')
      
      # Check user menu
      find('[data-dropdown-target="button"]').click
      expect(page).to have_link('Sign out')
    end
    
    scenario 'User logs out' do
      login_via_ui
      
      find('[data-dropdown-target="button"]').click
      click_link 'Sign out'
      
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('Sign in to your account')
    end
  end
  
  describe 'Protected routes' do
    scenario 'Redirects to login when not authenticated' do
      visit dashboard_path
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('Please sign in to continue')
    end
  end
end

# spec/features/invoice_management_spec.rb
require 'rails_helper'

RSpec.describe 'Invoice Management', type: :feature, js: true do
  before do
    login_via_ui
    stub_companies_list
    stub_invoice_creation
  end
  
  scenario 'Creating an invoice with multiple line items' do
    visit new_invoice_path
    
    # Select company
    select 'Test Company', from: 'Company'
    
    # Fill invoice details
    fill_in 'Invoice date', with: Date.current
    fill_in 'Due date', with: 30.days.from_now
    select '30 days', from: 'Payment terms'
    
    # Add first line item
    within '[data-invoice-form-target="lineItems"] .line-item:first-child' do
      fill_in 'Description', with: 'Professional Services'
      fill_in 'Quantity', with: '10'
      fill_in 'Unit price', with: '100'
      select '21%', from: 'Tax rate'
      fill_in 'Discount', with: '10'
    end
    
    # Add second line item
    click_button 'Add Line Item'
    
    within '[data-invoice-form-target="lineItems"] .line-item:last-child' do
      fill_in 'Description', with: 'Additional Services'
      fill_in 'Quantity', with: '5'
      fill_in 'Unit price', with: '50'
      select '10%', from: 'Tax rate'
    end
    
    # Verify calculations
    expect(page).to have_content('Subtotal: €1,150.00')
    expect(page).to have_content('Tax: €214.00')
    expect(page).to have_content('Total: €1,364.00')
    
    # Save invoice
    click_button 'Save as Draft'
    
    expect(page).to have_content('Invoice was successfully created')
    expect(page).to have_content('INV-001')
    expect(page).to have_content('Draft')
  end
  
  scenario 'Managing invoice workflow' do
    stub_invoice_details
    stub_workflow_transitions
    
    visit invoice_path(1)
    
    click_link 'Manage Workflow'
    
    expect(page).to have_content('Available Transitions')
    expect(page).to have_button('Transition to Sent')
    
    fill_in 'comment', with: 'Sending to customer'
    click_button 'Transition to Sent'
    
    expect(page).to have_content('Status successfully updated')
    expect(page).to have_content('Sent')
  end
end

# spec/features/tax_calculator_spec.rb
require 'rails_helper'

RSpec.describe 'Tax Calculator', type: :feature, js: true do
  before { login_via_ui }
  
  scenario 'Calculating tax with discount' do
    visit new_tax_calculation_path
    
    # Simple calculator tab should be active by default
    expect(page).to have_css('#simple-calculator:not(.hidden)')
    
    fill_in 'Base Amount', with: '1000'
    select '21% - Standard IVA', from: 'Tax Rate'
    fill_in 'Discount', with: '10'
    
    # Real-time calculation
    expect(page).to have_content('Base Amount: €1,000.00')
    expect(page).to have_content('Discount: -€100.00')
    expect(page).to have_content('Subtotal: €900.00')
    expect(page).to have_content('Tax (21%): €189.00')
    expect(page).to have_content('Total: €1,089.00')
    
    click_button 'Calculate'
    
    expect(page).to have_content('Tax Calculation Results')
  end
  
  scenario 'Validating Spanish tax ID' do
    visit new_tax_calculation_path
    
    click_button 'Tax ID Validation'
    
    expect(page).to have_css('#tax-validation:not(.hidden)')
    
    fill_in 'Tax ID', with: 'B12345678'
    select 'Spain', from: 'Country'
    
    stub_api_request(:post, '/tax_validations/tax_id', {
      valid: true,
      details: {
        company_name: 'Test Company S.L.',
        tax_type: 'CIF',
        region: 'Madrid'
      }
    })
    
    click_button 'Validate Tax ID'
    
    within '#validation_result' do
      expect(page).to have_content('Valid Tax ID')
      expect(page).to have_content('Company: Test Company S.L.')
      expect(page).to have_content('Type: CIF')
    end
  end
end
```

### 2. System Tests

```ruby
# spec/system/complete_invoice_workflow_spec.rb
require 'rails_helper'

RSpec.describe 'Complete Invoice Workflow', type: :system do
  before do
    driven_by(:cuprite)
    stub_all_api_endpoints
  end
  
  it 'completes full invoice lifecycle' do
    # Login
    visit root_path
    fill_in 'Email', with: 'admin@example.com'
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # Create company
    visit new_company_path
    fill_in 'Name', with: 'ACME Corp'
    fill_in 'Tax ID', with: 'B12345678'
    fill_in 'Email', with: 'billing@acme.com'
    within '.address-fields' do
      fill_in 'Street', with: 'Main St 123'
      fill_in 'City', with: 'Madrid'
      fill_in 'Postal Code', with: '28001'
    end
    click_button 'Create Company'
    
    expect(page).to have_content('Company was successfully created')
    
    # Create invoice for company
    visit new_invoice_path
    select 'ACME Corp', from: 'Company'
    
    within '.line-items' do
      fill_in 'Description', with: 'Consulting Services'
      fill_in 'Quantity', with: '40'
      fill_in 'Unit price', with: '75'
      select '21%', from: 'Tax rate'
    end
    
    click_button 'Save as Draft'
    
    invoice_number = find('.invoice-number').text
    
    # Manage workflow
    click_link 'Manage Workflow'
    click_button 'Transition to Sent'
    
    # Send email
    click_button 'Send Email'
    fill_in 'Recipient Email', with: 'billing@acme.com'
    click_button 'Send'
    
    expect(page).to have_content('Email sent successfully')
    
    # Download PDF
    click_link 'Download PDF'
    expect(page.response_headers['Content-Type']).to include('application/pdf')
    
    # Freeze invoice
    accept_confirm do
      click_button 'Freeze Invoice'
    end
    
    expect(page).to have_content('Invoice frozen successfully')
    expect(page).not_to have_link('Edit')
  end
end
```

---

## JavaScript Tests

### 1. Stimulus Controller Tests

```ruby
# spec/javascript/controllers/invoice_form_controller_spec.js
import { Application } from "@hotwired/stimulus"
import InvoiceFormController from "controllers/invoice_form_controller"

describe("InvoiceFormController", () => {
  let application
  
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="invoice-form">
        <div data-invoice-form-target="lineItems">
          <div class="line-item">
            <input data-invoice-form-target="quantity" value="10">
            <input data-invoice-form-target="unitPrice" value="100">
            <input data-invoice-form-target="taxRate" value="21">
            <input data-invoice-form-target="discount" value="0">
          </div>
        </div>
        <span data-invoice-form-target="subtotal"></span>
        <span data-invoice-form-target="totalTax"></span>
        <span data-invoice-form-target="total"></span>
        <button data-action="invoice-form#addLine">Add Line</button>
      </div>
    `
    
    application = Application.start()
    application.register("invoice-form", InvoiceFormController)
  })
  
  it("calculates totals correctly", () => {
    const controller = application.controllers[0]
    controller.calculate()
    
    expect(controller.subtotalTarget.textContent).toBe("€1,000.00")
    expect(controller.totalTaxTarget.textContent).toBe("€210.00")
    expect(controller.totalTarget.textContent).toBe("€1,210.00")
  })
  
  it("adds new line item", () => {
    const button = document.querySelector('[data-action="invoice-form#addLine"]')
    button.click()
    
    const lineItems = document.querySelectorAll('.line-item')
    expect(lineItems.length).toBe(2)
  })
  
  it("removes line item", () => {
    // Add second line first
    const addButton = document.querySelector('[data-action="invoice-form#addLine"]')
    addButton.click()
    
    const removeButton = document.querySelector('[data-action="invoice-form#removeLine"]')
    removeButton.click()
    
    const lineItems = document.querySelectorAll('.line-item')
    expect(lineItems.length).toBe(1)
  })
})
```

---

## Performance Tests

```ruby
# spec/performance/api_response_spec.rb
require 'rails_helper'
require 'rspec-benchmark'

RSpec.describe 'API Performance', type: :request do
  include RSpec::Benchmark::Matchers
  
  before { login_as }
  
  describe 'Invoice listing performance' do
    before do
      stub_api_request(:get, '/invoices', {
        invoices: Array.new(100) { |i| { id: i, invoice_number: "INV-#{i}" } },
        total: 100
      })
    end
    
    it 'responds within acceptable time' do
      expect {
        get invoices_path
      }.to perform_under(300).ms
    end
    
    it 'handles concurrent requests' do
      expect {
        threads = 10.times.map do
          Thread.new { get invoices_path }
        end
        threads.each(&:join)
      }.to perform_under(1).sec
    end
  end
end
```

---

## Test Data Management

### 1. Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    
    trait :admin do
      role { 'admin' }
    end
  end
end

# spec/factories/api_responses.rb
FactoryBot.define do
  factory :company_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    name { Faker::Company.name }
    tax_id { "B#{Faker::Number.number(digits: 8)}" }
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    
    initialize_with { attributes }
  end
  
  factory :invoice_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    invoice_number { "INV-#{Faker::Number.number(digits: 4)}" }
    status { %w[draft sent paid].sample }
    total { Faker::Commerce.price(range: 100..10000) }
    company { association :company_response }
    
    initialize_with { attributes }
  end
end
```

### 2. Shared Examples

```ruby
# spec/support/shared_examples/authenticated_request.rb
RSpec.shared_examples 'authenticated request' do
  context 'without authentication' do
    before { session.clear }
    
    it 'redirects to login' do
      subject
      expect(response).to redirect_to(login_path)
    end
  end
  
  context 'with expired token' do
    before do
      session[:access_token] = 'expired_token'
      stub_api_request(:get, endpoint, { error: 'Token expired' }, 401)
    end
    
    it 'attempts token refresh' do
      expect(AuthService).to receive(:refresh_token)
      subject
    end
  end
end

# Usage in specs:
RSpec.describe 'Companies', type: :request do
  describe 'GET /companies' do
    subject { get companies_path }
    let(:endpoint) { '/companies' }
    
    it_behaves_like 'authenticated request'
  end
end
```

---

## Test Coverage Configuration

```ruby
# spec/spec_helper.rb
require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
])

SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  add_group 'Services', 'app/services'
  add_group 'Controllers', 'app/controllers'
  add_group 'Helpers', 'app/helpers'
  add_group 'JavaScript', 'app/javascript'
  
  minimum_coverage 90
  minimum_coverage_by_file 80
end
```

---

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.5
          bundler-cache: true
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 20
          cache: 'npm'
      
      - name: Install dependencies
        run: |
          bundle install
          npm install
      
      - name: Setup database
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost/test
        run: |
          bundle exec rails db:create
          bundle exec rails db:schema:load
      
      - name: Run tests
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost/test
          API_BASE_URL: http://localhost:3001/api/v1
        run: |
          bundle exec rspec --format documentation
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
```

---

## Test Execution Commands

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/invoice_service_spec.rb

# Run specific test
bundle exec rspec spec/services/invoice_service_spec.rb:15

# Run with specific tag
bundle exec rspec --tag focus

# Run only unit tests
bundle exec rspec spec/services spec/helpers

# Run only integration tests
bundle exec rspec spec/requests

# Run only feature tests
bundle exec rspec spec/features

# Run with coverage
COVERAGE=true bundle exec rspec

# Run in parallel (requires parallel_tests gem)
bundle exec parallel_rspec spec/

# Run with documentation format
bundle exec rspec --format documentation

# Run and fail fast
bundle exec rspec --fail-fast

# Run with seed for reproducibility
bundle exec rspec --seed 12345
```

---

## Test Metrics Goals

### Coverage Targets
- **Overall Coverage**: ≥ 90%
- **Service Objects**: ≥ 95%
- **Controllers**: ≥ 90%
- **Helpers**: ≥ 85%
- **JavaScript**: ≥ 80%

### Performance Targets
- **Unit Tests**: < 0.1s per test
- **Integration Tests**: < 0.5s per test
- **Feature Tests**: < 2s per test
- **Total Suite Runtime**: < 5 minutes

### Quality Metrics
- **Test/Code Ratio**: ≥ 1.5:1
- **Mutation Coverage**: ≥ 80%
- **Flaky Tests**: < 1%
- **Test Maintenance**: < 10% of development time

---

*This automated test plan provides comprehensive coverage across all test levels, from unit to E2E, ensuring robust validation of the FacturaCircular Cliente application.*