require 'rails_helper'

RSpec.feature 'Company Contacts Workflow', type: :feature do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response, id: 123, name: 'Test Company', tax_id: 'B12345678') }
  let(:other_company) { build(:company_response, id: 124, name: 'Other Company', tax_id: 'B87654321') }
  let(:auth_response) { build(:auth_response) }
  
  let(:contact1) { build(:company_contact_response, id: 1, name: 'John', full_name: 'John Doe', email: 'john@test.com', is_active: true) }
  let(:contact2) { build(:company_contact_response, id: 2, name: 'Jane', full_name: 'Jane Smith', email: 'jane@test.com', is_active: true) }
  let(:inactive_contact) { build(:company_contact_response, id: 3, name: 'Bob', full_name: 'Bob Johnson', email: 'bob@test.com', is_active: false) }

  before do
    # Mock authentication
    stub_request(:post, 'http://albaranes-api:3000/api/v1/auth/login')
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
    scenario 'User views company contacts list' do
      # Mock company contacts service
      allow(CompanyContactsService).to receive(:all).with(company[:id].to_s, token: token)
        .and_return([contact1, contact2, inactive_contact])

      visit company_company_contacts_path(company[:id])

      expect(page).to have_content('Test Company Contacts')
      expect(page).to have_content('John Doe')
      expect(page).to have_content('john@test.com')
      expect(page).to have_content('Jane Smith')
      expect(page).to have_content('jane@test.com')
      expect(page).to have_content('Bob Johnson')
      expect(page).to have_content('bob@test.com')
      
      # Check for active/inactive status indicators
      within('tr', text: 'John Doe') do
        expect(page).to have_selector('.badge-success, .text-success', text: /active/i)
      end
      
      within('tr', text: 'Bob Johnson') do
        expect(page).to have_selector('.badge-danger, .text-danger', text: /inactive/i)
      end
    end

    scenario 'User creates a new company contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return([])
      allow(CompanyContactsService).to receive(:create).and_return({ success: true, contact: contact1 })

      visit company_company_contacts_path(company[:id])
      
      click_link 'Add New Contact'
      expect(page).to have_current_path(new_company_company_contact_path(company[:id]))
      expect(page).to have_content('Add New Contact for Test Company')

      fill_in 'Name', with: 'John'
      fill_in 'First Surname', with: 'Doe'
      fill_in 'Second Surname', with: 'Smith'
      fill_in 'Email', with: 'john.doe@test.com'
      fill_in 'Phone', with: '+34612345678'
      fill_in 'Contact Details', with: 'Sales Manager'
      check 'Active'

      click_button 'Create Contact'

      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
      expect(page).to have_content('Contact created successfully')
      
      expect(CompanyContactsService).to have_received(:create).with(
        company[:id].to_s,
        hash_including(
          'name' => 'John',
          'first_surname' => 'Doe',
          'second_surname' => 'Smith',
          'email' => 'john.doe@test.com',
          'telephone' => '+34612345678',
          'contact_details' => 'Sales Manager',
          'is_active' => 'true'
        ),
        token: token
      )
    end

    scenario 'User edits an existing company contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return([contact1])
      allow(CompanyContactsService).to receive(:find).with(company[:id].to_s, contact1[:id].to_s, token: token)
        .and_return(contact1)
      allow(CompanyContactsService).to receive(:update).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('tr', text: 'John Doe') do
        click_link 'Edit'
      end
      
      expect(page).to have_current_path(edit_company_company_contact_path(company[:id], contact1[:id]))
      expect(page).to have_content('Edit Contact for Test Company')
      
      # Form should be pre-filled
      expect(page).to have_field('Name', with: 'John')
      expect(page).to have_field('Email', with: contact1[:email])
      
      fill_in 'Email', with: 'john.updated@test.com'
      fill_in 'Contact Details', with: 'Senior Sales Manager'
      
      click_button 'Update Contact'
      
      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
      expect(page).to have_content('Contact updated successfully')
      
      expect(CompanyContactsService).to have_received(:update).with(
        company[:id].to_s,
        contact1[:id].to_s,
        hash_including(
          'email' => 'john.updated@test.com',
          'contact_details' => 'Senior Sales Manager'
        ),
        token: token
      )
    end

    scenario 'User activates an inactive contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return([inactive_contact])
      allow(CompanyContactsService).to receive(:activate).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('tr', text: 'Bob Johnson') do
        click_button 'Activate'
      end
      
      expect(page).to have_content('Contact activated successfully')
      
      expect(CompanyContactsService).to have_received(:activate).with(
        company[:id].to_s,
        inactive_contact[:id].to_s,
        token: token
      )
    end

    scenario 'User deactivates an active contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return([contact1])
      allow(CompanyContactsService).to receive(:deactivate).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('tr', text: 'John Doe') do
        click_button 'Deactivate'
      end
      
      expect(page).to have_content('Contact deactivated successfully')
      
      expect(CompanyContactsService).to have_received(:deactivate).with(
        company[:id].to_s,
        contact1[:id].to_s,
        token: token
      )
    end

    scenario 'User deletes a company contact' do
      # Mock the services
      allow(CompanyContactsService).to receive(:all).and_return([contact1])
      allow(CompanyContactsService).to receive(:destroy).and_return({ success: true })

      visit company_company_contacts_path(company[:id])
      
      within('tr', text: 'John Doe') do
        accept_confirm do
          click_button 'Delete'
        end
      end
      
      expect(page).to have_content('Contact deleted successfully')
      
      expect(CompanyContactsService).to have_received(:destroy).with(
        company[:id].to_s,
        contact1[:id].to_s,
        token: token
      )
    end
  end

  feature 'Invoice creation with company contacts' do
    let(:invoice_series) { [{ id: 1, name: 'FC', year: 2024, active: true }] }

    before do
      # Mock invoice-related services
      allow(InvoiceSeriesService).to receive(:all).and_return(invoice_series)
      allow(CompanyContactsService).to receive(:active_contacts)
        .with(company_id: company[:id], token: token).and_return([contact1, contact2])
      allow(CompanyContactsService).to receive(:active_contacts)
        .with(company_id: other_company[:id], token: token).and_return([])
    end

    scenario 'User creates invoice and selects company contact' do
      allow(InvoiceService).to receive(:create).and_return({ data: { id: 456 } })

      visit new_invoice_path
      
      expect(page).to have_content('Create New Invoice')
      
      # Select buyer company
      select 'Test Company', from: 'Buyer Company'
      
      # Wait for contact dropdown to be populated via JavaScript
      expect(page).to have_select('Company Contact', with_options: ['John Doe', 'Jane Smith'])
      
      # Select a company contact
      select 'John Doe', from: 'Company Contact'
      
      # Fill in other required fields
      select 'Test Company', from: 'Seller Company'
      fill_in 'Invoice Number', with: 'INV-001'
      select 'FC', from: 'Series'
      
      # Add invoice line
      within('.invoice-lines') do
        fill_in 'Description', with: 'Test Product', match: :first
        fill_in 'Quantity', with: '2', match: :first
        fill_in 'Unit Price', with: '100.50', match: :first
      end
      
      click_button 'Create Invoice'
      
      expect(CompanyContactsService).to have_received(:active_contacts)
        .with(company_id: company[:id], token: token)
      
      expect(InvoiceService).to have_received(:create).with(
        hash_including(
          'buyer_company_contact_id' => contact1[:id].to_s
        ),
        token: token
      )
      
      expect(page).to have_content('Invoice created successfully')
    end

    scenario 'Contact dropdown updates when buyer company changes', js: true do
      visit new_invoice_path
      
      # Initially no buyer company selected, no contacts shown
      expect(page).not_to have_select('Company Contact')
      
      # Select first company
      select 'Test Company', from: 'Buyer Company'
      
      # Contacts should be loaded
      expect(page).to have_select('Company Contact', with_options: ['John Doe', 'Jane Smith'])
      
      # Change to other company (no contacts)
      select 'Other Company', from: 'Buyer Company'
      
      # Contact dropdown should be empty or hidden
      expect(page).not_to have_content('John Doe')
      expect(page).not_to have_content('Jane Smith')
    end

    scenario 'User can create invoice without selecting company contact' do
      allow(InvoiceService).to receive(:create).and_return({ data: { id: 457 } })

      visit new_invoice_path
      
      # Fill required fields but don't select contact
      select 'Test Company', from: 'Seller Company'
      select 'Other Company', from: 'Buyer Company'  # Company with no contacts
      fill_in 'Invoice Number', with: 'INV-002'
      select 'FC', from: 'Series'
      
      within('.invoice-lines') do
        fill_in 'Description', with: 'Test Product', match: :first
        fill_in 'Quantity', with: '1', match: :first
        fill_in 'Unit Price', with: '50.00', match: :first
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

  feature 'API integration for company contacts' do
    scenario 'API endpoint returns properly formatted contact data' do
      # Mock the API controller behavior
      allow(CompanyContactsService).to receive(:active_contacts)
        .with(company_id: company[:id].to_s, token: token)
        .and_return([contact1, contact2])

      # Make request to API endpoint
      page.driver.header 'Accept', 'application/json'
      visit "/api/v1/company_contacts?company_id=#{company[:id]}"

      json_response = JSON.parse(page.body)
      
      expect(json_response).to have_key('contacts')
      expect(json_response['contacts']).to be_an(Array)
      expect(json_response['contacts'].length).to eq(2)
      
      first_contact = json_response['contacts'][0]
      expect(first_contact).to have_key('id')
      expect(first_contact).to have_key('name')
      expect(first_contact).to have_key('email')
      expect(first_contact).to have_key('telephone')
      expect(first_contact['name']).to eq('John Doe') # Should use full_name
      
      # Should not include internal fields
      expect(first_contact).not_to have_key('first_surname')
      expect(first_contact).not_to have_key('is_active')
    end

    scenario 'API endpoint handles company with no contacts' do
      allow(CompanyContactsService).to receive(:active_contacts).and_return([])

      page.driver.header 'Accept', 'application/json'
      visit "/api/v1/company_contacts?company_id=#{company[:id]}"

      json_response = JSON.parse(page.body)
      expect(json_response['contacts']).to eq([])
    end

    scenario 'API endpoint handles service errors gracefully' do
      allow(CompanyContactsService).to receive(:active_contacts)
        .and_raise(ApiService::ApiError.new('Company not found'))

      page.driver.header 'Accept', 'application/json'
      visit "/api/v1/company_contacts?company_id=#{company[:id]}"

      expect(page.status_code).to eq(422)
      json_response = JSON.parse(page.body)
      expect(json_response['error']).to eq('Company not found')
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
      allow(CompanyContactsService).to receive(:all).and_return([])
      allow(CompanyContactsService).to receive(:create)
        .and_raise(ApiService::ValidationError.new('Validation failed', { email: ['is invalid'] }))

      visit new_company_company_contact_path(company[:id])
      
      fill_in 'Name', with: 'John'
      fill_in 'Email', with: 'invalid-email'
      
      click_button 'Create Contact'
      
      expect(page).to have_current_path(company_company_contacts_path(company[:id]))
      expect(page).to have_content('Validation failed')
      
      # Form should be re-rendered with errors
      expect(page).to have_field('Name', with: 'John')
      expect(page).to have_field('Email', with: 'invalid-email')
    end

    scenario 'Company contacts service is unavailable' do
      allow(CompanyContactsService).to receive(:all)
        .and_raise(ApiService::ApiError.new('Service unavailable'))

      visit company_company_contacts_path(company[:id])
      
      expect(page).to have_current_path(companies_path)
      expect(page).to have_content('Service unavailable')
    end

    scenario 'Invoice form handles missing company contacts gracefully' do
      # Mock empty contacts for all companies
      allow(CompanyContactsService).to receive(:active_contacts).and_return([])

      visit new_invoice_path
      
      # Select buyer company
      select 'Test Company', from: 'Buyer Company'
      
      # Contact dropdown should not appear or should be empty
      expect(page).not_to have_select('Company Contact', with_options: ['John Doe'])
      
      # User should still be able to create invoice
      select 'Test Company', from: 'Seller Company'
      fill_in 'Invoice Number', with: 'INV-003'
      
      within('.invoice-lines') do
        fill_in 'Description', with: 'Test Product', match: :first
        fill_in 'Quantity', with: '1', match: :first
        fill_in 'Unit Price', with: '25.00', match: :first
      end
      
      allow(InvoiceService).to receive(:create).and_return({ data: { id: 458 } })
      
      click_button 'Create Invoice'
      expect(page).to have_content('Invoice created successfully')
    end

    scenario 'Contact activation/deactivation handles API errors' do
      allow(CompanyContactsService).to receive(:all).and_return([inactive_contact])
      allow(CompanyContactsService).to receive(:activate)
        .and_raise(ApiService::ApiError.new('Cannot activate contact'))

      visit company_company_contacts_path(company[:id])
      
      within('tr', text: 'Bob Johnson') do
        click_button 'Activate'
      end
      
      expect(page).to have_content('Cannot activate contact')
    end
  end
end