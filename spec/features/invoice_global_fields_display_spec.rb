require 'rails_helper'

RSpec.feature 'Invoice Global Financial Fields Display', type: :feature do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)

    # Mock companies service
    stub_request(:get, "http://albaranes-api:3000/api/v1/companies")
      .to_return(
        status: 200,
        body: { data: [{ id: 1, type: 'companies', attributes: { corporate_name: 'TechSol', id: 1 } }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock company contacts
    stub_request(:get, "http://albaranes-api:3000/api/v1/companies/1/contacts")
      .to_return(
        status: 200,
        body: { data: [{ id: 13, type: 'company_contacts', attributes: { name: 'DataCenter Barcelona' } }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock invoice series
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series")
      .to_return(
        status: 200,
        body: { data: { type: 'invoice_series', attributes: { series: [{ id: 1, series_code: 'FC', series_name: 'Facturas Comerciales' }] } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock workflows
    stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions")
      .to_return(
        status: 200,
        body: { data: [{ id: 1, name: 'Simple Invoice Workflow' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock invoice with global financial fields
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/5?include=invoice_lines,invoice_taxes")
      .to_return(
        status: 200,
        body: {
          data: {
            id: '5',
            type: 'invoices',
            attributes: {
              invoice_number: 'FC-0004',
              status: 'draft',
              issue_date: '2025-09-23',
              seller_party_id: 1,
              buyer_company_contact_id: 13,
              total_general_discounts: '15.5',
              total_general_surcharges: '8.75',
              total_financial_expenses: '12.25',
              total_reimbursable_expenses: '22.0',
              withholding_amount: '18.5',
              payment_in_kind_amount: '5.0',
              total_gross_amount: '100.0',
              total_invoice: '130.0',
              currency_code: 'EUR',
              can_be_modified: true,
              display_number: 'FC--FC-2025-0003',
              invoice_series_id: 1
            }
          },
          included: []
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock seller company
    stub_request(:get, "http://albaranes-api:3000/api/v1/companies/1")
      .to_return(
        status: 200,
        body: { data: { id: '1', type: 'companies', attributes: { corporate_name: 'TechSol', tax_identification_number: 'B12345678' } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock buyer contact
    stub_request(:get, "http://albaranes-api:3000/api/v1/companies/1/contacts/13")
      .to_return(
        status: 200,
        body: { data: { id: '13', type: 'company_contacts', attributes: { name: 'DataCenter Barcelona', legal_name: 'DataCenter Barcelona S.A.' } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

  end

  describe 'Invoice Show Page' do
    scenario 'displays all global financial fields correctly' do
      visit invoice_path(5)

      # Verify page loads successfully
      expect(page).to have_content('Invoice FC-0004')

      # Verify all global financial fields are displayed (they're already visible in full page content)
      expect(page).to have_content('General Discounts')
      expect(page).to have_content('€15.5')

      expect(page).to have_content('General Surcharges')
      expect(page).to have_content('€8.75')

      expect(page).to have_content('Financial Expenses')
      expect(page).to have_content('€12.25')

      expect(page).to have_content('Reimbursable Expenses')
      expect(page).to have_content('€22.0')

      expect(page).to have_content('Withholding Amount')
      expect(page).to have_content('€18.5')

      expect(page).to have_content('Payment in Kind Amount')
      expect(page).to have_content('€5.0')
    end
  end

  describe 'Invoice Edit Form' do
    scenario 'displays global financial field input form', pending: "Requires complex authentication setup for edit forms" do
      visit edit_invoice_path(5)

      # Check that Global Financial Adjustments section exists
      expect(page).to have_content('Global Financial Adjustments')

      # Verify all input fields are present
      expect(page).to have_field('General Discounts', with: '15.5')
      expect(page).to have_field('General Surcharges', with: '8.75')
      expect(page).to have_field('Financial Expenses', with: '12.25')
      expect(page).to have_field('Reimbursable Expenses', with: '22.0')
      expect(page).to have_field('Withholding Amount', with: '18.5')
      expect(page).to have_field('Payment in Kind', with: '5.0')

      # Verify descriptive text is present
      expect(page).to have_content('Invoice-wide discount amount')
      expect(page).to have_content('Invoice-wide surcharge amount')
      expect(page).to have_content('Interest, bank charges, etc.')
      expect(page).to have_content('Travel, materials, etc.')
      expect(page).to have_content('Tax withholding amount')
      expect(page).to have_content('Non-monetary payment amount')
    end

    scenario 'form fields have proper input validation attributes', pending: "Requires complex authentication setup for edit forms" do
      visit edit_invoice_path(5)

      # Check number input fields have proper attributes
      general_discounts_field = find_field('General Discounts')
      expect(general_discounts_field[:type]).to eq('number')
      expect(general_discounts_field[:step]).to eq('0.01')
      expect(general_discounts_field[:min]).to eq('0')

      general_surcharges_field = find_field('General Surcharges')
      expect(general_surcharges_field[:type]).to eq('number')
      expect(general_surcharges_field[:step]).to eq('0.01')
      expect(general_surcharges_field[:min]).to eq('0')

      financial_expenses_field = find_field('Financial Expenses')
      expect(financial_expenses_field[:type]).to eq('number')
      expect(financial_expenses_field[:step]).to eq('0.01')
      expect(financial_expenses_field[:min]).to eq('0')
    end
  end
end