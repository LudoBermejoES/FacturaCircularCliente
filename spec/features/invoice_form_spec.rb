require 'rails_helper'

RSpec.feature 'Invoice Form Interactions', type: :feature, js: true do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response, name: 'Test Company', tax_id: 'B12345678') }
  let(:auth_response) { build(:auth_response) }

  before do
    # Mock all API endpoints for feature tests
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .to_return(status: 200, body: auth_response.to_json)
    
    stub_request(:get, 'http://localhost:3001/api/v1/auth/validate')
      .to_return(status: 200, body: { valid: true }.to_json)
      
    # Mock the session/authentication state directly for feature tests
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    
    # Mock dashboard data calls (needed after login redirect)
    stub_request(:get, 'http://localhost:3001/api/v1/invoices/stats')
      .to_return(status: 200, body: {
        total_invoices: 25,
        total_amount: 50000.00,
        pending_amount: 15000.00
      }.to_json)
    
    stub_request(:get, 'http://localhost:3001/api/v1/invoices')
      .with(query: { limit: '5', status: 'recent' })
      .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)
    
    # Mock company data for form dropdowns - allow any query params
    stub_request(:get, %r{http://localhost:3001/api/v1/companies})
      .to_return(status: 200, body: { 
        companies: [company, build(:company_response, name: 'Another Company')], 
        total: 2 
      }.to_json)
    
    # Mock invoice creation/update endpoints
    stub_request(:post, 'http://localhost:3001/api/v1/invoices')
      .to_return(status: 201, body: build(:invoice_response).to_json)
    
    stub_request(:get, %r{http://localhost:3001/api/v1/invoices/\d+})
      .to_return(status: 200, body: build(:invoice_response).to_json)
    
    stub_request(:put, %r{http://localhost:3001/api/v1/invoices/\d+})
      .to_return(status: 200, body: build(:invoice_response).to_json)
  end

  scenario 'User creates a new invoice with single line item' do
    invoice_data = {
      invoice_number: 'INV-2024-001',
      company_id: company[:id],
      issue_date: Date.current.strftime('%Y-%m-%d'),
      invoice_lines_attributes: [{
        description: 'Web Development Services',
        quantity: 10,
        unit_price: 150.00,
        tax_rate: 21
      }]
    }

    # Mock invoice creation
    stub_request(:post, 'http://localhost:3001/api/v1/invoices')
      .with(body: invoice_data.to_json)
      .to_return(status: 201, body: build(:invoice_response, invoice_data).to_json)

    # Since we're mocking authentication state, directly visit the invoice form
    visit new_invoice_path

    expect(page).to have_content('New Invoice')
    
    # Fill in basic invoice information (using actual field names from the page)
    fill_in 'Invoice number', with: 'INV-2024-001'
    select 'Test Company', from: 'Customer'
    fill_in 'Invoice Date', with: Date.current.strftime('%Y-%m-%d')
    
    # Add a line item first since form starts empty
    click_button 'Add Line'
    
    # Fill in the line item using first line item in tbody
    within(first('tbody .line-item')) do
      find('input[placeholder="Item description"]').set('Web Development Services')
      find('input[name*="[quantity]"]').set('10')
      find('input[name*="[unit_price]"]').set('150.00')
      find('input[name*="[tax_rate]"]').set('21')
    end
    
    # Verify calculated totals update dynamically
    expect(page).to have_content('€1500.00') # subtotal
    expect(page).to have_content('€315.00')   # tax amount
    expect(page).to have_content('€1815.00') # total
    
    # Submit the form
    click_button 'Create Invoice'
    
    # Verify the form was submitted successfully
    # Form submission is working if we're not still on the new invoice page
    expect(page).not_to have_content('Create Invoice')
  end

  scenario 'User adds multiple line items dynamically' do
    visit new_invoice_path
    
    # Fill basic info
    fill_in 'Invoice number', with: 'INV-2024-002' 
    select 'Test Company', from: 'Customer'
    
    # Add first line item
    click_button 'Add Line'
    
    within(first('tbody .line-item')) do
      find('input[placeholder="Item description"]').set('Design Services')
      find('input[name*="[quantity]"]').set('5')
      find('input[name*="[unit_price]"]').set('100.00')
      find('input[name*="[tax_rate]"]').set('21')
    end
    
    # Click "Add Line" button
    click_button 'Add Line'
    
    # Verify new line item form appears
    expect(page).to have_css('.line-item', count: 2)
    
    # Fill second line item
    within all('.line-item').last do
      fill_in 'Description', with: 'Development Services'
      fill_in 'Quantity', with: '8'
      fill_in 'Unit Price', with: '125.00'
      select '10%', from: 'Tax Rate'
    end
    
    # Verify totals calculation with multiple items
    expect(page).to have_content('1500.00') # subtotal: 500 + 1000
    expect(page).to have_content('205.00')   # tax: 105 + 100  
    expect(page).to have_content('1705.00') # total
  end

  scenario 'User removes line items dynamically' do
    visit new_invoice_path
    
    fill_in 'Invoice number', with: 'INV-2024-003'
    select 'Test Company', from: 'Customer'
    
    # Add multiple line items
    click_button 'Add Line'
    click_button 'Add Line'
    
    expect(page).to have_css('.line-item', count: 3)
    
    # Fill all line items using array indexing for multiple items
    all('input[placeholder="Item description"]')[0].set('Item 1')
    all('input[name*="[quantity]"]')[0].set('1')
    all('input[name*="[unit_price]"]')[0].set('100.00')
    
    all('input[placeholder="Item description"]')[1].set('Item 2')
    all('input[name*="[quantity]"]')[1].set('1')
    all('input[name*="[unit_price]"]')[1].set('200.00')
    
    all('input[placeholder="Item description"]')[2].set('Item 3')
    all('input[name*="[quantity]"]')[2].set('1')
    all('input[name*="[unit_price]"]')[2].set('300.00')
    
    # Remove middle line item
    within all('.line-item')[1] do
      click_button 'Remove'
    end
    
    # Verify line item was removed and totals updated
    expect(page).to have_css('.line-item', count: 2)
    expect(page).not_to have_content('Item 2')
    expect(page).to have_content('Item 1')
    expect(page).to have_content('Item 3')
  end

  scenario 'User applies discount to invoice' do
    visit new_invoice_path
    
    fill_in 'Invoice number', with: 'INV-DISCOUNT'
    select 'Test Company', from: 'Customer'
    
    # Add line item
    click_button 'Add Line'
    
    within(first('tbody .line-item')) do
      find('input[placeholder="Item description"]').set('Service')
      find('input[name*="[quantity]"]').set('1')
      find('input[name*="[unit_price]"]').set('1000.00')
      find('input[name*="[tax_rate]"]').set('21')
    end
    
    # Apply 10% discount
    check 'Apply Discount'
    fill_in 'Discount Percentage', with: '10'
    
    # Verify discount calculation
    expect(page).to have_content('1000.00') # original subtotal
    expect(page).to have_content('100.00')   # discount amount
    expect(page).to have_content('900.00')   # discounted subtotal
    expect(page).to have_content('189.00')   # tax on discounted amount
    expect(page).to have_content('1089.00') # final total
  end

  scenario 'User validates form with missing required fields' do
    visit new_invoice_path
    
    # Try to submit empty form
    click_button 'Create Invoice'
    
    # Should show validation errors
    expect(page).to have_content("Invoice number can't be blank")
    expect(page).to have_content("Customer must be selected")
    expect(page).to have_content('Please add at least one line item')
    
    # Form should not be submitted
    expect(page).to have_current_path(new_invoice_path)
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
    stub_request(:get, "http://localhost:3001/api/v1/invoices/123")
      .to_return(status: 200, body: existing_invoice.to_json)

    # Mock update
    stub_request(:put, "http://localhost:3001/api/v1/invoices/123")
      .to_return(status: 200, body: existing_invoice.to_json)

    visit edit_invoice_path(123)
    
    expect(page).to have_content('Edit Invoice')
    
    # Verify form is pre-populated
    expect(page).to have_field('Invoice number', with: 'INV-EXISTING')
    expect(page).to have_select('Customer', selected: 'Test Company')
    expect(page).to have_field('Description', with: 'Original Service')
    expect(page).to have_field('Quantity', with: '2')
    expect(page).to have_field('Unit Price', with: '250.00')
    
    # Make changes
    fill_in 'Description', with: 'Updated Service Description'
    fill_in 'Unit Price', with: '275.00'
    
    # Verify totals update
    expect(page).to have_content('550.00') # 2 * 275
    
    # Submit changes
    click_button 'Update Invoice'
    
    expect(page).to have_content('Invoice updated successfully')
    expect(page).to have_content('Updated Service Description')
    expect(page).to have_content('275.00')
  end

  scenario 'Form handles API validation errors gracefully' do
    # Mock API validation error response
    stub_request(:post, 'http://localhost:3001/api/v1/invoices')
      .to_return(
        status: 422,
        body: {
          errors: {
            invoice_number: ['already exists'],
            'invoice_lines.0.unit_price': ['must be positive']
          }
        }.to_json
      )

    visit new_invoice_path
    
    # Fill form with invalid data
    fill_in 'Invoice number', with: 'DUPLICATE-001'
    select 'Test Company', from: 'Customer'
    
    # Fill line item with invalid data
    click_button 'Add Line'
    
    within(first('tbody .line-item')) do
      find('input[placeholder="Item description"]').set('Service')
      find('input[name*="[quantity]"]').set('1')
      find('input[name*="[unit_price]"]').set('-100.00') # negative price
    end
    
    click_button 'Create Invoice'
    
    # Should display API validation errors
    expect(page).to have_content('Invoice number already exists')
    expect(page).to have_content('Unit price must be positive')
    
    # Form should remain populated for user to fix
    expect(page).to have_field('Invoice number', with: 'DUPLICATE-001')
    expect(page).to have_field('Unit Price', with: '-100.00')
  end
end