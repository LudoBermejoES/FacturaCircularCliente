# FacturaCircular Client - Test Strategy & Coverage Expansion Plan
*Updated with 2025 Best Practices Research*

## Executive Summary

**Current Status**: 259 tests passing (100% success rate) but insufficient coverage
**Target**: Comprehensive test coverage across all application layers aligned with Rails 8 and 2025 best practices
**Priority**: Critical gaps in controller coverage, JavaScript testing, and edge case scenarios
**Philosophy**: Quality over quantity - meaningful testing with modern metrics beyond line coverage

## Current Test Coverage Analysis

### ✅ Well-Covered Areas
- **Service Layer**: 14 RSpec files + 3 Minitest files (good coverage)
- **System Tests**: 16 files covering user workflows
- **Integration Tests**: 8 files for end-to-end scenarios
- **Basic Controller Coverage**: 13 controller test files

### ❌ Critical Coverage Gaps

#### 1. **Missing Controller Tests** (High Priority)
```
Missing Tests:
- addresses_controller_test.rb
- dashboard_controller_test.rb
- invoice_series_controller_test.rb
- tax_calculations_controller_test.rb
- tax_rates_controller_test.rb
- api/v1/company_contacts_controller_test.rb (minimal coverage)
```

#### 2. **Missing Service Tests** (Medium Priority)
```
Untested Services:
- address_validator_service_test.rb
- user_company_service_test.rb
```

#### 3. **JavaScript Testing** (High Priority)
```
Untested JavaScript Controllers (15 files):
- invoice_form_controller.js
- bulk_workflow_controller.js
- tax_calculator_controller.js
- workflow_diagram_controller.js
- company_switch_controller.js
- modal_controller.js
- dropdown_controller.js
- tabs_controller.js
- navigation_controller.js
- flash_controller.js
- toast_controller.js
- loading_controller.js
- (plus 3 more)
```

#### 4. **View Testing** (Medium Priority)
```
No view tests for 58 ERB templates
- Form validation display
- Conditional rendering logic
- Partial integration
- Helper method usage
```

#### 5. **Model/Form Objects** (Low Priority)
```
Missing Tests:
- workflow_state_form.rb
- Custom validation classes
- Form object patterns
```

## 2025 Testing Philosophy & Modern Approaches

### Test-Driven Development (TDD) vs Behavior-Driven Development (BDD)
Based on Rails 8 best practices, we'll employ a **hybrid TDD/BDD approach**:

- **TDD for Units**: Write failing tests first for controllers, services, and models
- **BDD for Features**: Use human-readable scenarios for system tests and user workflows
- **Integration Focus**: Emphasize testing component interactions over isolated units

### Modern Coverage Metrics (Beyond Line Coverage)

#### 1. **Critical Path Coverage**
Focus on testing business logic, high-impact components, and failure-prone areas rather than achieving arbitrary percentage targets.

#### 2. **Risk-Based Coverage**
Prioritize testing high-risk areas:
- Payment processing workflows
- Authentication and authorization
- Data validation and transformation
- API integration points

#### 3. **Requirement Coverage**
Ensure tests validate business requirements, not just code execution:
- Invoice workflow state transitions
- Tax calculation compliance
- Multi-company data isolation
- Spanish regulatory compliance (Facturae)

#### 4. **Integration Coverage**
Measure testing of service interactions, API calls, and third-party integrations:
- Service-to-service communication
- Database transaction boundaries
- External API dependencies
- WebMock coverage completeness

### Test Pyramid Strategy (2025 Update)

Following modern Rails 8 testing philosophy:

```
    🔺 System Tests (Few, Slow, High Value)
      - Complete user journeys
      - Critical business workflows
      - Cross-browser compatibility

   🔺🔺 Integration Tests (Some, Medium Speed)
      - Component interactions
      - API contract testing
      - Service layer integration

  🔺🔺🔺 Unit Tests (Many, Fast, Focused)
      - Controller logic
      - Service methods
      - Model validations
      - JavaScript controller behaviors
```

## Comprehensive Test Strategy

### Phase 1: Controller Coverage Completion (Week 1)
**Target**: Achieve 100% controller test coverage

#### 1.1 Missing Controller Tests
```ruby
# Priority Order:
1. dashboard_controller_test.rb    - Core navigation
2. tax_calculations_controller_test.rb - Business logic
3. tax_rates_controller_test.rb    - CRUD operations
4. invoice_series_controller_test.rb - Complex business rules
5. addresses_controller_test.rb    - Address management
```

#### 1.2 Controller Test Patterns
```ruby
# Each controller test should cover:
- Authentication requirements
- Authorization checks (role-based access)
- Parameter validation
- Happy path scenarios
- Error handling
- Redirect logic
- Flash message verification
- JSON/HTML response formats
```

#### 1.3 Controller Test Template
```ruby
class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_authenticated_session(role: "admin", company_id: 1)
  end

  test "index loads successfully for authenticated user" do
    # Mock required services
    InvoiceService.stubs(:statistics).returns({ total_count: 10 })
    CompanyService.stubs(:current).returns({ id: 1, name: "Test Co" })

    get dashboard_path
    assert_response :success
    assert_select "h1", /Dashboard/
  end

  test "redirects unauthenticated users to login" do
    logout_user
    get dashboard_path
    assert_redirected_to login_path
  end

  # Additional test cases...
end
```

### Phase 2: JavaScript Testing Framework (Week 2)
**Target**: Establish robust frontend testing infrastructure following 2025 Stimulus testing best practices

#### 2.1 Modern JavaScript Testing Approach (2025 Research Update)

**Primary Strategy: System Test Focus**
Based on current best practices, **System Tests should be the primary method** for testing Stimulus controllers:
- Tests functionality from user perspective
- Catches integration issues (typos in targets, values, events)
- Reflects real-world usage patterns
- Avoids testing implementation details

**Secondary Strategy: Unit Tests for Complex Logic**
Use Jest/stimulus_tests gem for isolated controller logic:
- Complex data transformations
- Edge case handling
- Algorithm testing

#### 2.2 JavaScript Testing Tools Selection

**Option 1: System Test Focused (Recommended)**
```ruby
# test/system/stimulus_controllers_test.rb
class StimulusControllersTest < ApplicationSystemTestCase
  test "invoice form controller updates buyer selection" do
    visit new_invoice_path

    # Test real DOM interactions
    select "External Contact", from: "buyer_type"
    assert_selector "#buyer-company-contacts", visible: true
    assert_selector "#buyer-companies", visible: false
  end
end
```

**Option 2: Jest Unit Testing (For Complex Logic)**
```json
// package.json additions
{
  "devDependencies": {
    "@jest/environment-jsdom": "^29.0.0",
    "jest": "^29.0.0",
    "@testing-library/dom": "^8.0.0",
    "@testing-library/jest-dom": "^5.0.0",
    "mutationobserver-shim": "^0.3.7"
  }
}
```

**Option 3: stimulus_tests Gem (Rails-Native)**
```ruby
# Gemfile
gem 'stimulus_tests', group: :test

# test/stimulus/invoice_form_controller_test.rb
class InvoiceFormControllerTest < StimulusTestCase
  test "connects and initializes targets" do
    render_stimulus(<<~HTML)
      <div data-controller="invoice-form">
        <select data-invoice-form-target="buyerType"></select>
      </div>
    HTML

    assert_selector '[data-invoice-form-target="buyerType"]'
  end
end
```

#### 2.2 Stimulus Controller Tests
```javascript
// test/javascript/controllers/invoice_form_controller.test.js
import { Application } from "@hotwired/stimulus"
import InvoiceFormController from "../../../app/javascript/controllers/invoice_form_controller"

describe("InvoiceFormController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="invoice-form">
        <select data-invoice-form-target="buyerType"></select>
      </div>
    `

    const application = Application.start()
    application.register("invoice-form", InvoiceFormController)
  })

  test("connects successfully", () => {
    expect(document.querySelector('[data-controller="invoice-form"]')).toBeInTheDocument()
  })

  test("updates buyer selection correctly", () => {
    // Test buyer selection logic
  })
})
```

#### 2.3 JavaScript Test Categories
```
1. Stimulus Controller Logic Tests
   - Connection/disconnection
   - Target finding
   - Event handling
   - Data updates

2. Form Interaction Tests
   - Dynamic field updates
   - Validation display
   - Submission handling
   - AJAX requests

3. UI Component Tests
   - Modal behaviors
   - Dropdown interactions
   - Tab switching
   - Navigation states
```

### Phase 3: Service Layer Enhancement (Week 3)
**Target**: Complete service test coverage and add edge cases

#### 3.1 Missing Service Tests
```ruby
# test/services/address_validator_service_test.rb
class AddressValidatorServiceTest < ActiveSupport::TestCase
  test "validates Spanish postal codes correctly" do
    # Test Spanish postal code formats
  end

  test "handles international address formats" do
    # Test various country formats
  end

  test "validates required address fields" do
    # Test field validation logic
  end
end
```

#### 3.2 Enhanced Service Test Coverage
```ruby
# Expand existing service tests with:
- Error boundary testing
- Rate limiting scenarios
- Timeout handling
- Malformed response handling
- Authentication expiry scenarios
- Concurrent request handling
```

### Phase 4: View Testing Implementation (Week 4)
**Target**: Add view-specific testing for complex rendering logic

#### 4.1 View Test Framework
```ruby
# test/views/invoices/new_test.rb
class InvoicesNewViewTest < ActionView::TestCase
  setup do
    @invoice = OpenStruct.new(id: nil, status: 'draft')
    @companies = [{ id: 1, name: "Test Co" }]
    @invoice_series = [{ id: 1, series_code: "FC" }]
  end

  test "renders form with required fields" do
    render template: "invoices/new", locals: {
      invoice: @invoice,
      companies: @companies,
      invoice_series: @invoice_series
    }

    assert_select "form[action=?]", invoices_path
    assert_select "select[name='invoice[invoice_series_id]']"
    assert_select "input[name='invoice[issue_date]']"
  end

  test "shows validation errors when present" do
    @invoice.errors = { issue_date: ["can't be blank"] }

    render template: "invoices/new"
    assert_select ".error-message", "Issue date can't be blank"
  end
end
```

#### 4.2 View Testing Priorities
```
1. Form Rendering Tests
   - Required field display
   - Error message rendering
   - Conditional field visibility
   - Helper method usage

2. Partial Integration Tests
   - Shared partial rendering
   - Data passing between partials
   - Nested partial structures

3. Complex Logic Views
   - Workflow status displays
   - Tax calculations display
   - Permission-based rendering
   - Multi-step form displays
```

### Phase 5: Integration & E2E Enhancement (Week 5)
**Target**: Comprehensive user journey testing

#### 5.1 Critical User Journey Tests
```ruby
# test/integration/complete_invoice_lifecycle_test.rb
class CompleteInvoiceLifecycleTest < ActionDispatch::IntegrationTest
  test "complete invoice creation to approval workflow" do
    login_as_admin

    # Create invoice
    visit new_invoice_path
    fill_in_invoice_form
    click_button "Create Invoice"

    # Verify creation
    assert_text "Invoice created successfully"
    invoice_id = extract_invoice_id_from_url

    # Workflow transition
    visit invoice_workflow_path(invoice_id)
    select "Approved", from: "status"
    click_button "Update Status"

    # Verify workflow
    assert_text "Status updated to approved"

    # Freeze invoice
    click_button "Freeze Invoice"
    assert_text "Invoice frozen successfully"

    # Verify immutability
    visit edit_invoice_path(invoice_id)
    assert_text "Cannot edit frozen invoice"
  end
end
```

#### 5.2 Cross-Browser Testing
```yaml
# .github/workflows/browser-tests.yml
- name: Test on Chrome
  run: bundle exec rails test:system

- name: Test on Firefox
  env:
    SELENIUM_BROWSER: firefox
  run: bundle exec rails test:system

- name: Test on Safari
  env:
    SELENIUM_BROWSER: safari
  run: bundle exec rails test:system
```

### Phase 6: Performance & Security Testing (Week 6)
**Target**: Non-functional testing coverage

#### 6.1 Performance Testing
```ruby
# test/performance/page_load_performance_test.rb
class PageLoadPerformanceTest < ActionDispatch::IntegrationTest
  test "dashboard loads within acceptable time" do
    setup_large_dataset # 1000+ invoices

    start_time = Time.current
    get dashboard_path
    end_time = Time.current

    assert_response :success
    assert (end_time - start_time) < 2.seconds, "Dashboard took too long to load"
  end

  test "invoice list pagination performs well" do
    # Test pagination with large datasets
  end
end
```

#### 6.2 Security Testing
```ruby
# test/security/authorization_test.rb
class AuthorizationTest < ActionDispatch::IntegrationTest
  test "users cannot access other companies' data" do
    setup_authenticated_session(company_id: 1)

    # Try to access company 2's data
    get company_path(2)
    assert_response :forbidden
  end

  test "prevents CSRF attacks on forms" do
    # Test CSRF protection
  end

  test "sanitizes user input properly" do
    # Test XSS prevention
  end
end
```

## Testing Infrastructure Improvements

### 1. Test Data Management
```ruby
# test/factories/invoice_factory.rb
class InvoiceFactory
  def self.build(overrides = {})
    {
      id: 123,
      invoice_number: "FC-001",
      status: "draft",
      issue_date: Date.current.strftime('%Y-%m-%d'),
      total_amount: 1000.0
    }.merge(overrides)
  end

  def self.build_with_lines(line_count = 3)
    invoice = build
    invoice[:lines] = (1..line_count).map do |i|
      {
        id: i,
        description: "Item #{i}",
        quantity: 1,
        unit_price: 100.0
      }
    end
    invoice
  end
end
```

### 2. Enhanced Test Helpers
```ruby
# test/support/api_mock_helpers.rb
module ApiMockHelpers
  def mock_successful_invoice_creation
    InvoiceService.stubs(:create).returns({
      data: { id: "123", invoice_number: "FC-001" }
    })
  end

  def mock_api_error(service, method, error_type = :validation_error)
    service.stubs(method).raises(
      ApiService.const_get("#{error_type.to_s.camelize}")
    )
  end

  def mock_large_dataset(size = 1000)
    # Mock large dataset responses for performance testing
  end
end
```

### 3. Advanced Test Coverage Reporting (2025 Standards)
```ruby
# test/test_helper.rb
require 'simplecov'

SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
  add_filter '/test/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'JavaScript', 'app/javascript'
  add_group 'Views', 'app/views'
  add_group 'Critical Paths', ['app/services/auth_service.rb',
                                'app/controllers/invoices_controller.rb',
                                'app/services/workflow_service.rb']

  # Modern 2025 approach: Focus on meaningful coverage
  minimum_coverage 75  # Lower threshold but higher quality
  minimum_coverage_by_file 60  # Per-file minimums

  # Track additional metrics
  track_files "app/**/*.rb"
  refuse_coverage_drop

  # Custom formatters for modern reporting
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

# Add mutation testing configuration
# Enable with: gem 'mutant-rspec' (for mutation testing)
```

#### Modern Coverage Philosophy (Research-Based)
- **Quality over Quantity**: 75% meaningful coverage > 95% superficial coverage
- **Critical Path Focus**: 100% coverage of authentication, payments, data validation
- **Risk-Based Testing**: High coverage for high-risk, high-impact components
- **Business Logic Priority**: Ensure all business requirements have corresponding tests

## Implementation Priority Matrix

### High Priority (Week 1-2)
```
1. Controller Coverage Completion
   - Risk: Medium
   - Effort: Medium
   - Business Impact: High

2. JavaScript Testing Setup
   - Risk: High
   - Effort: High
   - Business Impact: High
```

### Medium Priority (Week 3-4)
```
3. Service Layer Enhancement
   - Risk: Low
   - Effort: Medium
   - Business Impact: Medium

4. View Testing Implementation
   - Risk: Low
   - Effort: Medium
   - Business Impact: Medium
```

### Lower Priority (Week 5-6)
```
5. Integration Enhancement
   - Risk: Medium
   - Effort: High
   - Business Impact: Medium

6. Performance & Security Testing
   - Risk: Low
   - Effort: Medium
   - Business Impact: Low
```

## Success Metrics

### Quantitative Goals (Updated for 2025)
- **Meaningful Coverage**: Achieve 75%+ overall coverage with high-quality tests
- **Critical Path Coverage**: 100% of business-critical paths tested
- **Controller Coverage**: 100% of controllers tested (reduced complexity focus)
- **Service Coverage**: 100% of services tested with edge cases
- **JavaScript Coverage**: System test coverage for all Stimulus interactions
- **Test Performance**: All tests complete in under 5 minutes
- **Mutation Testing**: 70%+ mutation test survival rate for critical components

### Qualitative Goals (2025 Standards)
- **Business Alignment**: Tests validate business requirements, not just code execution
- **Risk Mitigation**: High coverage of high-risk components (auth, payments, compliance)
- **User Experience**: System tests cover complete user journeys
- **Maintainability**: Tests are documentation for business logic
- **Confidence**: Teams can deploy frequently with automated testing assurance
- **Real-World Coverage**: Tests reflect actual usage patterns and edge cases

## Testing Tools & Technologies

### Current Stack
- **Minitest**: Rails default testing framework
- **RSpec**: BDD-style testing for services
- **Capybara**: System test browser automation
- **WebMock**: HTTP request mocking
- **SimpleCov**: Test coverage reporting

### Proposed Additions (2025 Research-Based)
- **Primary**: Enhanced System Tests for Stimulus (Rails-native approach)
- **Secondary**: Jest + Mutation Observer Shim (for complex JS logic only)
- **stimulus_tests Gem**: Rails-integrated Stimulus testing
- **Mutant/Mutant-RSpec**: Mutation testing for critical components
- **Factory Bot**: Advanced test data generation patterns
- **Parallel Testing**: Rails 7+ built-in parallel test execution
- **SimpleCov + Custom Metrics**: Advanced coverage reporting
- **Real-User Monitoring**: Testing based on production usage patterns

## Maintenance Strategy

### Daily Practices
- Run full test suite before each commit
- Maintain test coverage above 85%
- Write tests for all new features
- Update tests when modifying existing code

### Weekly Reviews
- Review test coverage reports
- Identify slow or flaky tests
- Update test data and mocks
- Refactor test code for maintainability

### Monthly Audits
- Analyze test effectiveness
- Remove obsolete tests
- Update testing infrastructure
- Train team on new testing patterns

---

## Next Steps

1. **Immediate Actions**:
   - Create missing controller tests (Phase 1)
   - Set up JavaScript testing framework (Phase 2)
   - Establish test coverage reporting

2. **Team Alignment**:
   - Review strategy with development team
   - Assign ownership for each testing phase
   - Set up automated test coverage reporting

3. **Infrastructure Setup**:
   - Configure parallel test execution
   - Set up CI/CD integration
   - Establish coverage thresholds

---

## 2025 Research Summary & Key Insights

### Key Findings from Industry Research

#### 1. **Rails 8 Testing Philosophy**
- Built-in testing framework promotes TDD/BDD hybrid approach
- System tests are the gold standard for full-stack integration
- Focus on test-driven development for quality and maintainability

#### 2. **Modern Stimulus Testing Best Practices**
- **Primary approach**: System tests for real user interactions
- **Secondary approach**: Unit tests only for complex logic
- Avoid testing implementation details; focus on user behavior
- Tools: System tests > stimulus_tests gem > Jest (in order of preference)

#### 3. **Coverage Metrics Evolution**
- **Line coverage is insufficient**: Focus on critical path and requirement coverage
- **Quality over quantity**: 75% meaningful coverage > 95% superficial coverage
- **Risk-based testing**: Prioritize high-impact, high-risk components
- **Integration coverage**: Test service interactions and API contracts

#### 4. **Modern Testing Tools (2025)**
- Mutation testing for validating test effectiveness
- Real-world traffic analysis for edge case discovery
- Advanced coverage metrics beyond line/branch coverage
- Automated test gap detection and prioritization

### Strategic Recommendations Based on Research

1. **Start with System Tests**: Prioritize comprehensive user journey testing
2. **Implement Risk-Based Coverage**: Focus on authentication, payments, and compliance
3. **Use Modern Metrics**: Track critical path and requirement coverage
4. **Adopt Rails 8 Patterns**: Leverage built-in testing framework capabilities
5. **Quality-First Approach**: Meaningful tests over coverage percentages

### Implementation Alignment

This strategy incorporates 2025 best practices while maintaining pragmatic implementation:
- **Phase 1-2**: Focus on high-impact, low-effort improvements (controllers, system tests)
- **Phase 3-4**: Advanced techniques (mutation testing, complex coverage metrics)
- **Phase 5-6**: Optimization and continuous improvement

The research validates our approach while emphasizing **quality over quantity** and **business alignment over technical metrics**. This comprehensive test strategy will transform the current basic test coverage into a robust, maintainable testing ecosystem that ensures code quality and developer confidence, aligned with 2025 industry standards.