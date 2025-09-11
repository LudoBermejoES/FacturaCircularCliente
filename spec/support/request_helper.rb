module RequestHelper
  def self.included(base)
    base.before(:each) do
      host! 'localhost:3002'
      
      # Setup HTTP stubs for all API calls
      setup_http_stubs
      setup_authentication_mocks
    end
  end
  
  private
  
  def setup_http_stubs
    user = build(:user_response)
    token = 'test_access_token'
    company = build(:company_response)
    invoice = build(:invoice_response)
    
    # Authentication endpoints
    stub_request(:post, "http://albaranes-api:3000/api/v1/auth/login")
      .to_return(
        status: 200,
        body: {
          access_token: token,
          refresh_token: 'test_refresh_token',
          user: user
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    stub_request(:get, "http://albaranes-api:3000/api/v1/auth/validate")
      .to_return(
        status: 200, 
        body: { valid: true }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:post, "http://albaranes-api:3000/api/v1/auth/logout")
      .to_return(
        status: 200,
        body: { message: 'Logged out successfully' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Company endpoints
    stub_request(:get, "http://albaranes-api:3000/api/v1/companies")
      .to_return(
        status: 200,
        body: { companies: [company], total: 1, meta: { page: 1, pages: 1, total: 1 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:get, %r{http://albaranes-api:3000/api/v1/companies/\d+})
      .to_return(
        status: 200,
        body: company.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:post, "http://albaranes-api:3000/api/v1/companies")
      .to_return(
        status: 201,
        body: company.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:put, %r{http://albaranes-api:3000/api/v1/companies/\d+})
      .to_return(
        status: 200,
        body: company.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:delete, %r{http://albaranes-api:3000/api/v1/companies/\d+})
      .to_return(
        status: 200,
        body: { message: 'Company deleted successfully' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Invoice endpoints
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices")
      .to_return(
        status: 200,
        body: { invoices: [invoice], total: 1, meta: { page: 1, pages: 1, total: 1 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/statistics")
      .to_return(
        status: 200,
        body: { total_count: 1, total_value: 1000.00, status_counts: { draft: 1 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/stats")
      .to_return(
        status: 200,
        body: {
          total_invoices: 45,
          draft_count: 12,
          sent_count: 18,
          paid_count: 15,
          total_amount: 125000.50,
          pending_amount: 45000.25
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:get, %r{http://albaranes-api:3000/api/v1/invoices/\d+})
      .to_return(
        status: 200,
        body: invoice.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:post, "http://albaranes-api:3000/api/v1/invoices")
      .to_return(
        status: 201,
        body: invoice.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:put, %r{http://albaranes-api:3000/api/v1/invoices/\d+})
      .to_return(
        status: 200,
        body: invoice.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:delete, %r{http://albaranes-api:3000/api/v1/invoices/\d+})
      .to_return(
        status: 200,
        body: { message: 'Invoice deleted successfully' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:post, %r{http://albaranes-api:3000/api/v1/invoices/\d+/freeze})
      .to_return(
        status: 200,
        body: { frozen: true, message: 'Invoice frozen' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:post, %r{http://albaranes-api:3000/api/v1/invoices/\d+/send_email})
      .to_return(
        status: 200,
        body: { sent: true, message: 'Email sent' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
    stub_request(:get, %r{http://albaranes-api:3000/api/v1/invoices/\d+/pdf})
      .to_return(
        status: 200,
        body: '%PDF-1.4 fake pdf content',
        headers: { 'Content-Type' => 'application/pdf' }
      )
      
    stub_request(:get, %r{http://albaranes-api:3000/api/v1/invoices/\d+/facturae})
      .to_return(
        status: 200,
        body: '<?xml version="1.0"?><Facturae></Facturae>',
        headers: { 'Content-Type' => 'application/xml' }
      )
  end
  
  def setup_authentication_mocks
    user = build(:user_response)
    token = 'test_access_token'
    
    # Mock authentication - comprehensive approach
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    
    # Disable CSRF protection for tests
    allow_any_instance_of(ApplicationController).to receive(:verify_authenticity_token).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:protect_against_forgery?).and_return(false)
    
    # Mock session to return token
    session_double = { access_token: token }
    allow_any_instance_of(ApplicationController).to receive(:session).and_return(session_double)
  end
  
  def setup_service_mocks
    user = build(:user_response)
    company = build(:company_response) 
    invoice = build(:invoice_response)
    token = 'test_access_token'
    
    # Mock AuthService methods
    allow(AuthService).to receive(:login).with(any_args).and_return({
      access_token: token,
      refresh_token: 'test_refresh_token', 
      user: user
    })
    allow(AuthService).to receive(:validate_token).with(any_args).and_return({ valid: true })
    allow(AuthService).to receive(:logout).with(any_args).and_return({ message: 'Logged out successfully' })
    allow(AuthService).to receive(:refresh_token).with(any_args).and_return({
      access_token: token,
      refresh_token: 'test_refresh_token'
    })
    
    # Mock CompanyService methods
    allow(CompanyService).to receive(:all).with(any_args).and_return({ 
      companies: [company], total: 1, meta: { page: 1, pages: 1, total: 1 }
    })
    allow(CompanyService).to receive(:find).with(any_args).and_return(company)
    allow(CompanyService).to receive(:create).with(any_args).and_return(company)
    allow(CompanyService).to receive(:update).with(any_args).and_return(company)
    allow(CompanyService).to receive(:delete).with(any_args).and_return(true)
    
    # Mock InvoiceService methods
    allow(InvoiceService).to receive(:all).with(any_args).and_return({ 
      invoices: [invoice], total: 1, meta: { page: 1, pages: 1, total: 1 }
    })
    allow(InvoiceService).to receive(:statistics).with(any_args).and_return({
      total_count: 1, total_value: 1000.00, status_counts: { draft: 1 }
    })
    allow(InvoiceService).to receive(:stats).with(any_args).and_return({
      total_invoices: 45,
      draft_count: 12,
      sent_count: 18,
      paid_count: 15,
      total_amount: 125000.50,
      pending_amount: 45000.25
    })
    allow(InvoiceService).to receive(:recent).with(any_args).and_return([invoice])
    allow(InvoiceService).to receive(:find).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:workflow_history).with(any_args).and_return([])
    allow(InvoiceService).to receive(:create).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:update).with(any_args).and_return(invoice)
    allow(InvoiceService).to receive(:delete).with(any_args).and_return(true)
    allow(InvoiceService).to receive(:freeze).with(any_args).and_return({ frozen: true, message: 'Invoice frozen' })
    allow(InvoiceService).to receive(:send_email).with(any_args).and_return({ sent: true, message: 'Email sent' })
    allow(InvoiceService).to receive(:download_pdf).with(any_args).and_return('%PDF-1.4 fake pdf content')
    allow(InvoiceService).to receive(:download_facturae).with(any_args).and_return('<?xml version="1.0"?><Facturae></Facturae>')
    
    # Mock controller-level methods that may need instance variables set
    allow_any_instance_of(CompaniesController).to receive(:set_company) do |instance|
      instance.instance_variable_set(:@company, company)
      true
    end
    
    allow_any_instance_of(InvoicesController).to receive(:load_companies) do |instance|
      instance.instance_variable_set(:@companies, [company])
      true
    end
    allow_any_instance_of(InvoicesController).to receive(:set_invoice) do |instance|
      instance.instance_variable_set(:@invoice, invoice)
      true
    end
  end
end

RSpec.configure do |config|
  config.include RequestHelper, type: :request
end