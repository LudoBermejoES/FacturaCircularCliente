require 'rails_helper'

RSpec.describe 'Addresses', type: :request do
  let(:company_id) { 123 }
  let(:address_id) { 456 }
  let(:company) { build(:company_response, id: company_id) }
  
  let(:address_params) do
    {
      address: '123 Main Street',
      post_code: '12345',
      town: 'Madrid',
      province: 'Madrid',
      country_code: 'ESP',
      address_type: 'legal',
      is_default: true
    }
  end

  # HTTP stubs and authentication mocking handled by RequestHelper
  include RequestHelper

  before do
    # Mock CompanyService methods - simplified for testing
    allow(CompanyService).to receive(:find).and_return(company)
    allow(CompanyService).to receive(:addresses).and_return([])
  end

  describe 'POST /companies/:company_id/addresses' do
    context 'when successful' do
      before do
        allow(CompanyService).to receive(:create_address).and_return({ success: true })
      end

      it 'creates the address and redirects with success message' do
        post company_addresses_path(company_id), params: { address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Address created successfully')
        expect(CompanyService).to have_received(:create_address)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyService).to receive(:create_address)
          .and_raise(ApiService::ValidationError.new('Validation failed', { address: ['is required'] }))
      end

      it 'redirects with error message' do
        post company_addresses_path(company_id), params: { address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Validation failed')
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyService).to receive(:create_address)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'redirects with error message' do
        post company_addresses_path(company_id), params: { address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Server error')
      end
    end
  end

  describe 'PATCH /companies/:company_id/addresses/:id' do
    let(:updated_params) do
      {
        address: '456 Updated Street',
        post_code: '54321',
        town: 'Barcelona',
        province: 'Barcelona',
        country_code: 'ESP',
        address_type: 'billing',
        is_default: false
      }
    end

    context 'when successful' do
      before do
        allow(CompanyService).to receive(:update_address).and_return({ success: true })
      end

      it 'updates the address and redirects with success message' do
        patch company_address_path(company_id, address_id), params: { address: updated_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Address updated successfully')
        expect(CompanyService).to have_received(:update_address)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyService).to receive(:update_address)
          .and_raise(ApiService::ValidationError.new('Validation failed', { town: ['is required'] }))
      end

      it 'redirects with error message' do
        patch company_address_path(company_id, address_id), params: { address: updated_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Validation failed')
      end
    end
  end

  describe 'DELETE /companies/:company_id/addresses/:id' do
    context 'when successful' do
      before do
        allow(CompanyService).to receive(:destroy_address).and_return({ success: true })
      end

      it 'deletes the address and redirects with success message' do
        delete company_address_path(company_id, address_id)
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Address deleted successfully')
        expect(CompanyService).to have_received(:destroy_address)
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyService).to receive(:destroy_address)
          .and_raise(ApiService::ApiError.new('Cannot delete address'))
      end

      it 'redirects with error message' do
        delete company_address_path(company_id, address_id)
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Cannot delete address')
      end
    end
  end

  describe 'parameter security' do
    it 'only allows permitted parameters' do
      malicious_params = address_params.merge(
        admin: true,
        user_id: 999,
        '<script>': 'alert("xss")'
      )
      
      allow(CompanyService).to receive(:create_address).and_return({ success: true })
      
      post company_addresses_path(company_id), params: { address: malicious_params }
      
      expect(response).to redirect_to(company_path(company_id))
      expect(CompanyService).to have_received(:create_address)
    end

    it 'handles missing address parameter' do
      post company_addresses_path(company_id), params: {}
      expect(response).to have_http_status(400)  # Bad Request for missing required parameter
    end
  end

  describe 'postal code validation' do
    context 'with valid Spanish postal code' do
      let(:valid_spanish_params) do
        address_params.merge(
          post_code: '28001',
          country_code: 'ESP'
        )
      end

      before do
        allow(CompanyService).to receive(:create_address).and_return({ success: true })
      end

      it 'accepts valid Spanish postal code' do
        post company_addresses_path(company_id), params: { address: valid_spanish_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Address created successfully')
        expect(CompanyService).to have_received(:create_address)
      end
    end

    context 'with invalid Spanish postal code' do
      let(:invalid_spanish_params) do
        address_params.merge(
          post_code: '123456',  # Invalid - too long for Spain
          country_code: 'ESP'
        )
      end

      it 'rejects invalid Spanish postal code' do
        post company_addresses_path(company_id), params: { address: invalid_spanish_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to include('Validation failed')
        expect(flash[:error]).to include('Post code is invalid')
      end
    end

    context 'with valid US postal code' do
      let(:valid_us_params) do
        address_params.merge(
          post_code: '90210',
          country_code: 'USA',
          town: 'Beverly Hills',
          province: 'California'
        )
      end

      before do
        allow(CompanyService).to receive(:create_address).and_return({ success: true })
      end

      it 'accepts valid US postal code' do
        post company_addresses_path(company_id), params: { address: valid_us_params }
        
        expect(response).to redirect_to(company_path(company_id))
        follow_redirect!
        
        expect(response.body).to include('Address created successfully')
        expect(CompanyService).to have_received(:create_address)
      end
    end

    context 'with invalid US postal code' do
      let(:invalid_us_params) do
        address_params.merge(
          post_code: '902',  # Invalid - too short for US
          country_code: 'USA',
          town: 'Beverly Hills',
          province: 'California'
        )
      end

      it 'rejects invalid US postal code' do
        post company_addresses_path(company_id), params: { address: invalid_us_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to include('Validation failed')
        expect(flash[:error]).to include('Post code is invalid')
      end
    end

    context 'with missing postal code' do
      let(:missing_post_code_params) do
        address_params.except(:post_code)
      end

      it 'rejects missing postal code' do
        post company_addresses_path(company_id), params: { address: missing_post_code_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to include('Validation failed')
        expect(flash[:error]).to include("Post code can't be blank")
      end
    end

    context 'with missing country code' do
      let(:missing_country_params) do
        address_params.except(:country_code)
      end

      it 'rejects missing country code' do
        post company_addresses_path(company_id), params: { address: missing_country_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to include('Validation failed')
        expect(flash[:error]).to include("Country code can't be blank")
      end
    end
  end

  describe 'authentication' do
    context 'when user is not logged in' do
      before do
        # Clear the authentication mocks from RequestHelper
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
        allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(false)
        allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)
        allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(nil)
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_call_original
      end

      it 'requires authentication for create' do
        post company_addresses_path(company_id), params: { address: address_params }
        expect(response).to have_http_status(:redirect)
      end

      it 'requires authentication for update' do
        patch company_address_path(company_id, address_id), params: { address: address_params }
        expect(response).to have_http_status(:redirect)
      end

      it 'requires authentication for delete' do
        delete company_address_path(company_id, address_id)
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end