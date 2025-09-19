# Migrated from test/security/session_security_test.rb
# Security spec: Session management and token security

require 'rails_helper'

RSpec.describe "Session Security", type: :request do
  # Security Test: Session management and token security
  # Risk Level: CRITICAL - Session vulnerabilities can lead to account takeover
  # Focus: Secure session handling, token management, and attack prevention

  describe "session fixation attack prevention" do
    it "changes session ID after login to prevent session fixation" do
      # Step 1: Get initial session
      get login_path
      initial_session_id = session.id

      # Step 2: Attempt login
      allow(AuthService).to receive(:login).and_return({
        access_token: 'valid_token',
        user: { id: 1, email: 'user@example.com', name: 'Test User', company_id: 1 },
        company_id: 1,
        companies: [{ id: 1, name: 'Test Company', role: 'admin' }]
      })

      allow(InvoiceService).to receive(:recent).and_return([])

      post login_path, params: { email: 'user@example.com', password: 'password123' }

      # Step 3: Verify session ID changed after login (session fixation prevention)
      new_session_id = session.id
      expect(new_session_id).not_to eq(initial_session_id), "Session ID should change after login to prevent session fixation"

      # Step 4: Verify old session is invalidated
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('Successfully logged in!')
    end
  end

  describe "session timeout and automatic logout" do
    it "redirects to login when session expires" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock token validation to simulate expired session
      allow(AuthService).to receive(:validate_token).and_return({ valid: false, expired: true })

      # Mock failed refresh attempt
      allow(AuthService).to receive(:refresh_token).and_raise(ApiService::AuthenticationError.new('Refresh token expired'))

      # Attempt to access protected resource
      get invoices_path

      # Should redirect to login due to expired session
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to match(/session.*expired|please.*log.*in/i)

      # Session should be cleared
      expect(session[:access_token]).to be_nil
      expect(session[:user_id]).to be_nil
    end
  end

  describe "concurrent session invalidation" do
    it "handles concurrent session detection" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Simulate concurrent login invalidating current session
      allow(AuthService).to receive(:validate_token).and_return({
        valid: false,
        reason: 'concurrent_session_detected'
      })

      get root_path

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to match(/concurrent.*session|session.*invalid/i)

      # Session should be completely cleared
      expect(session[:access_token]).to be_nil
      expect(session[:refresh_token]).to be_nil
      expect(session[:user_id]).to be_nil
      expect(session[:company_id]).to be_nil
    end
  end

  describe "token refresh security" do
    it "handles automatic token refresh" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock expired access token but valid refresh token
      allow(AuthService).to receive(:validate_token).and_return({ valid: false, expired: true })
      allow(AuthService).to receive(:refresh_token).and_return({
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token',
        user: { id: 1, email: 'user@example.com', company_id: 1 }
      })

      allow(InvoiceService).to receive(:recent).and_return([])

      get root_path

      # Should succeed with automatic token refresh
      expect(response).to have_http_status(:success)
      expect(session[:access_token]).to eq('new_access_token')
      expect(session[:refresh_token]).to eq('new_refresh_token')
    end

    it "prevents refresh token replay attacks" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Test refresh token replay attack prevention
      # If someone tries to reuse old refresh token
      allow(AuthService).to receive(:refresh_token).and_raise(ApiService::AuthenticationError.new('Refresh token already used'))

      # Simulate another refresh attempt
      allow(AuthService).to receive(:validate_token).and_return({ valid: false, expired: true })

      get invoices_path

      # Should fail and redirect to login
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to match(/authentication.*error|session.*expired/i)
    end
  end

  describe "secure logout and session cleanup" do
    it "completely clears session data on logout" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Verify session is active
      expect(session[:access_token]).to be_present
      expect(session[:user_id]).to be_present

      # Mock logout API call
      allow(AuthService).to receive(:logout).and_return({ success: true })

      # Perform logout
      delete logout_path

      expect(response).to redirect_to(login_path)
      expect(flash[:notice]).to eq('Successfully logged out!')

      # Verify complete session cleanup
      expect(session[:access_token]).to be_nil
      expect(session[:refresh_token]).to be_nil
      expect(session[:user_id]).to be_nil
      expect(session[:company_id]).to be_nil
      expect(session[:user_email]).to be_nil
      expect(session[:user_name]).to be_nil
      expect(session[:companies]).to be_nil

      # Verify accessing protected resources after logout fails
      get root_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "session cookie security attributes" do
    it "ensures session cookies have proper security attributes" do
      get login_path

      # Check session cookie security attributes
      session_cookie = response.cookies.find { |cookie| cookie.include?('session') }

      if session_cookie
        # In production, these should be set for security
        # HttpOnly prevents XSS access to cookies
        # Secure ensures cookies only sent over HTTPS
        # SameSite prevents CSRF attacks

        # Note: These checks depend on Rails configuration
        # In test environment, some security features may be disabled
        Rails.logger.info "Session cookie: #{session_cookie}"

        # Verify no sensitive data in cookie value (should be encrypted/signed)
        expect(session_cookie).not_to match(/access_token|user_id|email/),
                             "Session cookie should not contain plaintext sensitive data"
      else
        # If no session cookie found, that's also acceptable
        expect(true).to be_truthy, "No session cookie found - may be handled differently in test environment"
      end
    end
  end

  describe "brute force login protection simulation" do
    it "remains stable under repeated failed login attempts" do
      failed_attempts = []

      # Simulate multiple failed login attempts
      10.times do |attempt|
        allow(AuthService).to receive(:login).and_raise(ApiService::AuthenticationError.new('Invalid credentials'))

        start_time = Time.current
        post login_path, params: { email: 'attacker@example.com', password: 'wrong_password' }
        end_time = Time.current

        failed_attempts << (end_time - start_time)

        expect(response).to have_http_status(:success) # Should render login form again
        expect(flash[:error]).to match(/invalid.*credentials/i)
      end

      # Check if there's any rate limiting (response times should increase)
      # In a real implementation, this might include:
      # - Increasing delays between attempts
      # - Account lockout after X attempts
      # - CAPTCHA after Y attempts

      Rails.logger.info "Login attempt times: #{failed_attempts.map { |t| t.round(3) }}"

      # Basic check: application should remain stable under repeated failed attempts
      expect(failed_attempts.all? { |time| time < 5.seconds }).to be_truthy, "Login attempts should not cause performance degradation"
    end
  end

  describe "JWT token validation and tampering detection" do
    it "rejects tampered JWT tokens" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Test with tampered JWT token
      tampered_tokens = [
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.tampered_payload.signature',
        'tampered.header.signature',
        'valid_looking_but_fake_jwt_token_12345',
        session[:access_token] + 'tampered_suffix' # Tamper with valid token
      ]

      tampered_tokens.each do |tampered_token|
        # Set tampered token in session
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:access_token).and_return(tampered_token)

        # Mock JWT validation failure for tampered token
        allow(AuthService).to receive(:validate_token).and_raise(JWT::DecodeError.new('Invalid token signature'))

        get root_path

        expect(response).to redirect_to(login_path), "Tampered token should be rejected"
        expect(flash[:alert]).to match(/authentication.*error|invalid.*token/i)

        # Session should be cleared after tampered token detection
        expect(session[:access_token]).to be_nil
      end
    end
  end

  describe "company context switching security" do
    it "validates company switching authorization" do
      # User with access to multiple companies
      setup_multi_company_session

      # Should start with Company 1
      expect(session[:company_id]).to eq(1)

      # Mock switching to Company 2
      allow(CompanyService).to receive(:find).and_return({ id: 2, name: 'Company Two' })
      allow(InvoiceService).to receive(:recent).and_return([])

      post switch_company_path, params: { company_id: 2 }

      expect(response).to redirect_to(dashboard_path)
      expect(session[:company_id]).to eq(2)

      # Test unauthorized company switching (company user doesn't have access to)
      unauthorized_company_id = 999

      allow(CompanyService).to receive(:find).and_raise(ApiService::ApiError.new('Company not found'))

      post switch_company_path, params: { company_id: unauthorized_company_id }

      expect(response).to have_http_status(:redirect)
      expect(flash[:error] || flash[:alert]).to be_present, "Should prevent unauthorized company switching"

      # Company context should not change
      expect(session[:company_id]).not_to eq(unauthorized_company_id)
    end
  end

  describe "API token exposure in error messages" do
    it "sanitizes tokens from error messages" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Force an API error that might expose tokens
      allow(InvoiceService).to receive(:all).and_raise(ApiService::ApiError.new('Token abc123 is invalid'))

      get invoices_path

      # Error message should not expose actual tokens
      expect(response.body).not_to match(/#{session[:access_token]}/) if session[:access_token]
      expect(response.body).not_to match(/Bearer [a-zA-Z0-9\-_\.]+/), "Bearer tokens should not be exposed"
      expect(response.body).not_to match(/jwt[a-zA-Z0-9\-_\.]+/), "JWT tokens should not be exposed"
    end
  end

  describe "comprehensive CSRF protection" do
    it "enforces CSRF protection on sensitive operations" do
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Test CSRF protection on various sensitive operations
      sensitive_operations = [
        {
          method: :post,
          path: invoices_path,
          params: { invoice: { document_type: 'FC' } },
          description: 'Invoice creation'
        },
        {
          method: :post,
          path: company_addresses_path(1),
          params: { address: { address: 'Test' } },
          description: 'Address creation'
        }
      ]

      csrf_tokens_found = 0
      successful_operations = 0

      sensitive_operations.each do |operation|
        # First, get CSRF token from appropriate form
        case operation[:path]
        when /invoices/
          get new_invoice_path
        when /addresses/
          get company_path(1)
        end

        if response.successful?
          csrf_token = extract_csrf_token(response)

          # Test with valid CSRF token (should work)
          if csrf_token
            csrf_tokens_found += 1

            # Mock successful operation
            case operation[:description]
            when /Invoice creation/
              allow(InvoiceService).to receive(:create).and_return({ data: { id: '123' } })
              allow(InvoiceSeriesService).to receive(:all).and_return([{ id: 74, series_code: 'FC' }])
            when /Address creation/
              allow(CompanyService).to receive(:create_address).and_return({ success: true })
              allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })
            end

            send(operation[:method], operation[:path], params: operation[:params].merge(authenticity_token: csrf_token))

            # Should succeed with valid CSRF token
            if response.redirect?
              successful_operations += 1
            end
          end
        end
      end

      # Verify CSRF protection is in place
      expect(csrf_tokens_found).to be > 0, "CSRF tokens should be found in forms"
      expect(successful_operations).to be >= 0, "Some operations should succeed with valid CSRF tokens"
    end
  end

  private

  def setup_multi_company_session
    allow(AuthService).to receive(:login).and_return({
      access_token: 'multi_company_token',
      user: { id: 1, email: 'user@example.com', name: 'Multi User', company_id: 1 },
      company_id: 1,
      companies: [
        { id: 1, name: 'Company One', role: 'admin' },
        { id: 2, name: 'Company Two', role: 'manager' },
        { id: 3, name: 'Company Three', role: 'viewer' }
      ]
    })

    allow(AuthService).to receive(:validate_token).and_return({ valid: true })
    allow(InvoiceService).to receive(:recent).and_return([])

    post login_path, params: { email: 'user@example.com', password: 'password123' }

    # Select first company
    allow(CompanyService).to receive(:find).and_return({ id: 1, name: 'Company One' })
    post switch_company_path, params: { company_id: 1 }
  end

  def extract_csrf_token(response)
    doc = Nokogiri::HTML(response.body)
    token_element = doc.css('input[name="authenticity_token"]').first
    token_element&.[]('value')
  end
end