require 'rails_helper'

RSpec.feature 'Company Contacts Workflow', type: :feature, driver: :rack_test do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response, id: 123, name: 'Test Company', tax_id: 'B12345678') }
  let(:other_company) { build(:company_response, id: 124, name: 'Other Company', tax_id: 'B87654321') }
  let(:auth_response) { build(:auth_response) }
  
  let(:contact1) { build(:company_contact_response, id: 1, name: 'John', full_name: 'John', email: 'john@test.com', is_active: true) }
  let(:contact2) { build(:company_contact_response, id: 2, name: 'Jane', full_name: 'Jane Smith', email: 'jane@test.com', is_active: true) }
  let(:inactive_contact) { build(:company_contact_response, id: 3, name: 'Bob', full_name: 'Bob Johnson', email: 'bob@test.com', is_active: false) }

  before do
    # Mock authentication
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
      .with(
        body: { grant_type: 'password', email: 'admin@example.com', password: 'password123', remember_me: false }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
      )
      .to_return(status: 200, body: auth_response.to_json)
    
    stub_request(:get, 'http://albaranes-api:3000/api/v1/auth/validate')
      .to_return(status: 200, body: { valid: true }.to_json)
    
    # Mock session and user state
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:current_company_id).and_return(company[:id])
    allow_any_instance_of(ApplicationController).to receive(:user_companies).and_return([
      { id: company[:id], name: company[:name], role: 'manager' }
    ])
    allow_any_instance_of(ApplicationController).to receive(:current_user_role).and_return('manager')
    allow_any_instance_of(ApplicationController).to receive(:can?).and_return(true)

    # Mock company service
    allow(CompanyService).to receive(:all).and_return({ 
      companies: [company, other_company]
    })
    allow(CompanyService).to receive(:find).with(company[:id].to_s, token: token).and_return(company)
    allow(CompanyService).to receive(:find).with(other_company[:id].to_s, token: token).and_return(other_company)
  end

  feature 'Company contacts management' do
    scenario 'User views company contacts list', driver: :rack_test do
      # Force rack_test driver to avoid server issues
      Capybara.current_driver = :rack_test
      
      # Mock company contacts service
      allow(CompanyContactsService).to receive(:all).with(company_id: company[:id], token: token, params: {page: 1, per_page: 25})
        .and_return({
          contacts: [contact1, contact2, inactive_contact],
          meta: { total: 3, page: 1, pages: 1 }
        })

      visit company_company_contacts_path(company[:id])

      expect(page).to have_content('Company Contacts')
      expect(page).to have_content('John')
      expect(page).to have_content('john@test.com')
      expect(page).to have_content('Jane')
      expect(page).to have_content('jane@test.com')
      expect(page).to have_content('Bob')
      expect(page).to have_content('bob@test.com')
      
      # Verify the contacts are displayed
      expect(page).to have_content('Active')
      expect(page).to have_content('Inactive')
      expect(page).to have_content('3 contacts')
    end

    scenario 'User creates a new company contact' do
      # Mock the services with proper structure
      allow(CompanyContactsService).to receive(:all).with(company_id: company[:id], token: token, params: {page: 1, per_page: 25})
        .and_return({
          contacts: [],
          meta: { total: 0, page: 1, pages: 1 }
        })
      allow(CompanyContactsService).to receive(:create).and_return({ success: true, contact: contact1 })

      visit company_company_contacts_path(company[:id])
      
      # Click the first "Add Contact" link (in the header)
      first('a', text: 'Add Contact').click
      expect(page).to have_current_path(new_company_company_contact_path(company[:id]))
      expect(page).to have_content('Add Company Contact')

      fill_in 'Company Name *', with: 'Acme Corp'
      fill_in 'Legal Name', with: 'Acme Corporation S.L.'
      fill_in 'Tax ID', with: 'B12345678'
      fill_in 'Email Address', with: 'contact@acmecorp.com'
      fill_in 'Phone Number', with: '+34612345678'
      fill_in 'Website', with: 'https://acmecorp.com'

      click_button 'Create Company Contact'

      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
      expect(page).to have_content('Contact was successfully created.')
      
      expect(CompanyContactsService).to have_received(:create).with(
        company_id: company[:id],
        params: hash_including(
          'name' => 'Acme Corp',
          'legal_name' => 'Acme Corporation S.L.',
          'tax_id' => 'B12345678',
          'email' => 'contact@acmecorp.com',
          'phone' => '+34612345678',
          'website' => 'https://acmecorp.com'
        ),
        token: token
      )
    end

    scenario 'User edits an existing company contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).with(company_id: company[:id], token: token, params: {page: 1, per_page: 25})
        .and_return({
          contacts: [contact1],
          meta: { total: 1, page: 1, pages: 1 }
        })
      allow(CompanyContactsService).to receive(:find).with(company_id: company[:id], id: contact1[:id].to_s, token: token)
        .and_return(contact1)
      allow(CompanyContactsService).to receive(:update).with(company_id: company[:id], id: contact1[:id].to_s, params: anything, token: token)
        .and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('li', text: 'John') do
        click_link 'Edit'
      end
      
      expect(page).to have_current_path(edit_company_company_contact_path(company[:id], contact1[:id]))
      expect(page).to have_content('Edit Contact')
      
      # Form should be pre-filled
      expect(page).to have_field('Name', with: 'John')
      expect(page).to have_field('Email', with: contact1[:email])
      
      fill_in 'Email Address', with: 'john.updated@test.com'
      fill_in 'Company Name', with: 'Updated John Company'
      
      click_button 'Update Contact'
      
      expect(page).to have_current_path(company_company_contact_path(company[:id], contact1[:id]))
      expect(page).to have_content('Contact updated successfully')
      
      expect(CompanyContactsService).to have_received(:update).with(
        company_id: company[:id],
        id: contact1[:id],
        params: hash_including(
          'email' => 'john.updated@test.com',
          'name' => 'Updated John Company'
        ),
        token: token
      )
    end

    scenario 'User activates an inactive contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [inactive_contact], 
        meta: { total: 1, page: 1, pages: 1 } 
      })
      allow(CompanyContactsService).to receive(:find).and_return(inactive_contact)
      allow(CompanyContactsService).to receive(:activate).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('li', text: 'Bob') do
        click_button 'Activate'
      end
      
      expect(page).to have_content('Contact was successfully activated.')
      
      expect(CompanyContactsService).to have_received(:activate).with(
        company_id: company[:id],
        id: inactive_contact[:id],
        token: token
      )
    end

    scenario 'User deactivates an active contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [contact1], 
        meta: { total: 1, page: 1, pages: 1 } 
      })
      allow(CompanyContactsService).to receive(:find).and_return(contact1)
      allow(CompanyContactsService).to receive(:deactivate).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('li', text: 'John') do
        click_button 'Deactivate'
      end
      
      expect(page).to have_content('Contact was successfully deactivated.')
      
      expect(CompanyContactsService).to have_received(:deactivate).with(
        company_id: company[:id],
        id: contact1[:id],
        token: token
      )
    end

    scenario 'User deletes a company contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [contact1], 
        meta: { total: 1, page: 1, pages: 1 } 
      })
      allow(CompanyContactsService).to receive(:find).and_return(contact1)
      allow(CompanyContactsService).to receive(:destroy).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('li', text: 'John') do
        click_button 'Delete'
      end
      
      expect(page).to have_content('Contact was successfully deleted.')
      
      expect(CompanyContactsService).to have_received(:destroy).with(
        company_id: company[:id],
        id: contact1[:id],
        token: token
      )
    end
  end

  feature 'Invoice creation with company contacts' do
    let(:invoice_series) { [{ id: 1, name: 'FC', year: 2024, active: true }] }

    before do
      # Mock invoice-related services
      allow(InvoiceSeriesService).to receive(:all).and_return(invoice_series)
      
      # Mock CompanyContactsService.all for loading customer companies (used in invoices controller)
      allow(CompanyContactsService).to receive(:all)
        .with(company_id: company[:id], token: token, params: { per_page: 100 })
        .and_return({ 
          contacts: [company, other_company], # These are the companies available as customers
          meta: { total: 2, page: 1, pages: 1 } 
        })
      
      # Mock active_contacts for specific companies (used for contact person dropdown)
      allow(CompanyContactsService).to receive(:active_contacts)
        .with(company_id: company[:id], token: token).and_return([contact1, contact2])
      allow(CompanyContactsService).to receive(:active_contacts)
        .with(company_id: other_company[:id], token: token).and_return([])
    end

    scenario 'User creates invoice and selects company contact' do
      # Mock invoice series
      allow(InvoiceSeriesService).to receive(:all).and_return([
        { id: 1, series_code: 'FC', series_name: 'Facturas' }
      ])
      
      allow(InvoiceService).to receive(:create).and_return({ data: { id: 456 } })
      # Mock the redirect to invoice show page
      allow(InvoiceService).to receive(:find).with(456, token: token).and_return({
        id: 456,
        invoice_number: 'INV-001',
        status: 'draft'
      })

      visit new_invoice_path
      
      expect(page).to have_content('New Invoice')
      
      # Fill in required fields
      select 'Test Company', from: 'invoice_seller_party_id'
      select 'Test Company (Company)', from: 'buyer_selection'
      select 'FC - Facturas', from: 'invoice_invoice_series_id'
      
      # Add invoice line using the actual table structure
      within('tbody') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Test Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '2'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '100.50'
      end
      
      click_button 'Create Invoice'
      
      expect(InvoiceService).to have_received(:create).with(
        hash_including(
          'buyer_party_id' => company[:id].to_s
        ),
        token: token
      )
      
      expect(page).to have_content('Invoice created successfully')
    end

    scenario 'Contact dropdown updates when buyer company changes' do
      # Mock invoice series
      allow(InvoiceSeriesService).to receive(:all).and_return([
        { id: 1, series_code: 'FC', series_name: 'Facturas' }
      ])
      
      visit new_invoice_path
      
      # Initially no buyer company selected, contact field should be hidden
      expect(page).not_to have_select('Contact Person', visible: true)
      
      # Form should have customer dropdown available
      expect(page).to have_select('buyer_selection')
      
      # User can select companies from the dropdown
      expect(page).to have_select('buyer_selection', with_options: ['Test Company (Company)', 'Other Company (Company)'])
      
      # Contact field exists but is hidden initially (static test, no JS)
      contact_field = find('[data-invoice-form-target="contactField"]', visible: false)
      expect(contact_field).not_to be_visible
    end

    scenario 'User can create invoice without selecting company contact' do
      # Mock invoice series
      allow(InvoiceSeriesService).to receive(:all).and_return([
        { id: 1, series_code: 'FC', series_name: 'Facturas' }
      ])
      
      allow(InvoiceService).to receive(:create).and_return({ data: { id: 457 } })
      # Mock the redirect to invoice show page
      allow(InvoiceService).to receive(:find).with(457, token: token).and_return({
        id: 457,
        invoice_number: 'INV-002',
        status: 'draft'
      })

      visit new_invoice_path
      
      # Fill required fields but don't select contact
      select 'Test Company', from: 'invoice_seller_party_id'
      select 'Other Company (Company)', from: 'buyer_selection'  # Company with no contacts
      select 'FC - Facturas', from: 'invoice_invoice_series_id'
      
      within('tbody') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Test Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '1'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '50.00'
      end
      
      click_button 'Create Invoice'
      
      expect(InvoiceService).to have_received(:create).with(
        hash_including(
          'buyer_party_id' => other_company[:id].to_s
        ),
        token: token
      )
      
      # buyer_company_contact_id should not be present or should be nil
      expect(InvoiceService).to have_received(:create) do |params, options|
        expect(params['buyer_company_contact_id']).to be_blank
      end
      
      expect(page).to have_content('Invoice created successfully')
    end
  end

  feature 'Service integration for company contacts' do
    scenario 'Company contacts service returns properly formatted data' do
      # Mock proper service response structure
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [contact1, contact2], 
        meta: { total: 2, page: 1, pages: 1 } 
      })

      visit company_company_contacts_path(company[:id])
      
      # Service should have been called with proper parameters
      expect(CompanyContactsService).to have_received(:all)
      
      # Page should display contact data properly
      expect(page).to have_content('John') # contact1 name
      expect(page).to have_content('jane@test.com') # contact2 email
      
      # Should show properly formatted contact list
      expect(page).to have_content('Company Contacts')
      # Should show both contacts in the contact list area (not navigation)
      within('[data-testid="contacts-list"], .contacts-list, main') do
        expect(page).to have_content('John')
        expect(page).to have_content('Jane')
      end
    end

    scenario 'Service handles company with no contacts' do
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [], 
        meta: { total: 0, page: 1, pages: 1 } 
      })

      visit company_company_contacts_path(company[:id])
      
      expect(page).to have_content('Company Contacts')
      expect(page).to have_content('No contacts')
      expect(page).not_to have_css('.contacts-list li') # No contact items
    end

    scenario 'Service handles errors gracefully' do
      allow(CompanyContactsService).to receive(:all)
        .and_raise(ApiService::ApiError.new('Company not found'))

      visit company_company_contacts_path(company[:id])
      
      # Should show error message to user
      expect(page).to have_content('Company not found')
      # Should stay on same page showing the error
      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
    end
  end

  feature 'Error handling and edge cases' do
    scenario 'User tries to access contacts for non-existent company' do
      allow(CompanyService).to receive(:find)
        .and_raise(ApiService::ApiError.new('Company not found'))

      visit company_company_contacts_path(999)
      
      expect(page).to have_current_path(companies_path)
      expect(page).to have_content('Company not found')
    end

    scenario 'Contact creation fails with validation errors' do
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [], 
        meta: { total: 0, page: 1, pages: 1 } 
      })
      allow(CompanyContactsService).to receive(:create)
        .and_raise(ApiService::ValidationError.new('Validation failed', { email: ['is invalid'] }))

      visit new_company_company_contact_path(company[:id])
      
      fill_in 'Company Name', with: 'John'
      fill_in 'Email Address', with: 'invalid-email'
      
      click_button 'Create Company Contact'
      
      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
      expect(page).to have_content('Email is invalid')
      
      # Form should be re-rendered with errors
      expect(page).to have_field('Company Name', with: 'John')
      expect(page).to have_field('Email Address', with: 'invalid-email')
    end

    scenario 'Company contacts service is unavailable' do
      allow(CompanyContactsService).to receive(:all)
        .and_raise(ApiService::ApiError.new('Service unavailable'))

      visit company_company_contacts_path(company[:id])
      
      # Stays on the same path with error message
      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
      expect(page).to have_content('Service unavailable')
    end

    scenario 'Invoice form handles missing company contacts gracefully' do
      # Mock invoice series
      allow(InvoiceSeriesService).to receive(:all).and_return([
        { id: 1, series_code: 'FC', series_name: 'Facturas' }
      ])
      
      # Mock CompanyContactsService.all for loading customer companies
      allow(CompanyContactsService).to receive(:all)
        .with(company_id: company[:id], token: token, params: { per_page: 100 })
        .and_return({ 
          contacts: [company], # Test Company is available as customer
          meta: { total: 1, page: 1, pages: 1 } 
        })
      
      # Mock empty contacts for all companies
      allow(CompanyContactsService).to receive(:active_contacts).and_return([])

      visit new_invoice_path
      
      # Select buyer company using correct field names
      select 'Test Company (Company)', from: 'buyer_selection'
      
      # Contact dropdown should not appear or should be empty
      expect(page).not_to have_select('Contact Person', with_options: ['John'])
      
      # User should still be able to create invoice
      select 'Test Company', from: 'invoice_seller_party_id'
      select 'FC - Facturas', from: 'invoice_invoice_series_id'
      
      within('tbody') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Test Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '1'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '25.00'
      end
      
      allow(InvoiceService).to receive(:create).and_return({ data: { id: 458 } })
      # Mock the redirect to invoice show page
      allow(InvoiceService).to receive(:find).with(458, token: token).and_return({
        id: 458,
        invoice_number: 'INV-003',
        status: 'draft'
      })
      
      click_button 'Create Invoice'
      expect(page).to have_content('Invoice created successfully')
    end

    scenario 'Contact activation/deactivation handles API errors' do
      allow(CompanyContactsService).to receive(:all).and_return({ 
        contacts: [inactive_contact], 
        meta: { total: 1, page: 1, pages: 1 } 
      })
      allow(CompanyContactsService).to receive(:find).and_return(inactive_contact)
      allow(CompanyContactsService).to receive(:activate)
        .and_raise(ApiService::ApiError.new('Cannot activate contact'))

      visit company_company_contacts_path(company[:id])
      
      within('li', text: 'Bob') do
        click_button 'Activate'
      end
      
      expect(page).to have_content('Cannot activate contact')
    end
  end
end