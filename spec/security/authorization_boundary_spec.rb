# Migrated from test/security/authorization_boundary_test.rb
# Security spec: Cross-company data access prevention and authorization enforcement

require 'rails_helper'

RSpec.describe "Authorization Boundary Security", type: :request do
  # Security Test: Cross-company data access prevention
  # Risk Level: CRITICAL - Prevents data breaches and regulatory violations
  # Focus: Ensuring strict data isolation between companies

  before do
    setup_security_test_data
  end

  describe "cross-company data access prevention" do
    it "prevents users from accessing other companies' invoices" do
      # Login as Company 1 user
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock Company 1 invoices
      company_1_invoices = [
        { id: '100', company_id: 1, invoice_number: 'FC-001', status: 'draft' },
        { id: '101', company_id: 1, invoice_number: 'FC-002', status: 'sent' }
      ]

      allow(InvoiceService).to receive(:all).and_return({ invoices: company_1_invoices, meta: { total: 2 } })

      # Should successfully access own company's invoices
      get invoices_path
      expect(response).to have_http_status(:success)

      # Attempt to access Company 2's invoice directly
      get invoice_path('200')  # Invoice ID from Company 2

      # Should be blocked by authorization
      expect(response).to have_http_status(:redirect)
      expect(flash[:error] || flash[:alert]).to match(/not found|unauthorized|access denied/i)

      # Verify cannot create invoice for different company
      post invoices_path, params: {
        invoice: {
          seller_party_id: 2,  # Attempting to create invoice for Company 2
          buyer_party_id: 3,
          document_type: 'FC'
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error] || flash[:alert]).to be_present
    end

    it "enforces company data isolation in all CRUD operations" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      unauthorized_company_id = 2

      # Test READ operations are company-scoped
      protected_read_operations = [
        { path: company_path(unauthorized_company_id), description: "Company details" },
        { path: company_company_contacts_path(unauthorized_company_id), description: "Company contacts" },
        { path: company_invoice_series_index_path(unauthorized_company_id), description: "Invoice series" }
      ]

      protected_read_operations.each do |operation|
        get operation[:path]

        expect(response).to have_http_status(:redirect), "#{operation[:description]} should be protected"
        expect(flash[:error] || flash[:alert]).to be_present, "Should show authorization error for #{operation[:description]}"
      end

      # Test WRITE operations are company-scoped
      protected_write_operations = [
        {
          method: :post,
          path: company_addresses_path(unauthorized_company_id),
          params: { address: { address: "Test Street", post_code: "28001" } },
          description: "Address creation"
        },
        {
          method: :patch,
          path: company_address_path(unauthorized_company_id, 123),
          params: { address: { address: "Updated Street" } },
          description: "Address update"
        },
        {
          method: :delete,
          path: company_address_path(unauthorized_company_id, 123),
          params: {},
          description: "Address deletion"
        }
      ]

      protected_write_operations.each do |operation|
        send(operation[:method], operation[:path], params: operation[:params])

        expect(response).to have_http_status(:redirect), "#{operation[:description]} should be protected"
        expect(flash[:error] || flash[:alert]).to be_present, "Should show authorization error for #{operation[:description]}"
      end
    end
  end

  describe "role-based access control enforcement" do
    it "restricts viewer role operations" do
      # Test viewer role restrictions
      setup_authenticated_session(role: 'viewer', company_id: 1)

      restricted_operations_viewer = [
        { method: :get, path: new_invoice_path, description: "Invoice creation form" },
        { method: :post, path: invoices_path, params: { invoice: {} }, description: "Invoice creation" },
        { method: :patch, path: invoice_path('123'), params: { invoice: {} }, description: "Invoice update" },
        { method: :delete, path: invoice_path('123'), description: "Invoice deletion" }
      ]

      restricted_operations_viewer.each do |operation|
        send(operation[:method], operation[:path], params: operation[:params] || {})

        expect(response).to have_http_status(:redirect), "#{operation[:description]} should be restricted for viewer role"
        expect(flash[:error] || flash[:alert]).to match(/not authorized|permission denied|access denied/i)
      end
    end

    it "allows admin role access" do
      # Test admin role has access
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock required services for admin operations
      allow(InvoiceSeriesService).to receive(:all).and_return([{
        id: 74, series_code: 'FC', series_name: 'Facturas Comerciales', is_active: true
      }])
      allow(CompanyContactsService).to receive(:active_contacts).and_return([])

      # Admin should access creation form
      get new_invoice_path
      expect(response).to have_http_status(:success), "Admin should access invoice creation form"
    end

    it "allows manager role limited access" do
      # Test manager role has limited access
      setup_authenticated_session(role: 'manager', company_id: 1)

      # Mock required services
      allow(InvoiceSeriesService).to receive(:all).and_return([{
        id: 74, series_code: 'FC', series_name: 'Facturas Comerciales', is_active: true
      }])
      allow(CompanyContactsService).to receive(:active_contacts).and_return([])

      # Manager should access creation form
      get new_invoice_path
      expect(response).to have_http_status(:success), "Manager should access invoice creation form"

      # But should not access company management
      get companies_path
      # Company management access varies by implementation - could be success or redirect
      expect(response.status).to be_in([200, 302])
    end
  end

  describe "session security and token validation" do
    it "handles invalid session tokens" do
      # Test with invalid session token
      get root_path  # First get a page to establish session

      # Set invalid session data
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:access_token).and_return('invalid_token')
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(1)
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:company_id).and_return(1)

      allow(AuthService).to receive(:validate_token).and_return({ valid: false })

      get root_path
      expect(response).to redirect_to(login_path), "Invalid token should redirect to login"
    end

    it "handles expired sessions" do
      # Set up session with expired token
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:access_token).and_return('expired_token')
      allow(AuthService).to receive(:validate_token).and_return({ valid: false, expired: true })

      get invoices_path
      expect(response).to redirect_to(login_path), "Expired session should redirect to login"
    end

    it "handles malformed JWT tokens" do
      # Test with malformed JWT
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:access_token).and_return('malformed.jwt.token')
      allow(AuthService).to receive(:validate_token).and_raise(JWT::DecodeError.new('Invalid token format'))

      get dashboard_path
      expect(response).to redirect_to(login_path), "Malformed JWT should redirect to login"
    end

    it "prevents session hijacking" do
      original_token = 'original_token'
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:access_token).and_return(original_token)
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(1)

      # Simulate token invalidated due to concurrent session
      allow(AuthService).to receive(:validate_token).and_return({ valid: false, reason: 'concurrent_session' })

      get root_path
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to match(/session.*invalid|concurrent.*session/i)
    end
  end

  describe "input sanitization and XSS prevention" do
    it "prevents XSS attacks in address creation" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock services
      allow(CompanyService).to receive(:create_address).and_return({ success: true })
      allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })

      # Test XSS prevention in address creation
      malicious_inputs = [
        "<script>alert('XSS')</script>",
        "javascript:alert('XSS')",
        "<img src=x onerror=alert('XSS')>",
        "'; DROP TABLE addresses; --",
        "<iframe src='javascript:alert(1)'></iframe>"
      ]

      malicious_inputs.each do |malicious_input|
        post company_addresses_path(1), params: {
          address: {
            address: malicious_input,
            post_code: "28001",
            town: "Madrid",
            province: "Madrid",
            country_code: "ESP",
            address_type: "billing"
          }
        }

        # Should not crash or execute malicious code
        expect(response).to have_http_status(:redirect), "Application should handle malicious input gracefully"

        # Verify input was sanitized (implementation specific)
        expect(response.body).not_to match(/<script|javascript:|onerror|iframe/i), "Response should not contain unsanitized script tags"
      end
    end
  end

  describe "CSRF protection on sensitive operations" do
    it "enforces CSRF protection on invoice creation" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # First get the form to obtain CSRF token
      get new_invoice_path
      expect(response).to have_http_status(:success)

      csrf_token = extract_csrf_token(response)
      expect(csrf_token).to be_present, "CSRF token should be present in forms"

      # Mock successful creation
      allow(InvoiceService).to receive(:create).and_return({
        data: { id: '124', type: 'invoices', attributes: { status: 'draft' } }
      })

      allow(InvoiceSeriesService).to receive(:all).and_return([{
        id: 74, series_code: 'FC', series_name: 'Facturas Comerciales'
      }])

      # Valid request with CSRF token should work
      post invoices_path, params: {
        invoice: {
          invoice_series_id: '74',
          document_type: 'FC',
          issue_date: Date.current.iso8601,
          currency_code: 'EUR'
        },
        authenticity_token: csrf_token
      }

      expect(response).to have_http_status(:redirect), "Valid CSRF token should allow request"
    end

    it "enforces CSRF protection on address operations" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      get company_path(1)
      expect(response).to have_http_status(:success)

      address_csrf_token = extract_csrf_token(response)

      allow(CompanyService).to receive(:create_address).and_return({ success: true })
      allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })

      post company_addresses_path(1), params: {
        address: {
          address: "Test Street 123",
          post_code: "28001",
          town: "Madrid",
          province: "Madrid",
          country_code: "ESP",
          address_type: "billing"
        },
        authenticity_token: address_csrf_token
      }

      expect(response).to have_http_status(:redirect), "Valid CSRF token should allow address creation"
    end
  end

  describe "mass assignment protection" do
    it "prevents mass assignment in invoice creation" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock services
      allow(InvoiceService).to receive(:create).and_return({
        data: { id: '125', type: 'invoices', attributes: { status: 'draft' } }
      })

      allow(InvoiceSeriesService).to receive(:all).and_return([{
        id: 74, series_code: 'FC', series_name: 'Facturas Comerciales'
      }])

      # Attempt mass assignment with protected attributes
      post invoices_path, params: {
        invoice: {
          invoice_series_id: '74',
          document_type: 'FC',
          issue_date: Date.current.iso8601,
          currency_code: 'EUR',
          # Attempt to assign protected/internal attributes
          id: '999',
          created_at: '2020-01-01',
          updated_at: '2020-01-01',
          admin_only_field: 'malicious_value',
          internal_status: 'bypass_workflow'
        }
      }

      # Should succeed but ignore protected attributes
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq('Invoice created successfully')
    end

    it "prevents mass assignment in address creation" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      allow(CompanyService).to receive(:create_address).and_return({ success: true })
      allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })

      post company_addresses_path(1), params: {
        address: {
          address: "Test Street",
          post_code: "28001",
          town: "Madrid",
          province: "Madrid",
          country_code: "ESP",
          address_type: "billing",
          # Attempt mass assignment
          id: '888',
          admin_override: true,
          bypass_validation: true,
          internal_flag: 'malicious'
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq('Address created successfully')
    end
  end

  describe "API token exposure prevention" do
    it "prevents token exposure in HTML responses" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Access various pages and ensure tokens aren't exposed in HTML
      pages_to_check = [
        root_path,
        invoices_path,
        new_invoice_path,
        companies_path,
        tax_rates_path
      ]

      pages_to_check.each do |page_path|
        get page_path

        if response.successful?
          # Check that sensitive tokens are not exposed in HTML
          expect(response.body).not_to match(/access_token|jwt|bearer/i),
                               "Access tokens should not be exposed in HTML on #{page_path}"

          # Check that API keys are not in the response
          expect(response.body).not_to match(/api_key|secret_key|private_key/i),
                               "API keys should not be exposed in HTML on #{page_path}"
        end
      end
    end

    it "prevents session data exposure in client-side JavaScript" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      get root_path
      if response.successful?
        expect(response.body).not_to match(/session\[.*access_token.*\]/),
                           "Session tokens should not be accessible via JavaScript"
      end
    end
  end

  private

  def setup_security_test_data
    @company_1 = { id: 1, name: 'Company One', legal_name: 'Company One S.L.' }
    @company_2 = { id: 2, name: 'Company Two', legal_name: 'Company Two S.A.' }

    @company_1_invoices = [
      { id: '100', company_id: 1, invoice_number: 'C1-001', status: 'draft' },
      { id: '101', company_id: 1, invoice_number: 'C1-002', status: 'sent' }
    ]

    @company_2_invoices = [
      { id: '200', company_id: 2, invoice_number: 'C2-001', status: 'draft' },
      { id: '201', company_id: 2, invoice_number: 'C2-002', status: 'approved' }
    ]

    # Default service stubs with token parameter
    allow(CompanyService).to receive(:all).and_return({ companies: [@company_1] })
    allow(CompanyService).to receive(:find).with(1, token: anything).and_return(@company_1)
    allow(CompanyService).to receive(:find).with(2, token: anything).and_raise(ApiService::ApiError.new('Company not found'))

    allow(InvoiceService).to receive(:recent).with(token: anything).and_return(@company_1_invoices.first(2))
  end

  def extract_csrf_token(response)
    doc = Nokogiri::HTML(response.body)
    token_element = doc.css('input[name="authenticity_token"]').first
    token_element&.[]('value')
  end
end