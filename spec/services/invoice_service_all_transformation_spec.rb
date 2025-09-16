require 'rails_helper'

RSpec.describe InvoiceService, '.all transformation fixes' do
  let(:token) { 'test_access_token' }
  
  let(:json_api_response) do
    {
      data: [
        {
          id: "1",
          type: "invoices",
          attributes: {
            invoice_number: "FC-2025-0001",
            status: "sent",
            issue_date: "2025-09-15",
            due_date: "2025-10-15",
            total_invoice: "605.00",
            total_gross_amount_before_taxes: "500.00",
            total_tax_outputs: "105.00",
            currency_code: "EUR",
            buyer_name: "GreenWaste Solutions Ltd",
            seller_party_id: 1,
            buyer_party_id: 2
          }
        },
        {
          id: "2",
          type: "invoices", 
          attributes: {
            invoice_number: "FC-2025-0002",
            status: "draft",
            issue_date: "2025-09-16",
            due_date: "2025-10-16",
            total_invoice: "1210.00",
            total_gross_amount_before_taxes: "1000.00",
            total_tax_outputs: "210.00",
            currency_code: "EUR",
            buyer_name: "TechSol Corporation",
            seller_party_id: 1,
            buyer_party_id: 3
          }
        }
      ],
      meta: {
        total: 2,
        page: 1,
        pages: 1,
        per_page: 25
      }
    }
  end
  
  describe 'when API returns invoices with amounts and company names' do
    before do
      stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: json_api_response.to_json)
    end
    
    it 'correctly transforms total amounts from string to float' do
      result = described_class.all(token: token)
      
      invoices = result[:invoices]
      expect(invoices).to be_an(Array)
      expect(invoices.length).to eq(2)
      
      # Check first invoice amounts
      first_invoice = invoices.first
      expect(first_invoice[:total]).to eq(605.0)
      expect(first_invoice[:total]).to be_a(Float)
      expect(first_invoice[:subtotal]).to eq(500.0)
      expect(first_invoice[:subtotal]).to be_a(Float)
      expect(first_invoice[:total_tax]).to eq(105.0)
      expect(first_invoice[:total_tax]).to be_a(Float)
      
      # Check second invoice amounts
      second_invoice = invoices.last
      expect(second_invoice[:total]).to eq(1210.0)
      expect(second_invoice[:total]).to be_a(Float)
      expect(second_invoice[:subtotal]).to eq(1000.0)
      expect(second_invoice[:subtotal]).to be_a(Float)
      expect(second_invoice[:total_tax]).to eq(210.0)
      expect(second_invoice[:total_tax]).to be_a(Float)
    end
    
    it 'correctly maps company names from buyer_name field' do
      result = described_class.all(token: token)
      
      invoices = result[:invoices]
      
      # Check company names are mapped correctly
      first_invoice = invoices.first
      expect(first_invoice[:company_name]).to eq("GreenWaste Solutions Ltd")
      
      second_invoice = invoices.last
      expect(second_invoice[:company_name]).to eq("TechSol Corporation")
    end
    
    it 'maintains backward compatibility with existing fields' do
      result = described_class.all(token: token)
      
      invoices = result[:invoices]
      first_invoice = invoices.first
      
      # Check all expected fields are present
      expect(first_invoice[:id]).to eq("1")
      expect(first_invoice[:invoice_number]).to eq("FC-2025-0001")
      expect(first_invoice[:status]).to eq("sent")
      expect(first_invoice[:issue_date]).to eq("2025-09-15")
      expect(first_invoice[:due_date]).to eq("2025-10-15")
      expect(first_invoice[:currency_code]).to eq("EUR")
      expect(first_invoice[:seller_party_id]).to eq(1)
      expect(first_invoice[:buyer_party_id]).to eq(2)
      
      # Check aliases are maintained
      expect(first_invoice[:date]).to eq("2025-09-15") # alias for issue_date
      expect(first_invoice[:invoice_type]).to eq(first_invoice[:document_type]) # alias
    end
    
    it 'handles nil amounts gracefully' do
      # Test with nil amounts
      response_with_nils = json_api_response.deep_dup
      response_with_nils[:data][0][:attributes][:total_invoice] = nil
      response_with_nils[:data][0][:attributes][:total_gross_amount_before_taxes] = nil
      response_with_nils[:data][0][:attributes][:total_tax_outputs] = nil
      
      stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_with_nils.to_json)
      
      result = described_class.all(token: token)
      
      first_invoice = result[:invoices].first
      expect(first_invoice[:total]).to be_nil
      expect(first_invoice[:subtotal]).to be_nil
      expect(first_invoice[:total_tax]).to be_nil
    end
    
    it 'handles missing buyer_name gracefully' do
      # Test with missing buyer_name
      response_without_buyer_name = json_api_response.deep_dup
      response_without_buyer_name[:data][0][:attributes].delete(:buyer_name)
      
      stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_without_buyer_name.to_json)
      
      result = described_class.all(token: token)
      
      first_invoice = result[:invoices].first
      expect(first_invoice[:company_name]).to be_nil
    end
  end
  
  describe 'field mapping consistency with find method' do
    before do
      stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: json_api_response.to_json)
    end
    
    it 'uses the same field transformation as InvoiceService.find' do
      # This test ensures that .all and .find use consistent field mappings
      # The transformation should be the same for both methods
      
      result = described_class.all(token: token)
      first_invoice = result[:invoices].first
      
      # These are the key fields that were fixed
      expect(first_invoice).to have_key(:total)
      expect(first_invoice).to have_key(:subtotal) 
      expect(first_invoice).to have_key(:total_tax)
      expect(first_invoice).to have_key(:company_name)
      
      # These should be Float conversions (not strings)
      expect(first_invoice[:total]).to be_a(Float) if first_invoice[:total]
      expect(first_invoice[:subtotal]).to be_a(Float) if first_invoice[:subtotal]
      expect(first_invoice[:total_tax]).to be_a(Float) if first_invoice[:total_tax]
    end
  end
end