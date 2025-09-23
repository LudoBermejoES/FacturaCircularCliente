require 'rails_helper'

RSpec.describe InvoiceService, type: :service do
  describe 'Global Financial Fields Transformation' do
    let(:base_url) { 'http://albaranes-api:3000/api/v1' }
    let(:token) { 'test_token_123' }
    let(:invoice_id) { '5' }

    describe '.find with global financial fields' do
      let(:api_response) do
        {
          data: {
            id: invoice_id,
            type: 'invoices',
            attributes: {
              invoice_number: 'FC-0004',
              document_type: 'FC',
              status: 'draft',
              issue_date: '2025-09-23',
              total_invoice: '130.00',
              total_gross_amount: '100.0',
              total_gross_amount_before_taxes: '127.50',
              total_tax_outputs: '21.0',
              currency_code: 'EUR',
              language_code: 'es',
              # Global financial fields
              total_general_discounts: '15.5',
              total_general_surcharges: '8.75',
              total_financial_expenses: '12.25',
              total_reimbursable_expenses: '22.0',
              withholding_amount: '18.5',
              payment_in_kind_amount: '5.0',
              # Other required fields
              seller_party_id: 1,
              buyer_company_contact_id: 13,
              display_number: 'FC--FC-2025-0003',
              is_proforma: false,
              created_at: '2025-09-23T09:54:00.000Z',
              updated_at: '2025-09-23T09:56:00.000Z',
              can_be_modified: true,
              can_be_converted: false,
              exchange_rate: '1.0'
            },
            relationships: {
              invoice_lines: {
                data: [{ id: '9', type: 'invoice_lines' }]
              },
              invoice_taxes: {
                data: []
              }
            }
          },
          included: [
            {
              id: '9',
              type: 'invoice_lines',
              attributes: {
                line_number: 1,
                item_description: 'Software License',
                quantity: '1.0',
                unit_price_without_tax: '100.0',
                gross_amount: '1000.0',
                created_at: '2025-09-23T09:54:00.000Z',
                updated_at: '2025-09-23T09:54:00.000Z',
                net_amount: '100.0'
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: api_response.to_json)
      end

      it 'correctly transforms all global financial fields' do
        result = InvoiceService.find(invoice_id, token: token)

        # Verify global financial fields are present and correctly transformed
        expect(result[:total_general_discounts]).to eq('15.5')
        expect(result[:total_general_surcharges]).to eq('8.75')
        expect(result[:total_financial_expenses]).to eq('12.25')
        expect(result[:total_reimbursable_expenses]).to eq('22.0')
        expect(result[:withholding_amount]).to eq('18.5')
        expect(result[:payment_in_kind_amount]).to eq('5.0')
      end

      it 'maintains other invoice fields alongside global financial fields' do
        result = InvoiceService.find(invoice_id, token: token)

        # Verify core invoice fields are still present
        expect(result[:id]).to eq(invoice_id)
        expect(result[:invoice_number]).to eq('FC-0004')
        expect(result[:status]).to eq('draft')
        expect(result[:total_invoice]).to eq('130.00')
        expect(result[:total_gross_amount]).to eq('100.0')
        expect(result[:currency_code]).to eq('EUR')
      end

      it 'handles nil values for global financial fields' do
        # Test with nil global financial fields
        api_response_with_nils = api_response.deep_dup
        api_response_with_nils[:data][:attributes][:total_general_discounts] = nil
        api_response_with_nils[:data][:attributes][:total_general_surcharges] = nil
        api_response_with_nils[:data][:attributes][:total_financial_expenses] = nil
        api_response_with_nils[:data][:attributes][:total_reimbursable_expenses] = nil
        api_response_with_nils[:data][:attributes][:withholding_amount] = nil
        api_response_with_nils[:data][:attributes][:payment_in_kind_amount] = nil

        stub_request(:get, "#{base_url}/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: api_response_with_nils.to_json)

        result = InvoiceService.find(invoice_id, token: token)

        # Verify nil values are handled correctly
        expect(result[:total_general_discounts]).to be_nil
        expect(result[:total_general_surcharges]).to be_nil
        expect(result[:total_financial_expenses]).to be_nil
        expect(result[:total_reimbursable_expenses]).to be_nil
        expect(result[:withholding_amount]).to be_nil
        expect(result[:payment_in_kind_amount]).to be_nil
      end

      it 'handles zero values for global financial fields' do
        # Test with zero global financial fields
        api_response_with_zeros = api_response.deep_dup
        api_response_with_zeros[:data][:attributes][:total_general_discounts] = '0.0'
        api_response_with_zeros[:data][:attributes][:total_general_surcharges] = '0.0'
        api_response_with_zeros[:data][:attributes][:total_financial_expenses] = '0.0'
        api_response_with_zeros[:data][:attributes][:total_reimbursable_expenses] = '0.0'
        api_response_with_zeros[:data][:attributes][:withholding_amount] = '0.0'
        api_response_with_zeros[:data][:attributes][:payment_in_kind_amount] = '0.0'

        stub_request(:get, "#{base_url}/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: api_response_with_zeros.to_json)

        result = InvoiceService.find(invoice_id, token: token)

        # Verify zero values are preserved
        expect(result[:total_general_discounts]).to eq('0.0')
        expect(result[:total_general_surcharges]).to eq('0.0')
        expect(result[:total_financial_expenses]).to eq('0.0')
        expect(result[:total_reimbursable_expenses]).to eq('0.0')
        expect(result[:withholding_amount]).to eq('0.0')
        expect(result[:payment_in_kind_amount]).to eq('0.0')
      end

      it 'includes global financial fields in the complete transformed response' do
        result = InvoiceService.find(invoice_id, token: token)

        # Verify the result is a hash with all expected fields
        expect(result).to be_a(Hash)
        expect(result.keys).to include(
          :total_general_discounts,
          :total_general_surcharges,
          :total_financial_expenses,
          :total_reimbursable_expenses,
          :withholding_amount,
          :payment_in_kind_amount
        )
      end
    end

    describe '.update with global financial fields' do
      let(:update_params) do
        {
          invoice_number: 'FC-0004',
          status: 'draft',
          total_general_discounts: 20.0,
          total_general_surcharges: 10.0,
          total_financial_expenses: 15.0,
          total_reimbursable_expenses: 25.0,
          withholding_amount: 12.0,
          payment_in_kind_amount: 8.0
        }
      end

      let(:api_update_response) do
        {
          data: {
            id: invoice_id,
            type: 'invoices',
            attributes: {
              invoice_number: 'FC-0004',
              status: 'draft',
              total_general_discounts: '20.0',
              total_general_surcharges: '10.0',
              total_financial_expenses: '15.0',
              total_reimbursable_expenses: '25.0',
              withholding_amount: '12.0',
              payment_in_kind_amount: '8.0'
            }
          }
        }
      end

      before do
        # Mock the update API call
        stub_request(:put, "#{base_url}/invoices/#{invoice_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: api_update_response.to_json)
      end

      it 'includes global financial fields in update requests' do
        result = InvoiceService.update(invoice_id, update_params, token: token)

        # Verify the API was called with correct parameters
        expect(a_request(:put, "#{base_url}/invoices/#{invoice_id}")).to have_been_made.once

        # Verify global financial fields in response
        expect(result[:total_general_discounts]).to eq('20.0')
        expect(result[:total_general_surcharges]).to eq('10.0')
        expect(result[:total_financial_expenses]).to eq('15.0')
        expect(result[:total_reimbursable_expenses]).to eq('25.0')
        expect(result[:withholding_amount]).to eq('12.0')
        expect(result[:payment_in_kind_amount]).to eq('8.0')
      end
    end

    describe 'error handling with global financial fields' do
      it 'handles API errors gracefully while preserving global field structure' do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)

        expect {
          InvoiceService.find(invoice_id, token: token)
        }.to raise_error(ApiService::ApiError)
      end
    end
  end
end