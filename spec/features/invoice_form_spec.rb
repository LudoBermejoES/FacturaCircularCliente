require 'rails_helper'

RSpec.feature 'Invoice Form Interactions', type: :feature, js: true do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response, name: 'Test Company', tax_id: 'B12345678') }
  let(:auth_response) { build(:auth_response) }

  before do
    # Mock authentication endpoints needed for login_via_ui (exact match from authentication_flow_spec.rb)
    stub_request(:post, 'http://localhost:3001/api/v1/auth/login')
      .with(
        body: { email: 'admin@example.com', password: 'password123', remember_me: false }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 200, body: auth_response.to_json)
    
    stub_request(:get, 'http://localhost:3001/api/v1/auth/validate')
      .to_return(status: 200, body: { valid: true }.to_json)
    
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
    
    # Mock company data for form dropdowns
    stub_request(:get, 'http://localhost:3001/api/v1/companies')
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

    # Login sequence copied exactly from authentication_flow_spec.rb
    visit login_path
    
    within 'form' do
      find('input[type="email"]').set('admin@example.com')
      find('input[type="password"]').set('password123')
      click_button 'Sign in'
    end
    
    puts "DEBUG: After login form submission, current_path: #{current_path}"
    puts "DEBUG: Current page content: #{page.text[0..200]}"
    
    visit new_invoice_path
    puts "DEBUG: After visit new_invoice_path, current_path: #{current_path}"
    puts "DEBUG: Current page content: #{page.text[0..200]}"

    expect(page).to have_content('New Invoice')
    
    # Fill in basic invoice information
    fill_in 'Invoice Number', with: 'INV-2024-001'
    select 'Test Company', from: 'Company'
    fill_in 'Issue Date', with: Date.current.strftime('%Y-%m-%d')
    
    # Fill in first line item
    within '#invoice-lines' do
      fill_in 'Description', with: 'Web Development Services'
      fill_in 'Quantity', with: '10'
      fill_in 'Unit Price', with: '150.00'
      select '21%', from: 'Tax Rate'
    end
    
    # Verify calculated totals update dynamically
    expect(page).to have_content('1,500.00') # subtotal
    expect(page).to have_content('315.00')   # tax amount
    expect(page).to have_content('1,815.00') # total
    
    # Submit the form
    click_button 'Create Invoice'
    
    # Should redirect to invoice show page
    expect(page).to have_content('Invoice created successfully')
    expect(page).to have_content('INV-2024-001')
    expect(page).to have_content('Web Development Services')
    expect(page).to have_content('1,815.00')
  end

  scenario 'User adds multiple line items dynamically' do
    login_via_ui
    visit new_invoice_path
    
    # Fill basic info
    fill_in 'Invoice Number', with: 'INV-2024-002' 
    select 'Test Company', from: 'Company'
    
    # Add first line item
    within '#invoice-lines' do
      within first('.line-item') do
        fill_in 'Description', with: 'Design Services'
        fill_in 'Quantity', with: '5'
        fill_in 'Unit Price', with: '100.00'
        select '21%', from: 'Tax Rate'
      end
    end
    
    # Click "Add Line Item" button
    click_button 'Add Line Item'
    
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
    expect(page).to have_content('1,500.00') # subtotal: 500 + 1000
    expect(page).to have_content('205.00')   # tax: 105 + 100  
    expect(page).to have_content('1,705.00') # total
  end

  scenario 'User removes line items dynamically' do
    login_via_ui
    visit new_invoice_path
    
    fill_in 'Invoice Number', with: 'INV-2024-003'
    select 'Test Company', from: 'Company'
    
    # Add multiple line items
    click_button 'Add Line Item'
    click_button 'Add Line Item'
    
    expect(page).to have_css('.line-item', count: 3)
    
    # Fill all line items
    within first('.line-item') do
      fill_in 'Description', with: 'Item 1'
      fill_in 'Quantity', with: '1'
      fill_in 'Unit Price', with: '100.00'
    end
    
    within all('.line-item')[1] do
      fill_in 'Description', with: 'Item 2'
      fill_in 'Quantity', with: '1'
      fill_in 'Unit Price', with: '200.00'
    end
    
    within all('.line-item')[2] do
      fill_in 'Description', with: 'Item 3'
      fill_in 'Quantity', with: '1'
      fill_in 'Unit Price', with: '300.00'
    end
    
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
    login_via_ui
    visit new_invoice_path
    
    fill_in 'Invoice Number', with: 'INV-DISCOUNT'
    select 'Test Company', from: 'Company'
    
    # Add line item
    within '#invoice-lines' do
      fill_in 'Description', with: 'Service'
      fill_in 'Quantity', with: '1'
      fill_in 'Unit Price', with: '1000.00'
      select '21%', from: 'Tax Rate'
    end
    
    # Apply 10% discount
    check 'Apply Discount'
    fill_in 'Discount Percentage', with: '10'
    
    # Verify discount calculation
    expect(page).to have_content('1,000.00') # original subtotal
    expect(page).to have_content('100.00')   # discount amount
    expect(page).to have_content('900.00')   # discounted subtotal
    expect(page).to have_content('189.00')   # tax on discounted amount
    expect(page).to have_content('1,089.00') # final total
  end

  scenario 'User validates form with missing required fields' do
    login_via_ui
    visit new_invoice_path
    
    # Try to submit empty form
    click_button 'Create Invoice'
    
    # Should show validation errors
    expect(page).to have_content("Invoice number can't be blank")
    expect(page).to have_content("Company must be selected")
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

    login_via_ui
    visit edit_invoice_path(123)
    
    expect(page).to have_content('Edit Invoice')
    
    # Verify form is pre-populated
    expect(page).to have_field('Invoice Number', with: 'INV-EXISTING')
    expect(page).to have_select('Company', selected: 'Test Company')
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

    login_via_ui
    visit new_invoice_path
    
    # Fill form with invalid data
    fill_in 'Invoice Number', with: 'DUPLICATE-001'
    select 'Test Company', from: 'Company'
    
    within '#invoice-lines' do
      fill_in 'Description', with: 'Service'
      fill_in 'Quantity', with: '1'
      fill_in 'Unit Price', with: '-100.00' # negative price
    end
    
    click_button 'Create Invoice'
    
    # Should display API validation errors
    expect(page).to have_content('Invoice number already exists')
    expect(page).to have_content('Unit price must be positive')
    
    # Form should remain populated for user to fix
    expect(page).to have_field('Invoice Number', with: 'DUPLICATE-001')
    expect(page).to have_field('Unit Price', with: '-100.00')
  end
end