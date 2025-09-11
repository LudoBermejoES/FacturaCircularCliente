require 'rails_helper'

RSpec.describe TaxService do
  let(:token) { 'test_access_token' }
  
  describe '.rates' do
    let(:rates_response) do
      {
        rates: [
          { id: 1, name: 'Standard VAT', rate: 21.0, type: 'vat' },
          { id: 2, name: 'Reduced VAT', rate: 10.0, type: 'vat' }
        ]
      }
    end
    
    before do
      stub_request(:get, 'http://albaranes-api:3000/api/v1/tax/rates')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: rates_response.to_json)
    end
    
    it 'returns tax rates' do
      result = described_class.rates(token: token)
      expect(result).to eq(rates_response.deep_symbolize_keys)
    end
  end
  
  describe '.exemptions' do
    let(:exemptions_response) do
      {
        exemptions: [
          { id: 1, name: 'Export', description: 'Goods exported outside EU' },
          { id: 2, name: 'Education', description: 'Educational services' }
        ]
      }
    end
    
    before do
      stub_request(:get, 'http://albaranes-api:3000/api/v1/tax/exemptions')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: exemptions_response.to_json)
    end
    
    it 'returns tax exemptions' do
      result = described_class.exemptions(token: token)
      expect(result).to eq(exemptions_response.deep_symbolize_keys)
    end
  end
  
  describe '.calculate' do
    let(:invoice_id) { '1' }
    let(:calculation_response) do
      {
        invoice_id: invoice_id,
        base_amount: 1000.0,
        tax_amount: 210.0,
        total_amount: 1210.0,
        tax_breakdown: [
          { rate: 21.0, base: 1000.0, amount: 210.0 }
        ]
      }
    end
    
    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/tax/calculate/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: calculation_response.to_json)
    end
    
    it 'calculates tax for invoice' do
      result = described_class.calculate(invoice_id, token: token)
      expect(result).to eq(calculation_response.deep_symbolize_keys)
    end
  end
  
  describe '.validate' do
    let(:invoice_id) { '1' }
    let(:validation_response) do
      {
        invoice_id: invoice_id,
        valid: true,
        issues: [],
        compliance: {
          facturae: true,
          spanish_requirements: true
        }
      }
    end
    
    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/tax/validate/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: validation_response.to_json)
    end
    
    it 'validates tax for invoice' do
      result = described_class.validate(invoice_id, token: token)
      expect(result).to eq(validation_response.deep_symbolize_keys)
    end
  end
  
  describe '.recalculate' do
    let(:invoice_id) { '1' }
    let(:recalculation_response) do
      {
        invoice_id: invoice_id,
        base_amount: 1000.0,
        tax_amount: 210.0,
        total_amount: 1210.0,
        updated_at: '2024-01-01T12:00:00Z'
      }
    end
    
    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/tax/recalculate/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: recalculation_response.to_json)
    end
    
    it 'recalculates tax for invoice' do
      result = described_class.recalculate(invoice_id, token: token)
      expect(result).to eq(recalculation_response.deep_symbolize_keys)
    end
  end
end