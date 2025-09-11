# FacturaCircular Cliente - Comprehensive Test Plan

## Overview

This test plan covers all implemented features across the 6 completed phases of the FacturaCircular Cliente application. Each test case includes prerequisites, steps, expected results, and validation criteria.

## Test Environment Setup

### Prerequisites
1. **API Server Running**
   ```bash
   cd /Users/ludo/code/albaranes
   docker-compose up
   # API available at http://localhost:3001/api/v1
   ```

2. **Client Application Running**
   ```bash
   cd /Users/ludo/code/facturaCircularCliente
   docker-compose up
   # Client available at http://localhost:3002
   ```

3. **Test User Credentials**
   - Email: `admin@example.com`
   - Password: `password123`

---

## Phase 1: Authentication & Authorization Tests

### TEST-AUTH-001: User Login
**Priority:** Critical  
**Type:** Functional

**Steps:**
1. Navigate to http://localhost:3002/login
2. Enter valid email and password
3. Check "Remember me" checkbox
4. Click "Sign in"

**Expected Results:**
- User is redirected to dashboard
- JWT token is stored in session
- User menu shows logged-in state
- Remember me persists session

**Validation:**
- [ ] Login form validates email format
- [ ] Password field is masked
- [ ] Error messages display for invalid credentials
- [ ] Session persists after browser refresh (if Remember Me checked)

### TEST-AUTH-002: User Logout
**Priority:** Critical  
**Type:** Functional

**Prerequisites:** User is logged in

**Steps:**
1. Click user dropdown in top navigation
2. Click "Sign out"

**Expected Results:**
- User is redirected to login page
- Session is cleared
- Protected pages redirect to login
- JWT tokens are invalidated

### TEST-AUTH-003: Token Refresh
**Priority:** High  
**Type:** Functional

**Prerequisites:** User is logged in

**Steps:**
1. Wait for access token to expire (or modify token expiry)
2. Perform any API action (e.g., navigate to companies)

**Expected Results:**
- Token is automatically refreshed
- User remains logged in
- API calls continue working
- No interruption in user experience

### TEST-AUTH-004: Protected Routes
**Priority:** High  
**Type:** Security

**Steps:**
1. Without logging in, try to access:
   - /dashboard
   - /companies
   - /invoices
   - /tax_rates

**Expected Results:**
- All routes redirect to login page
- After login, user is redirected to originally requested page
- No sensitive data is exposed

---

## Phase 2: Dashboard & Navigation Tests

### TEST-DASH-001: Dashboard Display
**Priority:** High  
**Type:** Functional

**Prerequisites:** User is logged in

**Steps:**
1. Navigate to dashboard
2. Verify all widgets load
3. Check responsive layout on mobile/tablet/desktop

**Expected Results:**
- Invoice statistics display correctly
- Recent invoices list shows latest 5 invoices
- Quick action buttons are functional
- Charts/graphs render properly

**Validation:**
- [ ] Total invoices count is accurate
- [ ] Revenue calculations are correct
- [ ] Status distribution pie chart matches data
- [ ] Recent activity timeline is chronological

### TEST-NAV-001: Navigation Menu
**Priority:** High  
**Type:** UI/UX

**Steps:**
1. Click through all navigation items:
   - Dashboard
   - Invoices
   - Companies
   - Tax Management
2. Test mobile hamburger menu
3. Test breadcrumb navigation

**Expected Results:**
- Active page is highlighted in sidebar
- Mobile menu toggles correctly
- Breadcrumbs show correct hierarchy
- All links navigate to correct pages

### TEST-NAV-002: User Dropdown Menu
**Priority:** Medium  
**Type:** UI/UX

**Steps:**
1. Click user avatar/name in top right
2. Verify dropdown appears
3. Test each menu item

**Expected Results:**
- Dropdown opens/closes on click
- Profile link works (if implemented)
- Settings link works (if implemented)
- Sign out logs user out

### TEST-COMPONENT-001: Flash Messages
**Priority:** Medium  
**Type:** UI/UX

**Steps:**
1. Trigger success action (create company)
2. Trigger error action (invalid form submission)
3. Trigger warning (validation warning)

**Expected Results:**
- Success messages appear in green
- Error messages appear in red
- Messages auto-dismiss after 5 seconds
- Manual dismiss button works

### TEST-COMPONENT-002: Loading States
**Priority:** Medium  
**Type:** UI/UX

**Steps:**
1. Navigate to page with data loading
2. Submit form that requires processing
3. Trigger long-running operation

**Expected Results:**
- Loading spinners appear during data fetch
- Buttons show loading state when clicked
- Page remains responsive during loading
- Loading states clear after operation completes

---

## Phase 3: Company Management Tests

### TEST-COMPANY-001: Company List
**Priority:** High  
**Type:** Functional

**Prerequisites:** User is logged in

**Steps:**
1. Navigate to Companies page
2. Verify company list loads
3. Test pagination (if > 10 companies)
4. Test search functionality
5. Test filtering options

**Expected Results:**
- Companies display in table format
- Pagination controls work correctly
- Search filters results in real-time
- Sort options work (name, date, etc.)

**Validation:**
- [ ] Company count matches total
- [ ] Search is case-insensitive
- [ ] Pagination shows 10 items per page
- [ ] Sort maintains filter state

### TEST-COMPANY-002: Create Company
**Priority:** Critical  
**Type:** Functional

**Steps:**
1. Click "New Company" button
2. Fill in required fields:
   - Name: "Test Company S.L."
   - Tax ID: "B12345678"
   - Email: "test@company.com"
   - Phone: "+34 900 123 456"
3. Add address:
   - Street: "Calle Mayor 1"
   - City: "Madrid"
   - Postal Code: "28001"
   - Country: "Spain"
4. Submit form

**Expected Results:**
- Company is created successfully
- Redirected to company detail page
- Success message displays
- Company appears in list

**Validation:**
- [ ] Tax ID validation works (Spanish CIF/NIF format)
- [ ] Email validation enforces format
- [ ] Required fields are enforced
- [ ] Postal code validates Spanish format

### TEST-COMPANY-003: Edit Company
**Priority:** High  
**Type:** Functional

**Prerequisites:** Company exists

**Steps:**
1. Navigate to company detail page
2. Click "Edit" button
3. Modify company details
4. Save changes

**Expected Results:**
- Form pre-populates with existing data
- Changes are saved successfully
- Audit trail shows modification
- Updated data displays immediately

### TEST-COMPANY-004: Delete Company
**Priority:** High  
**Type:** Functional

**Prerequisites:** Company exists without invoices

**Steps:**
1. Navigate to company detail page
2. Click "Delete" button
3. Confirm deletion in modal

**Expected Results:**
- Confirmation modal appears
- Company is deleted after confirmation
- Redirected to companies list
- Company no longer appears in list

**Validation:**
- [ ] Cannot delete company with associated invoices
- [ ] Soft delete maintains data integrity
- [ ] Deletion is logged in audit trail

### TEST-COMPANY-005: Address Management
**Priority:** Medium  
**Type:** Functional

**Prerequisites:** Company exists

**Steps:**
1. Navigate to company detail page
2. Add new address
3. Edit existing address
4. Set address as default
5. Delete address

**Expected Results:**
- Multiple addresses can be added
- Only one default address allowed
- Address changes save correctly
- Deleted addresses are removed

---

## Phase 4: Invoice Management Tests

### TEST-INVOICE-001: Invoice List
**Priority:** Critical  
**Type:** Functional

**Prerequisites:** User is logged in

**Steps:**
1. Navigate to Invoices page
2. Test filters:
   - Status (Draft, Sent, Paid, etc.)
   - Date range
   - Company
   - Amount range
3. Test search by invoice number
4. Test bulk selection

**Expected Results:**
- All invoices display correctly
- Filters work independently and combined
- Search returns accurate results
- Bulk actions menu appears when items selected

**Validation:**
- [ ] Status badges show correct colors
- [ ] Amount formatting is consistent (€1,234.56)
- [ ] Date format is consistent
- [ ] Pagination works with filters applied

### TEST-INVOICE-002: Create Invoice
**Priority:** Critical  
**Type:** Functional

**Steps:**
1. Click "New Invoice" button
2. Select invoice type (Standard/Simplified)
3. Select company from dropdown
4. Set invoice details:
   - Invoice date: Today
   - Due date: Today + 30 days
   - Payment terms: 30 days
   - Payment method: Bank Transfer
5. Add line items:
   - Description: "Professional Services"
   - Quantity: 10
   - Unit Price: 100
   - Tax Rate: 21%
   - Discount: 10%
6. Add second line item
7. Add notes
8. Save as draft

**Expected Results:**
- Company dropdown shows search functionality
- Line items calculate automatically
- Totals update in real-time
- Tax calculations are correct
- Invoice saves with "Draft" status

**Validation:**
- [ ] Subtotal = Σ(quantity × unit_price × (1 - discount%))
- [ ] Tax = subtotal × tax_rate
- [ ] Total = subtotal + tax
- [ ] Invoice number auto-generates
- [ ] All calculations match API response

### TEST-INVOICE-003: Dynamic Line Items
**Priority:** High  
**Type:** Functional

**Prerequisites:** Creating or editing invoice

**Steps:**
1. Add multiple line items
2. Test "Add Line" button
3. Test "Remove Line" button
4. Modify quantities and prices
5. Apply different tax rates
6. Apply line-level discounts

**Expected Results:**
- Line items add/remove dynamically
- Calculations update instantly
- Tab navigation works between fields
- Remove button disabled when only 1 line
- Total recalculates correctly

**Validation:**
- [ ] Each line calculates independently
- [ ] Running total is accurate
- [ ] Tax groups by rate in summary
- [ ] Discount applies before tax

### TEST-INVOICE-004: Invoice Actions
**Priority:** High  
**Type:** Functional

**Prerequisites:** Invoice exists

**Steps:**
1. Test "Freeze Invoice" action
2. Test "Send Email" action
3. Test "Download PDF"
4. Test "Download Facturae XML"
5. Test "Edit" (for draft invoices)

**Expected Results:**
- Frozen invoices cannot be edited
- Email modal shows recipient field
- PDF downloads with correct formatting
- XML follows Facturae 3.2.2 schema
- Edit only available for drafts

**Validation:**
- [ ] Frozen status persists
- [ ] Email sends to correct recipient
- [ ] PDF contains all invoice data
- [ ] XML validates against schema
- [ ] Actions respect invoice status

### TEST-INVOICE-005: Invoice Detail View
**Priority:** Medium  
**Type:** UI/UX

**Prerequisites:** Invoice exists

**Steps:**
1. Navigate to invoice detail
2. Verify all sections display:
   - Header with status
   - Invoice details
   - Customer information
   - Line items table
   - Totals breakdown
   - Notes section
   - Action buttons
   - Workflow history

**Expected Results:**
- All data displays correctly
- Layout is responsive
- Print view works
- Links to company work
- History shows chronologically

---

## Phase 5: Workflow Management Tests

### TEST-WORKFLOW-001: Status Transitions
**Priority:** High  
**Type:** Functional

**Prerequisites:** Invoice exists

**Steps:**
1. Navigate to invoice detail
2. Click "Manage Workflow"
3. View available transitions
4. Select transition (e.g., Draft → Sent)
5. Add optional comment
6. Submit transition

**Expected Results:**
- Only valid transitions show
- Comment field appears when required
- Status updates immediately
- History entry is created
- Invoice status badge updates

**Validation:**
- [ ] Invalid transitions are not available
- [ ] Required comments are enforced
- [ ] Transition rules are followed
- [ ] Audit trail is complete

### TEST-WORKFLOW-002: Workflow History
**Priority:** Medium  
**Type:** Functional

**Prerequisites:** Invoice with status changes

**Steps:**
1. Navigate to workflow page
2. Review history timeline
3. Verify each transition shows:
   - From/To status
   - User who made change
   - Timestamp
   - Comment (if any)

**Expected Results:**
- Timeline displays chronologically
- All transitions are recorded
- User attribution is correct
- Timestamps are accurate

### TEST-WORKFLOW-003: Bulk Status Update
**Priority:** Medium  
**Type:** Functional

**Prerequisites:** Multiple invoices exist

**Steps:**
1. Navigate to invoices list
2. Select multiple invoices
3. Choose "Bulk Status Update"
4. Select new status
5. Add comment
6. Confirm action

**Expected Results:**
- Only common transitions available
- All selected invoices update
- Success/failure count displays
- Failed items show reasons

**Validation:**
- [ ] Only compatible invoices update
- [ ] Frozen invoices are skipped
- [ ] Each invoice gets history entry
- [ ] Bulk operation is atomic

---

## Phase 6: Tax Management Tests

### TEST-TAX-001: Tax Rates Display
**Priority:** High  
**Type:** Functional

**Prerequisites:** User is logged in

**Steps:**
1. Navigate to Tax Management
2. Verify standard IVA rates display
3. Check regional rates section
4. Check IRPF rates section

**Expected Results:**
- Standard rates show: 21%, 10%, 4%, 0%
- Regional rates show IGIC and IPSI
- IRPF rates show professional retentions
- Active/Inactive status displays

**Validation:**
- [ ] Rates match Spanish tax law
- [ ] Regional variations are accurate
- [ ] IRPF rates are current
- [ ] Rate descriptions are clear

### TEST-TAX-002: Tax Calculator - Simple Mode
**Priority:** High  
**Type:** Functional

**Steps:**
1. Navigate to Tax Calculator
2. Enter base amount: 1000
3. Select tax rate: 21%
4. Enter discount: 10%
5. View results

**Expected Results:**
- Real-time calculation updates
- Discount applies to base
- Tax applies to discounted amount
- Total is accurate

**Validation:**
- [ ] Base: €1,000.00
- [ ] Discount: -€100.00
- [ ] Subtotal: €900.00
- [ ] Tax (21%): €189.00
- [ ] Total: €1,089.00

### TEST-TAX-003: Tax Calculator - Advanced Mode
**Priority:** Medium  
**Type:** Functional

**Steps:**
1. Switch to Advanced Calculator tab
2. Enter base amount: 1000
3. Select region: Canary Islands
4. Enter tax rate: 7% (IGIC)
5. Enter equivalence surcharge: 1.75%
6. Enter IRPF retention: 15%
7. Calculate

**Expected Results:**
- Regional tax applies correctly
- Surcharge adds to tax
- Retention subtracts from total
- Breakdown shows all components

**Validation:**
- [ ] IGIC calculates at 7%
- [ ] Surcharge applies correctly
- [ ] Retention reduces final amount
- [ ] Total accounts for all factors

### TEST-TAX-004: Tax ID Validation
**Priority:** Medium  
**Type:** Functional

**Steps:**
1. Switch to Tax ID Validation tab
2. Test valid CIF: B12345678
3. Test valid NIF: 12345678Z
4. Test invalid format: ABC123
5. Test invalid checksum: B12345679

**Expected Results:**
- Valid IDs show green success
- Invalid IDs show red error
- Format errors explain issue
- Checksum errors are detected

**Validation:**
- [ ] Spanish CIF validation works
- [ ] Spanish NIF validation works
- [ ] NIE validation works
- [ ] Error messages are helpful

### TEST-TAX-005: Tax Calculation Results
**Priority:** Low  
**Type:** UI/UX

**Steps:**
1. Perform any tax calculation
2. View results page
3. Check visual breakdown
4. Test print function

**Expected Results:**
- Progress bars show proportions
- Colors differentiate components
- Print layout is clean
- All values are formatted

**Validation:**
- [ ] Bar widths match percentages
- [ ] Colors are consistent
- [ ] Print removes navigation
- [ ] Currency formatting is uniform

---

## Integration Tests

### TEST-INT-001: Invoice with Tax Calculation
**Priority:** Critical  
**Type:** Integration

**Steps:**
1. Create new invoice
2. Add items with different tax rates
3. Apply invoice-level discount
4. Save and view invoice
5. Verify tax breakdown

**Expected Results:**
- Tax groups by rate
- Calculations match tax calculator
- PDF shows tax breakdown
- API calculations are consistent

### TEST-INT-002: Company to Invoice Flow
**Priority:** High  
**Type:** Integration

**Steps:**
1. Create new company
2. Create invoice for company
3. Verify company details populate
4. Check invoice appears in company view

**Expected Results:**
- Company selection pre-fills data
- Address populates correctly
- Tax ID transfers to invoice
- Bidirectional linking works

### TEST-INT-003: Workflow with Notifications
**Priority:** Medium  
**Type:** Integration

**Steps:**
1. Create invoice
2. Transition through workflow
3. Check notifications appear
4. Verify email notifications (if configured)

**Expected Results:**
- Each transition triggers notification
- Toast messages appear
- Email notifications send
- History is complete

---

## Performance Tests

### TEST-PERF-001: Page Load Times
**Priority:** Medium  
**Type:** Performance

**Steps:**
1. Measure load times for:
   - Dashboard
   - Companies list (100+ records)
   - Invoices list (500+ records)
   - Complex invoice form

**Expected Results:**
- Dashboard: < 2 seconds
- Lists: < 3 seconds with pagination
- Forms: < 1 second
- API responses: < 500ms

### TEST-PERF-002: Concurrent Users
**Priority:** Low  
**Type:** Performance

**Steps:**
1. Simulate 10 concurrent users
2. All perform different operations
3. Monitor response times
4. Check for race conditions

**Expected Results:**
- No significant degradation
- No data conflicts
- Sessions remain isolated
- API handles load

---

## Security Tests

### TEST-SEC-001: Authorization Checks
**Priority:** Critical  
**Type:** Security

**Steps:**
1. Try to access other user's data
2. Attempt API calls without token
3. Try expired token usage
4. Test CSRF protection

**Expected Results:**
- 403 Forbidden for unauthorized
- 401 for missing/expired tokens
- CSRF tokens required for mutations
- No data leakage

### TEST-SEC-002: Input Validation
**Priority:** High  
**Type:** Security

**Steps:**
1. Test XSS in text fields
2. Test SQL injection attempts
3. Test file upload restrictions
4. Test rate limiting

**Expected Results:**
- Input is sanitized
- Injections are blocked
- File types are restricted
- Rate limits enforced

---

## Accessibility Tests

### TEST-A11Y-001: Keyboard Navigation
**Priority:** Medium  
**Type:** Accessibility

**Steps:**
1. Navigate entire app using only keyboard
2. Test form completion with Tab
3. Test modal interactions
4. Test dropdown menus

**Expected Results:**
- All interactive elements reachable
- Tab order is logical
- Escape closes modals
- Enter submits forms

### TEST-A11Y-002: Screen Reader Support
**Priority:** Medium  
**Type:** Accessibility

**Steps:**
1. Test with screen reader
2. Verify form labels
3. Check ARIA attributes
4. Test error announcements

**Expected Results:**
- All content is readable
- Forms have proper labels
- ARIA roles are correct
- Errors are announced

---

## Browser Compatibility Tests

### TEST-BROWSER-001: Cross-Browser Testing
**Priority:** High  
**Type:** Compatibility

**Browsers to Test:**
- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

**Steps:**
1. Test all major features
2. Check responsive design
3. Verify JavaScript works
4. Test print functionality

**Expected Results:**
- Consistent appearance
- All features work
- No JavaScript errors
- Print layouts correct

---

## Mobile Responsiveness Tests

### TEST-MOBILE-001: Responsive Design
**Priority:** High  
**Type:** UI/UX

**Devices:**
- iPhone 12/13/14
- iPad Pro
- Android phones
- Android tablets

**Steps:**
1. Test navigation menu
2. Test forms on mobile
3. Test tables on small screens
4. Test touch interactions

**Expected Results:**
- Hamburger menu works
- Forms are usable
- Tables scroll horizontally
- Touch targets are adequate

---

## Regression Test Suite

### Critical Path Tests (Run before each release)
1. TEST-AUTH-001: User Login
2. TEST-COMPANY-002: Create Company
3. TEST-INVOICE-002: Create Invoice
4. TEST-INVOICE-004: Invoice Actions
5. TEST-WORKFLOW-001: Status Transitions
6. TEST-TAX-002: Tax Calculator
7. TEST-INT-001: Invoice with Tax Calculation

---

## Test Execution Tracking

### Test Environment
- **API Version:** _________________
- **Client Version:** _______________
- **Test Date:** ____________________
- **Tester:** _______________________

### Test Results Summary
| Phase | Total Tests | Passed | Failed | Blocked | Pass Rate |
|-------|------------|--------|--------|---------|-----------|
| Phase 1: Authentication | 4 | | | | |
| Phase 2: Dashboard | 5 | | | | |
| Phase 3: Companies | 5 | | | | |
| Phase 4: Invoices | 5 | | | | |
| Phase 5: Workflow | 3 | | | | |
| Phase 6: Tax | 5 | | | | |
| Integration | 3 | | | | |
| Performance | 2 | | | | |
| Security | 2 | | | | |
| Accessibility | 2 | | | | |
| **TOTAL** | **36** | | | | |

### Defects Found
| ID | Test Case | Severity | Description | Status |
|----|-----------|----------|-------------|--------|
| | | | | |

### Sign-off
- **QA Lead:** _______________________ Date: ___________
- **Development Lead:** _______________ Date: ___________
- **Product Owner:** _________________ Date: ___________

---

## Automated Test Implementation Guide

### Recommended Test Framework Setup
```ruby
# Gemfile additions for testing
group :test do
  gem 'rspec-rails'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'vcr'
  gem 'webmock'
end
```

### Example RSpec Test Structure
```ruby
# spec/features/authentication_spec.rb
require 'rails_helper'

RSpec.describe 'Authentication', type: :feature do
  describe 'User Login' do
    it 'allows valid user to login' do
      visit login_path
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'
      
      expect(page).to have_content('Dashboard')
      expect(page).to have_current_path(dashboard_path)
    end
  end
end
```

### API Mocking Strategy
```ruby
# spec/support/api_helpers.rb
def stub_api_authentication
  stub_request(:post, "#{API_BASE_URL}/auth/login")
    .to_return(
      status: 200,
      body: {
        access_token: 'test_token',
        refresh_token: 'refresh_token',
        user: { id: 1, email: 'test@example.com' }
      }.to_json
    )
end
```

---

*This test plan should be executed before each major release and updated as new features are added.*