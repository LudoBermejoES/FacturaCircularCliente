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

    # Add workflow definitions stub for all controller tests
    stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions")
      .to_return(
        status: 200,
        body: { data: [{ id: 1, name: 'Default Workflow' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
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
        expect(response).to have_http_status(:unprocessable_content)
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
        expect(response).to have_http_status(:unprocessable_content)
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
        expect(response).to have_http_status(:unprocessable_content)
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
        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to eq('Error updating invoice: Invoice is frozen')
        
        expect(assigns(:company_contacts)).to be_present
        expect(CompanyContactsService).to have_received(:active_contacts)
      end
    end
  end

  describe 'GET #show' do
    let(:companies) { [company, build(:company_response, id: company_id + 1)] }
    let(:buyer_company) { build(:company_response, id: company_id + 1, name: 'Buyer Company') }
    let(:invoice_with_buyer_company) { build(:invoice_response, id: invoice_id, seller_party_id: company_id, buyer_party_id: company_id + 1) }
    let(:invoice_with_buyer_contact) { build(:invoice_response, id: invoice_id, seller_party_id: company_id, buyer_company_contact_id: contact_id, buyer_name: 'GreenWaste') }

    before do
      allow(InvoiceService).to receive(:find).and_return(invoice_with_buyer_company)
      allow(CompanyService).to receive(:find).and_return(company)
    end

    context 'when invoice has seller and buyer companies' do
      it 'loads seller and buyer company information' do
        allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(company)
        allow(CompanyService).to receive(:find).with(company_id + 1, token: token).and_return(buyer_company)

        get :show, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:show)

        expect(assigns(:invoice)).to eq(invoice_with_buyer_company)
        expect(assigns(:seller_company)).to eq(company)
        expect(assigns(:buyer_company)).to eq(buyer_company)
        expect(assigns(:buyer_contact)).to be_nil

        expect(InvoiceService).to have_received(:find).with(invoice_id.to_s, token: token)
        expect(CompanyService).to have_received(:find).with(company_id, token: token)
        expect(CompanyService).to have_received(:find).with(company_id + 1, token: token)
      end
    end

    context 'when invoice has seller company and buyer contact' do
      before do
        allow(InvoiceService).to receive(:find).and_return(invoice_with_buyer_contact)
      end

      it 'loads seller company and creates buyer contact information' do
        allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(company)

        get :show, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:show)

        expect(assigns(:invoice)).to eq(invoice_with_buyer_contact)
        expect(assigns(:seller_company)).to eq(company)
        expect(assigns(:buyer_company)).to be_nil

        buyer_contact = assigns(:buyer_contact)
        expect(buyer_contact).to be_present
        expect(buyer_contact[:id]).to eq(contact_id)
        expect(buyer_contact[:company_name]).to eq('GreenWaste')
        expect(buyer_contact[:email]).to be_nil
        expect(buyer_contact[:phone]).to be_nil
      end

      it 'logs the buyer contact creation' do
        allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(company)
        allow(Rails.logger).to receive(:info)

        get :show, params: { id: invoice_id }

        expect(Rails.logger).to have_received(:info)
          .with("DEBUG: Found buyer_company_contact_id: #{contact_id}")
      end
    end

    context 'when invoice has no buyer information' do
      let(:invoice_without_buyer) { build(:invoice_response, id: invoice_id, seller_party_id: company_id) }

      before do
        allow(InvoiceService).to receive(:find).and_return(invoice_without_buyer)
      end

      it 'only loads seller company information' do
        allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(company)

        get :show, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        expect(assigns(:seller_company)).to eq(company)
        expect(assigns(:buyer_company)).to be_nil
        expect(assigns(:buyer_contact)).to be_nil

        expect(CompanyService).to have_received(:find).once.with(company_id, token: token)
      end
    end

    context 'when seller company loading fails' do
      before do
        allow(CompanyService).to receive(:find).with(company_id, token: token)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'handles seller company loading errors gracefully' do
        get :show, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        expect(assigns(:seller_company)).to be_nil
        expect(assigns(:buyer_company)).to be_nil
      end
    end

    context 'when buyer company loading fails' do
      before do
        allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(company)
        allow(CompanyService).to receive(:find).with(company_id + 1, token: token)
          .and_raise(ApiService::ApiError.new('Buyer company not found'))
      end

      it 'handles buyer company error gracefully but rescue block sets all to nil' do
        get :show, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        # The rescue block in controller catches ApiService::ApiError and sets all company vars to nil
        expect(assigns(:seller_company)).to be_nil
        expect(assigns(:buyer_company)).to be_nil
        expect(flash.now[:alert]).to include('Error loading invoice details')
      end
    end

    context 'when invoice loading fails' do
      before do
        allow(InvoiceService).to receive(:find)
          .and_raise(ApiService::ApiError.new('Invoice not found'))
      end

      it 'redirects to invoices index with error message' do
        get :show, params: { id: invoice_id }

        expect(response).to redirect_to(invoices_path)
        expect(flash[:alert]).to eq('Invoice not found: Invoice not found')
      end
    end


    context 'with complex seller/buyer scenario' do
      let(:seller_company) { build(:company_response, id: company_id, name: 'Tech Solutions Inc.') }
      let(:buyer_company) { build(:company_response, id: company_id + 1, name: 'Green Waste Management S.L.') }
      let(:complex_invoice) do
        build(:invoice_response,
          id: invoice_id,
          seller_party_id: company_id,
          buyer_party_id: company_id + 1,
          invoice_number: 'FC-0001',
          total: 1500.50,
          status: 'approved'
        )
      end

      before do
        allow(InvoiceService).to receive(:find).and_return(complex_invoice)
        allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(seller_company)
        allow(CompanyService).to receive(:find).with(company_id + 1, token: token).and_return(buyer_company)
      end

      it 'successfully loads all information for complete display' do
        get :show, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:show)

        # Verify invoice data
        invoice = assigns(:invoice)
        expect(invoice[:id]).to eq(invoice_id)
        expect(invoice[:invoice_number]).to eq('FC-0001')
        expect(invoice[:total]).to eq(1500.50)
        expect(invoice[:status]).to eq('approved')

        # Verify seller information
        seller = assigns(:seller_company)
        expect(seller[:id]).to eq(company_id)
        expect(seller[:name]).to eq('Tech Solutions Inc.')

        # Verify buyer information
        buyer = assigns(:buyer_company)
        expect(buyer[:id]).to eq(company_id + 1)
        expect(buyer[:name]).to eq('Green Waste Management S.L.')

        # Verify no buyer contact (since it's a full company)
        expect(assigns(:buyer_contact)).to be_nil
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

  describe 'workflow functionality' do
    let(:workflow_definitions) do
      [
        { id: 1, name: 'Simple Invoice Workflow', company_id: company_id },
        { id: 2, name: 'Standard Invoice Workflow', company_id: company_id },
        { id: 3, name: 'Complex Approval Workflow', company_id: company_id }
      ]
    end

    let(:invoice_with_workflow) do
      build(:invoice_response,
        id: invoice_id,
        company_id: company_id,
        workflow_definition_id: 2,
        status: 'draft'
      )
    end

    describe 'GET #new with workflow support' do
      before do
        allow(CompanyService).to receive(:all).and_return({ companies: [company] })
        allow(InvoiceSeriesService).to receive(:all).and_return({ invoice_series: [] })
        allow(CompanyContactsService).to receive(:active_contacts).and_return([])
        allow(WorkflowService).to receive(:definitions).and_return({ data: workflow_definitions })
      end

      it 'loads available workflow definitions' do
        get :new

        expect(response).to have_http_status(:ok)
        expect(assigns(:workflows)).to eq(workflow_definitions)
        expect(WorkflowService).to have_received(:definitions).with(token: token)
      end

      it 'includes workflow definitions in the view context' do
        get :new

        workflows = assigns(:workflows)
        expect(workflows).to be_an(Array)
        expect(workflows.length).to eq(3)
        expect(workflows.first[:name]).to eq('Simple Invoice Workflow')
      end
    end

    describe 'GET #edit with workflow' do
      before do
        allow(InvoiceService).to receive(:find).and_return(invoice_with_workflow)
        allow(CompanyService).to receive(:all).and_return({ companies: [company] })
        allow(InvoiceSeriesService).to receive(:all).and_return({ invoice_series: [] })
        allow(CompanyContactsService).to receive(:active_contacts).and_return([])
        allow(WorkflowService).to receive(:definitions).and_return({ data: workflow_definitions })
      end

      it 'loads invoice with workflow information' do
        get :edit, params: { id: invoice_id }

        expect(response).to have_http_status(:ok)
        expect(assigns(:invoice)[:workflow_definition_id]).to eq(2)
        expect(assigns(:workflows)).to eq(workflow_definitions)
      end

      it 'preselects the current workflow in the form' do
        get :edit, params: { id: invoice_id }

        invoice = assigns(:invoice)
        workflows = assigns(:workflows)

        expect(invoice[:workflow_definition_id]).to eq(2)
        expect(workflows.find { |w| w[:id] == 2 }[:name]).to eq('Standard Invoice Workflow')
      end
    end

    describe 'POST #create with workflow_definition_id' do
      let(:invoice_params_with_workflow) do
        invoice_params.merge(
          workflow_definition_id: '2'
        )
      end

      let(:expected_processed_params) do
        {
          issue_date: '2024-01-15',
          due_date: '2024-02-15',
          seller_party_id: company_id,
          buyer_party_id: company_id + 1,
          buyer_company_contact_id: contact_id,
          notes: 'Test invoice',
          workflow_definition_id: 2,
          invoice_lines_attributes: [
            {
              item_description: 'Test item',
              quantity: 2.0,
              unit_price_without_tax: 100.0,
              tax_rate: 21.0
            }
          ]
        }
      end

      before do
        allow(InvoiceService).to receive(:create).and_return({ success: true, invoice: invoice_with_workflow })
      end

      it 'includes workflow_definition_id in processed parameters' do
        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:create) do |params, _|
          captured_params = params
          { data: { id: 123 } }
        end

        post :create, params: { invoice: invoice_params_with_workflow }

        expect(captured_params[:workflow_definition_id]).to eq("2")
        expect(InvoiceService).to have_received(:create).with(any_args)
      end

      it 'processes workflow_definition_id as string (Rails parameter behavior)' do
        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:create) do |params, _|
          captured_params = params
          { data: { id: 123 } }
        end

        post :create, params: { invoice: invoice_params_with_workflow }

        # Rails controller parameters keep workflow_definition_id as string
        expect(captured_params[:workflow_definition_id]).to eq("2")
        expect(captured_params[:workflow_definition_id]).to be_a(String)
      end

      it 'redirects on successful creation with workflow' do
        allow(InvoiceService).to receive(:create).and_return({ data: { id: 123 } })

        post :create, params: { invoice: invoice_params_with_workflow }

        expect(response).to redirect_to(invoice_path(123))
        expect(flash[:notice]).to eq('Invoice created successfully')
      end
    end

    describe 'PATCH #update with workflow_definition_id' do
      let(:update_params_with_workflow) do
        {
          workflow_definition_id: '3',
          notes: 'Updated with new workflow'
        }
      end

      before do
        allow(InvoiceService).to receive(:find).and_return(invoice_with_workflow)
        allow(InvoiceService).to receive(:update).and_return({ success: true, invoice: invoice_with_workflow })
      end

      it 'includes workflow_definition_id in update parameters' do
        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:update) do |id, params, _|
          captured_params = params
          { success: true }
        end

        patch :update, params: { id: invoice_id, invoice: update_params_with_workflow }

        expect(captured_params[:workflow_definition_id]).to eq("3")
        expect(InvoiceService).to have_received(:update).with(invoice_id, any_args)
      end

      it 'handles workflow change requests' do
        patch :update, params: { id: invoice_id, invoice: update_params_with_workflow }

        expect(response).to redirect_to(invoice_path(invoice_id))
        expect(flash[:notice]).to eq('Invoice updated successfully')
      end

      it 'processes empty workflow_definition_id gracefully' do
        params_with_empty_workflow = update_params_with_workflow.merge(workflow_definition_id: '')

        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:update) do |id, params, _|
          captured_params = params
          { success: true }
        end

        patch :update, params: { id: invoice_id, invoice: params_with_empty_workflow }

        # Empty string still gets passed through in Rails controllers
        expect(captured_params[:workflow_definition_id]).to eq("")
      end
    end

    describe 'workflow error handling' do
      before do
        allow(InvoiceService).to receive(:find).and_return(invoice_with_workflow)
      end

      context 'when workflow validation fails' do
        before do
          allow(InvoiceService).to receive(:update)
            .and_raise(ApiService::ValidationError.new('Validation failed', { workflow_definition_id: ['is invalid'] }))
          allow(CompanyService).to receive(:all).and_return({ companies: [company] })
          allow(InvoiceSeriesService).to receive(:all).and_return({ invoice_series: [] })
          allow(CompanyContactsService).to receive(:active_contacts).and_return([])
          allow(WorkflowService).to receive(:definitions).and_return({ data: workflow_definitions })
        end

        it 'handles workflow validation errors gracefully' do
          patch :update, params: { id: invoice_id, invoice: { workflow_definition_id: '999' } }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(assigns(:invoice)[:workflow_definition_id]).to eq(2) # Original value preserved
          expect(assigns(:workflows)).to eq(workflow_definitions) # Workflows reloaded for form
        end

        it 'displays workflow-specific error messages' do
          patch :update, params: { id: invoice_id, invoice: { workflow_definition_id: '999' } }

          expect(flash.now[:alert]).to eq('Please fix the errors below.')
        end
      end

      context 'when trying to change workflow of frozen invoice' do
        let(:frozen_invoice) { invoice_with_workflow.merge(is_frozen: true, status: 'sent') }

        before do
          allow(InvoiceService).to receive(:find).and_return(frozen_invoice)
          allow(InvoiceService).to receive(:update)
            .and_raise(ApiService::ApiError.new('Cannot modify frozen invoice'))
          allow(CompanyService).to receive(:all).and_return({ companies: [company] })
          allow(InvoiceSeriesService).to receive(:all).and_return({ invoice_series: [] })
          allow(CompanyContactsService).to receive(:active_contacts).and_return([])
          allow(WorkflowService).to receive(:definitions).and_return({ data: workflow_definitions })
        end

        it 'prevents workflow changes on frozen invoices' do
          patch :update, params: { id: invoice_id, invoice: { workflow_definition_id: '3' } }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash.now[:alert]).to eq('Error updating invoice: Cannot modify frozen invoice')
        end
      end
    end

    describe 'workflow parameter processing' do
      it 'passes empty workflow_definition_id as empty string' do
        # Test the actual controller behavior - it passes empty strings through
        params_with_empty_workflow = invoice_params.merge(workflow_definition_id: '')

        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:create) do |params, _|
          captured_params = params
          { data: { id: 123 } }
        end

        post :create, params: { invoice: params_with_empty_workflow }

        # Rails controllers pass empty strings through
        expect(captured_params[:workflow_definition_id]).to eq("")
      end

      it 'keeps workflow_definition_id as string (Rails parameter behavior)' do
        params_with_string_workflow = invoice_params.merge(workflow_definition_id: '2')

        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:create) do |params, _|
          captured_params = params
          { data: { id: 123 } }
        end

        post :create, params: { invoice: params_with_string_workflow }

        # Rails controllers keep string parameters as strings
        expect(captured_params[:workflow_definition_id]).to eq("2")
        expect(captured_params[:workflow_definition_id]).to be_a(String)
      end

      it 'handles nil workflow_definition_id' do
        params_with_nil_workflow = invoice_params.merge(workflow_definition_id: nil)

        # Setup stub to capture parameters
        captured_params = nil
        allow(InvoiceService).to receive(:create) do |params, _|
          captured_params = params
          { data: { id: 123 } }
        end

        post :create, params: { invoice: params_with_nil_workflow }

        # Rails converts nil to empty string in form submissions
        expect(captured_params[:workflow_definition_id]).to eq("")
      end
    end
  end
end