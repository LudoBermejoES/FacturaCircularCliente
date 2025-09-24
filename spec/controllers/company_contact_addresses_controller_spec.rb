require 'rails_helper'

RSpec.describe CompanyContactAddressesController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company_id) { 123 }
  let(:contact_id) { 456 }
  let(:address_id) { 789 }
  let(:company) { build(:company_response, id: company_id) }
  let(:contact) { build(:company_contact_response, id: contact_id) }
  let(:address) { build(:address_response, id: address_id) }

  let(:address_params) do
    {
      street_address: 'Calle Mayor 123',
      city: 'Madrid',
      postal_code: '28001',
      country_code: 'ESP',
      address_type: 'billing',
      is_default: false
    }
  end

  before do
    # Mock authentication for controller specs
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_token).and_return(token)

    # Mock company and contact lookups for all tests
    allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
    allow(CompanyContactService).to receive(:find).with(contact_id.to_s, company_id: company[:id], token: token).and_return(contact)
  end

  describe 'GET #index' do
    let(:addresses_list) { [address, build(:address_response)] }
    let(:addresses_response) { { addresses: addresses_list, meta: { total: 2, page: 1, pages: 1 } } }

    context 'when successful' do
      before do
        allow(CompanyContactAddressService).to receive(:all)
          .with(company_id: company[:id], contact_id: contact[:id], token: token)
          .and_return(addresses_response)
      end

      it 'fetches all addresses and renders index' do
        get :index, params: { company_id: company_id, company_contact_id: contact_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
        expect(assigns(:company)).to eq(company)
        expect(assigns(:contact)).to eq(contact)
        expect(assigns(:addresses)).to eq(addresses_list)
        expect(CompanyContactAddressService).to have_received(:all).with(
          company_id: company[:id],
          contact_id: contact[:id],
          token: token
        )
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactAddressService).to receive(:all)
          .with(company_id: company[:id], contact_id: contact[:id], token: token)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'sets flash alert and renders index with empty addresses' do
        get :index, params: { company_id: company_id, company_contact_id: contact_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
        expect(flash.now[:alert]).to eq('Error loading addresses: Server error')
        expect(assigns(:addresses)).to eq([])
      end
    end

    context 'when contact not found' do
      before do
        allow(CompanyContactService).to receive(:find)
          .with(contact_id.to_s, company_id: company[:id], token: token)
          .and_raise(ApiService::ApiError.new('Contact not found'))
      end

      it 'sets alert flash and redirects to contacts index' do
        get :index, params: { company_id: company_id, company_contact_id: contact_id }

        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:alert]).to eq('Contact not found: Contact not found')
      end
    end
  end

  describe 'GET #new' do
    context 'when successful' do
      it 'renders new address form' do
        get :new, params: { company_id: company_id, company_contact_id: contact_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:new)
        expect(assigns(:company)).to eq(company)
        expect(assigns(:contact)).to eq(contact)
        expect(assigns(:address)).to be_present
        expect(assigns(:address)[:is_default]).to be(true) # First address should be default
      end
    end

    context 'when contact not found' do
      before do
        allow(CompanyContactService).to receive(:find)
          .with(contact_id.to_s, company_id: company[:id], token: token)
          .and_raise(ApiService::ApiError.new('Contact not found'))
      end

      it 'sets alert flash and redirects to contacts index' do
        get :new, params: { company_id: company_id, company_contact_id: contact_id }

        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:alert]).to eq('Contact not found: Contact not found')
      end
    end
  end

  describe 'POST #create' do
    context 'when successful' do
      before do
        allow(CompanyContactAddressService).to receive(:create)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_return({ data: { id: address_id } })
      end

      it 'creates address and redirects to addresses index' do
        post :create, params: { company_id: company_id, company_contact_id: contact_id, address: address_params }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:notice]).to eq('Address was successfully created.')
        expect(CompanyContactAddressService).to have_received(:create)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyContactAddressService).to receive(:create)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_raise(ApiService::ValidationError.new('Validation failed', { street_address: ['is required'] }))
      end

      it 'sets flash alert and renders new template' do
        post :create, params: { company_id: company_id, company_contact_id: contact_id, address: address_params }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
        expect(flash.now[:alert]).to eq('There were errors creating the address.')
        expect(assigns(:address)).to be_a(ActionController::Parameters)
        expect(assigns(:errors)).to eq({ street_address: ['is required'] })
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactAddressService).to receive(:create)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets flash alert and renders new template' do
        post :create, params: { company_id: company_id, company_contact_id: contact_id, address: address_params }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
        expect(flash.now[:alert]).to eq('Error creating address: API error')
        expect(assigns(:address)).to be_a(ActionController::Parameters)
      end
    end
  end

  describe 'GET #edit' do
    before do
      allow(CompanyContactAddressService).to receive(:find)
        .with(
          company_id: company[:id],
          contact_id: contact[:id],
          address_id: address_id.to_s,
          token: token
        )
        .and_return(address)
    end

    context 'when successful' do
      it 'renders edit address form' do
        get :edit, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:edit)
        expect(assigns(:company)).to eq(company)
        expect(assigns(:contact)).to eq(contact)
        expect(assigns(:address)).to eq(address)
      end
    end

    context 'when address not found' do
      before do
        allow(CompanyContactAddressService).to receive(:find)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address_id.to_s,
            token: token
          )
          .and_raise(ApiService::ApiError.new('Address not found'))
      end

      it 'sets alert flash and redirects to addresses index' do
        get :edit, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:alert]).to eq('Address not found: Address not found')
      end
    end
  end

  describe 'PATCH #update' do
    before do
      allow(CompanyContactAddressService).to receive(:find)
        .with(
          company_id: company[:id],
          contact_id: contact[:id],
          address_id: address_id.to_s,
          token: token
        )
        .and_return(address)
    end

    context 'when successful' do
      before do
        allow(CompanyContactAddressService).to receive(:update)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_return({ data: { id: address_id } })
      end

      it 'updates address and redirects to addresses index' do
        patch :update, params: { company_id: company_id, company_contact_id: contact_id, id: address_id, address: address_params }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:notice]).to eq('Address was successfully updated.')
        expect(CompanyContactAddressService).to have_received(:update)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyContactAddressService).to receive(:update)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_raise(ApiService::ValidationError.new('Validation failed', { city: ['is required'] }))
      end

      it 'sets flash alert and renders edit template' do
        patch :update, params: { company_id: company_id, company_contact_id: contact_id, id: address_id, address: address_params }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:edit)
        expect(flash.now[:alert]).to eq('There were errors updating the address.')
        expect(assigns(:errors)).to eq({ city: ['is required'] })
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactAddressService).to receive(:update)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets flash alert and renders edit template' do
        patch :update, params: { company_id: company_id, company_contact_id: contact_id, id: address_id, address: address_params }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:edit)
        expect(flash.now[:alert]).to eq('Error updating address: API error')
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      allow(CompanyContactAddressService).to receive(:find)
        .with(
          company_id: company[:id],
          contact_id: contact[:id],
          address_id: address_id.to_s,
          token: token
        )
        .and_return(address)
    end

    context 'when successful' do
      before do
        allow(CompanyContactAddressService).to receive(:delete)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            token: token
          )
          .and_return(true)
      end

      it 'deletes address and redirects to addresses index' do
        delete :destroy, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:notice]).to eq('Address was successfully deleted.')
        expect(CompanyContactAddressService).to have_received(:delete)
      end
    end

    context 'when cannot delete default address' do
      before do
        allow(CompanyContactAddressService).to receive(:delete)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            token: token
          )
          .and_raise(ApiService::ApiError.new('Cannot delete the only address or default address'))
      end

      it 'sets alert flash and redirects to addresses index' do
        delete :destroy, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:alert]).to eq('Error deleting address: Cannot delete the only address or default address')
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactAddressService).to receive(:delete)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            token: token
          )
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets alert flash and redirects to addresses index' do
        delete :destroy, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:alert]).to eq('Error deleting address: API error')
      end
    end
  end

  describe 'POST #set_default' do
    before do
      allow(CompanyContactAddressService).to receive(:find)
        .with(
          company_id: company[:id],
          contact_id: contact[:id],
          address_id: address_id.to_s,
          token: token
        )
        .and_return(address)
    end

    context 'when successful' do
      before do
        allow(CompanyContactAddressService).to receive(:set_default)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            token: token
          )
          .and_return({ data: { id: address_id, attributes: { is_default: true } } })
      end

      it 'sets address as default and redirects to addresses index' do
        post :set_default, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:notice]).to eq('Address was successfully set as default.')
        expect(CompanyContactAddressService).to have_received(:set_default)
      end

      context 'when request is AJAX' do
        before do
          request.headers['Accept'] = 'application/json'
          request.headers['X-Requested-With'] = 'XMLHttpRequest'
        end

        it 'returns JSON response' do
          post :set_default, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq('application/json; charset=utf-8')

          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be(true)
          expect(json_response['message']).to eq('Address was successfully set as default.')
        end
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactAddressService).to receive(:set_default)
          .with(
            company_id: company[:id],
            contact_id: contact[:id],
            address_id: address[:id],
            token: token
          )
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets alert flash and redirects to addresses index' do
        post :set_default, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

        expect(response).to redirect_to(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(flash[:alert]).to eq('Error setting default address: API error')
      end

      context 'when request is AJAX' do
        before do
          request.headers['Accept'] = 'application/json'
          request.headers['X-Requested-With'] = 'XMLHttpRequest'
        end

        it 'returns JSON error response' do
          post :set_default, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.content_type).to eq('application/json; charset=utf-8')

          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be(false)
          expect(json_response['message']).to eq('API error')
        end
      end
    end
  end

  describe 'authentication and authorization' do
    before do
      allow(controller).to receive(:authenticate_user!).and_call_original
      allow(controller).to receive(:logged_in?).and_return(false)
    end

    it 'redirects to login for index action' do
      get :index, params: { company_id: company_id, company_contact_id: contact_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for create action' do
      post :create, params: { company_id: company_id, company_contact_id: contact_id, address: address_params }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for update action' do
      patch :update, params: { company_id: company_id, company_contact_id: contact_id, id: address_id, address: address_params }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for destroy action' do
      delete :destroy, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for set_default action' do
      post :set_default, params: { company_id: company_id, company_contact_id: contact_id, id: address_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end
  end
end