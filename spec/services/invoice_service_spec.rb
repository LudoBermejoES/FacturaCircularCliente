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
        stub_request(:get, 'http://localhost:3001/api/v1/invoices')
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
        stub_request(:get, 'http://localhost:3001/api/v1/invoices')
          .with(
            query: filters,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)
      end
      
      it 'passes filters as query parameters' do
        described_class.all(token: token, filters: filters)
        expect(WebMock).to have_requested(:get, 'http://localhost:3001/api/v1/invoices')
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
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice_id}")
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
      stub_request(:post, 'http://localhost:3001/api/v1/invoices')
        .with(
          body: invoice_params.to_json,
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
      stub_request(:put, "http://localhost:3001/api/v1/invoices/#{invoice_id}")
        .with(
          body: update_params.to_json,
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
      stub_request(:delete, "http://localhost:3001/api/v1/invoices/#{invoice_id}")
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
      stub_request(:post, "http://localhost:3001/api/v1/invoices/#{invoice_id}/freeze")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: { frozen: true, message: 'Invoice frozen' }.to_json)
    end
    
    it 'freezes the invoice' do
      result = described_class.freeze(invoice_id, token: token)
      expect(result).to eq({ frozen: true, message: 'Invoice frozen' })
    end
  end
  
  describe '.send_email' do
    let(:invoice_id) { 1 }
    let(:recipient_email) { 'client@example.com' }
    
    before do
      stub_request(:post, "http://localhost:3001/api/v1/invoices/#{invoice_id}/send_email")
        .with(body: { recipient_email: recipient_email }.to_json)
        .to_return(status: 200, body: { sent: true, message: 'Email sent' }.to_json)
    end
    
    it 'sends invoice email' do
      result = described_class.send_email(invoice_id, recipient_email, token: token)
      expect(result).to eq({ sent: true, message: 'Email sent' })
    end
  end
  
  describe '.download_pdf' do
    let(:invoice_id) { 1 }
    let(:pdf_content) { '%PDF-1.4 fake pdf content' }
    
    before do
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice_id}/pdf")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: pdf_content, headers: { 'Content-Type' => 'application/pdf' })
    end
    
    it 'returns PDF content' do
      result = described_class.download_pdf(invoice_id, token: token)
      expect(result).to eq(pdf_content)
    end
  end
  
  describe '.download_facturae' do
    let(:invoice_id) { 1 }
    let(:xml_content) { '<?xml version="1.0"?><Facturae></Facturae>' }
    
    before do
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice_id}/facturae")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: xml_content, headers: { 'Content-Type' => 'application/xml' })
    end
    
    it 'returns Facturae XML content' do
      result = described_class.download_facturae(invoice_id, token: token)
      expect(result).to eq(xml_content)
    end
  end
end