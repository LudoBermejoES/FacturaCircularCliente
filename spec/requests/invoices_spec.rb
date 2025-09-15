require 'rails_helper'

RSpec.describe 'Invoices', type: :request do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:invoice) { build(:invoice_response) }
  let(:company) { build(:company_response) }

  # HTTP stubs and authentication mocking handled by RequestHelper
  
  before do
    # Setup authentication session
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    
    # Mock user role and permissions for invoice management (same as feature tests)
    allow_any_instance_of(ApplicationController).to receive(:current_company_id).and_return(company[:id])
    allow_any_instance_of(ApplicationController).to receive(:user_companies).and_return([
      { id: company[:id], name: company[:name], role: 'manager' }
    ])
    allow_any_instance_of(ApplicationController).to receive(:current_user_role).and_return('manager')
    
    # Mock all can? calls with default permissions (manager can do most things)
    allow_any_instance_of(ApplicationController).to receive(:can?) do |_, action, resource|
      case action
      when :view, :create, :edit, :approve, :manage_invoices, :manage_workflows
        true
      else
        false
      end
    end
    
    # Mock InvoiceService methods to use the test's invoice data
    allow(InvoiceService).to receive(:all).with(any_args).and_return({ 
      invoices: [invoice], total: 1, meta: { page: 1, pages: 1, total: 1 }
    })
    # Note: statistics and stats methods removed from InvoiceService
    allow(InvoiceService).to receive(:recent).with(any_args).and_return([invoice])
    allow(InvoiceService).to receive(:find).with(any_args).and_return(invoice)
    # Note: workflow_history method removed from InvoiceService
    allow(InvoiceService).to receive(:create).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:update).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:delete).with(any_args).and_return(true)
    allow(InvoiceService).to receive(:freeze).with(any_args).and_return({ frozen: true, message: 'Invoice frozen' })
    # Note: send_email method removed from InvoiceService
    # Note: download_pdf method removed from InvoiceService
    allow(InvoiceService).to receive(:download_facturae).with(any_args).and_return('<?xml version="1.0"?><Facturae></Facturae>')
    
    # Mock CompanyService methods that were added recently (matching feature tests)
    allow(CompanyService).to receive(:all).with(any_args).and_return({ 
      companies: [company], 
      total: 1, 
      meta: { page: 1, pages: 1, total: 1 } 
    })
    
    # Mock CompanyContactsService methods that were added recently
    allow(CompanyContactsService).to receive(:all).with(any_args).and_return({ 
      contacts: [company], 
      total: 1, 
      meta: { page: 1, pages: 1, total: 1 } 
    })
    allow(CompanyContactsService).to receive(:active_contacts).with(any_args).and_return([])
    
    # Mock InvoiceSeriesService for invoice form  
    allow(InvoiceSeriesService).to receive(:all).with(any_args).and_return([
      { id: 1, series_code: 'FC', series_name: 'Facturas Comerciales', year: Date.current.year, is_active: true }
    ])
  end

  describe 'GET /invoices' do

    it 'lists invoices' do
      get invoices_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Invoices')
      expect(response.body).to include(invoice[:invoice_number])
    end

  end

  describe 'GET /invoices/new' do

    it 'renders new invoice form' do
      get new_invoice_path
      if response.status != 200
        puts "Response status: #{response.status}"
        puts "Response body sample: #{response.body[0..500]}"
      end
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Invoice')
      expect(response.body).to include('form')
    end
  end

  describe 'POST /invoices' do
    let(:invoice_params) do
      {
        invoice_number: 'INV-001',
        invoice_series_id: 1,
        seller_party_id: company[:id],
        buyer_party_id: company[:id],
        issue_date: Date.current.strftime('%Y-%m-%d'),
        due_date: (Date.current + 30).strftime('%Y-%m-%d'),
        invoice_type: 'invoice',
        status: 'draft',
        invoice_lines_attributes: [
          {
            description: 'Service',
            quantity: 1,
            unit_price: 100.00,
            tax_rate: 21.0
          }
        ]
      }
    end


    it 'creates invoice and redirects' do
      # Mock should return the same structure as the API response
      expected_response = { data: invoice }
      expect(InvoiceService).to receive(:create).with(any_args).and_return(expected_response)
      post invoices_path, params: { invoice: invoice_params }
      
      if response.status == 422
        puts "ERROR: Got 422 response"
        puts "Response body: #{response.body[0..500]}"
        puts "Response headers: #{response.headers.inspect}"
      end
      
      expect(response).to redirect_to(invoice_path(invoice[:id]))
      follow_redirect!
      expect(response.body).to include('Invoice created successfully')
    end

    context 'with invalid data' do
      it 'renders form with errors' do
        # Override the global mock to raise validation error
        allow(InvoiceService).to receive(:create).and_raise(
          ApiService::ValidationError.new("Validation failed", {
            invoice_number: ["can't be blank"],
            seller_party_id: ["can't be blank"],
            buyer_party_id: ["can't be blank"]
          })
        )
        
        post invoices_path, params: { invoice: { invoice_number: '', seller_party_id: nil, buyer_party_id: nil } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("New Invoice")
        expect(response.body).to include("form")
      end
    end
  end

  describe 'GET /invoices/:id' do
    it 'shows invoice details' do
      get invoice_path(invoice[:id])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(invoice[:invoice_number])
      expect(response.body).to include('Invoice Details')
    end
  end

  describe 'GET /invoices/:id/edit' do
    it 'renders edit form' do
      get edit_invoice_path(invoice[:id])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit Invoice')
      expect(response.body).to include(invoice[:invoice_number])
    end
  end

  describe 'PUT /invoices/:id' do
    let(:updated_params) { { invoice_number: 'INV-UPDATED' } }


    it 'updates invoice and redirects' do
      put invoice_path(invoice[:id]), params: { invoice: updated_params }
      expect(response).to redirect_to(invoice_path(invoice[:id]))
      follow_redirect!
      expect(response.body).to include('Invoice updated successfully')
    end
  end

  describe 'DELETE /invoices/:id' do

    it 'deletes invoice and redirects' do
      delete invoice_path(invoice[:id])
      expect(response).to redirect_to(invoices_path)
      follow_redirect!
      expect(response.body).to include('Invoice deleted successfully')
    end
  end

  describe 'POST /invoices/:id/freeze' do

    it 'freezes invoice' do
      post freeze_invoice_path(invoice[:id])
      expect(response).to redirect_to(invoice_path(invoice[:id]))
      follow_redirect!
      expect(response.body).to include('Invoice frozen')
    end
  end



  describe 'GET /invoices/:id/facturae' do
    let(:xml_content) { '<?xml version="1.0"?><Facturae></Facturae>' }

    it 'downloads Facturae XML' do
      get facturae_invoice_path(invoice[:id])
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/xml')
      expect(response.body).to eq(xml_content)
    end
  end
end