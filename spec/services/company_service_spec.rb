require 'rails_helper'

RSpec.describe CompanyService, type: :service do
  let(:token) { 'test_access_token' }
  let(:company_id) { 123 }
  let(:address_id) { 456 }
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }

  describe '.all' do
    context 'when successful' do
      let(:companies_response) do
        {
          data: [
            {
              id: 1,
              type: 'companies',
              attributes: {
                corporate_name: 'ACME Corp',
                trade_name: 'ACME Corp',
                tax_identification_number: 'B12345678',
                email: 'contact@acme.com',
                telephone: '123456789',
                web_address: 'https://acme.com'
              }
            },
            {
              id: 2,
              type: 'companies',
              attributes: {
                corporate_name: 'Test Inc',
                trade_name: 'Test Inc',
                tax_identification_number: 'B87654321',
                email: 'info@test.com',
                telephone: '987654321',
                web_address: 'https://test.com'
              }
            }
          ],
          meta: { total: 2, page: 1, pages: 1 }
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: companies_response.to_json)
      end

      it 'returns companies list' do
        result = CompanyService.all(token: token)
        
        expect(result[:companies].size).to eq(2)
        expect(result[:companies].first[:name]).to eq('ACME Corp')
        expect(result[:companies].first[:tax_id]).to eq('B12345678')
        expect(result[:meta][:total]).to eq(2)
      end
    end

    context 'with pagination parameters' do
      let(:params) { { page: 2, per_page: 10 } }

      before do
        stub_request(:get, "#{base_url}/companies")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: params
          )
          .to_return(status: 200, body: { companies: [] }.to_json)
      end

      it 'passes pagination parameters' do
        CompanyService.all(token: token, params: params)
        
        expect(WebMock).to have_requested(:get, "#{base_url}/companies")
          .with(query: params)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{base_url}/companies")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyService.all(token: token) }
          .to raise_error(ApiService::AuthenticationError)
      end
    end
  end

  describe '.find' do
    context 'when successful' do
      let(:company_response) do
        {
          id: company_id,
          name: 'ACME Corp',
          tax_id: 'B12345678',
          email: 'info@acme.com',
          addresses: [
            { id: 1, street: 'Main St 123', city: 'Madrid', postal_code: '28001' }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: company_response.to_json)
      end

      it 'returns company details' do
        result = CompanyService.find(company_id, token: token)
        
        expect(result[:id]).to eq(company_id)
        expect(result[:name]).to eq('ACME Corp')
        expect(result[:tax_id]).to eq('B12345678')
        expect(result[:addresses].size).to eq(1)
      end
    end

    context 'when company not found' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyService.find(company_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.create' do
    let(:company_params) do
      {
        name: 'New Company',
        tax_id: 'B99999999',
        email: 'info@newcompany.com',
        phone: '+34123456789'
      }
    end

    context 'when successful' do
      let(:created_company) do
        {
          data: {
            id: 789,
            type: 'companies',
            attributes: {
              trade_name: 'New Company',
              corporate_name: 'New Company',
              tax_identification_number: 'B99999999',
              email: 'info@newcompany.com',
              telephone: '+34123456789',
              created_at: Time.current.iso8601
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/companies")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'companies',
                attributes: {
                  trade_name: 'New Company',
                  corporate_name: 'New Company',
                  tax_identification_number: 'B99999999',
                  email: 'info@newcompany.com',
                  telephone: '+34123456789',
                  person_type_code: 'J',
                  residence_type_code: 'R'
                }
              }
            }.to_json
          )
          .to_return(status: 201, body: created_company.to_json)
      end

      it 'creates company and returns data' do
        result = CompanyService.create(company_params, token: token)
        
        expect(result[:data][:id]).to eq(789)
        expect(result[:data][:attributes][:trade_name]).to eq('New Company')
        expect(result[:data][:attributes][:tax_identification_number]).to eq('B99999999')
      end
    end

    context 'when validation fails' do
      before do
        stub_request(:post, "#{base_url}/companies")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: {
              error: 'Validation failed',
              errors: { name: ["can't be blank"], tax_id: ['invalid format'] }
            }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { CompanyService.create(company_params, token: token) }
          .to raise_error(ApiService::ValidationError) do |error|
            expect(error.errors[:name]).to include("can't be blank")
            expect(error.errors[:tax_id]).to include('invalid format')
          end
      end
    end
  end

  describe '.update' do
    let(:update_params) do
      {
        name: 'Updated Company Name',
        email: 'updated@company.com'
      }
    end

    context 'when successful' do
      let(:updated_company) do
        {
          data: {
            id: company_id,
            type: 'companies',
            attributes: {
              trade_name: 'Updated Company Name',
              corporate_name: 'Updated Company Name',
              tax_identification_number: 'B12345678',
              email: 'updated@company.com',
              updated_at: Time.current.iso8601
            }
          }
        }
      end

      before do
        stub_request(:put, "#{base_url}/companies/#{company_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'companies',
                attributes: {
                  trade_name: 'Updated Company Name',
                  corporate_name: 'Updated Company Name',
                  email: 'updated@company.com',
                  person_type_code: 'J',
                  residence_type_code: 'R'
                }
              }
            }.to_json
          )
          .to_return(status: 200, body: updated_company.to_json)
      end

      it 'updates company and returns data' do
        result = CompanyService.update(company_id, update_params, token: token)
        
        expect(result[:data][:id]).to eq(company_id)
        expect(result[:data][:attributes][:trade_name]).to eq('Updated Company Name')
        expect(result[:data][:attributes][:email]).to eq('updated@company.com')
      end
    end

    context 'when company not found' do
      before do
        stub_request(:put, "#{base_url}/companies/#{company_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Company not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyService.update(company_id, update_params, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.destroy' do
    context 'when successful' do
      before do
        stub_request(:delete, "#{base_url}/companies/#{company_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'deletes company successfully' do
        result = CompanyService.destroy(company_id, token: token)
        
        expect(result).to be_nil
        expect(WebMock).to have_requested(:delete, "#{base_url}/companies/#{company_id}")
      end
    end

    context 'when company has dependencies' do
      before do
        stub_request(:delete, "#{base_url}/companies/#{company_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: { error: 'Cannot delete company with existing invoices' }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { CompanyService.destroy(company_id, token: token) }
          .to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.addresses' do
    context 'when successful' do
      let(:addresses_response) do
        {
          data: [
            {
              id: 1,
              type: 'addresses',
              attributes: {
                address_type: 'billing',
                address: 'Main St 123',
                town: 'Madrid',
                post_code: '28001',
                province: 'Madrid',
                country_code: 'ESP',
                is_primary: true
              }
            },
            {
              id: 2,
              type: 'addresses',
              attributes: {
                address_type: 'shipping',
                address: 'Oak Ave 456',
                town: 'Barcelona',
                post_code: '08001',
                province: 'Barcelona',
                country_code: 'ESP',
                is_primary: false
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/addresses")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: addresses_response.to_json)
      end

      it 'returns company addresses' do
        result = CompanyService.addresses(company_id, token: token)
        
        expect(result.size).to eq(2)
        expect(result.first[:address_type]).to eq('billing')
        expect(result.first[:address]).to eq('Main St 123')
        expect(result.first[:is_default]).to eq(true)
        expect(result.last[:address_type]).to eq('shipping')
        expect(result.last[:is_default]).to eq(false)
      end
    end
  end

  describe '.create_address' do
    let(:address_params) do
      {
        address_type: 'billing',
        address: 'New Street 789',
        town: 'Valencia',
        post_code: '46001',
        country_code: 'ESP',
        province: 'Valencia',
        is_default: false
      }
    end

    context 'when successful' do
      let(:created_address) do
        {
          data: {
            id: address_id,
            type: 'addresses',
            attributes: {
              address_type: 'billing',
              address: 'New Street 789',
              town: 'Valencia',
              post_code: '46001',
              country_code: 'ESP',
              province: 'Valencia',
              is_primary: false
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/addresses")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'addresses',
                attributes: {
                  address: 'New Street 789',
                  post_code: '46001',
                  town: 'Valencia',
                  province: 'Valencia',
                  country_code: 'ESP',
                  is_primary: false,
                  address_type: 'billing'
                }
              }
            }.to_json
          )
          .to_return(status: 201, body: created_address.to_json)
      end

      it 'creates address and returns data' do
        result = CompanyService.create_address(company_id, address_params, token: token)
        
        expect(result[:data][:id]).to eq(address_id)
        expect(result[:data][:attributes][:address]).to eq('New Street 789')
        expect(result[:data][:attributes][:town]).to eq('Valencia')
        expect(result[:data][:attributes][:address_type]).to eq('billing')
      end
    end
  end

  describe '.update_address' do
    let(:address_update_params) do
      {
        address: 'Updated Street 999',
        post_code: '46002',
        town: 'Valencia',
        province: 'Valencia',
        country_code: 'ESP',
        address_type: 'billing',
        is_default: true
      }
    end

    context 'when successful' do
      let(:updated_address) do
        {
          data: {
            id: address_id,
            type: 'addresses',
            attributes: {
              address_type: 'billing',
              address: 'Updated Street 999',
              town: 'Valencia',
              post_code: '46002',
              province: 'Valencia',
              country_code: 'ESP',
              is_primary: true
            }
          }
        }
      end

      before do
        stub_request(:put, "#{base_url}/companies/#{company_id}/addresses/#{address_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'addresses',
                attributes: {
                  address: 'Updated Street 999',
                  post_code: '46002',
                  town: 'Valencia',
                  province: 'Valencia',
                  country_code: 'ESP',
                  is_primary: true,
                  address_type: 'billing'
                }
              }
            }.to_json
          )
          .to_return(status: 200, body: updated_address.to_json)
      end

      it 'updates address and returns data' do
        result = CompanyService.update_address(company_id, address_id, address_update_params, token: token)
        
        expect(result[:data][:id]).to eq(address_id)
        expect(result[:data][:attributes][:address]).to eq('Updated Street 999')
        expect(result[:data][:attributes][:post_code]).to eq('46002')
        expect(result[:data][:attributes][:is_primary]).to eq(true)
      end
    end
  end

  describe '.destroy_address' do
    context 'when successful' do
      before do
        stub_request(:delete, "#{base_url}/companies/#{company_id}/addresses/#{address_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'deletes address successfully' do
        result = CompanyService.destroy_address(company_id, address_id, token: token)
        
        expect(result).to be_nil
        expect(WebMock).to have_requested(:delete, "#{base_url}/companies/#{company_id}/addresses/#{address_id}")
      end
    end
  end

  describe '.search' do
    let(:query) { 'ACME' }

    context 'when successful' do
      let(:search_response) do
        {
          companies: [
            { id: 1, name: 'ACME Corp', tax_id: 'B12345678' },
            { id: 3, name: 'ACME Industries', tax_id: 'B11111111' }
          ],
          meta: { total: 2, query: query }
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { q: query }
          )
          .to_return(status: 200, body: search_response.to_json)
      end

      it 'returns search results' do
        result = CompanyService.search(query, token: token)
        
        expect(result[:companies].size).to eq(2)
        expect(result[:companies].all? { |c| c[:name].include?('ACME') }).to be true
        expect(result[:meta][:query]).to eq(query)
      end
    end

    context 'when no results found' do
      before do
        stub_request(:get, "#{base_url}/companies")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { q: query }
          )
          .to_return(status: 200, body: { companies: [], meta: { total: 0 } }.to_json)
      end

      it 'returns empty results' do
        result = CompanyService.search(query, token: token)
        
        expect(result[:companies]).to be_empty
        expect(result[:meta][:total]).to eq(0)
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'when token is nil' do
      it 'raises ArgumentError for all methods' do
        expect { CompanyService.all(token: nil) }
          .to raise_error(ApiService::AuthenticationError, 'Authentication failed. Please login again.')
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "#{base_url}/companies")
          .to_raise(Net::ReadTimeout)
      end

      it 'raises NetworkError' do
        expect { CompanyService.all(token: token) }
          .to raise_error(ApiService::ApiError, 'Unexpected error: Net::ReadTimeout with "Exception from WebMock"')
      end
    end

    context 'when server returns 500' do
      before do
        stub_request(:get, "#{base_url}/companies")
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyService.all(token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end
end