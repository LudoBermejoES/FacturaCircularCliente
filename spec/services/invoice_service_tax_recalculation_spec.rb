require 'rails_helper'

RSpec.describe InvoiceService, '.create with backend handling' do
  let(:token) { 'test_access_token' }

  describe 'when creating invoice with line items' do
    let(:invoice_params) do
      {
        invoice_type: 'standard',
        date: Date.current.to_s,
        due_date: 30.days.from_now.to_s,
        seller_party_id: 1,
        buyer_party_id: 2,
        invoice_lines_attributes: [
          {
            description: 'Web Development Service',
            quantity: 1,
            unit_price: 500,
            tax_rate: 21,
            discount_percentage: 0
          }
        ]
      }
    end

    before do
      # Mock the invoice creation (backend handles line items and tax calculation automatically)
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            invoice_type: 'standard',
            date: Date.current.to_s,
            due_date: 30.days.from_now.to_s,
            invoice_lines: {
              '0' => {
                description: 'Web Development Service',
                quantity: '1',
                unit_price: '500',
                tax_rate: '21',
                discount_percentage: '0'
              }
            }
          },
          relationships: {
            seller_party: {
              data: { type: 'companies', id: '1' }
            },
            buyer_party: {
              data: { type: 'companies', id: '2' }
            }
          }
        }
      }

      stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
        .to_return(status: 201, body: { data: { id: '10' } }.to_json)
    end

    it 'creates invoice with line items handled by backend' do
      result = described_class.create(invoice_params, token: token)

      # Verify the invoice was created
      expect(result[:data][:id]).to eq('10')

      # Verify only the invoice creation API call was made (backend handles line items)
      expect(a_request(:post, 'http://albaranes-api:3000/api/v1/invoices')).to have_been_made.once
    end

    context 'when no line items are provided' do
      let(:invoice_params_without_lines) do
        {
          invoice_type: 'standard',
          date: Date.current.to_s,
          due_date: 30.days.from_now.to_s,
          seller_party_id: 1,
          buyer_party_id: 2
        }
      end

      it 'creates invoice without line items' do
        result = described_class.create(invoice_params_without_lines, token: token)

        expect(result[:data][:id]).to eq('10')

        # Verify only the invoice creation call was made
        expect(a_request(:post, 'http://albaranes-api:3000/api/v1/invoices')).to have_been_made.once
      end
    end
  end

  describe '.recalculate_taxes' do
    let(:invoice_id) { '123' }

    context 'when successful' do
      before do
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/taxes/recalculate")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: {
            total_tax_outputs: 105.0,
            total_gross_amount_before_taxes: 500.0,
            total_invoice: 605.0
          }.to_json)
      end

      it 'successfully recalculates taxes' do
        result = described_class.recalculate_taxes(invoice_id, token: token)
        expect(result).not_to be_nil
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/taxes/recalculate")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 422, body: { error: 'Tax calculation failed' }.to_json)
      end

      it 'handles errors gracefully and returns nil' do
        allow(Rails.logger).to receive(:error)

        result = described_class.recalculate_taxes(invoice_id, token: token)

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(/Error recalculating taxes for invoice #{invoice_id}/)
      end
    end
  end
end