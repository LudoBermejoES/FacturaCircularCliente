# FacturaCircular Cliente - Automated Test Implementation Plan

## Overview

This document provides a comprehensive plan for implementing automated tests using RSpec, covering unit tests, integration tests, functional tests, and end-to-end tests for the FacturaCircular Cliente application.

## TO UNDERSTAND HOW TO TEST

Read HOW_TO_TEST.md

## Test Environment Setup

### 1. Add Testing Dependencies

```ruby
# Gemfile
group :development, :test do
  # Debugging
  gem 'pry-rails'
  gem 'pry-byebug'
  
  # Testing framework
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails'
  gem 'faker'
  
  # Code quality
  gem 'rubocop-rspec'
end

group :test do
  # Test coverage
  gem 'simplecov', require: false
  gem 'simplecov-lcov', require: false
  
  # API mocking
  gem 'webmock'
  gem 'vcr'
  
  # Browser testing
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'cuprite' # Headless Chrome driver
  
  # Cleaning database
  gem 'database_cleaner-active_record'
  
  # Time helpers
  gem 'timecop'
  
  # Matchers
  gem 'shoulda-matchers'
  gem 'rspec-json_expectations'
  
  # Performance testing
  gem 'rspec-benchmark'
  
  # Request specs
  gem 'rack-test'
  
  # JavaScript testing
  gem 'rspec-rails-examples'
end
```

### 2. RSpec Configuration

```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Rails is running in production!") if Rails.env.production?
require 'rspec/rails'
require 'webmock/rspec'
require 'vcr'
require 'capybara/rspec'
require 'capybara/cuprite'

# Configure Capybara
Capybara.javascript_driver = :cuprite
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, {
    window_size: [1920, 1080],
    browser_options: { 'no-sandbox': nil },
    inspector: ENV['INSPECTOR'] == 'true',
    headless: ENV['HEADLESS'] != 'false'
  })
end

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<JWT_TOKEN>') { |interaction|
    interaction.request.headers['Authorization']&.first
  }
end

# Configure DatabaseCleaner
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

# Include helpers
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = Rails.root.join('spec/fixtures')
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include custom helpers
  config.include AuthenticationHelper, type: :request
  config.include ApiHelper
  config.include SessionHelper, type: :feature
end
```

### 3. Test Helpers

```ruby
# spec/support/authentication_helper.rb
module AuthenticationHelper
  def login_as(user = nil)
    user ||= create(:user)
    token = generate_jwt_token(user)
    session[:access_token] = token[:access_token]
    session[:refresh_token] = token[:refresh_token]
    session[:user_id] = user.id
    user
  end
  
  def generate_jwt_token(user)
    {
      access_token: JWT.encode(
        { user_id: user.id, exp: 1.hour.from_now.to_i },
        Rails.application.secret_key_base
      ),
      refresh_token: JWT.encode(
        { user_id: user.id, exp: 7.days.from_now.to_i },
        Rails.application.secret_key_base
      )
    }
  end
end

# spec/support/api_helper.rb
module ApiHelper
  def stub_api_request(method, endpoint, response_body, status = 200)
    stub_request(method, "#{ENV['API_BASE_URL']}#{endpoint}")
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_successful_login
    stub_api_request(:post, '/auth/login', {
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      user: { id: 1, email: 'test@example.com', name: 'Test User' }
    })
  end
end
```

---

## Unit Tests

### 1. Service Objects Tests

```ruby
# spec/services/api_service_spec.rb
require 'rails_helper'

RSpec.describe ApiService do
  describe '.get' do
    let(:token) { 'test_token' }
    let(:endpoint) { '/test' }
    
    context 'when request is successful' do
      before do
        stub_request(:get, "#{ApiService::BASE_URL}#{endpoint}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: { data: 'test' }.to_json)
      end
      
      it 'returns parsed JSON response' do
        result = described_class.get(endpoint, token: token)
        expect(result).to eq({ 'data' => 'test' })
      end
    end
    
    context 'when request returns 401' do
      before do
        stub_request(:get, "#{ApiService::BASE_URL}#{endpoint}")
          .to_return(status: 401)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
    
    context 'when request returns 422' do
      before do
        stub_request(:get, "#{ApiService::BASE_URL}#{endpoint}")
          .to_return(
            status: 422,
            body: { errors: ['Invalid data'] }.to_json
          )
      end
      
      it 'raises ValidationError with errors' do
        expect {
          described_class.get(endpoint, token: token)
        }.to raise_error(ApiService::ValidationError) do |error|
          expect(error.errors).to eq(['Invalid data'])
        end
      end
    end
  end
  
  describe '.post' do
    let(:token) { 'test_token' }
    let(:endpoint) { '/test' }
    let(:body) { { name: 'Test' } }
    
    it 'sends POST request with body' do
      stub = stub_request(:post, "#{ApiService::BASE_URL}#{endpoint}")
        .with(
          body: body.to_json,
          headers: {
            'Authorization' => "Bearer #{token}",
            'Content-Type' => 'application/json'
          }
        )
        .to_return(status: 201, body: { id: 1 }.to_json)
      
      described_class.post(endpoint, body: body, token: token)
      expect(stub).to have_been_requested
    end
  end
end

# spec/services/auth_service_spec.rb
require 'rails_helper'

RSpec.describe AuthService do
  describe '.login' do
    let(:email) { 'test@example.com' }
    let(:password) { 'password123' }
    
    context 'with valid credentials' do
      before do
        stub_api_request(:post, '/auth/login', {
          access_token: 'access_token_123',
          refresh_token: 'refresh_token_456',
          user: { id: 1, email: email }
        })
      end
      
      it 'returns tokens and user data' do
        result = described_class.login(email, password)
        
        expect(result[:access_token]).to eq('access_token_123')
        expect(result[:refresh_token]).to eq('refresh_token_456')
        expect(result[:user][:email]).to eq(email)
      end
    end
    
    context 'with invalid credentials' do
      before do
        stub_api_request(:post, '/auth/login', 
          { error: 'Invalid credentials' }, 401)
      end
      
      it 'raises AuthenticationError' do
        expect {
          described_class.login(email, password)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
  end
  
  describe '.refresh_token' do
    let(:refresh_token) { 'refresh_token_456' }
    
    before do
      stub_api_request(:post, '/auth/refresh', {
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token'
      })
    end
    
    it 'returns new tokens' do
      result = described_class.refresh_token(refresh_token)
      
      expect(result[:access_token]).to eq('new_access_token')
      expect(result[:refresh_token]).to eq('new_refresh_token')
    end
  end
end

# spec/services/invoice_service_spec.rb
require 'rails_helper'

RSpec.describe InvoiceService do
  let(:token) { 'test_token' }
  
  describe '.all' do
    context 'with filters' do
      let(:filters) { { status: 'draft', company_id: 1 } }
      
      before do
        stub_request(:get, "#{ApiService::BASE_URL}/invoices")
          .with(
            query: filters,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(
            status: 200,
            body: {
              invoices: [{ id: 1, status: 'draft' }],
              total: 1,
              page: 1
            }.to_json
          )
      end
      
      it 'passes filters as query parameters' do
        result = described_class.all(filters: filters, token: token)
        expect(result[:invoices]).to have(1).item
        expect(result[:total]).to eq(1)
      end
    end
  end
  
  describe '.create' do
    let(:invoice_params) do
      {
        company_id: 1,
        invoice_type: 'standard',
        invoice_lines: [
          { description: 'Service', quantity: 1, unit_price: 100, tax_rate: 21 }
        ]
      }
    end
    
    before do
      stub_api_request(:post, '/invoices', {
        id: 1,
        invoice_number: 'INV-001',
        status: 'draft',
        total: 121.00
      })
    end
    
    it 'creates invoice with line items' do
      result = described_class.create(invoice_params, token: token)
      
      expect(result[:id]).to eq(1)
      expect(result[:invoice_number]).to eq('INV-001')
      expect(result[:total]).to eq(121.00)
    end
  end
  
  describe '.freeze' do
    let(:invoice_id) { 1 }
    
    before do
      stub_api_request(:post, "/invoices/#{invoice_id}/freeze", {
        id: invoice_id,
        is_frozen: true,
        frozen_at: Time.current
      })
    end
    
    it 'freezes the invoice' do
      result = described_class.freeze(invoice_id, token: token)
      
      expect(result[:is_frozen]).to be true
      expect(result[:frozen_at]).to be_present
    end
  end
end
```

### 2. Helper Tests

```ruby
# spec/helpers/application_helper_spec.rb
require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#format_currency' do
    it 'formats amount with currency symbol' do
      expect(helper.format_currency(1234.56)).to eq('1,234.56 €')
    end
    
    it 'handles nil values' do
      expect(helper.format_currency(nil)).to eq('-')
    end
    
    it 'accepts custom currency' do
      expect(helper.format_currency(100, '$')).to eq('100.00 $')
    end
  end
  
  describe '#format_percentage' do
    it 'formats percentage with symbol' do
      expect(helper.format_percentage(21.5)).to eq('21.50%')
    end
    
    it 'handles nil values' do
      expect(helper.format_percentage(nil)).to eq('-')
    end
  end
  
  describe '#status_badge_class' do
    it 'returns correct classes for draft status' do
      expect(helper.status_badge_class('draft'))
        .to include('bg-gray-100', 'text-gray-800')
    end
    
    it 'returns correct classes for paid status' do
      expect(helper.status_badge_class('paid'))
        .to include('bg-green-100', 'text-green-800')
    end
    
    it 'handles unknown status' do
      expect(helper.status_badge_class('unknown'))
        .to include('bg-gray-100', 'text-gray-800')
    end
  end
end
```

---

## Controller Tests

### 1. Request Specs (Functional Tests)

```ruby
# spec/requests/sessions_spec.rb
require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  describe 'GET /login' do
    it 'renders login form' do
      get login_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sign in to your account')
    end
    
    context 'when already logged in' do
      before { login_as }
      
      it 'redirects to dashboard' do
        get login_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
  
  describe 'POST /login' do
    let(:login_params) do
      { email: 'test@example.com', password: 'password123' }
    end
    
    context 'with valid credentials' do
      before { stub_successful_login }
      
      it 'logs user in and redirects to dashboard' do
        post login_path, params: login_params
        
        expect(session[:access_token]).to be_present
        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(response.body).to include('Dashboard')
      end
      
      it 'sets remember me cookie when checked' do
        post login_path, params: login_params.merge(remember_me: '1')
        
        expect(cookies[:remember_token]).to be_present
      end
    end
    
    context 'with invalid credentials' do
      before do
        stub_api_request(:post, '/auth/login', 
          { error: 'Invalid credentials' }, 401)
      end
      
      it 'renders login form with error' do
        post login_path, params: login_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email or password')
        expect(session[:access_token]).to be_nil
      end
    end
  end
  
  describe 'DELETE /logout' do
    before { login_as }
    
    it 'logs user out and clears session' do
      delete logout_path
      
      expect(session[:access_token]).to be_nil
      expect(session[:refresh_token]).to be_nil
      expect(response).to redirect_to(login_path)
    end
  end
end

# spec/requests/companies_spec.rb
require 'rails_helper'

RSpec.describe 'Companies', type: :request do
  before { login_as }
  let(:token) { session[:access_token] }
  
  describe 'GET /companies' do
    before do
      stub_api_request(:get, '/companies', {
        companies: [
          { id: 1, name: 'Company A', tax_id: 'A12345678' },
          { id: 2, name: 'Company B', tax_id: 'B87654321' }
        ],
        total: 2,
        page: 1
      })
    end
    
    it 'displays list of companies' do
      get companies_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Company A', 'Company B')
      expect(response.body).to include('A12345678', 'B87654321')
    end
    
    context 'with search params' do
      it 'filters companies' do
        stub_request(:get, "#{ApiService::BASE_URL}/companies")
          .with(query: { search: 'test' })
          .to_return(
            status: 200,
            body: { companies: [], total: 0 }.to_json
          )
        
        get companies_path, params: { search: 'test' }
        expect(response).to have_http_status(:ok)
      end
    end
  end
  
  describe 'GET /companies/new' do
    it 'renders new company form' do
      get new_company_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Company')
      expect(response.body).to include('name="company[name]"')
    end
  end
  
  describe 'POST /companies' do
    let(:company_params) do
      {
        company: {
          name: 'Test Company',
          tax_id: 'B12345678',
          email: 'test@company.com',
          phone: '+34 900 123 456'
        }
      }
    end
    
    context 'with valid params' do
      before do
        stub_api_request(:post, '/companies', {
          id: 1,
          name: 'Test Company',
          tax_id: 'B12345678'
        }, 201)
      end
      
      it 'creates company and redirects' do
        post companies_path, params: company_params
        
        expect(response).to redirect_to(company_path(1))
        expect(flash[:notice]).to eq('Company was successfully created.')
      end
    end
    
    context 'with invalid params' do
      before do
        stub_api_request(:post, '/companies',
          { errors: ['Tax ID is invalid'] }, 422)
      end
      
      it 'renders form with errors' do
        post companies_path, params: company_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Tax ID is invalid')
      end
    end
  end
end

# spec/requests/invoices_spec.rb
require 'rails_helper'

RSpec.describe 'Invoices', type: :request do
  before { login_as }
  
  describe 'GET /invoices' do
    before do
      stub_api_request(:get, '/invoices', {
        invoices: [
          {
            id: 1,
            invoice_number: 'INV-001',
            status: 'draft',
            total: 121.00,
            company: { name: 'Test Co' }
          }
        ],
        statistics: {
          total_count: 1,
          total_amount: 121.00,
          status_counts: { draft: 1 }
        }
      })
    end
    
    it 'displays invoices with statistics' do
      get invoices_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('INV-001')
      expect(response.body).to include('€121.00')
      expect(response.body).to include('Test Co')
    end
  end
  
  describe 'POST /invoices' do
    let(:invoice_params) do
      {
        invoice: {
          company_id: 1,
          invoice_type: 'standard',
          date: Date.current,
          due_date: 30.days.from_now,
          invoice_lines_attributes: {
            '0' => {
              description: 'Service',
              quantity: 10,
              unit_price: 100,
              tax_rate: 21,
              discount_percentage: 0
            }
          }
        }
      }
    end
    
    before do
      stub_api_request(:post, '/invoices', {
        id: 1,
        invoice_number: 'INV-001',
        status: 'draft',
        total: 1210.00
      }, 201)
    end
    
    it 'creates invoice with line items' do
      post invoices_path, params: invoice_params
      
      expect(response).to redirect_to(invoice_path(1))
      expect(flash[:notice]).to include('successfully created')
    end
  end
end
```

### 2. Controller Concerns Tests

```ruby
# spec/controllers/concerns/authentication_concern_spec.rb
require 'rails_helper'

RSpec.describe 'AuthenticationConcern', type: :controller do
  controller(ApplicationController) do
    def index
      render plain: 'OK'
    end
  end
  
  describe '#authenticate_user!' do
    context 'without session' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(login_path)
      end
    end
    
    context 'with valid session' do
      before do
        session[:access_token] = 'valid_token'
        session[:user_id] = 1
      end
      
      it 'allows access' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
    
    context 'with expired token' do
      before do
        session[:access_token] = 'expired_token'
        session[:refresh_token] = 'refresh_token'
        
        # Stub refresh endpoint
        stub_api_request(:post, '/auth/refresh', {
          access_token: 'new_token',
          refresh_token: 'new_refresh'
        })
      end
      
      it 'refreshes token automatically' do
        get :index
        expect(session[:access_token]).to eq('new_token')
      end
    end
  end
end
```

---

## Integration Tests

### 1. Feature Specs (E2E Tests)

```ruby
# spec/features/authentication_flow_spec.rb
require 'rails_helper'

RSpec.describe 'Authentication Flow', type: :feature, js: true do
  describe 'User login journey' do
    before { stub_successful_login }
    
    scenario 'User logs in successfully' do
      visit root_path
      expect(page).to have_current_path(login_path)
      
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Password', with: 'password123'
      check 'Remember me'
      
      click_button 'Sign in'
      
      expect(page).to have_current_path(dashboard_path)
      expect(page).to have_content('Dashboard')
      expect(page).to have_content('test@example.com')
      
      # Check user menu
      find('[data-dropdown-target="button"]').click
      expect(page).to have_link('Sign out')
    end
    
    scenario 'User logs out' do
      login_via_ui
      
      find('[data-dropdown-target="button"]').click
      click_link 'Sign out'
      
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('Sign in to your account')
    end
  end
  
  describe 'Protected routes' do
    scenario 'Redirects to login when not authenticated' do
      visit dashboard_path
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('Please sign in to continue')
    end
  end
end

# spec/features/invoice_management_spec.rb
require 'rails_helper'

RSpec.describe 'Invoice Management', type: :feature, js: true do
  before do
    login_via_ui
    stub_companies_list
    stub_invoice_creation
  end
  
  scenario 'Creating an invoice with multiple line items' do
    visit new_invoice_path
    
    # Select company
    select 'Test Company', from: 'Company'
    
    # Fill invoice details
    fill_in 'Invoice date', with: Date.current
    fill_in 'Due date', with: 30.days.from_now
    select '30 days', from: 'Payment terms'
    
    # Add first line item
    within '[data-invoice-form-target="lineItems"] .line-item:first-child' do
      fill_in 'Description', with: 'Professional Services'
      fill_in 'Quantity', with: '10'
      fill_in 'Unit price', with: '100'
      select '21%', from: 'Tax rate'
      fill_in 'Discount', with: '10'
    end
    
    # Add second line item
    click_button 'Add Line Item'
    
    within '[data-invoice-form-target="lineItems"] .line-item:last-child' do
      fill_in 'Description', with: 'Additional Services'
      fill_in 'Quantity', with: '5'
      fill_in 'Unit price', with: '50'
      select '10%', from: 'Tax rate'
    end
    
    # Verify calculations
    expect(page).to have_content('Subtotal: €1,150.00')
    expect(page).to have_content('Tax: €214.00')
    expect(page).to have_content('Total: €1,364.00')
    
    # Save invoice
    click_button 'Save as Draft'
    
    expect(page).to have_content('Invoice was successfully created')
    expect(page).to have_content('INV-001')
    expect(page).to have_content('Draft')
  end
  
  scenario 'Managing invoice workflow' do
    stub_invoice_details
    stub_workflow_transitions
    
    visit invoice_path(1)
    
    click_link 'Manage Workflow'
    
    expect(page).to have_content('Available Transitions')
    expect(page).to have_button('Transition to Sent')
    
    fill_in 'comment', with: 'Sending to customer'
    click_button 'Transition to Sent'
    
    expect(page).to have_content('Status successfully updated')
    expect(page).to have_content('Sent')
  end
end

# spec/features/tax_calculator_spec.rb
require 'rails_helper'

RSpec.describe 'Tax Calculator', type: :feature, js: true do
  before { login_via_ui }
  
  scenario 'Calculating tax with discount' do
    visit new_tax_calculation_path
    
    # Simple calculator tab should be active by default
    expect(page).to have_css('#simple-calculator:not(.hidden)')
    
    fill_in 'Base Amount', with: '1000'
    select '21% - Standard IVA', from: 'Tax Rate'
    fill_in 'Discount', with: '10'
    
    # Real-time calculation
    expect(page).to have_content('Base Amount: €1,000.00')
    expect(page).to have_content('Discount: -€100.00')
    expect(page).to have_content('Subtotal: €900.00')
    expect(page).to have_content('Tax (21%): €189.00')
    expect(page).to have_content('Total: €1,089.00')
    
    click_button 'Calculate'
    
    expect(page).to have_content('Tax Calculation Results')
  end
  
  scenario 'Validating Spanish tax ID' do
    visit new_tax_calculation_path
    
    click_button 'Tax ID Validation'
    
    expect(page).to have_css('#tax-validation:not(.hidden)')
    
    fill_in 'Tax ID', with: 'B12345678'
    select 'Spain', from: 'Country'
    
    stub_api_request(:post, '/tax_validations/tax_id', {
      valid: true,
      details: {
        company_name: 'Test Company S.L.',
        tax_type: 'CIF',
        region: 'Madrid'
      }
    })
    
    click_button 'Validate Tax ID'
    
    within '#validation_result' do
      expect(page).to have_content('Valid Tax ID')
      expect(page).to have_content('Company: Test Company S.L.')
      expect(page).to have_content('Type: CIF')
    end
  end
end
```

### 2. System Tests

```ruby
# spec/system/complete_invoice_workflow_spec.rb
require 'rails_helper'

RSpec.describe 'Complete Invoice Workflow', type: :system do
  before do
    driven_by(:cuprite)
    stub_all_api_endpoints
  end
  
  it 'completes full invoice lifecycle' do
    # Login
    visit root_path
    fill_in 'Email', with: 'admin@example.com'
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # Create company
    visit new_company_path
    fill_in 'Name', with: 'ACME Corp'
    fill_in 'Tax ID', with: 'B12345678'
    fill_in 'Email', with: 'billing@acme.com'
    within '.address-fields' do
      fill_in 'Street', with: 'Main St 123'
      fill_in 'City', with: 'Madrid'
      fill_in 'Postal Code', with: '28001'
    end
    click_button 'Create Company'
    
    expect(page).to have_content('Company was successfully created')
    
    # Create invoice for company
    visit new_invoice_path
    select 'ACME Corp', from: 'Company'
    
    within '.line-items' do
      fill_in 'Description', with: 'Consulting Services'
      fill_in 'Quantity', with: '40'
      fill_in 'Unit price', with: '75'
      select '21%', from: 'Tax rate'
    end
    
    click_button 'Save as Draft'
    
    invoice_number = find('.invoice-number').text
    
    # Manage workflow
    click_link 'Manage Workflow'
    click_button 'Transition to Sent'
    
    # Send email
    click_button 'Send Email'
    fill_in 'Recipient Email', with: 'billing@acme.com'
    click_button 'Send'
    
    expect(page).to have_content('Email sent successfully')
    
    # Download PDF
    click_link 'Download PDF'
    expect(page.response_headers['Content-Type']).to include('application/pdf')
    
    # Freeze invoice
    accept_confirm do
      click_button 'Freeze Invoice'
    end
    
    expect(page).to have_content('Invoice frozen successfully')
    expect(page).not_to have_link('Edit')
  end
end
```

---

## JavaScript Tests

### 1. Stimulus Controller Tests

```ruby
# spec/javascript/controllers/invoice_form_controller_spec.js
import { Application } from "@hotwired/stimulus"
import InvoiceFormController from "controllers/invoice_form_controller"

describe("InvoiceFormController", () => {
  let application
  
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="invoice-form">
        <div data-invoice-form-target="lineItems">
          <div class="line-item">
            <input data-invoice-form-target="quantity" value="10">
            <input data-invoice-form-target="unitPrice" value="100">
            <input data-invoice-form-target="taxRate" value="21">
            <input data-invoice-form-target="discount" value="0">
          </div>
        </div>
        <span data-invoice-form-target="subtotal"></span>
        <span data-invoice-form-target="totalTax"></span>
        <span data-invoice-form-target="total"></span>
        <button data-action="invoice-form#addLine">Add Line</button>
      </div>
    `
    
    application = Application.start()
    application.register("invoice-form", InvoiceFormController)
  })
  
  it("calculates totals correctly", () => {
    const controller = application.controllers[0]
    controller.calculate()
    
    expect(controller.subtotalTarget.textContent).toBe("€1,000.00")
    expect(controller.totalTaxTarget.textContent).toBe("€210.00")
    expect(controller.totalTarget.textContent).toBe("€1,210.00")
  })
  
  it("adds new line item", () => {
    const button = document.querySelector('[data-action="invoice-form#addLine"]')
    button.click()
    
    const lineItems = document.querySelectorAll('.line-item')
    expect(lineItems.length).toBe(2)
  })
  
  it("removes line item", () => {
    // Add second line first
    const addButton = document.querySelector('[data-action="invoice-form#addLine"]')
    addButton.click()
    
    const removeButton = document.querySelector('[data-action="invoice-form#removeLine"]')
    removeButton.click()
    
    const lineItems = document.querySelectorAll('.line-item')
    expect(lineItems.length).toBe(1)
  })
})
```

---

## Performance Tests

```ruby
# spec/performance/api_response_spec.rb
require 'rails_helper'
require 'rspec-benchmark'

RSpec.describe 'API Performance', type: :request do
  include RSpec::Benchmark::Matchers
  
  before { login_as }
  
  describe 'Invoice listing performance' do
    before do
      stub_api_request(:get, '/invoices', {
        invoices: Array.new(100) { |i| { id: i, invoice_number: "INV-#{i}" } },
        total: 100
      })
    end
    
    it 'responds within acceptable time' do
      expect {
        get invoices_path
      }.to perform_under(300).ms
    end
    
    it 'handles concurrent requests' do
      expect {
        threads = 10.times.map do
          Thread.new { get invoices_path }
        end
        threads.each(&:join)
      }.to perform_under(1).sec
    end
  end
end
```

---

## Test Data Management

### 1. Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    
    trait :admin do
      role { 'admin' }
    end
  end
end

# spec/factories/api_responses.rb
FactoryBot.define do
  factory :company_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    name { Faker::Company.name }
    tax_id { "B#{Faker::Number.number(digits: 8)}" }
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    
    initialize_with { attributes }
  end
  
  factory :invoice_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    invoice_number { "INV-#{Faker::Number.number(digits: 4)}" }
    status { %w[draft sent paid].sample }
    total { Faker::Commerce.price(range: 100..10000) }
    company { association :company_response }
    
    initialize_with { attributes }
  end
end
```

### 2. Shared Examples

```ruby
# spec/support/shared_examples/authenticated_request.rb
RSpec.shared_examples 'authenticated request' do
  context 'without authentication' do
    before { session.clear }
    
    it 'redirects to login' do
      subject
      expect(response).to redirect_to(login_path)
    end
  end
  
  context 'with expired token' do
    before do
      session[:access_token] = 'expired_token'
      stub_api_request(:get, endpoint, { error: 'Token expired' }, 401)
    end
    
    it 'attempts token refresh' do
      expect(AuthService).to receive(:refresh_token)
      subject
    end
  end
end

# Usage in specs:
RSpec.describe 'Companies', type: :request do
  describe 'GET /companies' do
    subject { get companies_path }
    let(:endpoint) { '/companies' }
    
    it_behaves_like 'authenticated request'
  end
end
```

---

## Test Coverage Configuration

```ruby
# spec/spec_helper.rb
require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
])

SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  add_group 'Services', 'app/services'
  add_group 'Controllers', 'app/controllers'
  add_group 'Helpers', 'app/helpers'
  add_group 'JavaScript', 'app/javascript'
  
  minimum_coverage 90
  minimum_coverage_by_file 80
end
```

---

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.5
          bundler-cache: true
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 20
          cache: 'npm'
      
      - name: Install dependencies
        run: |
          bundle install
          npm install
      
      - name: Setup database
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost/test
        run: |
          bundle exec rails db:create
          bundle exec rails db:schema:load
      
      - name: Run tests
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost/test
          API_BASE_URL: http://localhost:3001/api/v1
        run: |
          bundle exec rspec --format documentation
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
```

---

## Test Execution Commands

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/invoice_service_spec.rb

# Run specific test
bundle exec rspec spec/services/invoice_service_spec.rb:15

# Run with specific tag
bundle exec rspec --tag focus

# Run only unit tests
bundle exec rspec spec/services spec/helpers

# Run only integration tests
bundle exec rspec spec/requests

# Run only feature tests
bundle exec rspec spec/features

# Run with coverage
COVERAGE=true bundle exec rspec

# Run in parallel (requires parallel_tests gem)
bundle exec parallel_rspec spec/

# Run with documentation format
bundle exec rspec --format documentation

# Run and fail fast
bundle exec rspec --fail-fast

# Run with seed for reproducibility
bundle exec rspec --seed 12345
```

---

## Test Metrics Goals

### Coverage Targets
- **Overall Coverage**: ≥ 90%
- **Service Objects**: ≥ 95%
- **Controllers**: ≥ 90%
- **Helpers**: ≥ 85%
- **JavaScript**: ≥ 80%

### Performance Targets
- **Unit Tests**: < 0.1s per test
- **Integration Tests**: < 0.5s per test
- **Feature Tests**: < 2s per test
- **Total Suite Runtime**: < 5 minutes

### Quality Metrics
- **Test/Code Ratio**: ≥ 1.5:1
- **Mutation Coverage**: ≥ 80%
- **Flaky Tests**: < 1%
- **Test Maintenance**: < 10% of development time

---

*This automated test plan provides comprehensive coverage across all test levels, from unit to E2E, ensuring robust validation of the FacturaCircular Cliente application.*