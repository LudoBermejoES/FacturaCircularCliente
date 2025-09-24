require 'rails_helper'

RSpec.describe CompanyContactAddressService, type: :service do
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }
  let(:token) { 'test_token' }
  let(:company_id) { '123' }
  let(:contact_id) { '456' }
  let(:address_id) { '789' }

  describe '.all' do
    let(:response_data) {
      {
        data: [
          {
            id: "789",
            type: "company_contact_addresses",
            attributes: {
              street_address: "Calle Mayor 123\nPiso 2, Puerta A",
              city: "Madrid",
              state_province: "Madrid",
              postal_code: "28001",
              country_code: "ESP",
              country_name: "Spain",
              address_type: "billing",
              is_default: true,
              created_at: "2025-09-18T10:45:11.882+02:00",
              updated_at: "2025-09-18T10:45:11.882+02:00"
            }
          },
          {
            id: "790",
            type: "company_contact_addresses",
            attributes: {
              street_address: "Avenida de la Paz 456",
              city: "Barcelona",
              state_province: "Barcelona",
              postal_code: "08001",
              country_code: "ESP",
              country_name: "Spain",
              address_type: "shipping",
              is_default: false,
              created_at: "2025-09-18T10:50:11.882+02:00",
              updated_at: "2025-09-18T10:50:11.882+02:00"
            }
          }
        ],
        meta: {
          total: 2,
          page_count: 1,
          current_page: 1,
          per_page: 25
        }
      }
    }

    before do
      stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns transformed addresses data' do
      result = CompanyContactAddressService.all(company_id: company_id, contact_id: contact_id, token: token)

      expect(result[:addresses]).to be_an(Array)
      expect(result[:addresses].size).to eq(2)

      # Check first address
      first_address = result[:addresses].first
      expect(first_address[:id]).to eq("789")
      expect(first_address[:street_address]).to eq("Calle Mayor 123\nPiso 2, Puerta A")
      expect(first_address[:city]).to eq("Madrid")
      expect(first_address[:postal_code]).to eq("28001")
      expect(first_address[:country_code]).to eq("ESP")
      expect(first_address[:address_type]).to eq("billing")
      expect(first_address[:is_default]).to be(true)
      expect(first_address[:display_type]).to eq("Billing")

      # Check second address
      second_address = result[:addresses].second
      expect(second_address[:id]).to eq("790")
      expect(second_address[:address_type]).to eq("shipping")
      expect(second_address[:is_default]).to be(false)
      expect(second_address[:display_type]).to eq("Shipping")

      expect(result[:meta][:total]).to eq(2)
    end

    it 'handles empty response' do
      empty_response = { data: [], meta: { total: 0, page_count: 0, current_page: 1, per_page: 25 } }

      stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: empty_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = CompanyContactAddressService.all(company_id: company_id, contact_id: contact_id, token: token)

      expect(result[:addresses]).to eq([])
      expect(result[:meta][:total]).to eq(0)
    end

    context 'when API error occurs' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns empty result and logs error' do
        expect(Rails.logger).to receive(:error).with("Unexpected error: Server error. Please try again later.")
        expect(Rails.logger).to receive(:error).with("DEBUG: CompanyContactAddressService.all error: Unexpected error: Server error. Please try again later.")

        result = CompanyContactAddressService.all(company_id: company_id, contact_id: contact_id, token: token)

        expect(result[:addresses]).to eq([])
        expect(result[:meta][:total]).to eq(0)
      end
    end
  end

  describe '.find' do
    let(:response_data) {
      {
        data: {
          id: "789",
          type: "company_contact_addresses",
          attributes: {
            street_address: "Calle Mayor 123\nPiso 2, Puerta A",
            city: "Madrid",
            state_province: "Madrid",
            postal_code: "28001",
            country_code: "ESP",
            country_name: "Spain",
            address_type: "billing",
            is_default: true,
            full_address: "Calle Mayor 123, Piso 2, Puerta A, 28001 Madrid, Madrid, Spain",
            full_address_with_country: "Calle Mayor 123, Piso 2, Puerta A, 28001 Madrid, Madrid, Spain",
            created_at: "2025-09-18T10:45:11.882+02:00",
            updated_at: "2025-09-18T10:45:11.882+02:00"
          }
        }
      }
    }

    context 'when address exists' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns transformed address data' do
        result = CompanyContactAddressService.find(
          company_id: company_id,
          contact_id: contact_id,
          address_id: address_id,
          token: token
        )

        expect(result[:id]).to eq("789")
        expect(result[:street_address]).to eq("Calle Mayor 123\nPiso 2, Puerta A")
        expect(result[:city]).to eq("Madrid")
        expect(result[:state_province]).to eq("Madrid")
        expect(result[:postal_code]).to eq("28001")
        expect(result[:country_code]).to eq("ESP")
        expect(result[:country_name]).to eq("Spain")
        expect(result[:address_type]).to eq("billing")
        expect(result[:is_default]).to be(true)
        expect(result[:display_type]).to eq("Billing")
        expect(result[:full_address]).to eq("Calle Mayor 123, Piso 2, Puerta A, 28001 Madrid, Madrid, Spain")
        expect(result[:full_address_with_country]).to eq("Calle Mayor 123, Piso 2, Puerta A, 28001 Madrid, Madrid, Spain")
      end
    end

    context 'when address does not exist' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns nil and logs error' do
        expect(Rails.logger).to receive(:error).with("Unexpected error: The requested resource was not found.")
        expect(Rails.logger).to receive(:error).with("DEBUG: CompanyContactAddressService.find error: Unexpected error: The requested resource was not found.")

        result = CompanyContactAddressService.find(
          company_id: company_id,
          contact_id: contact_id,
          address_id: address_id,
          token: token
        )

        expect(result).to be_nil
      end
    end
  end

  describe '.create' do
    let(:params) {
      {
        street_address: "Gran Via 100",
        city: "Madrid",
        postal_code: "28013",
        country_code: "ESP",
        address_type: "billing",
        is_default: false
      }
    }

    let(:response_data) {
      {
        data: {
          id: "791",
          type: "company_contact_addresses",
          attributes: params.merge(
            id: "791",
            country_name: "Spain",
            full_address: "Gran Via 100, 28013 Madrid, Spain",
            created_at: "2025-09-18T11:00:00.000+02:00",
            updated_at: "2025-09-18T11:00:00.000+02:00"
          )
        }
      }
    }

    before do
      stub_request(:post, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: {
            data: {
              type: 'addresses',
              attributes: params
            }
          }.to_json
        )
        .to_return(status: 201, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates new address with proper JSON API format' do
      result = CompanyContactAddressService.create(
        company_id: company_id,
        contact_id: contact_id,
        params: params,
        token: token
      )

      expect(result[:data][:id]).to eq("791")
      expect(result[:data][:attributes][:street_address]).to eq("Gran Via 100")
      expect(result[:data][:attributes][:city]).to eq("Madrid")
      expect(result[:data][:attributes][:address_type]).to eq("billing")
    end

    context 'when validation fails' do
      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'addresses',
                attributes: params
              }
            }.to_json
          )
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'Street address is required', source: { pointer: '/data/attributes/street_address' } }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ValidationError with proper error details' do
        expect {
          CompanyContactAddressService.create(
            company_id: company_id,
            contact_id: contact_id,
            params: params,
            token: token
          )
        }.to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.update' do
    let(:params) {
      {
        street_address: "Gran Via 200",
        city: "Madrid",
        postal_code: "28013"
      }
    }

    let(:response_data) {
      {
        data: {
          id: "789",
          type: "company_contact_addresses",
          attributes: {
            street_address: "Gran Via 200",
            city: "Madrid",
            state_province: "Madrid",
            postal_code: "28013",
            country_code: "ESP",
            country_name: "Spain",
            address_type: "billing",
            is_default: true,
            updated_at: "2025-09-18T11:10:00.000+02:00"
          }
        }
      }
    }

    before do
      stub_request(:patch, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: {
            data: {
              type: 'addresses',
              attributes: params
            }
          }.to_json
        )
        .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'updates address with proper JSON API format' do
      result = CompanyContactAddressService.update(
        company_id: company_id,
        contact_id: contact_id,
        address_id: address_id,
        params: params,
        token: token
      )

      expect(result[:data][:id]).to eq("789")
      expect(result[:data][:attributes][:street_address]).to eq("Gran Via 200")
      expect(result[:data][:attributes][:postal_code]).to eq("28013")
    end
  end

  describe '.delete' do
    before do
      stub_request(:delete, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '', headers: {})
    end

    it 'deletes address' do
      expect {
        CompanyContactAddressService.delete(
          company_id: company_id,
          contact_id: contact_id,
          address_id: address_id,
          token: token
        )
      }.not_to raise_error
    end

    context 'when address cannot be deleted' do
      before do
        stub_request(:delete, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 409,
            body: { error: 'Cannot delete default address' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ApiError' do
        expect {
          CompanyContactAddressService.delete(
            company_id: company_id,
            contact_id: contact_id,
            address_id: address_id,
            token: token
          )
        }.to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.set_default' do
    let(:response_data) {
      {
        data: {
          id: "789",
          type: "company_contact_addresses",
          attributes: {
            street_address: "Calle Mayor 123",
            city: "Madrid",
            postal_code: "28001",
            country_code: "ESP",
            address_type: "billing",
            is_default: true,
            updated_at: "2025-09-18T11:15:00.000+02:00"
          }
        }
      }
    }

    before do
      stub_request(:post, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}/set_default")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'sets address as default' do
      result = CompanyContactAddressService.set_default(
        company_id: company_id,
        contact_id: contact_id,
        address_id: address_id,
        token: token
      )

      expect(result[:data][:id]).to eq("789")
      expect(result[:data][:attributes][:is_default]).to be(true)
    end

    context 'when address not found' do
      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}/set_default")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Address not found' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError' do
        expect {
          CompanyContactAddressService.set_default(
            company_id: company_id,
            contact_id: contact_id,
            address_id: address_id,
            token: token
          )
        }.to raise_error(ApiService::ApiError)
      end
    end
  end

  describe 'address type display transformation' do
    it 'transforms billing type to Billing' do
      address = { address_type: 'billing' }
      transformed = CompanyContactAddressService.send(:transform_address, address)
      expect(transformed[:display_type]).to eq('Billing')
    end

    it 'transforms shipping type to Shipping' do
      address = { address_type: 'shipping' }
      transformed = CompanyContactAddressService.send(:transform_address, address)
      expect(transformed[:display_type]).to eq('Shipping')
    end

    it 'handles unknown address types gracefully' do
      address = { address_type: 'unknown' }
      transformed = CompanyContactAddressService.send(:transform_address, address)
      expect(transformed[:display_type]).to eq('Unknown')
    end
  end
end