require 'rails_helper'

RSpec.describe InvoiceService do
  let(:token) { 'test_access_token' }
  
  describe '.all' do
    context 'without filters' do
      let(:response_body) do
        {
          invoices: [
            { id: 1, invoice_number: 'INV-001', status: 'draft', total: 1210.00 },
            { id: 2, invoice_number: 'INV-002', status: 'sent', total: 550.00 }
          ],
          statistics: {
            total_count: 2,
            total_amount: 1760.00,
            status_counts: { draft: 1, sent: 1 }
          },
          total: 2,
          page: 1
        }
      end
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns all invoices' do
        result = described_class.all(token: token)
        expect(result).to eq(response_body.deep_symbolize_keys)
      end
    end
    
    context 'with filters' do
      let(:filters) { { status: 'draft', company_id: 1, page: 2 } }
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(
            query: filters,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)
      end
      
      it 'passes filters as query parameters' do
        described_class.all(token: token, filters: filters)
        expect(WebMock).to have_requested(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(query: filters)
      end
    end
  end
  
  describe '.find' do
    let(:invoice_id) { 1 }
    let(:response_body) do
      {
        id: 1,
        invoice_number: 'INV-001',
        status: 'draft',
        total: 1210.00,
        company: { id: 1, name: 'Test Company' },
        invoice_lines: [
          { description: 'Service', quantity: 10, unit_price: 100, tax_rate: 21 }
        ]
      }
    end
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_body.to_json)
    end
    
    it 'returns invoice details' do
      result = described_class.find(invoice_id, token: token)
      expect(result).to eq(response_body.deep_symbolize_keys)
    end
  end
  
  describe '.create' do
    let(:invoice_params) do
      {
        company_id: 1,
        invoice_type: 'standard',
        date: Date.current.to_s,
        due_date: 30.days.from_now.to_s,
        invoice_lines_attributes: [
          { description: 'Service', quantity: 10, unit_price: 100, tax_rate: 21 }
        ]
      }
    end
    
    let(:response_body) do
      {
        id: 1,
        invoice_number: 'INV-001',
        status: 'draft',
        total: 1210.00
      }
    end
    
    before do
      # Expected JSON API format
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            invoice_number: 'INV-001',
            status: 'draft',
            invoice_lines_attributes: [
              { description: 'Service', quantity: 10, unit_price: 100, tax_rate: 21 }
            ]
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
        .to_return(status: 201, body: response_body.to_json)
    end
    
    it 'creates invoice with line items' do
      result = described_class.create(invoice_params, token: token)
      expect(result).to eq(response_body.deep_symbolize_keys)
    end
  end
  
  describe '.update' do
    let(:invoice_id) { 1 }
    let(:update_params) { { status: 'sent' } }
    
    before do
      # Expected JSON API format
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            status: 'sent'
          }
        }
      }
      
      stub_request(:put, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}")
        .with(
          body: expected_body.to_json,
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 200, body: { id: invoice_id, status: 'sent' }.to_json)
    end
    
    it 'updates invoice' do
      result = described_class.update(invoice_id, update_params, token: token)
      expect(result).to eq({ id: invoice_id, status: 'sent' })
    end
  end
  
  describe '.delete' do
    let(:invoice_id) { 1 }
    
    before do
      stub_request(:delete, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '')
    end
    
    it 'deletes invoice' do
      result = described_class.delete(invoice_id, token: token)
      expect(result).to be_nil
    end
  end
  
  describe '.freeze' do
    let(:invoice_id) { 1 }
    
    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/freeze")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: { frozen: true, message: 'Invoice frozen' }.to_json)
    end
    
    it 'freezes the invoice' do
      result = described_class.freeze(invoice_id, token: token)
      expect(result).to eq({ frozen: true, message: 'Invoice frozen' })
    end
  end
  
  describe '.update_status' do
    let(:invoice_id) { 1 }
    let(:status) { 'approved' }
    let(:comment) { 'Looks good' }
    
    before do
      # Expected JSON API format
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            status: status,
            comment: comment
          }
        }
      }
      
      stub_request(:patch, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/status")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: expected_body.to_json
        )
        .to_return(status: 200, body: { id: invoice_id, status: status }.to_json)
    end
    
    it 'updates invoice status with comment' do
      result = described_class.update_status(invoice_id, status, comment: comment, token: token)
      expect(result[:status]).to eq(status)
    end
  end
  
  describe '.download_facturae' do
    let(:invoice_id) { 1 }
    let(:xml_content) { '<?xml version="1.0"?><Facturae></Facturae>' }
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/facturae")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: xml_content, headers: { 'Content-Type' => 'application/xml' })
    end
    
    it 'returns Facturae XML content' do
      result = described_class.download_facturae(invoice_id, token: token)
      expect(result).to eq(xml_content)
    end
  end

  describe 'line items management' do
    let(:invoice_id) { 1 }

    describe '.add_line_item' do
      let(:line_params) do
        {
          description: 'New Service',
          quantity: 5,
          unit_price: 100.0,
          tax_rate: 21
        }
      end

      before do
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/lines")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { invoice_line: line_params }.to_json
          )
          .to_return(status: 201, body: { id: 10 }.to_json)
      end

      it 'creates new line item' do
        result = described_class.add_line_item(invoice_id, line_params, token: token)
        expect(result[:id]).to eq(10)
      end
    end

    describe '.update_line_item' do
      let(:line_id) { 5 }
      let(:update_params) { { quantity: 10 } }

      before do
        stub_request(:put, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/lines/#{line_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { invoice_line: update_params }.to_json
          )
          .to_return(status: 200, body: { id: line_id, quantity: 10 }.to_json)
      end

      it 'updates line item' do
        result = described_class.update_line_item(invoice_id, line_id, update_params, token: token)
        expect(result[:quantity]).to eq(10)
      end
    end

    describe '.remove_line_item' do
      let(:line_id) { 5 }

      before do
        stub_request(:delete, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/lines/#{line_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'removes line item' do
        result = described_class.remove_line_item(invoice_id, line_id, token: token)
        expect(result).to be_nil
      end
    end
  end

  describe '.recent' do
    let(:recent_response) do
      {
        invoices: [
          { id: 1, invoice_number: 'INV-001', status: 'sent' },
          { id: 2, invoice_number: 'INV-002', status: 'draft' }
        ]
      }
    end

    context 'when successful' do
      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices")
          .with(query: { limit: 5, status: 'recent' })
          .to_return(status: 200, body: recent_response.to_json)
      end

      it 'returns recent invoices array' do
        result = described_class.recent(token: token)
        expect(result).to eq(recent_response[:invoices])
      end
    end

    context 'when response is nil' do
      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices")
          .with(
            query: { limit: 5, status: 'recent' },
            headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' }
          )
          .to_return(status: 204, body: '')
      end

      it 'returns empty array' do
        result = described_class.recent(token: token)
        expect(result).to eq([])
      end
    end
  end
end