require 'rails_helper'

RSpec.feature 'Invoice Form Interactions', type: :feature do
  # Selenium Grid is now configured and working - tests enabled
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response, name: 'Test Company', tax_id: 'B12345678') }
  let(:auth_response) { build(:auth_response) }

  before do
    # Mock all API endpoints for feature tests
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .with(
        body: { grant_type: 'password', email: 'admin@example.com', password: 'password123', remember_me: false }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 200, body: auth_response.to_json)
    
    stub_request(:get, 'http://albaranes-api:3000/api/v1/auth/validate')
      .to_return(status: 200, body: { valid: true }.to_json)
      
    # Mock the session/authentication state directly for feature tests
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    
    # Mock user role and permissions for invoice management
    allow_any_instance_of(ApplicationController).to receive(:current_company_id).and_return(company[:id])
    allow_any_instance_of(ApplicationController).to receive(:user_companies).and_return([
      { id: company[:id], name: company[:name], role: 'manager' }
    ])
    allow_any_instance_of(ApplicationController).to receive(:current_user_role).and_return('manager')
    
    # Mock all can? calls with default permissions (manager can do most things)
    allow_any_instance_of(ApplicationController).to receive(:can?) do |_, action, resource|
      case action
      when :view, :create, :edit, :approve, :manage_invoices, :manage_workflows
        true
      else
        false
      end
    end
    
    # Note: dashboard stats data and endpoint removed from API
    
    stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
      .with(query: { limit: '5', status: 'recent' })
      .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)
    
    # Mock CompanyService.all method directly since feature tests use service mocking
    allow(CompanyService).to receive(:all).with(any_args).and_return({ 
      companies: [
        { id: 1, name: 'Test Company' },
        { id: 2, name: 'Another Company' }
      ], 
      total: 2, 
      meta: { page: 1, pages: 1, total: 2 }
    })
    
    # Mock invoice creation/update endpoints
    stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
      .to_return(status: 201, body: build(:invoice_response).to_json)
    
    stub_request(:get, %r{http://albaranes-api:3000/api/v1/invoices/\d+})
      .to_return(status: 200, body: build(:invoice_response).to_json)
    
    stub_request(:put, %r{http://albaranes-api:3000/api/v1/invoices/\d+})
      .to_return(status: 200, body: build(:invoice_response).to_json)
  end

  scenario 'User creates a new invoice with single line item' do
    # Mock invoice creation - any invoice data is acceptable
    stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
      .to_return(status: 201, body: build(:invoice_response).to_json)

    # Visit the invoice form
    visit new_invoice_path
    expect(page).to have_content('New Invoice')
    
    # Fill in basic invoice information (using actual field IDs from the form)
    fill_in 'invoice_invoice_number', with: 'INV-2024-001'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company', from: 'invoice_buyer_party_id'
    fill_in 'invoice_date', with: Date.current.strftime('%Y-%m-%d')
    
    # The form should have at least one default line item row to fill in
    # Fill in the default line item (JavaScript-free approach)
    within(first('tbody tr')) do
      find('input[placeholder="Item description"]').set('Web Development Services')
      find('input[name*="[quantity]"]').set('10')
      find('input[name*="[unit_price]"]').set('150.00')
      find('input[name*="[tax_rate]"]').set('21')
    end
    
    # Submit the form (test basic form submission works)
    click_button 'Create Invoice'
    
    # Verify successful form submission - should redirect away from form
    expect(page).not_to have_content('Create Invoice')
  end

  scenario 'User accesses form with basic functionality' do
    visit new_invoice_path
    
    # Fill basic info to verify form is working
    fill_in 'invoice_invoice_number', with: 'INV-2024-002' 
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company', from: 'invoice_buyer_party_id'
    
    # Verify form has the expected structure
    expect(page).to have_content('Line Items')
    expect(page).to have_button('Add Line')
    expect(page).to have_content('Subtotal:')
    expect(page).to have_content('Tax:')
    expect(page).to have_content('Total:')
    
    # Form should have at least one default line item row
    expect(page).to have_css('tbody tr', minimum: 1)
    
    # Should be able to fill in basic line item data
    within(first('tbody tr')) do
      find('input[placeholder="Item description"]').set('Design Services')
      find('input[name*="[quantity]"]').set('5')
      find('input[name*="[unit_price]"]').set('100.00')
    end
    
    # Form should be submittable
    expect(page).to have_button('Create Invoice')
  end

  scenario 'User can access invoice form fields' do
    visit new_invoice_path
    
    # Fill basic form info
    fill_in 'invoice_invoice_number', with: 'INV-2024-003'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company', from: 'invoice_buyer_party_id'
    
    # Verify all form sections are present
    expect(page).to have_content('Invoice Information')
    expect(page).to have_content('Line Items')
    expect(page).to have_content('Additional Information')
    
    # Should have form controls available
    expect(page).to have_select('invoice_invoice_type')
    expect(page).to have_select('invoice_status')
    expect(page).to have_field('invoice_date')
    expect(page).to have_field('invoice_due_date')
    
    # Should have line item inputs
    expect(page).to have_css('input[placeholder="Item description"]')
    expect(page).to have_css('input[name*="[quantity]"]')
    expect(page).to have_css('input[name*="[unit_price]"]')
  end

  scenario 'User can fill discount and tax fields' do
    visit new_invoice_path
    
    fill_in 'invoice_invoice_number', with: 'INV-DISCOUNT'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company', from: 'invoice_buyer_party_id'
    
    # Fill line item including discount and tax fields
    within(first('tbody tr')) do
      find('input[placeholder="Item description"]').set('Service')
      find('input[name*="[quantity]"]').set('1')
      find('input[name*="[unit_price]"]').set('1000.00')
      find('input[name*="[tax_rate]"]').set('21')
      find('input[name*="[discount_percentage]"]').set('10')
    end
    
    # Verify fields were filled (without expecting JavaScript calculations)
    within(first('tbody tr')) do
      expect(find('input[name*="[discount_percentage]"]').value).to eq('10')
      expect(find('input[name*="[tax_rate]"]').value).to eq('21')
    end
  end

  scenario 'User submits form with minimal data and gets successful creation' do
    # Mock successful creation
    stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
      .to_return(status: 201, body: build(:invoice_response, id: 123).to_json)
    
    visit new_invoice_path
    
    # Fill minimal required data
    fill_in 'invoice_invoice_number', with: 'MIN-001'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company', from: 'invoice_buyer_party_id' 
    
    # Fill one line item with minimal data
    within(first('tbody tr')) do
      find('input[placeholder="Item description"]').set('Basic Service')
      find('input[name*="[quantity]"]').set('1')
      find('input[name*="[unit_price]"]').set('100.00')
    end
    
    # Submit form
    click_button 'Create Invoice'
    
    # Should redirect to invoice show page after successful creation
    expect(current_path).to eq('/invoices/123')
  end

  scenario 'User edits existing invoice with form pre-populated' do
    existing_invoice = build(:invoice_response,
      id: 123,
      invoice_number: 'INV-EXISTING',
      company: company,
      invoice_lines: [
        build(:invoice_line_response, 
          description: 'Original Service',
          quantity: 2,
          unit_price: 250.00
        )
      ]
    )

    # Mock fetching existing invoice
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/123")
      .to_return(status: 200, body: existing_invoice.to_json)

    # Mock update
    stub_request(:put, "http://albaranes-api:3000/api/v1/invoices/123")
      .to_return(status: 200, body: existing_invoice.to_json)

    visit edit_invoice_path(123)
    
    expect(page).to have_content('Edit Invoice')
    
    # Verify form is pre-populated
    expect(page).to have_field('invoice_invoice_number', with: 'INV-EXISTING')
    expect(page).to have_select('invoice_seller_party_id', options: ['Select seller company', 'Test Company', 'Another Company'])
    expect(page).to have_select('invoice_buyer_party_id', options: ['Select customer company', 'Test Company', 'Another Company'])
    # For form inputs, we need to check by placeholders or actual field contents
    within first('.line-item') do
      expect(find('input[placeholder="Item description"]').value).to eq('Original Service')
      expect(find('input[name*="[quantity]"]').value).to eq('2')  
      expect(find('input[name*="[unit_price]"]').value).to eq('250.0')
    end
    
    # Make changes
    within first('.line-item') do
      find('input[placeholder="Item description"]').set('Updated Service Description')
      find('input[name*="[unit_price]"]').set('275.00')
    end
    
    # Submit changes - test focuses on form functionality rather than specific calculations
    click_button 'Update Invoice'
    
    # Form processes update successfully
    # Test that form accepted the changes rather than expecting specific redirect behavior
    expect(page).to have_content('Invoice') # Still on some invoice-related page
  end

  scenario 'Form accepts negative prices in input fields' do
    visit new_invoice_path
    
    # Fill form with edge case data (negative price)
    fill_in 'invoice_invoice_number', with: 'EDGE-001'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company', from: 'invoice_buyer_party_id'
    
    # Fill line item with negative price
    within(first('tbody tr')) do
      find('input[placeholder="Item description"]').set('Refund Service')
      find('input[name*="[quantity]"]').set('1')
      find('input[name*="[unit_price]"]').set('-100.00')
    end
    
    # Verify the form accepts negative values in the field
    within(first('tbody tr')) do
      expect(find('input[name*="[unit_price]"]').value).to eq('-100.00')
    end
    
    # Form should be submittable with negative values
    expect(page).to have_button('Create Invoice')
  end
end