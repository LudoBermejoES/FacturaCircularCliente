require 'rails_helper'

RSpec.describe CompanyContactsController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company_id) { 123 }
  let(:contact_id) { 456 }
  let(:company) { build(:company_response, id: company_id) }
  let(:contact) { build(:company_contact_response, id: contact_id) }
  
  let(:contact_params) do
    {
      name: 'John',
      first_surname: 'Doe',
      second_surname: 'Smith',
      email: 'john.doe@example.com',
      telephone: '+34612345678',
      contact_details: 'Sales Manager'
    }
  end

  before do
    # Mock authentication for controller specs
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_token).and_return(token)
    
    # Mock CompanyService.find for all tests
    allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
  end

  describe 'GET #index' do
    let(:contacts_list) { [contact, build(:company_contact_response)] }
    let(:contacts_response) { { contacts: contacts_list, meta: { total: 2, page: 1, pages: 1 } } }

    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:all)
          .with(company_id: company[:id], token: token, params: { page: 1, per_page: 25 })
          .and_return(contacts_response)
      end

      it 'fetches all company contacts and renders index' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
        expect(assigns(:company)).to eq(company)
        expect(assigns(:contacts)).to eq(contacts_list)
        expect(CompanyContactsService).to have_received(:all).with(
          company_id: company[:id], 
          token: token, 
          params: { page: 1, per_page: 25 }
        )
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:all)
          .with(company_id: company[:id], token: token, params: { page: 1, per_page: 25 })
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'sets flash alert and renders index with empty contacts' do
        get :index, params: { company_id: company_id }
        
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
        expect(flash.now[:alert]).to eq('Error loading contacts: Server error')
        expect(assigns(:contacts)).to eq([])
      end
    end

    context 'when company not found' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'sets alert flash and redirects to companies index' do
        get :index, params: { company_id: company_id }
        
        expect(response).to redirect_to(companies_path)
        expect(flash[:alert]).to eq('Company not found: Company not found')
      end
    end
  end

  describe 'GET #new' do
    context 'when successful' do
      it 'renders new contact form' do
        get :new, params: { company_id: company_id }
        
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:new)
        expect(assigns(:company)).to eq(company)
        expect(assigns(:contact)).to be_present
      end
    end

    context 'when company not found' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'sets alert flash and redirects to companies index' do
        get :new, params: { company_id: company_id }
        
        expect(response).to redirect_to(companies_path)
        expect(flash[:alert]).to eq('Company not found: Company not found')
      end
    end
  end

  describe 'POST #create' do
    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:create)
          .with(company_id: company[:id], params: instance_of(ActionController::Parameters), token: token)
          .and_return({ id: contact_id })
      end

      it 'creates contact and redirects to company contacts index' do
        post :create, params: { company_id: company_id, company_contact: contact_params }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:notice]).to eq('Contact was successfully created.')
        expect(CompanyContactsService).to have_received(:create)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyContactsService).to receive(:create)
          .with(company_id: company[:id], params: instance_of(ActionController::Parameters), token: token)
          .and_raise(ApiService::ValidationError.new('Validation failed', { name: ['is required'] }))
      end

      it 'sets flash alert and renders new template' do
        post :create, params: { company_id: company_id, company_contact: contact_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(flash.now[:alert]).to eq('There were errors creating the contact.')
        expect(assigns(:contact)).to be_a(ActionController::Parameters)
        expect(assigns(:errors)).to eq({ name: ['is required'] })
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:create)
          .with(company_id: company[:id], params: instance_of(ActionController::Parameters), token: token)
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets flash alert and renders new template' do
        post :create, params: { company_id: company_id, company_contact: contact_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(flash.now[:alert]).to eq('Error creating contact: API error')
        expect(assigns(:contact)).to be_a(ActionController::Parameters)
      end
    end

    context 'when company not found' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'sets alert flash and redirects to companies index' do
        post :create, params: { company_id: company_id, company_contact: contact_params }
        
        expect(response).to redirect_to(companies_path)
        expect(flash[:alert]).to eq('Company not found: Company not found')
      end
    end
  end

  describe 'GET #edit' do
    before do
      allow(CompanyContactsService).to receive(:find)
        .with(company_id: company[:id], id: contact_id.to_s, token: token)
        .and_return(contact)
    end

    context 'when successful' do
      it 'renders edit contact form' do
        get :edit, params: { company_id: company_id, id: contact_id }
        
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:edit)
        expect(assigns(:company)).to eq(company)
        expect(assigns(:contact)).to eq(contact)
      end
    end

    context 'when contact not found' do
      before do
        allow(CompanyContactsService).to receive(:find)
          .with(company_id: company[:id], id: contact_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Contact not found'))
      end

      it 'sets alert flash and redirects to company contacts index' do
        get :edit, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:alert]).to eq('Contact not found: Contact not found')
      end
    end

    context 'when company not found' do
      before do
        allow(CompanyService).to receive(:find).with(company_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'sets alert flash and redirects to companies index' do
        get :edit, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(companies_path)
        expect(flash[:alert]).to eq('Company not found: Company not found')
      end
    end
  end

  describe 'PATCH #update' do
    before do
      allow(CompanyContactsService).to receive(:find)
        .with(company_id: company[:id], id: contact_id.to_s, token: token)
        .and_return(contact)
    end

    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:update)
          .with(company_id: company[:id], id: contact[:id], params: instance_of(ActionController::Parameters), token: token)
          .and_return(true)
      end

      it 'updates contact and redirects to company contacts index' do
        patch :update, params: { company_id: company_id, id: contact_id, company_contact: contact_params }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:notice]).to eq('Contact was successfully updated.')
        expect(CompanyContactsService).to have_received(:update)
      end
    end

    context 'when validation fails' do
      before do
        allow(CompanyContactsService).to receive(:update)
          .with(company_id: company[:id], id: contact[:id], params: instance_of(ActionController::Parameters), token: token)
          .and_raise(ApiService::ValidationError.new('Validation failed', { name: ['is required'] }))
      end

      it 'sets flash alert and renders edit template' do
        patch :update, params: { company_id: company_id, id: contact_id, company_contact: contact_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
        expect(flash.now[:alert]).to eq('There were errors updating the contact.')
        expect(assigns(:errors)).to eq({ name: ['is required'] })
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:update)
          .with(company_id: company[:id], id: contact[:id], params: instance_of(ActionController::Parameters), token: token)
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets flash alert and renders edit template' do
        patch :update, params: { company_id: company_id, id: contact_id, company_contact: contact_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
        expect(flash.now[:alert]).to eq('Error updating contact: API error')
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      allow(CompanyContactsService).to receive(:find)
        .with(company_id: company[:id], id: contact_id.to_s, token: token)
        .and_return(contact)
    end

    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:destroy)
          .with(company_id: company[:id], id: contact[:id], token: token)
          .and_return(true)
      end

      it 'deletes contact and redirects to company contacts index' do
        delete :destroy, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:notice]).to eq('Contact was successfully deleted.')
        expect(CompanyContactsService).to have_received(:destroy)
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:destroy)
          .with(company_id: company[:id], id: contact[:id], token: token)
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets alert flash and redirects to company contacts index' do
        delete :destroy, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:alert]).to eq('Error deleting contact: API error')
      end
    end
  end

  describe 'PATCH #activate' do
    before do
      allow(CompanyContactsService).to receive(:find)
        .with(company_id: company[:id], id: contact_id.to_s, token: token)
        .and_return(contact)
    end

    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:activate)
          .with(company_id: company[:id], id: contact[:id], token: token)
          .and_return(true)
      end

      it 'activates contact and redirects to company contacts index' do
        patch :activate, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:notice]).to eq('Contact was successfully activated.')
        expect(CompanyContactsService).to have_received(:activate)
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:activate)
          .with(company_id: company[:id], id: contact[:id], token: token)
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets alert flash and redirects to company contacts index' do
        patch :activate, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:alert]).to eq('Error activating contact: API error')
      end
    end
  end

  describe 'PATCH #deactivate' do
    before do
      allow(CompanyContactsService).to receive(:find)
        .with(company_id: company[:id], id: contact_id.to_s, token: token)
        .and_return(contact)
    end

    context 'when successful' do
      before do
        allow(CompanyContactsService).to receive(:deactivate)
          .with(company_id: company[:id], id: contact[:id], token: token)
          .and_return(true)
      end

      it 'deactivates contact and redirects to company contacts index' do
        patch :deactivate, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:notice]).to eq('Contact was successfully deactivated.')
        expect(CompanyContactsService).to have_received(:deactivate)
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactsService).to receive(:deactivate)
          .with(company_id: company[:id], id: contact[:id], token: token)
          .and_raise(ApiService::ApiError.new('API error'))
      end

      it 'sets alert flash and redirects to company contacts index' do
        patch :deactivate, params: { company_id: company_id, id: contact_id }
        
        expect(response).to redirect_to(company_company_contacts_path(company[:id]))
        expect(flash[:alert]).to eq('Error deactivating contact: API error')
      end
    end
  end

  describe 'authentication and authorization' do
    before do
      allow(controller).to receive(:authenticate_user!).and_call_original
      allow(controller).to receive(:logged_in?).and_return(false)
    end

    it 'redirects to login for index action' do
      get :index, params: { company_id: company_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for create action' do
      post :create, params: { company_id: company_id, company_contact: contact_params }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for update action' do
      patch :update, params: { company_id: company_id, id: contact_id, company_contact: contact_params }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for destroy action' do
      delete :destroy, params: { company_id: company_id, id: contact_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for activate action' do
      patch :activate, params: { company_id: company_id, id: contact_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end

    it 'redirects to login for deactivate action' do
      patch :deactivate, params: { company_id: company_id, id: contact_id }
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('Please sign in to continue')
    end
  end
end