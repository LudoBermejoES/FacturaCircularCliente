# Rails Client Testing Guide

This document provides testing guidelines and execution instructions for the FacturaCircular Rails client application, including both unit/integration tests (RSpec) and end-to-end tests (Playwright).

## Testing Stack Overview

### Test Types
1. **Unit/Integration Tests (RSpec)** - Ruby-based tests for services, controllers, and Rails components
2. **End-to-End Tests (Playwright)** - Modern browser automation tests for user workflows

## How to Execute Tests

### Prerequisites
- Docker and Docker Compose running
- Client application services started: `docker-compose up -d`

## 🎭 E2E Tests with Playwright (Recommended)

### Quick Start
```bash
# Run all E2E tests in Docker
./run-e2e-tests.sh

# Run tests with specific browser
./run-e2e-tests.sh -b firefox

# Run tests in debug mode (visible browser)
./run-e2e-tests.sh -h -d

# Run specific test suite
./run-e2e-tests.sh -t tests/invoices
```

### Playwright Test Commands

#### Docker-based Testing (Production-like)
```bash
# Build Playwright Docker image (first time only)
docker-compose build playwright

# Run all E2E tests
docker-compose run --rm playwright

# Run specific browser tests
docker-compose run --rm playwright npx playwright test --project=chromium
docker-compose run --rm playwright npx playwright test --project=firefox
docker-compose run --rm playwright npx playwright test --project=webkit

# Run specific test file
docker-compose run --rm playwright npx playwright test tests/invoices/invoice-calculations.spec.ts

# Run tests in headed mode (visible browser - requires X11)
docker-compose run --rm -e HEADED=1 playwright npx playwright test --headed

# Generate HTML report
docker-compose run --rm playwright npx playwright show-report
```

#### Local Testing (Development)
```bash
cd e2e

# Install dependencies (first time only)
npm install

# Install browsers (first time only)
npx playwright install

# Run all tests
npx playwright test

# Run with UI mode (interactive debugging)
npx playwright test --ui

# Run specific test file
npx playwright test tests/workflows/sla-tracking.spec.ts

# Run in debug mode
npx playwright test --debug

# Generate test code with Codegen
npx playwright codegen http://localhost:3002

# View test report
npx playwright show-report
```

### E2E Test Structure
```
e2e/
├── tests/                    # Test files
│   ├── auth/                 # Authentication tests
│   ├── invoices/            # Invoice management tests
│   │   └── invoice-calculations.spec.ts
│   ├── workflows/           # Workflow and SLA tests
│   │   └── sla-tracking.spec.ts
│   └── smoke/               # Critical path tests
├── pages/                   # Page Object Model
│   ├── base.page.ts        # Base page class
│   ├── login.page.ts       # Login page actions
│   ├── invoice.page.ts     # Invoice page actions
│   └── workflow.page.ts    # Workflow/SLA page actions
├── fixtures/                # Test fixtures and helpers
│   ├── auth.fixture.ts     # Authentication helpers
│   └── api-mocks.fixture.ts # API response mocks
├── playwright.config.ts    # Playwright configuration
└── package.json            # Dependencies
```

### Writing New E2E Tests

#### Example Test Structure
```typescript
import { test, expect } from '../fixtures/auth.fixture';
import { InvoicePage } from '../pages/invoice.page';

test.describe('Feature Name', () => {
  let invoicePage: InvoicePage;

  test.beforeEach(async ({ authenticatedPage }) => {
    invoicePage = new InvoicePage(authenticatedPage);
    await invoicePage.gotoNew();
  });

  test('should perform expected behavior', async () => {
    // Arrange
    await invoicePage.addInvoiceLine('Product', 1, 100);

    // Act
    await invoicePage.submit();

    // Assert
    await expect(invoicePage.successMessage).toBeVisible();
  });
});
```

### Playwright Benefits Over Selenium/Capybara
✅ **No timeout issues** - Direct browser communication without WebDriver
✅ **3-5x faster** - Native browser automation
✅ **Better debugging** - Trace viewer, screenshots, videos
✅ **Auto-waiting** - Intelligent element detection
✅ **Cross-browser** - Chromium, Firefox, WebKit in one tool
✅ **TypeScript** - Type safety and IntelliSense

### Debugging E2E Tests
```bash
# Use UI Mode for step-by-step debugging
npx playwright test --ui

# Use Debug mode with breakpoints
npx playwright test --debug

# Use headed mode to see the browser
./run-e2e-tests.sh -h

# View trace files for failed tests
npx playwright show-trace trace.zip

# Check test reports
npx playwright show-report
```

## 🧪 RSpec Tests (Unit/Integration)

### RSpec Test Commands

#### Docker Environment
```bash
cd /Users/ludo/code/albaranes/client

# Service tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/ --format progress"

# Controller tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/controllers/ --format progress"

# Feature tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/features/ --format progress"

# All RSpec tests
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec --format progress"
```

#### Specific Test Files
```bash
# Individual service test
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/workflow_service_spec.rb"

# Individual controller test
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/controllers/workflow_definitions_controller_spec.rb"

# Verbose output for debugging
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/ -v"
```

#### Local Environment (Alternative)
```bash
cd /Users/ludo/code/albaranes/client

# Service tests
RAILS_ENV=test bundle exec rspec spec/services/

# Controller tests
RAILS_ENV=test bundle exec rspec spec/controllers/

# All tests
RAILS_ENV=test bundle exec rspec
```

### ⚠️ Critical Environment Configuration

**MUST use `RAILS_ENV=test`** for all test executions to ensure:
- Proper host authorization configuration
- Test database isolation
- Correct environment-specific settings
- Avoidance of "Blocked hosts" errors

## Test Areas Coverage

### 🧩 Service Layer Tests (`spec/services/`)
Tests for API client services that communicate with the backend:

- **ApiService**: Base HTTP client functionality and error handling
- **AuthService**: Authentication, login, logout, token management
- **CompanyService**: Company CRUD operations
- **CompanyContactsService**: Company contact management
- **InvoiceService**: Invoice operations and data transformations
- **InvoiceSeriesService**: Invoice numbering and series management
- **TaxService**: Tax calculations and compliance
- **WorkflowService**: Workflow management and status transitions

**Key Testing Patterns:**
- WebMock stubs for HTTP requests
- JSON response parsing and data transformation
- Error handling for API failures
- Parameter validation and sanitization

### 🎮 Controller Tests (`spec/controllers/`)
Tests for web controllers handling user interactions:

- **ApplicationController**: Authentication, permissions, session management
- **SessionsController**: Login/logout flows
- **CompaniesController**: Company selection and management
- **InvoicesController**: Invoice form handling and workflow assignment
- **DashboardController**: Main application dashboard
- **HomeController**: Landing pages and public content

**Key Testing Patterns:**
- RSpec authentication helpers with Devise
- Form parameter validation
- Redirect behavior verification
- Permission-based access control
- Session state management

### 🌐 Feature Tests (`spec/features/`)
End-to-end user workflow tests:

- **Authentication flows**: Complete login/logout scenarios
- **Invoice management**: Creating and editing invoices
- **User permissions**: Role-based access control
- **Multi-step form interactions**: Complex form workflows
- **Error handling**: User-facing error scenarios

**Key Testing Patterns:**
- Service mocking for external API calls
- Page navigation and content verification
- Form submission and validation
- Session persistence testing

### 📡 Integration Tests (`spec/integration/`)
Testing component integration and data flow:

- **Service integration**: API client service interactions
- **Authentication flow**: Login/logout integration
- **Data transformation**: Request/response processing

### 🔗 Request Tests (`spec/requests/`)
Testing HTTP request/response cycles:

- **API endpoint testing**: Internal API endpoints
- **Authentication requirements**: Protected routes
- **Parameter handling**: Request processing

### 🖥️ System Tests (`spec/system/`)
Browser-based integration tests using Capybara:

- **SLA tracking**: Performance monitoring workflows
- **Full user journeys**: Complete application workflows
- **JavaScript behavior**: Dynamic UI interactions

**Key Testing Patterns:**
- Capybara for browser automation
- Real browser testing scenarios
- End-to-end workflow validation

### ⚡ Performance Tests (`spec/performance/`)
Performance and load testing:

- **Response times**: API call performance
- **Memory usage**: Resource consumption testing
- **Scalability**: Load testing scenarios

### 🔒 Security Tests (`spec/security/`)
Security and vulnerability testing:

- **Authentication security**: Session management
- **Authorization checks**: Permission validation
- **Input validation**: XSS and injection prevention
- **CSRF protection**: Security token validation

## Testing Best Practices

### Service Test Patterns
```ruby
# WebMock stub setup
stub_request(:get, "#{base_url}/endpoint")
  .with(headers: { 'Authorization' => "Bearer #{token}" })
  .to_return(status: 200, body: response.to_json)

# Service call verification
result = ServiceClass.method(params, token: token)
expect(result[:key]).to eq(expected_value)
```

### Controller Test Patterns
```ruby
# Authentication setup (with RSpec helpers)
let(:current_user) { create(:user, role: "admin", company_id: 1) }
before { sign_in current_user }

# Request testing
post endpoint_url, params: { model: { field: value } }
expect(response).to redirect_to(expected_path)
expect(flash[:success]).to eq('Success message')
```

### Feature Test Patterns
```ruby
# Service mocking
allow(ServiceClass).to receive(:method).and_return(mock_response)

# User interaction testing
visit page_path
fill_in 'Field', with: 'value'
click_button 'Submit'
expect(page).to have_content('Expected content')
```

## Debugging Test Failures

### Common Issues and Solutions

1. **Authentication Errors**: Ensure proper RSpec authentication helpers are used
2. **WebMock Mismatches**: Verify URL patterns match service calls exactly
3. **JSON Parsing**: Check response format matches expected structure
4. **Environment Issues**: Always use `RAILS_ENV=test`
5. **Docker Permission**: Ensure Docker has proper file system access

### Debugging Commands
```bash
# Run with full backtrace
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/path --backtrace"

# Run single test with verbose output
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/path:line_number -v"

# Check test logs
docker-compose logs web
```

## Test Environment Setup

### Required Services
- **Web Container**: Rails application
- **Selenium Container**: Browser testing (for system tests)
- **Test Database**: Isolated test data

### Configuration Files
- `config/environments/test.rb`: Test environment settings
- `spec/rails_helper.rb`: RSpec configuration and helpers
- `spec/spec_helper.rb`: Core RSpec configuration
- `spec/support/`: Shared test helpers and configuration
- `docker-compose.yml`: Container orchestration

### Authentication Test Helpers
The test suite includes RSpec helpers for authentication setup:

```ruby
# In spec/rails_helper.rb or spec/support/
RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :feature
end

# Usage in specs
let(:current_user) { create(:user, role: "viewer", company_id: 1) }
before { sign_in current_user }
```

This provides consistent authentication across all test types and ensures proper permission testing.

## 🚀 CI/CD Integration

### GitHub Actions Example
```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  playwright-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start services
        run: docker-compose up -d web

      - name: Build Playwright container
        run: docker-compose build playwright

      - name: Run E2E tests
        run: docker-compose run --rm playwright

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/

  rspec-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start services
        run: docker-compose up -d web

      - name: Run RSpec tests
        run: docker-compose exec -T web bash -c "RAILS_ENV=test bundle exec rspec"
```

## 📊 Test Coverage Goals

### E2E Tests (Playwright)
- **Critical User Paths**: 100% coverage
- **Feature Coverage**: 80% of UI features
- **Cross-browser**: Test on Chromium, Firefox, WebKit
- **Mobile**: Test responsive design on mobile viewports

### Unit/Integration Tests (RSpec)
- **Service Layer**: 100% coverage
- **Controllers**: 90% coverage
- **Edge Cases**: 80% coverage
- **Error Handling**: 100% coverage

## 🎯 Testing Best Practices

### For E2E Tests
1. **Use Page Object Model** - Maintain all page interactions in page objects
2. **Mock External APIs** - Use fixtures for faster, reliable tests
3. **Test User Journeys** - Focus on complete workflows, not individual pages
4. **Keep Tests Independent** - Each test should be able to run in isolation
5. **Use Data Attributes** - Add `data-testid` attributes for stable selectors

### For RSpec Tests
1. **Mock External Services** - Use WebMock for HTTP requests
2. **Use Factories** - FactoryBot for test data generation
3. **Test Behavior, Not Implementation** - Focus on outcomes
4. **Keep Tests Fast** - Avoid database operations when possible
5. **Use Shared Examples** - DRY up common test patterns

## 🐛 Troubleshooting

### Playwright Tests
- **Timeout Issues**: Increase timeout in `playwright.config.ts`
- **Browser Not Found**: Run `npx playwright install`
- **Docker Issues**: Rebuild with `docker-compose build playwright`
- **Network Errors**: Check if services are running with `docker-compose ps`

### RSpec Tests
- **Database Errors**: Ensure `RAILS_ENV=test` is set
- **WebMock Errors**: Check URL patterns match exactly
- **Authentication Errors**: Verify test helpers are included
- **Timeout Errors**: Consider migrating to Playwright for browser tests

## 📚 Additional Resources
- [Playwright Documentation](https://playwright.dev)
- [RSpec Documentation](https://rspec.info)
- [Test Migration Plan](plan_for_e2e_tests.md)
- [Project README](../README.md)