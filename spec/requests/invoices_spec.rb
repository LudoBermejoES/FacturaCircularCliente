require 'rails_helper'

RSpec.describe 'Invoices', type: :request do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:invoice) { build(:invoice_response) }
  let(:company) { build(:company_response) }

  before do
    # Mock authentication - more comprehensive
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:session).and_return({ access_token: token })
    
    # Mock controller methods to avoid API calls
    allow_any_instance_of(InvoicesController).to receive(:load_companies) do |instance|
      instance.instance_variable_set(:@companies, [company])
      true
    end
    allow_any_instance_of(InvoicesController).to receive(:set_invoice) do |instance|
      instance.instance_variable_set(:@invoice, invoice)
      true
    end
    
    # Mock service methods to avoid HTTP calls
    allow(InvoiceService).to receive(:all).with(any_args).and_return({ 
      invoices: [invoice, build(:invoice_response)], 
      total: 2, 
      meta: { page: 1, pages: 1, total: 2 }
    })
    allow(InvoiceService).to receive(:statistics).with(any_args).and_return({
      total_count: 2,
      total_value: 1500.00,
      status_counts: { draft: 1, sent: 1 }
    })
    allow(CompanyService).to receive(:all).with(any_args).and_return({ companies: [company], total: 1 })
    allow(CompanyService).to receive(:find).with(any_args).and_return(company)
    allow(InvoiceService).to receive(:find).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:workflow_history).with(any_args).and_return([])
    allow(InvoiceService).to receive(:create).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:update).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:delete).with(any_args).and_return(true)
    allow(InvoiceService).to receive(:freeze).with(any_args).and_return({ frozen: true, message: 'Invoice frozen' })
    allow(InvoiceService).to receive(:send_email).with(any_args).and_return({ sent: true, message: 'Email sent' })
    allow(InvoiceService).to receive(:download_pdf).with(any_args).and_return('%PDF-1.4 fake pdf content')
    allow(InvoiceService).to receive(:download_facturae).with(any_args).and_return('<?xml version="1.0"?><Facturae></Facturae>')
  end

  describe 'GET /invoices' do

    it 'lists invoices' do
      get invoices_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Invoices')
      expect(response.body).to include(invoice[:invoice_number])
    end

    it 'shows statistics' do
      get invoices_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('1,500')
      expect(response.body).to include('Total')  
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
        company_id: company[:id],
        invoice_lines_attributes: [
          {
            description: 'Service',
            quantity: 1,
            unit_price: 100.00
          }
        ]
      }
    end


    it 'creates invoice and redirects' do
      post invoices_path, params: { invoice: invoice_params }
      expect(response).to redirect_to(invoice_path(invoice[:id]))
      follow_redirect!
      expect(response.body).to include('Invoice created successfully')
    end

    context 'with invalid data' do
      before do
        stub_request(:get, 'http://localhost:3001/api/v1/companies')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: { companies: [company], total: 1 }.to_json)
        
        stub_request(:post, 'http://localhost:3001/api/v1/invoices')
          .with(
            body: { invoice_number: '', company_id: nil }.to_json,
            headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
          )
          .to_return(
            status: 422,
            body: {
              errors: {
                invoice_number: ["can't be blank"],
                company_id: ["can't be blank"]
              }
            }.to_json
          )
      end

      it 'renders form with errors' do
        # Override the global mock to raise validation error
        allow(InvoiceService).to receive(:create).and_raise(
          ApiService::ValidationError.new("Validation failed", {
            invoice_number: ["can't be blank"],
            company_id: ["can't be blank"]
          })
        )
        
        post invoices_path, params: { invoice: { invoice_number: '', company_id: nil } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("New Invoice")
        expect(response.body).to include("form")
      end
    end
  end

  describe 'GET /invoices/:id' do
    before do
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: invoice.to_json)
      
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}/workflow_history")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: [].to_json)
      
      stub_request(:get, "http://localhost:3001/api/v1/companies/#{company[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: company.to_json)
    end

    it 'shows invoice details' do
      get invoice_path(invoice[:id])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(invoice[:invoice_number])
      expect(response.body).to include('Invoice Details')
    end
  end

  describe 'GET /invoices/:id/edit' do
    before do
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: invoice.to_json)
      
      stub_request(:get, 'http://localhost:3001/api/v1/companies')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: { companies: [company] }.to_json)
    end

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

  describe 'POST /invoices/:id/send_email' do
    let(:recipient_email) { 'client@example.com' }


    it 'sends invoice email' do
      post send_email_invoice_path(invoice[:id]), params: { recipient_email: recipient_email }
      expect(response).to redirect_to(invoice_path(invoice[:id]))
      follow_redirect!
      expect(response.body).to include('Email sent')
    end
  end

  describe 'GET /invoices/:id/pdf' do
    let(:pdf_content) { '%PDF-1.4 fake pdf content' }

    before do
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: invoice.to_json)
      
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}/pdf")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(
          status: 200,
          body: pdf_content,
          headers: { 'Content-Type' => 'application/pdf' }
        )
    end

    it 'downloads PDF' do
      get pdf_invoice_path(invoice[:id])
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
      expect(response.body).to eq(pdf_content)
    end
  end

  describe 'GET /invoices/:id/facturae' do
    let(:xml_content) { '<?xml version="1.0"?><Facturae></Facturae>' }

    before do
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: invoice.to_json)
      
      stub_request(:get, "http://localhost:3001/api/v1/invoices/#{invoice[:id]}/facturae")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(
          status: 200,
          body: xml_content,
          headers: { 'Content-Type' => 'application/xml' }
        )
    end

    it 'downloads Facturae XML' do
      get facturae_invoice_path(invoice[:id])
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/xml')
      expect(response.body).to eq(xml_content)
    end
  end
end