require 'rails_helper'

RSpec.describe InvoiceService, '.find' do
  let(:token) { 'test_access_token' }
  let(:invoice_id) { '4' }
  
  let(:api_response) do
    {
      data: {
        id: "4",
        type: "invoices",
        attributes: {
          invoice_number: "FC-2025-0002",
          invoice_series_code: "FC",
          document_type: "FC",
          status: "draft",
          issue_date: "2025-09-15",
          due_date: "2025-10-15",
          total_invoice: "121.00",
          total_gross_amount_before_taxes: "100.00",
          total_tax_outputs: "21.00",
          currency_code: "EUR",
          language_code: "es",
          is_frozen: false,
          display_number: "FC-FC-2025-0002",
          is_proforma: false,
          can_be_modified: true,
          can_be_converted: false,
          seller_party_id: "1",
          buyer_party_id: "1",
          notes: "Test notes",
          internal_notes: "Internal notes",
          payment_terms: "30",
          payment_method: "transfer",
          created_at: "2025-09-15T10:00:00.000Z",
          updated_at: "2025-09-15T10:00:00.000Z"
        }
      }
    }
  end

  before do
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'transforms API response to expected format for views' do
    result = described_class.find(invoice_id, token: token)
    
    # Verify basic fields
    expect(result[:id]).to eq("4")
    expect(result[:invoice_number]).to eq("FC-2025-0002")
    expect(result[:status]).to eq("draft")
    
    # Verify field mappings for view compatibility
    expect(result[:invoice_type]).to eq("FC")  # mapped from document_type
    expect(result[:date]).to eq("2025-09-15")  # mapped from issue_date
    expect(result[:issue_date]).to eq("2025-09-15")  # alias
    expect(result[:due_date]).to eq("2025-10-15")
    
    # Verify amount fields for view display
    expect(result[:total_invoice]).to eq("121.00")
    expect(result[:total]).to eq(121.00)  # converted to float for view
    expect(result[:subtotal]).to eq(100.00)  # from total_gross_amount_before_taxes
    expect(result[:total_tax]).to eq(21.00)  # from total_tax_outputs
    
    # Verify additional fields
    expect(result[:is_frozen]).to eq(false)
    expect(result[:notes]).to eq("Test notes")
    expect(result[:internal_notes]).to eq("Internal notes")
    expect(result[:payment_terms]).to eq("30")
    expect(result[:payment_method]).to eq("transfer")
    
    # Verify invoice_lines default (empty array when no included data)
    expect(result[:invoice_lines]).to eq([])
  end

  it 'handles response with included invoice lines' do
    api_response_with_lines = api_response.dup
    api_response_with_lines[:included] = [
      {
        id: "1",
        type: "invoice_lines",
        attributes: {
          item_description: "Test Service",
          quantity: 1.0,
          unit_price_without_tax: 100.0,
          tax_rate: 21.0,
          discount_rate: 0.0,
          gross_amount: 100.0
        }
      }
    ]
    
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: api_response_with_lines.to_json, headers: { 'Content-Type' => 'application/json' })
    
    result = described_class.find(invoice_id, token: token)
    
    expect(result[:invoice_lines]).to be_an(Array)
    expect(result[:invoice_lines].length).to eq(1)
    
    line = result[:invoice_lines].first
    expect(line[:id]).to eq("1")
    expect(line[:description]).to eq("Test Service")
    expect(line[:quantity]).to eq(1.0)
    expect(line[:unit_price]).to eq(100.0)
    expect(line[:total]).to eq(100.0)
  end
end