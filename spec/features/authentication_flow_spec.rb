require 'rails_helper'

RSpec.feature 'Authentication Flow', type: :feature do
  let(:valid_email) { 'admin@example.com' }
  let(:valid_password) { 'password123' }
  let(:auth_response) { build(:auth_response) }

  scenario 'User successfully logs in and accesses dashboard' do
    # Stub the login API call
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .with(
        body: { email: valid_email, password: valid_password, remember_me: false }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 200, body: auth_response.to_json)

    # Stub dashboard data calls
    stub_request(:get, 'http://localhost:3001/api/v1/invoices/stats')
      .to_return(status: 200, body: {
        total_invoices: 25,
        total_amount: 50000.00,
        pending_amount: 15000.00
      }.to_json)
    
    stub_request(:get, 'http://localhost:3001/api/v1/invoices')
      .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)

    # Visit login page
    visit login_path
    expect(page).to have_content('Sign in to FacturaCircular')
    
    # Fill in credentials and submit
    fill_in 'Email address', with: valid_email
    fill_in 'Password', with: valid_password
    click_button 'Sign in'
    
    # Should redirect to dashboard
    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content('Dashboard')
    expect(page).to have_content('25')
    expect(page).to have_content('50,000.00')
  end

  scenario 'User fails to log in with invalid credentials' do
    # Stub failed login API call
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .with(
        body: { email: valid_email, password: 'wrongpassword', remember_me: false }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 401, body: { error: 'Invalid credentials' }.to_json)

    # Visit login page
    visit login_path
    
    # Fill in invalid credentials
    fill_in 'Email address', with: valid_email
    fill_in 'Password', with: 'wrongpassword'
    click_button 'Sign in'
    
    # Should stay on login page with error
    expect(page).to have_current_path(login_path)
    expect(page).to have_content('Invalid credentials')
    expect(page).to have_content('Sign in to FacturaCircular')
  end

  scenario 'User logs out successfully' do
    # First log in
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    # Stub dashboard data
    stub_request(:get, 'http://localhost:3001/api/v1/invoices/stats')
      .to_return(status: 200, body: { total_invoices: 0, total_amount: 0 }.to_json)
    stub_request(:get, 'http://localhost:3001/api/v1/invoices')
      .to_return(status: 200, body: { invoices: [] }.to_json)
    
    # Stub logout API call
    stub_request(:post, 'http://localhost:3001/api/v1/auth/logout')
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
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    # Mock dashboard data
    invoice_stats = {
      total_invoices: 15,
      draft_count: 5,
      sent_count: 7,
      paid_count: 3,
      total_amount: 25000.50,
      pending_amount: 12000.25
    }
    
    stub_request(:get, 'http://localhost:3001/api/v1/invoices/stats')
      .to_return(status: 200, body: invoice_stats.to_json)
    
    stub_request(:get, 'http://localhost:3001/api/v1/invoices')
      .to_return(status: 200, body: { 
        invoices: [build(:invoice_response, invoice_number: 'INV-001')], 
        total: 1 
      }.to_json)

    # Complete login flow
    with_authenticated_session do
      expect(page).to have_content('Dashboard')
      expect(page).to have_content('15 invoices')
      expect(page).to have_content('25,000.50')
      expect(page).to have_content('12,000.25')
      expect(page).to have_content('5') # draft count
      expect(page).to have_content('7') # sent count  
      expect(page).to have_content('3') # paid count
      expect(page).to have_content('INV-001') # recent invoice
    end
  end

  scenario 'Session expires and user needs to re-authenticate' do
    # Initial successful login
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    stub_request(:get, 'http://localhost:3001/api/v1/invoices/stats')
      .to_return(status: 200, body: { total_invoices: 0 }.to_json)
    stub_request(:get, 'http://localhost:3001/api/v1/invoices')
      .to_return(status: 200, body: { invoices: [] }.to_json)

    login_via_ui(valid_email, valid_password)
    expect_to_be_logged_in

    # Simulate expired session on next request
    stub_request(:get, 'http://localhost:3001/api/v1/companies')
      .to_return(status: 401, body: { error: 'Token expired' }.to_json)

    # Try to access companies page
    visit companies_path
    
    # Should be redirected to login due to expired session
    expect(page).to have_current_path(login_path)
    expect_authentication_error
  end
end