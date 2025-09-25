require 'rails_helper'

RSpec.describe CompanyEstablishmentService do
  let(:token) { 'test_access_token' }
  let(:base_url) { 'http://albaranes-api:3000/api/v1/company_establishments' }

  describe '.all' do
    context 'successful request' do
      let(:establishments_response) do
        {
          data: [
            {
              id: 1,
              type: 'company_establishment',
              attributes: {
                name: 'Main Office',
                address_line_1: '123 Main Street',
                address_line_2: 'Suite 100',
                city: 'Madrid',
                state_province: 'Madrid',
                postal_code: '28001',
                currency_code: 'EUR',
                is_default: true,
                tax_jurisdiction_id: 1
              }
            },
            {
              id: 2,
              type: 'company_establishment',
              attributes: {
                name: 'Barcelona Branch',
                address_line_1: '456 Barcelona Ave',
                city: 'Barcelona',
                state_province: 'Catalonia',
                postal_code: '08001',
                currency_code: 'EUR',
                is_default: false,
                tax_jurisdiction_id: 1
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, base_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: establishments_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns transformed establishment list' do
        result = described_class.all(token: token)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        first_establishment = result.first
        expect(first_establishment).to include(
          id: 1,
          name: 'Main Office',
          address_line_1: '123 Main Street',
          address_line_2: 'Suite 100',
          city: 'Madrid',
          state_province: 'Madrid',
          postal_code: '28001',
          currency_code: 'EUR',
          is_default: true,
          tax_jurisdiction_id: 1
        )
        expect(first_establishment[:display_name]).to eq('Main Office (Default)')
        expect(first_establishment[:full_address]).to include('123 Main Street')
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
    let(:establishment_id) { '1' }

    context 'successful request' do
      let(:establishment_response) do
        {
          data: {
            id: 1,
            type: 'company_establishment',
            attributes: {
              name: 'Main Office',
              address_line_1: '123 Main Street',
              address_line_2: 'Suite 100',
              city: 'Madrid',
              state_province: 'Madrid',
              postal_code: '28001',
              currency_code: 'EUR',
              is_default: true,
              tax_jurisdiction_id: 1,
              created_at: '2024-01-01T10:00:00Z',
              updated_at: '2024-01-15T14:30:00Z'
            }
          }
        }
      end

      before do
        stub_request(:get, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: establishment_response.to_json)
      end

      it 'returns transformed establishment' do
        result = described_class.find(establishment_id, token: token)

        expect(result).to include(
          id: 1,
          name: 'Main Office',
          address_line_1: '123 Main Street',
          address_line_2: 'Suite 100',
          city: 'Madrid',
          state_province: 'Madrid',
          postal_code: '28001',
          currency_code: 'EUR',
          is_default: true,
          tax_jurisdiction_id: 1,
          created_at: '2024-01-01T10:00:00Z',
          updated_at: '2024-01-15T14:30:00Z'
        )
        expect(result[:display_name]).to eq('Main Office (Default)')
        expect(result[:full_address]).to eq("123 Main Street\nSuite 100\nMadrid, Madrid, 28001")
      end
    end

    context 'not found' do
      before do
        stub_request(:get, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises not found error' do
        expect { described_class.find(establishment_id, token: token) }.to raise_error(ApiService::NotFoundError)
      end
    end
  end

  describe '.create' do
    let(:establishment_params) do
      {
        name: 'New Branch',
        address_line_1: '789 New Street',
        city: 'Valencia',
        postal_code: '46001',
        currency_code: 'EUR',
        tax_jurisdiction_id: 1,
        is_default: false
      }
    end

    context 'successful creation' do
      let(:creation_response) do
        {
          data: {
            id: 3,
            type: 'company_establishment',
            attributes: establishment_params.merge(
              created_at: '2024-01-20T09:00:00Z',
              updated_at: '2024-01-20T09:00:00Z'
            )
          }
        }
      end

      let(:expected_api_params) do
        {
          data: {
            type: 'company_establishments',
            attributes: {
              name: 'New Branch',
              address_line_1: '789 New Street',
              address_line_2: nil,
              city: 'Valencia',
              state_province: nil,
              postal_code: '46001',
              currency_code: 'EUR',
              is_default: false,
              tax_jurisdiction_id: 1
            }
          }
        }
      end

      before do
        stub_request(:post, base_url)
          .with(
            body: expected_api_params.to_json,
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 201, body: creation_response.to_json)
      end

      it 'creates and returns new establishment' do
        result = described_class.create(establishment_params, token: token)

        expect(result).to include(
          id: 3,
          name: 'New Branch',
          address_line_1: '789 New Street',
          city: 'Valencia',
          postal_code: '46001',
          currency_code: 'EUR',
          tax_jurisdiction_id: 1,
          is_default: false
        )
        expect(result[:display_name]).to eq('New Branch')
      end
    end

    context 'validation error' do
      let(:validation_error_response) do
        {
          errors: [
            {
              field: 'name',
              message: "can't be blank"
            },
            {
              field: 'city',
              message: "can't be blank"
            }
          ]
        }
      end

      before do
        stub_request(:post, base_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 422, body: validation_error_response.to_json)
      end

      it 'raises validation error' do
        expect { described_class.create({}, token: token) }.to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.update' do
    let(:establishment_id) { '1' }
    let(:update_params) do
      {
        name: 'Updated Office',
        currency_code: 'USD'
      }
    end

    context 'successful update' do
      let(:update_response) do
        {
          data: {
            id: 1,
            type: 'company_establishment',
            attributes: {
              name: 'Updated Office',
              address_line_1: '123 Main Street',
              city: 'Madrid',
              postal_code: '28001',
              currency_code: 'USD',
              is_default: true,
              tax_jurisdiction_id: 1,
              updated_at: '2024-01-20T15:30:00Z'
            }
          }
        }
      end

      let(:expected_api_params) do
        {
          data: {
            type: 'company_establishments',
            attributes: {
              name: 'Updated Office',
              address_line_1: nil,
              address_line_2: nil,
              city: nil,
              state_province: nil,
              postal_code: nil,
              currency_code: 'USD',
              is_default: false,
              tax_jurisdiction_id: nil
            }
          }
        }
      end

      before do
        stub_request(:patch, "#{base_url}/#{establishment_id}")
          .with(
            body: expected_api_params.to_json,
            headers: {
              'Authorization' => "Bearer #{token}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: update_response.to_json)
      end

      it 'updates and returns establishment' do
        result = described_class.update(establishment_id, update_params, token: token)

        expect(result).to include(
          id: 1,
          name: 'Updated Office',
          currency_code: 'USD',
          is_default: true
        )
      end
    end

    context 'not found' do
      before do
        stub_request(:patch, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises not found error' do
        expect { described_class.update(establishment_id, update_params, token: token) }.to raise_error(ApiService::NotFoundError)
      end
    end

    context 'validation error' do
      let(:validation_error_response) do
        {
          errors: [
            {
              field: 'name',
              message: "can't be blank"
            }
          ]
        }
      end

      before do
        stub_request(:patch, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 422, body: validation_error_response.to_json)
      end

      it 'raises validation error' do
        expect { described_class.update(establishment_id, { name: '' }, token: token) }.to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.destroy' do
    let(:establishment_id) { '1' }

    context 'successful deletion' do
      before do
        stub_request(:delete, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204)
      end

      it 'deletes establishment successfully' do
        result = described_class.destroy(establishment_id, token: token)
        expect(result).to be(true)
      end
    end

    context 'forbidden deletion (default establishment)' do
      before do
        stub_request(:delete, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 403, body: { error: 'Cannot delete default establishment' }.to_json)
      end

      it 'raises forbidden error' do
        expect { described_class.destroy(establishment_id, token: token) }.to raise_error(ApiService::ForbiddenError)
      end
    end

    context 'not found' do
      before do
        stub_request(:delete, "#{base_url}/#{establishment_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises not found error' do
        expect { described_class.destroy(establishment_id, token: token) }.to raise_error(ApiService::NotFoundError)
      end
    end
  end

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
              name: 'Main Office',
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
                { name: 'Standard VAT', rate: 21.0, applies_to: ['goods'] },
                { name: 'Services VAT', rate: 21.0, applies_to: ['services'] }
              ]
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/#{establishment_id}/resolve_tax_context")
          .with(
            body: {
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
          establishment_id,
          buyer_location: buyer_location,
          product_types: product_types,
          token: token
        )

        expect(result).to include(
          establishment: hash_including(
            id: 1,
            name: 'Main Office'
          ),
          buyer_location: buyer_location,
          tax_context: hash_including(
            cross_border: true,
            eu_transaction: true,
            reverse_charge: false
          )
        )

        applicable_rates = result[:tax_context][:applicable_rates]
        expect(applicable_rates).to be_an(Array)
        expect(applicable_rates.length).to eq(2)
      end
    end

    context 'minimal parameters' do
      before do
        stub_request(:post, "#{base_url}/#{establishment_id}/resolve_tax_context")
          .with(
            body: {
              buyer_location: {},
              product_types: []
            }.to_json,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: { data: { tax_context: {} } }.to_json)
      end

      it 'handles minimal parameters' do
        result = described_class.resolve_tax_context(establishment_id, token: token)
        expect(result).to include(tax_context: {})
      end
    end
  end

  describe '.transform_api_response' do
    let(:api_data) do
      {
        id: 1,
        type: 'company_establishment',
        attributes: {
          name: 'Test Office',
          address_line_1: '123 Test St',
          address_line_2: 'Unit 5',
          city: 'Test City',
          state_province: 'Test State',
          postal_code: '12345',
          currency_code: 'EUR',
          is_default: true,
          tax_jurisdiction_id: 1
        }
      }
    end

    it 'transforms API response correctly' do
      result = described_class.send(:transform_api_response, api_data)

      expect(result).to include(
        id: 1,
        name: 'Test Office',
        address_line_1: '123 Test St',
        address_line_2: 'Unit 5',
        city: 'Test City',
        state_province: 'Test State',
        postal_code: '12345',
        currency_code: 'EUR',
        is_default: true,
        tax_jurisdiction_id: 1
      )
      expect(result[:display_name]).to eq('Test Office (Default)')
      expect(result[:full_address]).to eq("123 Test St\nUnit 5\nTest City, Test State, 12345")
    end

    context 'with minimal address data' do
      let(:minimal_data) do
        {
          id: 2,
          type: 'company_establishment',
          attributes: {
            name: 'Minimal Office',
            city: 'Test City'
          }
        }
      end

      it 'handles missing address components gracefully' do
        result = described_class.send(:transform_api_response, minimal_data)

        expect(result).to include(
          id: 2,
          name: 'Minimal Office',
          city: 'Test City',
          display_name: 'Minimal Office'
        )
        expect(result[:full_address]).to eq('Test City')
      end
    end

    context 'with no address data' do
      let(:no_address_data) do
        {
          id: 3,
          type: 'company_establishment',
          attributes: {
            name: 'Address-less Office'
          }
        }
      end

      it 'handles completely missing address' do
        result = described_class.send(:transform_api_response, no_address_data)

        expect(result).to include(
          id: 3,
          name: 'Address-less Office',
          display_name: 'Address-less Office'
        )
        expect(result[:full_address]).to be_nil
      end
    end
  end

  describe '.format_for_api' do
    let(:params) do
      {
        name: 'Test Office',
        address_line_1: '123 Test St',
        city: 'Test City',
        currency_code: 'EUR'
      }
    end

    it 'formats parameters for API request' do
      result = described_class.send(:format_for_api, params)

      expect(result).to eq({
        data: {
          type: 'company_establishments',
          attributes: {
            name: 'Test Office',
            address_line_1: '123 Test St',
            address_line_2: nil,
            city: 'Test City',
            state_province: nil,
            postal_code: nil,
            currency_code: 'EUR',
            is_default: false,
            tax_jurisdiction_id: nil
          }
        }
      })
    end
  end
end