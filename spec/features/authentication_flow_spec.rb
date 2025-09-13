require 'rails_helper'

RSpec.feature 'Authentication Flow', type: :feature, js: true do
  # Selenium Grid is now configured and working - tests enabled
  let(:valid_email) { 'admin@example.com' }
  let(:valid_password) { 'password123' }
  let(:auth_response) { build(:auth_response) }

  scenario 'User successfully logs in and accesses dashboard' do
    # Stub the login API call
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .with(
        body: { grant_type: 'password', email: valid_email, password: valid_password, remember_me: false }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 200, body: auth_response.to_json)

    # Note: stats endpoint removed from API
    
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
      .with(query: { limit: '5', status: 'recent' })
      .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)

    # Visit login page
    visit login_path
    expect(page).to have_content('Sign in to FacturaCircular')
    
    # Fill in credentials and submit
    within 'form' do
      find('input[type="email"]').set(valid_email)
      find('input[type="password"]').set(valid_password)
      click_button 'Sign in'
    end
    
    # Should redirect to dashboard
    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content('Dashboard')
    # Note: stats-based content checks removed
  end

  scenario 'User fails to log in with invalid credentials' do
    # Stub failed login API call
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .with(
        body: { grant_type: 'password', email: valid_email, password: 'wrongpassword', remember_me: false }.to_json,
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
    # First log in
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    # Stub dashboard data
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices/stats')
      .to_return(status: 200, body: { total_invoices: 0, total_amount: 0 }.to_json)
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
      .with(query: { limit: '5', status: 'recent' })
      .to_return(status: 200, body: { invoices: [] }.to_json)
    
    # Stub logout API call
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/logout')
      .to_return(status: 200, body: { message: 'Logged out successfully' }.to_json)

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
    # Mock successful authentication
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    # Note: dashboard stats data and endpoint removed from API
    
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
      .with(query: { limit: '5', status: 'recent' })
      .to_return(status: 200, body: { 
        invoices: [build(:invoice_response, invoice_number: 'INV-001')], 
        total: 1 
      }.to_json)

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
    # Initial successful login
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices/stats')
      .to_return(status: 200, body: { total_invoices: 0 }.to_json)
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
      .with(query: { limit: '5', status: 'recent' })
      .to_return(status: 200, body: { invoices: [] }.to_json)

    login_via_ui(valid_email, valid_password)
    expect_to_be_logged_in

    # Simulate expired session on next request
    stub_request(:get, 'http://albaranes-api:3000/api/v1/companies')
      .with(query: { page: '1', per_page: '25' })
      .to_return(status: 401, body: { error: 'Token expired' }.to_json)

    # Try to access companies page
    visit companies_path
    
    # Should be redirected to login due to expired session
    expect(page).to have_current_path(login_path)
    expect_authentication_error
  end
end
