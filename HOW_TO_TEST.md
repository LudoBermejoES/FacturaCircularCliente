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

# Controller tests (Minitest)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rails test test/controllers/"

# Feature tests (RSpec)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/features/"

# System tests (Browser-based)
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rails test test/system/"
```

#### Specific Test Files
```bash
# Individual service test
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/workflow_service_spec.rb"

# Individual controller test
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rails test test/controllers/workflow_definitions_controller_test.rb"

# Verbose output for debugging
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/ -v"
```

#### Local Environment (Alternative)
```bash
cd /Users/ludo/code/albaranes/client

# Service tests
RAILS_ENV=test bundle exec rspec spec/services/

# Controller tests
RAILS_ENV=test bundle exec rails test test/controllers/
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

### 🎮 Controller Tests (`test/controllers/`)
Tests for web controllers handling user interactions:

- **ApplicationController**: Authentication, permissions, session management
- **SessionsController**: Login/logout flows
- **CompaniesController**: Company selection and management
- **WorkflowDefinitionsController**: Workflow CRUD with company security
- **InvoicesController**: Invoice form handling
- **API Controllers**: Internal API endpoints

**Key Testing Patterns:**
- Authentication setup with `setup_authenticated_session`
- Form parameter validation
- Redirect behavior verification
- Permission-based access control
- Session state management

### 🌐 Feature Tests (`spec/features/`)
End-to-end user workflow tests:

- **AuthenticationFlow**: Complete login/logout scenarios
- **User permissions and role-based access
- **Multi-step form interactions
- **Error handling in user workflows

**Key Testing Patterns:**
- Service mocking for external API calls
- Page navigation and content verification
- Form submission and validation
- Session persistence testing

### 🖥️ System Tests (`test/system/`)
Browser-based integration tests using Selenium:

- **Form interactions**: Field validation, submissions
- **JavaScript behavior**: Dynamic form elements
- **Full user journeys**: Complete workflows
- **Visual regression**: UI component behavior

**Key Testing Patterns:**
- Chrome driver for browser automation
- Page object patterns for UI interactions
- Capybara for DOM manipulation
- Screenshot capture for debugging

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
# Authentication setup
setup_authenticated_session(role: "admin", company_id: 1)

# Request testing
post endpoint_url, params: { model: { field: value } }
assert_redirected_to expected_path
assert_equal 'Success message', flash[:success]
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

1. **Authentication Errors**: Ensure `setup_authenticated_session` is called
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
- `spec/rails_helper.rb`: RSpec configuration
- `test/test_helper.rb`: Minitest configuration
- `docker-compose.yml`: Container orchestration

### Authentication Test Helpers
The test suite includes helpers for authentication setup:

```ruby
# In test_helper.rb
def setup_authenticated_session(role: "viewer", company_id: 1, companies: nil)
  # Sets up user session with specified role and company access
end
```

This provides consistent authentication across all test types and ensures proper permission testing.