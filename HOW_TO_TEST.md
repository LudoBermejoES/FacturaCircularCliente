# Rails Client Testing Guide

This document provides testing guidelines and execution instructions for the FacturaCircular Rails client application.

## How to Execute Tests

### Prerequisites
- Docker and Docker Compose running
- Client application services started: `docker-compose up -d`

### Test Execution Commands

#### Docker Environment (Recommended)
```bash
cd /Users/ludo/code/albaranes/client

# Service tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/ --format progress"

# Controller tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/controllers/ --format progress"

# Feature tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/features/ --format progress"

# Integration tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/integration/ --format progress"

# Request tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/requests/ --format progress"

# System tests (RSpec with Capybara)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/system/ --format progress"

# Performance tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/performance/ --format progress"

# Security tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/security/ --format progress"

# All tests
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