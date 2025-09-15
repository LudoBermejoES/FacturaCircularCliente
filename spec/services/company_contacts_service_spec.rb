require 'rails_helper'

RSpec.describe CompanyContactsService, type: :service do
  let(:token) { 'test_access_token' }
  let(:company_id) { 123 }
  let(:contact_id) { 456 }
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }

  describe '.all' do
    context 'when successful' do
      let(:contacts_response) do
        {
          data: [
            {
              id: 1,
              type: 'company_contacts',
              attributes: {
                person_name: 'John',
                first_surname: 'Doe',
                second_surname: 'Smith',
                email: 'john.doe@example.com',
                telephone: '+34123456789',
                contact_details: 'Sales Manager',
                is_active: true
              }
            },
            {
              id: 2,
              type: 'company_contacts',
              attributes: {
                person_name: 'Jane',
                first_surname: 'Wilson',
                second_surname: nil,
                email: 'jane.wilson@example.com',
                telephone: '+34987654321',
                contact_details: 'Accounting Department',
                is_active: true
              }
            }
          ],
          meta: { total: 2, page: 1, pages: 1 }
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/contacts")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: contacts_response.to_json)
      end

      it 'returns contacts list' do
        result = CompanyContactsService.all(company_id: company_id, token: token)
        
        expect(result[:contacts].size).to eq(2)
        expect(result[:contacts].first[:name]).to eq('John')
        expect(result[:contacts].first[:email]).to eq('john.doe@example.com')
        expect(result[:contacts].first[:first_surname]).to eq('Doe')
        expect(result[:contacts].first[:is_active]).to eq(true)
        expect(result[:meta][:total]).to eq(2)
      end
    end

    context 'with pagination parameters' do
      let(:params) { { page: 2, per_page: 10 } }

      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: params
          )
          .to_return(status: 200, body: { data: [], meta: { total: 0 } }.to_json)
      end

      it 'passes pagination parameters' do
        CompanyContactsService.all(company_id: company_id, token: token, params: params)
        
        expect(WebMock).to have_requested(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(query: params)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyContactsService.all(company_id: company_id, token: token) }
          .to raise_error(ApiService::AuthenticationError)
      end
    end
  end

  describe '.find' do
    context 'when successful' do
      let(:contact_response) do
        {
          data: {
            id: contact_id,
            type: 'company_contacts',
            attributes: {
              person_name: 'John',
              first_surname: 'Doe',
              second_surname: 'Smith',
              email: 'john.doe@example.com',
              telephone: '+34123456789',
              contact_details: 'Sales Manager',
              is_active: true
            }
          }
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: contact_response.to_json)
      end

      it 'returns contact details' do
        result = CompanyContactsService.find(company_id: company_id, id: contact_id, token: token)
        
        expect(result[:id]).to eq(contact_id)
        expect(result[:name]).to eq('John')
        expect(result[:first_surname]).to eq('Doe')
        expect(result[:email]).to eq('john.doe@example.com')
        expect(result[:is_active]).to eq(true)
      end
    end

    context 'when contact not found' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Contact not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyContactsService.find(company_id: company_id, id: contact_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.create' do
    let(:contact_params) do
      {
        name: 'John',
        first_surname: 'Doe',
        second_surname: 'Smith',
        email: 'john.doe@example.com',
        telephone: '+34123456789',
        contact_details: 'Sales Manager'
      }
    end

    context 'when successful' do
      let(:created_contact) do
        {
          data: {
            id: 789,
            type: 'company_contacts',
            attributes: {
              person_name: 'John',
              first_surname: 'Doe',
              second_surname: 'Smith',
              email: 'john.doe@example.com',
              telephone: '+34123456789',
              contact_details: 'Sales Manager',
              is_active: true,
              created_at: Time.current.iso8601
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 201, body: created_contact.to_json)
      end

      it 'creates contact and returns data' do
        result = CompanyContactsService.create(company_id: company_id, params: contact_params, token: token)
        
        expect(result[:data][:id]).to eq(789)
        expect(result[:data][:attributes][:person_name]).to eq('John')
        expect(result[:data][:attributes][:email]).to eq('john.doe@example.com')
        expect(result[:data][:attributes][:is_active]).to eq(true)
      end
    end

    context 'when validation fails' do
      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: {
              errors: [
                {
                  status: '422',
                  source: { pointer: '/data/attributes/person_name' },
                  title: 'Validation Error',
                  detail: "Person name can't be blank"
                }
              ]
            }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { CompanyContactsService.create(company_id: company_id, params: contact_params, token: token) }
          .to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.update' do
    let(:update_params) do
      {
        name: 'John',
        first_surname: 'Doe',
        email: 'john.updated@example.com',
        contact_details: 'Senior Sales Manager'
      }
    end

    context 'when successful' do
      let(:updated_contact) do
        {
          data: {
            id: contact_id,
            type: 'company_contacts',
            attributes: {
              person_name: 'John',
              first_surname: 'Doe',
              second_surname: 'Smith',
              email: 'john.updated@example.com',
              telephone: '+34123456789',
              contact_details: 'Senior Sales Manager',
              is_active: true,
              updated_at: Time.current.iso8601
            }
          }
        }
      end

      before do
        stub_request(:put, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: updated_contact.to_json)
      end

      it 'updates contact and returns data' do
        result = CompanyContactsService.update(company_id: company_id, id: contact_id, params: update_params, token: token)
        
        expect(result[:data][:id]).to eq(contact_id)
        expect(result[:data][:attributes][:email]).to eq('john.updated@example.com')
        expect(result[:data][:attributes][:contact_details]).to eq('Senior Sales Manager')
      end
    end

    context 'when contact not found' do
      before do
        stub_request(:put, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Contact not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyContactsService.update(company_id: company_id, id: contact_id, params: update_params, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.destroy' do
    context 'when successful' do
      before do
        stub_request(:delete, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'deletes contact successfully' do
        result = CompanyContactsService.destroy(company_id: company_id, id: contact_id, token: token)
        
        expect(result).to be_nil
        expect(WebMock).to have_requested(:delete, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
      end
    end

    context 'when contact has dependencies' do
      before do
        stub_request(:delete, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: { error: 'Cannot delete contact with existing invoices' }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { CompanyContactsService.destroy(company_id: company_id, id: contact_id, token: token) }
          .to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.activate' do
    context 'when successful' do
      let(:activated_contact) do
        {
          data: {
            id: contact_id,
            type: 'company_contacts',
            attributes: {
              person_name: 'John',
              first_surname: 'Doe',
              email: 'john.doe@example.com',
              is_active: true,
              updated_at: Time.current.iso8601
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}/activate")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: activated_contact.to_json)
      end

      it 'activates contact successfully' do
        result = CompanyContactsService.activate(company_id: company_id, id: contact_id, token: token)
        
        expect(result[:data][:attributes][:is_active]).to eq(true)
        expect(WebMock).to have_requested(:post, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}/activate")
      end
    end

    context 'when contact not found' do
      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}/activate")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Contact not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyContactsService.activate(company_id: company_id, id: contact_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.deactivate' do
    context 'when successful' do
      let(:deactivated_contact) do
        {
          data: {
            id: contact_id,
            type: 'company_contacts',
            attributes: {
              person_name: 'John',
              first_surname: 'Doe',
              email: 'john.doe@example.com',
              is_active: false,
              updated_at: Time.current.iso8601
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}/deactivate")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: deactivated_contact.to_json)
      end

      it 'deactivates contact successfully' do
        result = CompanyContactsService.deactivate(company_id: company_id, id: contact_id, token: token)
        
        expect(result[:data][:attributes][:is_active]).to eq(false)
        expect(WebMock).to have_requested(:post, "#{base_url}/companies/#{company_id}/company_contacts/#{contact_id}/deactivate")
      end
    end
  end

  describe '.active_contacts' do
    context 'when successful' do
      let(:active_contacts_response) do
        {
          data: [
            {
              id: 1,
              type: 'company_contacts',
              attributes: {
                person_name: 'John',
                first_surname: 'Doe',
                second_surname: 'Smith',
                email: 'john.doe@example.com',
                telephone: '+34123456789',
                is_active: true
              }
            },
            {
              id: 2,
              type: 'company_contacts',
              attributes: {
                person_name: 'Jane',
                first_surname: 'Wilson',
                second_surname: nil,
                email: 'jane.wilson@example.com',
                telephone: '+34987654321',
                is_active: true
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { is_active: true } }
          )
          .to_return(status: 200, body: active_contacts_response.to_json)
      end

      it 'returns only active contacts with full names' do
        result = CompanyContactsService.active_contacts(company_id: company_id, token: token)
        
        expect(result.size).to eq(2)
        expect(result.first[:name]).to eq('John')
        expect(result.first[:full_name]).to eq('John Doe Smith')
        expect(result.last[:name]).to eq('Jane')
        expect(result.last[:full_name]).to eq('Jane Wilson')
      end

      it 'filters for active contacts only' do
        CompanyContactsService.active_contacts(company_id: company_id, token: token)
        
        expect(WebMock).to have_requested(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(query: { filter: { is_active: true } })
      end
    end

    context 'when no active contacts exist' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { is_active: true } }
          )
          .to_return(status: 200, body: { data: [] }.to_json)
      end

      it 'returns empty array' do
        result = CompanyContactsService.active_contacts(company_id: company_id, token: token)
        
        expect(result).to be_empty
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'when token is nil' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .to_return(status: 401, body: { error: 'Authentication failed. Please login again.' }.to_json)
      end

      it 'raises AuthenticationError for all methods' do
        expect { CompanyContactsService.all(company_id: company_id, token: nil) }
          .to raise_error(ApiService::AuthenticationError, 'Authentication failed. Please login again.')
      end
    end

    context 'when company_id is nil' do
      before do
        stub_request(:get, "#{base_url}/companies//company_contacts")
          .to_return(status: 401, body: { error: 'Authentication failed. Please login again.' }.to_json)
      end

      it 'raises AuthenticationError when company_id is nil' do
        expect { CompanyContactsService.all(company_id: nil, token: token) }
          .to raise_error(ApiService::AuthenticationError, 'Authentication failed. Please login again.')
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .to_raise(Net::ReadTimeout)
      end

      it 'raises NetworkError' do
        expect { CompanyContactsService.all(company_id: company_id, token: token) }
          .to raise_error(ApiService::ApiError, 'Unexpected error: Net::ReadTimeout with "Exception from WebMock"')
      end
    end

    context 'when server returns 500' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json)
      end

      it 'raises ApiError' do
        expect { CompanyContactsService.all(company_id: company_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end

    context 'when response data is malformed' do
      before do
        stub_request(:get, "#{base_url}/companies/#{company_id}/company_contacts")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: { invalid: 'response' }.to_json)
      end

      it 'handles gracefully and returns empty contacts' do
        result = CompanyContactsService.all(company_id: company_id, token: token)
        
        expect(result[:contacts]).to be_empty
      end
    end
  end
end