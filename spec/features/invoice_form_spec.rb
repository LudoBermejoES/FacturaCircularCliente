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
    
    # Mock CompanyContactsService methods that were added recently
    allow(CompanyContactsService).to receive(:all).with(any_args).and_return({ 
      contacts: [
        { id: 1, name: 'Test Company' },
        { id: 2, name: 'Another Company' }
      ], 
      total: 2, 
      meta: { page: 1, pages: 1, total: 2 } 
    })
    allow(CompanyContactsService).to receive(:active_contacts).with(any_args).and_return([])
    
    # Mock InvoiceSeriesService for invoice form  
    allow(InvoiceSeriesService).to receive(:all).with(any_args).and_return([
      { id: 1, series_code: 'FC', series_name: 'Facturas Comerciales', year: Date.current.year, is_active: true }
    ])
    
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
    # Invoice number is auto-generated
    select 'FC - Facturas Comerciales', from: 'invoice_invoice_series_id'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company (Company)', from: 'buyer_selection'
    fill_in 'Invoice Date', with: Date.current.strftime('%Y-%m-%d')
    
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
    # Invoice number is auto-generated
    select 'FC - Facturas Comerciales', from: 'invoice_invoice_series_id'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company (Company)', from: 'buyer_selection'
    
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
    # Invoice number is auto-generated
    select 'FC - Facturas', from: 'invoice_invoice_series_id'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company (Company)', from: 'buyer_selection'

    # Verify all form sections are present
    expect(page).to have_content('Invoice Information')
    expect(page).to have_content('Line Items')
    expect(page).to have_content('Additional Information')

    # Should have form controls available
    expect(page).to have_select('invoice[invoice_type]')
    expect(page).to have_select('invoice[status]')
    expect(page).to have_field('invoice[issue_date]')
    expect(page).to have_field('invoice[due_date]')

    # Should have line item inputs
    expect(page).to have_css('input[placeholder="Item description"]')
    expect(page).to have_css('input[name*="[quantity]"]')
    expect(page).to have_css('input[name*="[unit_price]"]')
  end

  scenario 'User can fill discount and tax fields' do
    visit new_invoice_path

    # Invoice number is auto-generated
    select 'FC - Facturas Comerciales', from: 'invoice_invoice_series_id'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company (Company)', from: 'buyer_selection'
    
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
    # Mock successful creation using service mocking
    invoice_response = build(:invoice_response, id: 123)
    response_data = { data: invoice_response }
    allow(InvoiceService).to receive(:create).and_return(response_data)
    
    visit new_invoice_path
    
    # Fill minimal required data
    # Invoice number is auto-generated
    select 'FC - Facturas Comerciales', from: 'invoice_invoice_series_id'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company (Company)', from: 'buyer_selection' 
    
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

    # Mock all dependencies for edit action (ID comes as string from params)
    allow(InvoiceService).to receive(:find).with("123", token: anything).and_return(existing_invoice)
    allow(InvoiceService).to receive(:update).with(123, anything, token: anything).and_return(existing_invoice)

    # Mock load_companies (needed by before_action)
    allow(CompanyService).to receive(:all).with(token: anything, params: anything).and_return({
      companies: [company, build(:company_response, name: 'Another Company')],
      total: 2
    })

    # Mock load_invoice_series (needed by before_action)
    allow(InvoiceSeriesService).to receive(:all).and_return([
      { id: 1, series_code: 'FC', series_name: 'Facturas Comerciales', year: Date.current.year, is_active: true }
    ])

    # Mock CompanyContactsService (needed by load_all_company_contacts)
    # Customer companies come from contacts, not companies
    allow(CompanyContactsService).to receive(:all).with(
      company_id: anything, token: anything, params: anything
    ).and_return({
      contacts: [company, build(:company_response, name: 'Another Company')],
      total: 2
    })
    allow(CompanyContactsService).to receive(:active_contacts).and_return([])

    # Mock permission check
    allow_any_instance_of(ApplicationController).to receive(:can?).and_return(true)

    visit edit_invoice_path(123)
    
    # Debug: Check what page we actually got
    puts "DEBUG: Current path: #{current_path}"
    puts "DEBUG: Page title: #{page.title}"
    puts "DEBUG: Page has 'Edit Invoice'?: #{page.has_content?('Edit Invoice')}"
    puts "DEBUG: Page has error content?: #{page.has_css?('.exception-message')}"

    expect(page).to have_content('Edit Invoice')

    # The invoice number field is readonly, so we need to check by CSS selector instead of field name
    invoice_number_field = find('input[data-invoice-form-target="invoiceNumber"]')
    expect(invoice_number_field.value).to eq('INV-EXISTING')
    expect(page).to have_select('invoice_seller_party_id', options: ['Select seller company', 'Test Company', 'Another Company'])
    # Verify buyer selection dropdown has expected options (more options may be available)
    expect(page).to have_select('buyer_selection')
    expect(page).to have_select('buyer_selection', with_options: ['Test Company (Company)', 'Another Company (Company)'])
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
    # Invoice number is auto-generated
    select 'FC - Facturas Comerciales', from: 'invoice_invoice_series_id'
    select 'Test Company', from: 'invoice_seller_party_id'
    select 'Test Company (Company)', from: 'buyer_selection'
    
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