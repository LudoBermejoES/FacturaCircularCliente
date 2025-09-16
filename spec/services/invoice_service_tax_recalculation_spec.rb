require 'rails_helper'

RSpec.describe InvoiceService, '.create with tax recalculation' do
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
      # Mock the initial invoice creation (without line items)
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            invoice_type: 'standard',
            date: Date.current.to_s,
            due_date: 30.days.from_now.to_s
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
        .with(
          body: expected_body.to_json,
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 201, body: { data: { id: '10' } }.to_json)
    end
    
    context 'when line items are successfully added' do
      before do
        # Mock the line item creation
        expected_line_body = {
          data: {
            type: 'invoice_lines',
            attributes: {
              item_description: 'Web Development Service',
              unit_price_without_tax: 500,
              quantity: 1,
              tax_rate: 21,
              discount_percentage: 0,
              gross_amount: 500.0
            }
          }
        }
        
        stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices/10/lines')
          .with(
            body: expected_line_body.to_json,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 201, body: { id: 100, tax_amount: 105.0 }.to_json)
          
        # Mock the tax recalculation - this is the key part we're testing
        @tax_recalc_stub = stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices/10/taxes/recalculate')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: { 
            total_tax_outputs: 105.0,
            total_gross_amount_before_taxes: 500.0,
            total_invoice: 605.0 
          }.to_json)
      end
      
      it 'calls tax recalculation after adding line items' do
        described_class.create(invoice_params, token: token)
        
        # Verify that tax recalculation was called
        expect(@tax_recalc_stub).to have_been_requested.once
      end
      
      it 'creates invoice and processes line items correctly' do
        result = described_class.create(invoice_params, token: token)
        
        # Verify the invoice was created
        expect(result[:data][:id]).to eq('10')
        
        # Verify all expected API calls were made
        expect(a_request(:post, 'http://albaranes-api:3000/api/v1/invoices')).to have_been_made.once
        expect(a_request(:post, 'http://albaranes-api:3000/api/v1/invoices/10/lines')).to have_been_made.once
        expect(a_request(:post, 'http://albaranes-api:3000/api/v1/invoices/10/taxes/recalculate')).to have_been_made.once
      end
    end
    
    context 'when tax recalculation fails' do
      before do
        # Mock successful line item creation
        stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices/10/lines')
          .to_return(status: 201, body: { id: 100 }.to_json)
          
        # Mock tax recalculation failure
        stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices/10/taxes/recalculate')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Tax calculation failed' }.to_json)
      end
      
      it 'does not fail the entire invoice creation process' do
        expect {
          result = described_class.create(invoice_params, token: token)
          expect(result[:data][:id]).to eq('10')
        }.not_to raise_error
      end
      
      it 'logs the tax recalculation error' do
        allow(Rails.logger).to receive(:error)
        
        described_class.create(invoice_params, token: token)
        
        expect(Rails.logger).to have_received(:error).with(/Error recalculating taxes for invoice 10/)
      end
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
      
      it 'does not attempt to add line items or recalculate taxes' do
        result = described_class.create(invoice_params_without_lines, token: token)
        
        expect(result[:data][:id]).to eq('10')
        
        # Verify only the invoice creation call was made
        expect(a_request(:post, 'http://albaranes-api:3000/api/v1/invoices')).to have_been_made.once
        expect(a_request(:post, %r{/invoices/10/lines})).not_to have_been_made
        expect(a_request(:post, %r{/taxes/recalculate})).not_to have_been_made
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