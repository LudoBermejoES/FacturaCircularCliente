require 'rails_helper'

RSpec.describe InvoicesController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:invoice_id) { 123 }
  let(:company_id) { 456 }
  let(:contact_id) { 789 }
  
  let(:company) { build(:company_response, id: company_id) }
  let(:invoice) { build(:invoice_response, id: invoice_id, company_id: company_id, buyer_company_contact_id: contact_id) }
  let(:contact) { build(:company_contact_response, id: contact_id, name: 'John', full_name: 'John Doe') }
  
  let(:invoice_params) do
    {
      invoice_number: 'INV-001',
      invoice_type: 'invoice',
      date: '2024-01-15',
      due_date: '2024-02-15',
      seller_party_id: company_id,
      buyer_party_id: company_id + 1,
      buyer_company_contact_id: contact_id,
      notes: 'Test invoice',
      invoice_lines: {
        '0' => {
          description: 'Test item',
          quantity: '2',
          unit_price: '100.0',
          tax_rate: '21.0'
        }
      }
    }
  end

  before do
    # Mock authentication
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_token).and_return(token)
    allow(controller).to receive(:can?).and_return(true)
  end

  describe 'GET #new' do
    let(:companies) { [company, build(:company_response, id: company_id + 1)] }
    let(:invoice_series) { [{ id: 1, name: 'FC', year: 2024 }] }
    let(:company_contacts) { { company_id.to_s => [contact] } }

    before do
      allow(CompanyService).to receive(:all).and_return({ companies: companies })
      allow(InvoiceSeriesService).to receive(:all).and_return(invoice_series)
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact])
    end

    context 'when successful' do
      it 'initializes a new invoice with default values and loads company contacts' do
        get :new
        
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:new)
        
        invoice = assigns(:invoice)
        expect(invoice[:invoice_type]).to eq('invoice')
        expect(invoice[:status]).to eq('draft')
        expect(invoice[:buyer_company_contact_id]).to be_nil
        expect(invoice[:invoice_lines]).to be_an(Array)
        expect(invoice[:invoice_lines].first).to include(:description, :quantity, :unit_price)
        
        expect(assigns(:companies)).to eq(companies)
        expect(assigns(:invoice_series)).to eq(invoice_series)
        expect(assigns(:company_contacts)).to be_a(Hash)
        expect(CompanyContactsService).to have_received(:active_contacts).at_least(:once)
      end

      it 'pre-fills buyer_company_contact_id when provided in params' do
        get :new, params: { buyer_company_contact_id: contact_id }
        
        invoice = assigns(:invoice)
        expect(invoice[:buyer_company_contact_id]).to eq(contact_id.to_s)
      end

      it 'loads company contacts for all companies' do
        get :new
        
        expect(CompanyContactsService).to have_received(:active_contacts)
          .with(company_id: company_id, token: token)
        expect(CompanyContactsService).to have_received(:active_contacts)
          .with(company_id: company_id + 1, token: token)
      end
    end

    context 'when company contacts service fails' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::ApiError.new('Company contacts service unavailable'))
      end

      it 'sets empty contacts array and continues' do
        get :new
        
        expect(response).to have_http_status(:ok)
        company_contacts = assigns(:company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([])
      end
    end
  end

  describe 'POST #create' do
    let(:companies) { [company] }
    let(:invoice_series) { [{ id: 1, name: 'FC' }] }
    let(:created_invoice) { { data: { id: invoice_id } } }

    before do
      allow(CompanyService).to receive(:all).and_return({ companies: companies })
      allow(InvoiceSeriesService).to receive(:all).and_return(invoice_series)
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact])
    end

    context 'when successful' do
      before do
        allow(InvoiceService).to receive(:create).and_return(created_invoice)
      end

      it 'creates invoice with company contact and redirects' do
        post :create, params: { invoice: invoice_params }
        
        expect(InvoiceService).to have_received(:create) do |params, options|
          expect(params[:buyer_company_contact_id]).to eq(contact_id.to_s)
          expect(params[:invoice_lines_attributes]).to be_an(Array)
          expect(params[:invoice_lines_attributes].first[:description]).to eq('Test item')
          expect(options[:token]).to eq(token)
        end
        
        expect(response).to redirect_to(invoice_path(invoice_id))
        expect(flash[:notice]).to eq('Invoice created successfully')
      end

      it 'processes invoice lines correctly' do
        post :create, params: { invoice: invoice_params }
        
        expect(InvoiceService).to have_received(:create) do |params, options|
          lines = params[:invoice_lines_attributes]
          expect(lines.length).to eq(1)
          expect(lines.first['description']).to eq('Test item')
          expect(lines.first['quantity']).to eq(2.0)
          expect(lines.first['unit_price']).to eq(100.0)
          expect(lines.first['tax_rate']).to eq(21.0)
        end
      end

      it 'filters out empty invoice lines' do
        invoice_params_with_empty_line = invoice_params.deep_dup
        invoice_params_with_empty_line[:invoice_lines]['1'] = {
          description: '',
          quantity: '',
          unit_price: '',
          tax_rate: '21.0'
        }

        post :create, params: { invoice: invoice_params_with_empty_line }
        
        expect(InvoiceService).to have_received(:create) do |params, options|
          lines = params[:invoice_lines_attributes]
          expect(lines.length).to eq(1) # Only the non-empty line
        end
      end
    end

    context 'when validation fails' do
      let(:validation_error) do
        ApiService::ValidationError.new('Validation failed', [
          {
            status: '422',
            source: { pointer: '/data/attributes/buyer_company_contact_id' },
            title: 'Validation Error',
            detail: 'Buyer company contact must belong to the buyer company',
            code: 'VALIDATION_ERROR'
          }
        ])
      end

      before do
        allow(InvoiceService).to receive(:create).and_raise(validation_error)
      end

      it 'handles validation errors and re-renders form with contacts loaded' do
        post :create, params: { invoice: invoice_params }
        
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash.now[:alert]).to eq('Please fix the errors below.')
        
        # Check that company contacts are reloaded
        expect(assigns(:company_contacts)).to be_present
        expect(CompanyContactsService).to have_received(:active_contacts)
        
        # Check that errors are properly parsed
        errors = assigns(:errors)
        expect(errors['buyer_company_contact_id']).to include('must belong to the buyer company')
      end

      it 'preserves invoice data including company contact selection' do
        post :create, params: { invoice: invoice_params }
        
        invoice = assigns(:invoice)
        expect(invoice[:buyer_company_contact_id]).to eq(contact_id.to_s)
        expect(invoice[:invoice_lines]).to be_present
      end
    end

    context 'when API error occurs' do
      before do
        allow(InvoiceService).to receive(:create)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'handles API errors and reloads company contacts' do
        post :create, params: { invoice: invoice_params }
        
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash.now[:alert]).to eq('Error creating invoice: Server error')
        
        expect(assigns(:company_contacts)).to be_present
        expect(CompanyContactsService).to have_received(:active_contacts)
      end
    end
  end

  describe 'GET #edit' do
    let(:companies) { [company] }
    let(:invoice_series) { [{ id: 1, name: 'FC' }] }

    before do
      allow(InvoiceService).to receive(:find).and_return(invoice)
      allow(CompanyService).to receive(:all).and_return({ companies: companies })
      allow(InvoiceSeriesService).to receive(:all).and_return(invoice_series)
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact])
    end

    context 'when successful' do
      it 'loads invoice and company contacts for editing' do
        get :edit, params: { id: invoice_id }
        
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:edit)
        
        expect(assigns(:invoice)).to eq(invoice)
        expect(assigns(:companies)).to eq(companies)
        expect(assigns(:company_contacts)).to be_a(Hash)
        
        expect(InvoiceService).to have_received(:find).with(invoice_id.to_s, token: token)
        expect(CompanyContactsService).to have_received(:active_contacts)
      end

      it 'ensures invoice has invoice_lines array' do
        invoice_without_lines = invoice.except(:invoice_lines)
        allow(InvoiceService).to receive(:find).and_return(invoice_without_lines)
        
        get :edit, params: { id: invoice_id }
        
        updated_invoice = assigns(:invoice)
        expect(updated_invoice[:invoice_lines]).to be_an(Array)
        expect(updated_invoice[:invoice_lines]).not_to be_empty
      end
    end

    context 'when invoice not found' do
      before do
        allow(InvoiceService).to receive(:find)
          .and_raise(ApiService::ApiError.new('Invoice not found'))
      end

      it 'redirects to invoices index with error message' do
        get :edit, params: { id: invoice_id }
        
        expect(response).to redirect_to(invoices_path)
        expect(flash[:alert]).to eq('Invoice not found: Invoice not found')
      end
    end
  end

  describe 'PATCH #update' do
    let(:companies) { [company] }
    let(:invoice_series) { [{ id: 1, name: 'FC' }] }
    let(:updated_params) { invoice_params.merge(buyer_company_contact_id: contact_id + 1) }

    before do
      allow(InvoiceService).to receive(:find).and_return(invoice)
      allow(CompanyService).to receive(:all).and_return({ companies: companies })
      allow(InvoiceSeriesService).to receive(:all).and_return(invoice_series)
      allow(CompanyContactsService).to receive(:active_contacts).and_return([contact])
    end

    context 'when successful' do
      before do
        allow(InvoiceService).to receive(:update).and_return(true)
      end

      it 'updates invoice with new company contact' do
        patch :update, params: { id: invoice_id, invoice: updated_params }
        
        expect(InvoiceService).to have_received(:update) do |id, params, options|
          expect(id).to eq(invoice_id)
          expect(params[:buyer_company_contact_id]).to eq((contact_id + 1).to_s)
          expect(options[:token]).to eq(token)
        end
        
        expect(response).to redirect_to(invoice_path(invoice_id))
        expect(flash[:notice]).to eq('Invoice updated successfully')
      end

      it 'processes updated invoice lines' do
        patch :update, params: { id: invoice_id, invoice: updated_params }
        
        expect(InvoiceService).to have_received(:update) do |id, params, options|
          lines = params[:invoice_lines_attributes]
          expect(lines).to be_an(Array)
          expect(lines.first[:description]).to eq('Test item')
        end
      end
    end

    context 'when validation fails with company contact error' do
      let(:validation_error) do
        ApiService::ValidationError.new('Validation failed', [
          {
            status: '422',
            source: { pointer: '/data/attributes/buyer_company_contact_id' },
            title: 'Validation Error',
            detail: 'Buyer company contact is not active',
            code: 'VALIDATION_ERROR'
          }
        ])
      end

      before do
        allow(InvoiceService).to receive(:update).and_raise(validation_error)
      end

      it 'handles validation errors and reloads company contacts' do
        patch :update, params: { id: invoice_id, invoice: updated_params }
        
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash.now[:alert]).to eq('Please fix the errors below.')
        
        expect(assigns(:company_contacts)).to be_present
        expect(CompanyContactsService).to have_received(:active_contacts)
        
        errors = assigns(:errors)
        expect(errors['buyer_company_contact_id']).to include('is not active')
      end
    end

    context 'when API error occurs' do
      before do
        allow(InvoiceService).to receive(:update)
          .and_raise(ApiService::ApiError.new('Invoice is frozen'))
      end

      it 'handles API errors and reloads company contacts' do
        patch :update, params: { id: invoice_id, invoice: updated_params }
        
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash.now[:alert]).to eq('Error updating invoice: Invoice is frozen')
        
        expect(assigns(:company_contacts)).to be_present
        expect(CompanyContactsService).to have_received(:active_contacts)
      end
    end
  end

  describe 'private methods' do
    describe '#load_company_contacts' do
      it 'loads contacts for specific company' do
        allow(CompanyContactsService).to receive(:active_contacts).and_return([contact])
        
        controller.send(:load_company_contacts, company_id)
        
        company_contacts = controller.instance_variable_get(:@company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([contact])
        expect(CompanyContactsService).to have_received(:active_contacts)
          .with(company_id: company_id, token: token)
      end

      it 'returns empty hash when company_id is nil' do
        controller.send(:load_company_contacts, nil)
        
        company_contacts = controller.instance_variable_get(:@company_contacts)
        expect(company_contacts).to eq({})
      end

      it 'handles API errors gracefully' do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::ApiError.new('Service unavailable'))
        
        controller.send(:load_company_contacts, company_id)
        
        company_contacts = controller.instance_variable_get(:@company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([])
      end
    end

    describe '#load_all_company_contacts' do
      let(:companies) { [company, build(:company_response, id: company_id + 1)] }
      
      before do
        controller.instance_variable_set(:@companies, companies)
      end

      it 'loads contacts for all companies' do
        allow(CompanyContactsService).to receive(:active_contacts).and_return([contact])
        
        controller.send(:load_all_company_contacts)
        
        company_contacts = controller.instance_variable_get(:@company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([contact])
        expect(company_contacts[(company_id + 1).to_s]).to eq([contact])
        
        expect(CompanyContactsService).to have_received(:active_contacts)
          .with(company_id: company_id, token: token)
        expect(CompanyContactsService).to have_received(:active_contacts)
          .with(company_id: company_id + 1, token: token)
      end

      it 'handles mixed success and failure scenarios' do
        allow(CompanyContactsService).to receive(:active_contacts)
          .with(company_id: company_id, token: token)
          .and_return([contact])
        allow(CompanyContactsService).to receive(:active_contacts)
          .with(company_id: company_id + 1, token: token)
          .and_raise(ApiService::ApiError.new('Service unavailable'))
        
        controller.send(:load_all_company_contacts)
        
        company_contacts = controller.instance_variable_get(:@company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([contact])
        expect(company_contacts[(company_id + 1).to_s]).to eq([])
      end

      it 'returns empty hash when no companies present' do
        controller.instance_variable_set(:@companies, nil)
        
        controller.send(:load_all_company_contacts)
        
        company_contacts = controller.instance_variable_get(:@company_contacts)
        expect(company_contacts).to eq({})
      end
    end

    describe '#invoice_params' do
      it 'permits buyer_company_contact_id parameter' do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new(invoice: invoice_params)
        )
        
        permitted_params = controller.send(:invoice_params)
        expect(permitted_params[:buyer_company_contact_id]).to eq(contact_id)
      end
    end
  end

  describe 'company contacts integration' do
    let(:companies) { [company] }
    
    before do
      allow(CompanyService).to receive(:all).and_return({ companies: companies })
      allow(InvoiceSeriesService).to receive(:all).and_return([])
    end

    context 'when company has no contacts' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts).and_return([])
      end

      it 'handles empty contacts gracefully in new action' do
        get :new
        
        expect(response).to have_http_status(:ok)
        company_contacts = assigns(:company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([])
      end
    end

    context 'when company contacts service is down' do
      before do
        allow(CompanyContactsService).to receive(:active_contacts)
          .and_raise(ApiService::ApiError.new('Service unavailable'))
      end

      it 'continues with empty contacts in new action' do
        get :new
        
        expect(response).to have_http_status(:ok)
        company_contacts = assigns(:company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([])
      end

      it 'continues with empty contacts in create action when validation fails' do
        allow(InvoiceService).to receive(:create)
          .and_raise(ApiService::ValidationError.new('Validation failed', []))
        
        post :create, params: { invoice: invoice_params }
        
        expect(response).to render_template(:new)
        company_contacts = assigns(:company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([])
      end
    end

    context 'when company contacts service returns partial data' do
      let(:partial_contact) { { id: contact_id, name: 'John', email: 'john@example.com' } }
      
      before do
        allow(CompanyContactsService).to receive(:active_contacts).and_return([partial_contact])
      end

      it 'handles partial contact data correctly' do
        get :new
        
        expect(response).to have_http_status(:ok)
        company_contacts = assigns(:company_contacts)
        expect(company_contacts[company_id.to_s]).to eq([partial_contact])
      end
    end
  end
end