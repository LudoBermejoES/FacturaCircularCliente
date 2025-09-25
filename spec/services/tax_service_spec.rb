require 'rails_helper'

RSpec.describe TaxService do
  let(:token) { 'test_access_token' }
  let(:base_url) { 'http://albaranes-api:3000/api/v1/tax' }

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
      stub_request(:get, "#{base_url}/rates")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: rates_response.to_json)
    end

    it 'returns tax rates' do
      result = described_class.rates(token: token)
      expect(result).to eq(rates_response[:rates])
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
      stub_request(:get, "#{base_url}/exemptions")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: exemptions_response.to_json)
    end
    
    it 'returns tax exemptions' do
      result = described_class.exemptions(token: token)
      expect(result).to eq(exemptions_response[:exemptions])
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
      stub_request(:post, "#{base_url}/calculate/#{invoice_id}")
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
      stub_request(:post, "#{base_url}/validate/#{invoice_id}")
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
      stub_request(:post, "#{base_url}/recalculate/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: recalculation_response.to_json)
    end
    
    it 'recalculates tax for invoice' do
      result = described_class.recalculate(invoice_id, token: token)
      expect(result).to eq(recalculation_response.deep_symbolize_keys)
    end
  end

  # New multi-jurisdiction tax methods
  describe '.resolve_tax_context' do
    let(:establishment_id) { '1' }
    let(:buyer_location) { { country: 'FRA', city: 'Paris' } }
    let(:product_types) { ['goods', 'services'] }

    context 'successful tax context resolution' do
      let(:tax_context_response) do
        {
          data: {
            establishment: {
              id: 1,
              name: 'Madrid Office',
              tax_jurisdiction: {
                code: 'ESP',
                country_name: 'Spain'
              }
            },
            buyer_location: buyer_location,
            tax_context: {
              cross_border: true,
              eu_transaction: true,
              reverse_charge: false,
              applicable_rates: [
                { name: 'Standard VAT', rate: 21.0, applies_to: ['goods', 'services'] }
              ]
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/resolve_context")
          .with(
            body: {
              establishment_id: establishment_id,
              buyer_location: buyer_location,
              product_types: product_types
            }.to_json,
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: tax_context_response.to_json)
      end

      it 'resolves tax context successfully' do
        result = described_class.resolve_tax_context(
          establishment_id: establishment_id,
          buyer_location: buyer_location,
          product_types: product_types,
          token: token
        )

        expect(result).to include(
          establishment: hash_including(
            id: 1,
            name: 'Madrid Office'
          ),
          tax_context: hash_including(
            cross_border: true,
            eu_transaction: true,
            reverse_charge: false
          )
        )
      end
    end

    context 'minimal parameters' do
      let(:minimal_response) do
        {
          data: {
            establishment: nil,
            tax_jurisdiction: nil,
            applicable_rates: [],
            cross_border: false,
            reverse_charge: false
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/resolve_context")
          .with(
            body: {
              establishment_id: nil,
              buyer_location: nil,
              product_types: []
            }.to_json,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: minimal_response.to_json)
      end

      it 'handles minimal parameters' do
        result = described_class.resolve_tax_context(token: token)

        expect(result).to include(
          establishment: nil,
          tax_jurisdiction: nil,
          applicable_rates: [],
          cross_border: false,
          reverse_charge: false
        )
      end
    end

    context 'authentication error' do
      before do
        stub_request(:post, "#{base_url}/resolve_context")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises authentication error' do
        expect { described_class.resolve_tax_context(token: token) }.to raise_error(ApiService::AuthenticationError)
      end
    end
  end

  describe '.calculate_invoice_tax' do
    let(:invoice_id) { '123' }

    context 'successful calculation' do
      let(:invoice_tax_response) do
        {
          data: {
            invoice_id: invoice_id,
            tax_context: {
              establishment_id: 1,
              cross_border: false,
              eu_transaction: false
            },
            tax_calculations: {
              subtotal: 1000.0,
              total_tax: 210.0,
              total_amount: 1210.0,
              tax_breakdown: [
                {
                  rate: 21.0,
                  base_amount: 1000.0,
                  tax_amount: 210.0,
                  category: 'vat'
                }
              ]
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/calculate_invoice/#{invoice_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: invoice_tax_response.to_json)
      end

      it 'calculates invoice tax with context' do
        result = described_class.calculate_invoice_tax(invoice_id, token: token)

        expect(result).to include(
          invoice_id: invoice_id,
          tax_context: hash_including(
            establishment_id: 1,
            cross_border: false
          ),
          tax_calculations: hash_including(
            subtotal: 1000.0,
            total_tax: 210.0,
            total_amount: 1210.0
          )
        )

        tax_breakdown = result[:tax_calculations][:tax_breakdown]
        expect(tax_breakdown).to be_an(Array)
        expect(tax_breakdown.first).to include(
          rate: 21.0,
          base_amount: 1000.0,
          tax_amount: 210.0,
          category: 'vat'
        )
      end
    end

    context 'invoice not found' do
      before do
        stub_request(:post, "#{base_url}/calculate_invoice/#{invoice_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Invoice not found' }.to_json)
      end

      it 'raises not found error' do
        expect { described_class.calculate_invoice_tax(invoice_id, token: token) }.to raise_error(ApiService::NotFoundError)
      end
    end
  end

  describe '.validate_cross_border_transaction' do
    let(:seller_jurisdiction) { 'ESP' }
    let(:buyer_jurisdiction) { 'FRA' }
    let(:product_types) { ['goods'] }

    context 'successful validation' do
      let(:validation_response) do
        {
          data: {
            is_cross_border: true,
            is_eu_transaction: true,
            reverse_charge_required: false,
            documentation_required: ['invoice', 'delivery_confirmation'],
            applicable_exemptions: ['intra_eu_supply'],
            warnings: [],
            recommendations: [
              'Ensure VAT number validation for B2B transactions',
              'Keep delivery confirmation for audit trail'
            ]
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/validate_cross_border")
          .with(
            body: {
              seller_jurisdiction: seller_jurisdiction,
              buyer_jurisdiction: buyer_jurisdiction,
              product_types: product_types
            }.to_json,
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: validation_response.to_json)
      end

      it 'validates cross-border transaction' do
        result = described_class.validate_cross_border_transaction(
          seller_jurisdiction: seller_jurisdiction,
          buyer_jurisdiction: buyer_jurisdiction,
          product_types: product_types,
          token: token
        )

        expect(result).to include(
          is_cross_border: true,
          is_eu_transaction: true,
          reverse_charge_required: false,
          documentation_required: ['invoice', 'delivery_confirmation'],
          applicable_exemptions: ['intra_eu_supply']
        )

        expect(result[:recommendations]).to be_an(Array)
        expect(result[:recommendations].first).to include('VAT number validation')
      end
    end
  end

  describe '.get_jurisdiction_requirements' do
    let(:jurisdiction_code) { 'ESP' }

    context 'successful request' do
      let(:requirements_response) do
        {
          data: {
            jurisdiction: {
              code: 'ESP',
              country_name: 'Spain'
            },
            requirements: {
              vat_registration: true,
              tax_representative: false,
              digital_services_tax: false,
              monthly_reporting: true,
              quarterly_reporting: false
            },
            thresholds: {
              vat_registration: 0,
              distance_selling: 10000
            },
            deadlines: {
              monthly_return: 'day_20_following_month',
              annual_return: 'january_31'
            }
          }
        }
      end

      before do
        stub_request(:get, "#{base_url}/jurisdictions/#{jurisdiction_code}/requirements")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: requirements_response.to_json)
      end

      it 'returns jurisdiction requirements' do
        result = described_class.get_jurisdiction_requirements(jurisdiction_code, token: token)

        expect(result).to include(
          jurisdiction: hash_including(
            code: 'ESP',
            country_name: 'Spain'
          ),
          requirements: hash_including(
            vat_registration: true,
            monthly_reporting: true
          ),
          thresholds: hash_including(
            vat_registration: 0,
            distance_selling: 10000
          ),
          deadlines: hash_including(
            monthly_return: 'day_20_following_month'
          )
        )
      end
    end

    context 'jurisdiction not found' do
      before do
        stub_request(:get, "#{base_url}/jurisdictions/#{jurisdiction_code}/requirements")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Jurisdiction not found' }.to_json)
      end

      it 'raises not found error' do
        expect { described_class.get_jurisdiction_requirements(jurisdiction_code, token: token) }.to raise_error(ApiService::NotFoundError)
      end
    end
  end
end