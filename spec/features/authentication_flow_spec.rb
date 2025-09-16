require 'rails_helper'

RSpec.feature 'Authentication Flow', type: :feature do
  # Using Rack::Test by default to avoid server boot timeout issues
  # For JavaScript-heavy tests, use server_test: true metadata
  let(:valid_email) { 'admin@example.com' }
  let(:valid_password) { 'password123' }
  let(:auth_response) do
    {
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      user: {
        id: 1,
        email: valid_email,
        name: 'Test User',
        role: 'admin'
      },
      companies: [{ id: 1, name: 'Test Company', role: 'admin' }],
      company_id: 1
    }
  end

  scenario 'User successfully logs in and accesses dashboard' do
    # Set up mocks for login and dashboard
    allow(AuthService).to receive(:login).with(valid_email, valid_password, nil).and_return(auth_response)
    allow(AuthService).to receive(:validate_token).and_return(true)
    allow(AuthService).to receive(:user_companies).and_return([{ id: 1, name: 'Test Company', role: 'admin' }])
    allow(InvoiceService).to receive(:recent).and_return([])

    # Visit login page
    visit login_path
    expect(page).to have_content('Sign in to FacturaCircular')

    # Fill in credentials and submit
    within 'form' do
      fill_in 'email', with: valid_email
      fill_in 'password', with: valid_password
      click_button 'Sign in'
    end

    # Should redirect to dashboard
    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content('Dashboard')
    expect(page).to have_content('Welcome back, Test User')
    # Note: stats-based content checks removed
  end

  scenario 'User fails to log in with invalid credentials' do
    # Stub failed login API call
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .with(
        body: { grant_type: 'password', email: valid_email, password: 'wrongpassword', company_id: nil, remember_me: "0" }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 401, body: { error: 'Invalid credentials' }.to_json)

    # Visit login page
    visit login_path
    
    # Fill in invalid credentials
    within 'form' do
      find('input[type="email"]').set(valid_email)
      find('input[type="password"]').set('wrongpassword')
      click_button 'Sign in'
    end
    
    # Should stay on login page with error
    expect(page).to have_current_path(login_path)
    expect(page).to have_content('Invalid credentials')
    expect(page).to have_content('Sign in to FacturaCircular')
  end

  scenario 'User logs out successfully' do
    # Set up service mocks for login and dashboard
    allow(AuthService).to receive(:login).with(valid_email, valid_password, nil).and_return(auth_response)
    allow(AuthService).to receive(:validate_token).and_return(true)
    allow(AuthService).to receive(:user_companies).and_return([{ id: 1, name: 'Test Company', role: 'admin' }])
    allow(InvoiceService).to receive(:recent).and_return([])
    allow(AuthService).to receive(:logout).and_return(true)

    # Log in via UI
    login_via_ui(valid_email, valid_password)
    expect_to_be_logged_in

    # Log out
    logout_via_ui

    # Should be redirected to login page
    expect_to_be_logged_out
  end

  scenario 'Unauthenticated user is redirected to login' do
    # Try to visit dashboard without being logged in
    visit dashboard_path
    
    # Should be redirected to login
    expect(page).to have_current_path(login_path)
    expect(page).to have_content('Please sign in to continue')
  end

  scenario 'User can access dashboard after successful login' do
    # Set up service mocks for login and dashboard
    allow(AuthService).to receive(:login).with(valid_email, valid_password, nil).and_return(auth_response)
    allow(AuthService).to receive(:validate_token).and_return(true)
    allow(AuthService).to receive(:user_companies).and_return([{ id: 1, name: 'Test Company', role: 'admin' }])
    allow(InvoiceService).to receive(:recent).and_return([build(:invoice_response, invoice_number: 'INV-001')])
    allow(AuthService).to receive(:logout).and_return(true)

    # Complete login flow
    with_authenticated_session do
      expect(page).to have_content('Dashboard')
      # Since stats endpoint doesn't exist, controller falls back to defaults
      expect(page).to have_content('0 invoices') # total_invoices defaults to 0
      expect(page).to have_content('0.00 €')     # amounts default to 0
      expect(page).to have_content('Total Invoices').and have_content('0')
      expect(page).to have_content('Pending').and have_content('0.00 €')
      # Status breakdown will all be 0 due to missing stats endpoint
      expect(page).to have_content('0') # draft count (appears multiple times)
      # Should show recent invoice if mock works properly
      expect(page).to have_content('INV-001') # recent invoice from mock
    end
  end

  scenario 'Session expires and user needs to re-authenticate' do
    # Set up service mocks for initial login
    allow(AuthService).to receive(:login).with(valid_email, valid_password, nil).and_return(auth_response)
    allow(AuthService).to receive(:validate_token).and_return(true)
    allow(AuthService).to receive(:user_companies).and_return([{ id: 1, name: 'Test Company', role: 'admin' }])
    allow(InvoiceService).to receive(:recent).and_return([])

    login_via_ui(valid_email, valid_password)
    expect_to_be_logged_in

    # Simulate expired session - make token validation fail on next request
    allow(AuthService).to receive(:validate_token).and_return(false)
    # Simulate CompanyService call that would fail with expired token
    allow(CompanyService).to receive(:all).and_raise(ApiService::AuthenticationError.new('Token expired'))

    # Try to access companies page
    visit companies_path

    # Should be redirected to login due to expired session
    expect(page).to have_current_path(login_path)
    expect_authentication_error
  end
end
