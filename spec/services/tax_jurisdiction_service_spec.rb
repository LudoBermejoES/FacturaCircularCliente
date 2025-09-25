require 'rails_helper'

RSpec.describe TaxJurisdictionService do
  let(:token) { 'test_access_token' }
  let(:base_url) { 'http://albaranes-api:3000/api/v1/tax_jurisdictions' }

  describe '.all' do
    context 'successful request' do
      let(:jurisdictions_response) do
        {
          data: [
            {
              id: 1,
              type: 'tax_jurisdictions',
              attributes: {
                code: 'ESP',
                country_name: 'Spain',
                tax_regime: 'standard_vat',
                eu_member: true,
                default_vat_rate: 21.0,
                reduced_vat_rates: [10.0, 4.0],
                requirements: {
                  vat_registration: true,
                  reverse_charge: false,
                  intrastat: true
                }
              }
            },
            {
              id: 2,
              type: 'tax_jurisdictions',
              attributes: {
                code: 'PRT',
                country_name: 'Portugal',
                tax_regime: 'standard_vat',
                eu_member: true,
                default_vat_rate: 23.0,
                reduced_vat_rates: [13.0, 6.0],
                requirements: {
                  vat_registration: true,
                  reverse_charge: false,
                  intrastat: true
                }
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, base_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: jurisdictions_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns transformed jurisdiction list' do
        result = described_class.all(token: token)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        first_jurisdiction = result.first
        expect(first_jurisdiction).to include(
          id: 1,
          code: 'ESP',
          country_name: 'Spain',
          tax_regime: 'standard_vat',
          eu_member: true,
          default_vat_rate: 21.0,
          reduced_vat_rates: [10.0, 4.0]
        )
        expect(first_jurisdiction[:display_name]).to eq('Spain (ESP)')
      end
    end

    context 'with filters' do
      let(:filtered_response) do
        {
          data: [
            {
              id: 1,
              type: 'tax_jurisdictions',
              attributes: {
                code: 'ESP',
                country_name: 'Spain',
                tax_regime: 'standard_vat',
                eu_member: true
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, base_url)
          .with(
            query: { country: 'ESP' },
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: filtered_response.to_json)
      end

      it 'passes filters to API request' do
        result = described_class.all(token: token, filters: { country: 'ESP' })

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:code]).to eq('ESP')
      end
    end

    context 'authentication error' do
      before do
        stub_request(:get, base_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises authentication error' do
        expect { described_class.all(token: token) }.to raise_error(ApiService::AuthenticationError)
      end
    end

    context 'api error' do
      before do
        stub_request(:get, base_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)
      end

      it 'raises api error' do
        expect { described_class.all(token: token) }.to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.find' do
    let(:jurisdiction_id) { '1' }

    context 'successful request' do
      let(:jurisdiction_response) do
        {
          data: {
            id: 1,
            type: 'tax_jurisdiction',
            attributes: {
              code: 'ESP',
              country_name: 'Spain',
              tax_regime: 'standard_vat',
              eu_member: true,
              default_vat_rate: 21.0,
              reduced_vat_rates: [10.0, 4.0],
              requirements: {
                vat_registration: true,
                reverse_charge: false,
                intrastat: true
              },
              exemptions: ['export', 'education'],
              compliance_notes: 'Standard EU VAT rules apply'
            }
          }
        }
      end

      before do
        stub_request(:get, "#{base_url}/#{jurisdiction_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: jurisdiction_response.to_json)
      end

      it 'returns transformed jurisdiction' do
        result = described_class.find(jurisdiction_id, token: token)

        expect(result).to include(
          id: 1,
          code: 'ESP',
          country_name: 'Spain',
          tax_regime: 'standard_vat',
          eu_member: true,
          default_vat_rate: 21.0,
          reduced_vat_rates: [10.0, 4.0],
          exemptions: ['export', 'education'],
          compliance_notes: 'Standard EU VAT rules apply'
        )
        expect(result[:display_name]).to eq('Spain (ESP)')
      end
    end

    context 'not found' do
      before do
        stub_request(:get, "#{base_url}/#{jurisdiction_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises not found error' do
        expect { described_class.find(jurisdiction_id, token: token) }.to raise_error(ApiService::NotFoundError)
      end
    end
  end

  describe '.tax_rates' do
    let(:jurisdiction_id) { '1' }

    context 'successful request' do
      let(:tax_rates_response) do
        {
          data: [
            {
              id: 1,
              type: 'tax_rate',
              attributes: {
                name: 'Standard VAT',
                rate: 21.0,
                category: 'vat',
                effective_from: '2024-01-01',
                effective_to: nil,
                applies_to: ['goods', 'services']
              }
            },
            {
              id: 2,
              type: 'tax_rate',
              attributes: {
                name: 'Reduced VAT',
                rate: 10.0,
                category: 'vat',
                effective_from: '2024-01-01',
                effective_to: nil,
                applies_to: ['books', 'food']
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/#{jurisdiction_id}/tax_rates")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: tax_rates_response.to_json)
      end

      it 'returns transformed tax rates' do
        result = described_class.tax_rates(jurisdiction_id, token: token)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        first_rate = result.first
        expect(first_rate).to include(
          id: 1,
          name: 'Standard VAT',
          rate: 21.0,
          category: 'vat',
          applies_to: ['goods', 'services']
        )
        expect(first_rate[:is_active]).to be(true)
      end
    end

    context 'with date filtering' do
      before do
        stub_request(:get, "#{base_url}/#{jurisdiction_id}/tax_rates")
          .with(
            query: { effective_date: '2024-06-15' },
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: { data: [] }.to_json)
      end

      it 'passes date filter to API' do
        result = described_class.tax_rates(jurisdiction_id, token: token, effective_date: '2024-06-15')

        expect(result).to be_an(Array)
        expect(result).to be_empty
      end
    end
  end

  describe '.transform_api_response' do
    let(:api_data) do
      {
        id: 1,
        type: 'tax_jurisdiction',
        attributes: {
          code: 'ESP',
          country_name: 'Spain',
          tax_regime: 'standard_vat',
          eu_member: true,
          default_vat_rate: 21.0,
          reduced_vat_rates: [10.0, 4.0],
          requirements: {
            vat_registration: true,
            reverse_charge: false
          }
        }
      }
    end

    it 'transforms API response correctly' do
      result = described_class.send(:transform_api_response, api_data)

      expect(result).to include(
        id: 1,
        code: 'ESP',
        country_name: 'Spain',
        tax_regime: 'standard_vat',
        eu_member: true,
        default_vat_rate: 21.0,
        reduced_vat_rates: [10.0, 4.0],
        requirements: {
          vat_registration: true,
          reverse_charge: false
        }
      )
      expect(result[:display_name]).to eq('Spain (ESP)')
    end

    context 'with missing attributes' do
      let(:minimal_data) do
        {
          id: 1,
          type: 'tax_jurisdiction',
          attributes: {
            code: 'ESP',
            country_name: 'Spain'
          }
        }
      end

      it 'handles missing attributes gracefully' do
        result = described_class.send(:transform_api_response, minimal_data)

        expect(result).to include(
          id: 1,
          code: 'ESP',
          country_name: 'Spain',
          display_name: 'Spain (ESP)'
        )
        expect(result[:tax_regime]).to be_nil
        expect(result[:requirements]).to eq({})
      end
    end
  end

  describe '.transform_tax_rate_response' do
    let(:tax_rate_data) do
      {
        id: 1,
        type: 'tax_rate',
        attributes: {
          name: 'Standard VAT',
          rate: 21.0,
          category: 'vat',
          effective_from: '2024-01-01',
          effective_to: '2024-12-31',
          applies_to: ['goods', 'services']
        }
      }
    end

    it 'transforms tax rate response correctly' do
      result = described_class.send(:transform_tax_rate_response, tax_rate_data)

      expect(result).to include(
        id: 1,
        name: 'Standard VAT',
        rate: 21.0,
        category: 'vat',
        effective_from: '2024-01-01',
        effective_to: '2024-12-31',
        applies_to: ['goods', 'services']
      )
      expect(result[:is_active]).to be(false) # has effective_to date
    end

    context 'with no end date' do
      let(:active_rate_data) do
        {
          id: 2,
          type: 'tax_rate',
          attributes: {
            name: 'Current VAT',
            rate: 21.0,
            category: 'vat',
            effective_from: '2024-01-01',
            effective_to: nil
          }
        }
      end

      it 'marks as active when no end date' do
        result = described_class.send(:transform_tax_rate_response, active_rate_data)

        expect(result[:is_active]).to be(true)
      end
    end
  end
end