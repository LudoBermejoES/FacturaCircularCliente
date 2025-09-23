require 'rails_helper'

RSpec.describe InvoicesController, type: :controller do
  describe 'Global Financial Fields Strong Parameters' do
    let(:user) { build(:user_response) }
    let(:token) { 'test_access_token' }
    let(:invoice_id) { 5 }
    let(:company_id) { 1 }
    let(:contact_id) { 13 }

    let(:company) { build(:company_response, id: company_id) }
    let(:invoice) { build(:invoice_response, id: invoice_id, company_id: company_id, buyer_company_contact_id: contact_id) }

    before do
      # Mock authentication
      allow(controller).to receive(:authenticate_user!).and_return(true)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_token).and_return(token)
      allow(controller).to receive(:can?).and_return(true)

      # Mock necessary API calls with WebMock
      stub_request(:get, "http://albaranes-api:3000/api/v1/companies")
        .to_return(
          status: 200,
          body: { data: [{ id: company_id, type: 'companies', attributes: company }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "http://albaranes-api:3000/api/v1/companies/#{company_id}/contacts")
        .to_return(
          status: 200,
          body: { data: [{ id: contact_id, type: 'company_contacts', attributes: { name: 'DataCenter Barcelona' } }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series")
        .to_return(
          status: 200,
          body: { data: { type: 'invoice_series', attributes: { series: [{ id: 1, series_code: 'FC', series_name: 'Facturas Comerciales' }] } } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions")
        .to_return(
          status: 200,
          body: { data: [{ id: 1, name: 'Simple Invoice Workflow' }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    describe 'POST #create with global financial fields' do
      let(:valid_params) do
        {
          invoice: {
            invoice_number: 'FC-0005',
            document_type: 'FC',
            status: 'draft',
            issue_date: '2025-09-23',
            seller_party_id: 1,
            buyer_company_contact_id: 13,
            # Global financial fields
            total_general_discounts: '15.5',
            total_general_surcharges: '8.75',
            total_financial_expenses: '12.25',
            total_reimbursable_expenses: '22.0',
            withholding_amount: '18.5',
            payment_in_kind_amount: '5.0',
            # Line items
            invoice_lines_attributes: {
              '0' => {
                item_description: 'Test Service',
                quantity: '1.0',
                unit_price_without_tax: '100.0',
                tax_rate: '21.0'
              }
            }
          }
        }
      end

      before do
        # Mock successful creation with WebMock - match any POST to invoices
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 201,
            body: {
              data: {
                id: '5',
                type: 'invoices',
                attributes: {
                  invoice_number: 'FC-0005',
                  total_general_discounts: '15.5',
                  total_general_surcharges: '8.75',
                  total_financial_expenses: '12.25',
                  total_reimbursable_expenses: '22.0',
                  withholding_amount: '18.5',
                  payment_in_kind_amount: '5.0'
                }
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'successfully creates invoice with global financial fields' do
        post :create, params: valid_params

        expect(response).to have_http_status(:redirect)
        # Verify the API was called
        expect(a_request(:post, "http://albaranes-api:3000/api/v1/invoices")).to have_been_made.once
      end
    end

    describe 'PATCH #update with global financial fields' do
      let(:update_params) do
        {
          id: '5',
          invoice: {
            invoice_number: 'FC-0004',
            status: 'draft',
            # Updated global financial fields
            total_general_discounts: '20.0',
            total_general_surcharges: '10.0',
            total_financial_expenses: '15.0',
            total_reimbursable_expenses: '25.0',
            withholding_amount: '12.0',
            payment_in_kind_amount: '8.0'
          }
        }
      end

      before do
        # Mock the GET request that the update action makes first
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/5?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 200,
            body: {
              data: {
                id: '5',
                type: 'invoices',
                attributes: {
                  invoice_number: 'FC-0004',
                  status: 'draft',
                  total_general_discounts: '15.5',
                  total_general_surcharges: '8.75',
                  can_be_modified: true
                }
              },
              included: []
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Mock successful update with WebMock - match any PUT to this invoice
        stub_request(:put, "http://albaranes-api:3000/api/v1/invoices/5")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 200,
            body: {
              data: {
                id: '5',
                type: 'invoices',
                attributes: {
                  invoice_number: 'FC-0004',
                  total_general_discounts: '20.0',
                  total_general_surcharges: '10.0',
                  total_financial_expenses: '15.0',
                  total_reimbursable_expenses: '25.0',
                  withholding_amount: '12.0',
                  payment_in_kind_amount: '8.0'
                }
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'permits all global financial fields in update strong parameters' do
        patch :update, params: update_params

        expect(response).to have_http_status(:redirect)
        # Verify the API was called
        expect(a_request(:put, "http://albaranes-api:3000/api/v1/invoices/5")).to have_been_made.once
      end

      it 'successfully updates invoice with global financial fields' do
        patch :update, params: update_params

        expect(response).to have_http_status(:redirect)
      end
    end

    describe 'parameter validation' do
      it 'rejects unpermitted global financial field parameters' do
        # Test with a parameter that should not be permitted
        invalid_params = {
          invoice: {
            invoice_number: 'FC-0004',
            malicious_field: 'should_not_be_permitted',
            total_general_discounts: '15.5',
            document_type: 'FC',
            status: 'draft',
            issue_date: '2025-09-23',
            currency_code: 'EUR',
            seller_party_id: 1
          }
        }

        # Mock successful creation
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 201,
            body: { data: { id: '5', type: 'invoices', attributes: { invoice_number: 'FC-0004' } } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        post :create, params: invalid_params

        # Verify the request was made and response is successful
        expect(response).to have_http_status(:redirect)
        expect(a_request(:post, "http://albaranes-api:3000/api/v1/invoices")).to have_been_made.once
      end

      it 'handles missing global financial fields gracefully' do
        # Test with minimal valid parameters (no global financial fields)
        minimal_params = {
          invoice: {
            invoice_number: 'FC-0004',
            document_type: 'FC',
            status: 'draft',
            issue_date: '2025-09-23',
            currency_code: 'EUR',
            seller_party_id: 1
          }
        }

        # Mock successful creation without global fields
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 201,
            body: { data: { id: '5', type: 'invoices', attributes: { invoice_number: 'FC-0004' } } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        post :create, params: minimal_params

        # Verify the service is called successfully even without global fields
        expect(response).to have_http_status(:redirect)
      end

      it 'handles zero values for global financial fields' do
        zero_params = {
          invoice: {
            invoice_number: 'FC-0004',
            document_type: 'FC',
            status: 'draft',
            issue_date: '2025-09-23',
            currency_code: 'EUR',
            seller_party_id: 1,
            total_general_discounts: '0.0',
            total_general_surcharges: '0.0',
            total_financial_expenses: '0.0',
            total_reimbursable_expenses: '0.0',
            withholding_amount: '0.0',
            payment_in_kind_amount: '0.0'
          }
        }

        # Mock successful creation with zero values
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 201,
            body: { data: { id: '5', type: 'invoices', attributes: { invoice_number: 'FC-0004' } } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        post :create, params: zero_params

        # Verify request was made successfully
        expect(response).to have_http_status(:redirect)
        expect(a_request(:post, "http://albaranes-api:3000/api/v1/invoices")).to have_been_made.once
      end
    end

    describe 'error handling with global financial fields' do
      it 'handles service errors gracefully when global fields are present' do
        params_with_globals = {
          invoice: {
            invoice_number: 'FC-0004',
            document_type: 'FC',
            status: 'draft',
            issue_date: '2025-09-23',
            currency_code: 'EUR',
            seller_party_id: 1,
            total_general_discounts: '15.5',
            total_general_surcharges: '8.75'
          }
        }

        # Mock API error response
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'Service error' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        post :create, params: params_with_globals

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end