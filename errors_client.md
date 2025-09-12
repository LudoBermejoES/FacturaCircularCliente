# Client Test Errors Report

## Summary
- **Total Tests**: ~130+ tests across different specs
- **Passing**: Most unit tests (services, requests, some controllers)
- **Failing**: Controller tests for InvoiceSeriesController
- **Pending**: 13 feature tests (intentionally skipped)

## Test Results by Category

### ✅ PASSING TESTS

#### 1. Request Specs (82/82 passing)
- All invoice series request specs: **23/23 passing**
- All addresses request specs: **passing**
- All other request specs: **passing**
- **Coverage**: 44.3% (478/1079)

#### 2. Addresses Controller (19/19 passing)
- All CRUD operations working
- Authentication tests passing
- Error handling working

#### 3. Service Specs (Most passing, some timeout issues)
- CompanyService tests
- AuthService tests
- InvoiceSeriesService tests
- Most other service tests

### ❌ FAILING TESTS

#### InvoiceSeriesController (19 failures)
All failures are due to incorrect method signatures when mocking service calls:

**Root Cause**: The specs are using old method signatures that don't match the current implementation.

**Example Error**:
```ruby
# Spec expects:
InvoiceSeriesService.all(company_id, token: token, filters: {})

# But actual method signature is:
InvoiceSeriesService.all(token: token, filters: {})
```

**Affected Tests**:
1. GET #index - renders index template
2. GET #index with filters
3. GET #index when API error occurs
4. GET #show - renders show template
5. GET #new - renders new template
6. GET #edit - renders edit template
7. POST #create - when successful
8. POST #create - when validation fails
9. POST #create - when API error occurs
10. PATCH #update - when successful
11. PATCH #update - when validation fails
12. DELETE #destroy - when successful
13. DELETE #destroy - when deletion fails
14. POST #activate
15. POST #deactivate
16. GET #statistics
17. GET #compliance
18. POST #rollover - when successful
19. POST #rollover - when rollover fails

### ⏸️ PENDING TESTS (13 tests)

All feature tests are intentionally skipped with message:
"Feature tests require browser environment - run manually in development"

#### Authentication Flow (6 pending)
- User successfully logs in and accesses dashboard
- User fails to log in with invalid credentials
- User logs out successfully
- Unauthenticated user is redirected to login
- User can access dashboard after successful login
- Session expires and user needs to re-authenticate

#### Invoice Form Interactions (7 pending)
- User creates a new invoice with single line item
- User adds multiple line items dynamically
- User removes line items dynamically
- User applies discount to line item
- User submits form with minimal data
- User edits existing invoice with form pre-populated
- Form accepts negative prices and creates invoice

## Chromium/Browser Test Investigation

### Environment Status
✅ **Chromium installed**: Version 140.0.7339.127
✅ **ChromeDriver installed**: Version 140.0.7339.127
✅ **Headless mode works**: Successfully renders HTML
✅ **Selenium can connect**: Direct connection to ChromeDriver works

### Issues Identified

1. **Capybara Server Binding**: When JavaScript tests run, Capybara tries to start a test server but the process hangs
2. **WebMock Interference**: WebMock blocks Capybara's internal `__identify__` endpoint
3. **Zombie Processes**: Chrome processes become defunct during test runs
4. **Timeout Issues**: Tests hang indefinitely when trying to use Selenium driver through Capybara

### Configuration Present
- Proper Capybara configuration in `spec/support/capybara.rb`
- Chromium binary path correctly set to `/usr/bin/chromium`
- ChromeDriver path correctly set to `/usr/bin/chromedriver`
- Headless arguments properly configured
- Timeout settings added

### Root Cause Analysis
The feature tests fail to run because:
1. Capybara's test server cannot properly bind in the Docker environment
2. The interaction between WebMock, Capybara, and Selenium creates a deadlock
3. The test environment needs specific network configuration for inter-process communication

## Recommendations

### Immediate Fixes Needed

1. **Fix InvoiceSeriesController specs**:
   - Update all mock method signatures to match actual service implementations
   - Remove `company_id` as first parameter where not needed
   - Ensure `token:` is passed as keyword argument

2. **For Feature Tests**:
   - Keep them skipped in CI/Docker environment
   - Run manually in development with proper browser setup
   - Consider using a different approach like system tests with headless Chrome outside Docker

### Test Coverage
- Current line coverage varies: 0% to 44.3% depending on test suite
- Most critical business logic is tested through request specs
- Feature/integration tests would provide better coverage but require different environment setup

## Files to Fix

1. `/spec/controllers/invoice_series_controller_spec.rb` - Update all service mock signatures
2. Consider creating a separate test environment for browser tests outside Docker container

## Notes

- The application code is working correctly (as evidenced by passing request specs)
- The controller spec failures are test-only issues, not application bugs
- Feature tests require a more complex setup that may not be suitable for Docker environments