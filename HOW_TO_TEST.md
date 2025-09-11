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
  -e API_BASE_URL=http://albaranes-api:3000/api/v1 \
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
API_BASE_URL=http://albaranes-api:3000/api/v1
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
          API_BASE_URL: http://albaranes-api:3000/api/v1
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

### Phase 1: Authentication ✅
- Login/logout flows
- Token management
- Protected routes

### Phase 2: Dashboard & Navigation ✅
- Dashboard widgets
- Navigation menus
- Global components

### Phase 3: Company Management ✅
- CRUD operations
- Address management
- Search and filters

### Phase 4: Invoice Management ✅
- Invoice creation with line items
- Dynamic calculations
- PDF/XML exports

### Phase 5: Workflow Management ✅
- Status transitions
- Workflow history
- Bulk operations

### Phase 6: Tax Management ✅
- Tax calculations
- Tax ID validation
- Regional variations

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
