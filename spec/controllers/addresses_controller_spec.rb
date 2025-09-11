require 'rails_helper'

RSpec.describe AddressesController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
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

  before do
    # Mock authentication for controller specs
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_token).and_return(token)
    
    # Mock CompanyService.find for all tests
    allow(CompanyService).to receive(:find).and_return(company)
  end

  describe 'POST #create' do
    context 'when successful' do
      before do
        allow(CompanyService).to receive(:create_address).and_return({ success: true })
      end

      it 'creates address and redirects to company show' do
        post :create, params: { company_id: company_id, address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:notice]).to eq('Address created successfully')
        expect(CompanyService).to have_received(:create_address)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyService).to receive(:create_address)
          .and_raise(ApiService::ValidationError.new('Validation failed', { address: ['is required'] }))
      end

      it 'sets error flash and redirects to company show' do
        post :create, params: { company_id: company_id, address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to include('Validation failed')
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyService).to receive(:create_address)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'sets error flash and redirects to company show' do
        post :create, params: { company_id: company_id, address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to eq('Server error')
      end
    end

    context 'when address creation returns errors' do
      before do
        allow(CompanyService).to receive(:create_address)
          .and_return({ errors: 'Address is invalid' })
      end

      it 'sets error flash and redirects to company show' do
        post :create, params: { company_id: company_id, address: address_params }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to include('Failed to create address')
      end
    end

    context 'when company not found' do
      before do
        allow(CompanyService).to receive(:find).with(company_id, token: token)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'sets error flash and redirects to companies index' do
        post :create, params: { company_id: company_id, address: address_params }
        
        expect(response).to redirect_to(companies_path)
        expect(flash[:error]).to eq('Company not found')
      end
    end
  end

  describe 'PATCH #update' do
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
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:update_address).with(company_id.to_s, address_id.to_s, updated_params, token: token)
          .and_return({ success: true })
      end

      it 'updates address and redirects to company show' do
        patch :update, params: { company_id: company_id, id: address_id, address: updated_params }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:notice]).to eq('Address updated successfully')
        expect(CompanyService).to have_received(:update_address).with(company_id.to_s, address_id.to_s, updated_params, token: token)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:update_address).with(company_id.to_s, address_id.to_s, updated_params, token: token)
          .and_raise(ApiService::ValidationError.new('Validation failed', { town: ['is required'] }))
      end

      it 'sets error flash and redirects to company show' do
        patch :update, params: { company_id: company_id, id: address_id, address: updated_params }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:error]).to include('Validation failed')
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:update_address).with(company_id.to_s, address_id.to_s, updated_params, token: token)
          .and_raise(ApiService::ApiError.new('Address not found'))
      end

      it 'sets error flash and redirects to company show' do
        patch :update, params: { company_id: company_id, id: address_id, address: updated_params }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:error]).to eq('Address not found')
      end
    end

    context 'when update returns errors' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:update_address).with(company_id.to_s, address_id.to_s, updated_params, token: token)
          .and_return({ errors: 'Update failed' })
      end

      it 'sets error flash and redirects to company show' do
        patch :update, params: { company_id: company_id, id: address_id, address: updated_params }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:error]).to include('Failed to update address')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when successful' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:destroy_address).with(company_id.to_s, address_id.to_s, token: token)
          .and_return({ success: true })
      end

      it 'deletes address and redirects to company show' do
        delete :destroy, params: { company_id: company_id, id: address_id }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:notice]).to eq('Address deleted successfully')
        expect(CompanyService).to have_received(:destroy_address).with(company_id.to_s, address_id.to_s, token: token)
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:destroy_address).with(company_id.to_s, address_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Cannot delete address'))
      end

      it 'sets error flash and redirects to company show' do
        delete :destroy, params: { company_id: company_id, id: address_id }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:error]).to eq('Cannot delete address')
      end
    end

    context 'when delete returns errors' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:destroy_address).with(company_id.to_s, address_id.to_s, token: token)
          .and_return({ errors: 'Delete failed' })
      end

      it 'sets error flash and redirects to company show' do
        delete :destroy, params: { company_id: company_id, id: address_id }
        
        expect(response).to redirect_to(company_path(company_id.to_s))
        expect(flash[:error]).to include('Failed to delete address')
      end
    end
  end

  describe 'parameter handling' do
    context 'with invalid parameters' do
      it 'filters out unpermitted parameters' do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:create_address).and_return({ success: true })

        post :create, params: { 
          company_id: company_id, 
          address: address_params.merge(
            unauthorized_field: 'should be filtered',
            malicious_script: '<script>alert("xss")</script>'
          )
        }
        
        expect(CompanyService).to have_received(:create_address) do |company_id, params, options|
          expect(params.keys).to match_array([:address, :post_code, :town, :province, :country_code, :address_type, :is_default])
          expect(params[:unauthorized_field]).to be_nil
          expect(params[:malicious_script]).to be_nil
        end
      end
    end

    context 'with missing required parameters' do
      it 'handles missing address parameter gracefully' do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        
        expect {
          post :create, params: { company_id: company_id }
        }.to raise_error(ActionController::ParameterMissing)
      end
    end
  end

  describe 'authentication and authorization' do
    context 'when user is not authenticated' do
      before do
        allow(controller).to receive(:logged_in?).and_return(false)
        allow(controller).to receive(:authenticate_user!).and_call_original
        allow(controller).to receive(:redirect_to)
      end

      it 'redirects to login for create action' do
        post :create, params: { company_id: company_id, address: address_params }
        expect(controller).to have_received(:authenticate_user!)
      end

      it 'redirects to login for update action' do
        patch :update, params: { company_id: company_id, id: address_id, address: address_params }
        expect(controller).to have_received(:authenticate_user!)
      end

      it 'redirects to login for destroy action' do
        delete :destroy, params: { company_id: company_id, id: address_id }
        expect(controller).to have_received(:authenticate_user!)
      end
    end
  end

  describe 'error handling edge cases' do
    context 'when network errors occur' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:create_address)
          .and_raise(Net::TimeoutError.new('Request timeout'))
      end

      it 'handles network timeouts gracefully' do
        expect {
          post :create, params: { company_id: company_id, address: address_params }
        }.to raise_error(Net::TimeoutError)
      end
    end

    context 'when unexpected errors occur' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
        allow(CompanyService).to receive(:create_address)
          .and_raise(StandardError.new('Unexpected error'))
      end

      it 'allows unexpected errors to bubble up' do
        expect {
          post :create, params: { company_id: company_id, address: address_params }
        }.to raise_error(StandardError, 'Unexpected error')
      end
    end
  end
end