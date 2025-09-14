require 'rails_helper'

RSpec.describe Api::V1::CompanyContactsController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company_id) { 123 }
  
  let(:contact1) { build(:company_contact_response, id: 1, name: 'John', full_name: 'John Doe', email: 'john@example.com', telephone: '+34612345678') }
  let(:contact2) { build(:company_contact_response, id: 2, name: 'Jane', full_name: 'Jane Smith', email: 'jane@example.com', telephone: '+34687654321') }
  let(:active_contacts) { [contact1, contact2] }

  before do
    # Mock authentication for API controller specs
    allow(controller).to receive(:current_token).and_return(token)
  end

  describe 'GET #index' do
    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts).with(company_id: company_id.to_s, token: token)
          .and_return(active_contacts)
      end

      it 'returns active contacts in JSON format' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        
        json_response = JSON.parse(response.body)
        expect(json_response['contacts']).to be_an(Array)
        expect(json_response['contacts'].length).to eq(2)
        
        first_contact = json_response['contacts'][0]
        expect(first_contact['id']).to eq(1)
        expect(first_contact['name']).to eq('John Doe')
        expect(first_contact['email']).to eq('john@example.com')
        expect(first_contact['telephone']).to eq('+34612345678')
        
        second_contact = json_response['contacts'][1]
        expect(second_contact['id']).to eq(2)
        expect(second_contact['name']).to eq('Jane Smith')
        expect(second_contact['email']).to eq('jane@example.com')
        expect(second_contact['telephone']).to eq('+34687654321')
        
        expect(CompanyContactsService).to have_received(:active_contacts).with(company_id: company_id.to_s, token: token)
      end

      it 'handles contacts without full_name by using name field' do
        contact_without_full_name = build(:company_contact_response, 
          id: 3, 
          name: 'Bob', 
          full_name: nil,
          email: 'bob@example.com'
        )
        
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_return([contact_without_full_name])

        get :index, params: { company_id: company_id }
        
        json_response = JSON.parse(response.body)
        expect(json_response['contacts'][0]['name']).to eq('Bob')
      end

      it 'returns empty array when no active contacts exist' do
        allow(CompanyContactsService).to receive(:active_contacts).with(company_id: company_id.to_s, token: token)
          .and_return([])

        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['contacts']).to eq([])
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'returns API error with unprocessable entity status' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Company not found')
      end
    end

    context 'when validation error occurs' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::ValidationError.new('Invalid company ID', { company_id: ['is invalid'] }))
      end

      it 'returns validation error with unprocessable entity status' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid company ID')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(StandardError.new('Database connection failed'))
      end

      it 'returns internal server error with error message' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:internal_server_error)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unexpected error: Database connection failed')
      end
    end

    context 'when network timeout occurs' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(Timeout::Error.new('Request timeout'))
      end

      it 'returns internal server error for timeout' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:internal_server_error)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unexpected error: Request timeout')
      end
    end
  end

  describe 'parameter handling' do
    context 'with valid company_id' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts).and_return([])
      end

      it 'accepts string company_id parameter' do
        get :index, params: { company_id: '456' }
        
        expect(CompanyContactsService).to have_received(:active_contacts).with(company_id: '456', token: token)
      end

      it 'converts integer company_id to string' do
        get :index, params: { company_id: 789 }
        
        expect(CompanyContactsService).to have_received(:active_contacts).with(company_id: '789', token: token)
      end
    end

    context 'with missing company_id' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts).and_return([])
      end

      it 'passes empty string company_id when missing' do
        get :index, params: { company_id: '' }
        
        expect(CompanyContactsService).to have_received(:active_contacts).with(company_id: '', token: token)
      end
    end
  end

  describe 'authentication' do
    context 'when current_token is nil' do
      before do
        allow(controller).to receive(:current_token).and_return(nil)
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::AuthenticationError.new('Authentication failed'))
      end

      it 'handles authentication error by redirecting to login' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq('Please sign in to continue')
      end
    end

    context 'when current_token is empty string' do
      before do
        allow(controller).to receive(:current_token).and_return('')
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::AuthenticationError.new('Authentication failed'))
      end

      it 'handles authentication error by redirecting to login' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq('Please sign in to continue')
      end
    end
  end

  describe 'JSON response format' do
    before do
      allow(CompanyContactsService).to receive(:active_contacts).and_return(active_contacts)
    end

    it 'returns properly formatted JSON with contacts array' do
      get :index, params: { company_id: company_id }
      
      expect(response.content_type).to eq('application/json; charset=utf-8')
      
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('contacts')
      expect(json_response['contacts']).to be_an(Array)
    end

    it 'includes only required fields in contact objects' do
      get :index, params: { company_id: company_id }
      
      json_response = JSON.parse(response.body)
      contact = json_response['contacts'][0]
      
      expect(contact.keys.sort).to eq(['email', 'id', 'name', 'telephone'])
      expect(contact).not_to have_key('first_surname')
      expect(contact).not_to have_key('second_surname')
      expect(contact).not_to have_key('is_active')
      expect(contact).not_to have_key('contact_details')
    end

    it 'maps full_name to name field when available' do
      contact_with_full_name = build(:company_contact_response, 
        id: 1,
        name: 'John',
        full_name: 'John Doe Smith'
      )
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact_with_full_name])

      get :index, params: { company_id: company_id }
      
      json_response = JSON.parse(response.body)
      expect(json_response['contacts'][0]['name']).to eq('John Doe Smith')
    end

    it 'falls back to name field when full_name is nil' do
      contact_without_full_name = build(:company_contact_response, 
        id: 1,
        name: 'John',
        full_name: nil
      )
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact_without_full_name])

      get :index, params: { company_id: company_id }
      
      json_response = JSON.parse(response.body)
      expect(json_response['contacts'][0]['name']).to eq('John')
    end

    it 'uses empty string when full_name is empty string' do
      contact_with_empty_full_name = build(:company_contact_response, 
        id: 1,
        name: 'John',
        full_name: ''
      )
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact_with_empty_full_name])

      get :index, params: { company_id: company_id }
      
      json_response = JSON.parse(response.body)
      expect(json_response['contacts'][0]['name']).to eq('')
    end
  end

  describe 'edge cases' do
    it 'handles contacts with missing fields gracefully' do
      incomplete_contact = {
        id: 1,
        name: 'John',
        full_name: nil,
        email: nil,
        telephone: nil
      }
      
      allow(CompanyContactsService).to receive(:active_contacts).and_return([incomplete_contact])

      get :index, params: { company_id: company_id }
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      contact = json_response['contacts'][0]
      
      expect(contact['id']).to eq(1)
      expect(contact['name']).to eq('John')
      expect(contact['email']).to be_nil
      expect(contact['telephone']).to be_nil
    end

    it 'handles large number of contacts' do
      large_contact_list = (1..100).map do |i|
        build(:company_contact_response, 
          id: i, 
          name: "Contact #{i}",
          email: "contact#{i}@example.com"
        )
      end
      
      allow(CompanyContactsService).to receive(:active_contacts).and_return(large_contact_list)

      get :index, params: { company_id: company_id }
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['contacts'].length).to eq(100)
    end

    it 'handles contacts with special characters in names' do
      special_contact = build(:company_contact_response,
        id: 1,
        name: 'José María',
        full_name: 'José María González-López',
        email: 'jose.maria@example.com'
      )
      
      allow(CompanyContactsService).to receive(:active_contacts).and_return([special_contact])

      get :index, params: { company_id: company_id }
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['contacts'][0]['name']).to eq('José María González-López')
    end
  end
end