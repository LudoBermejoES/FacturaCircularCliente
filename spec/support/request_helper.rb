module RequestHelper
  def self.included(base)
    base.before(:each) do
      host! 'localhost:3002'
      
      # Global mocking for all request specs
      setup_authentication_mocks
      setup_service_mocks
    end
  end
  
  private
  
  def setup_authentication_mocks
    user = build(:user_response)
    token = 'test_access_token'
    
    # Mock authentication - comprehensive approach
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    
    # Mock session to return token
    session_double = { access_token: token }
    allow_any_instance_of(ApplicationController).to receive(:session).and_return(session_double)
    
    # Mock authentication service to avoid API calls
    allow(AuthService).to receive(:validate_token).with(any_args).and_return({ valid: true })
  end
  
  def setup_service_mocks
    company = build(:company_response)
    invoice = build(:invoice_response)
    
    # Mock all service methods to avoid HTTP calls
    allow(CompanyService).to receive(:all).with(any_args).and_return({ 
      companies: [company], total: 1, meta: { page: 1, pages: 1, total: 1 }
    })
    allow(CompanyService).to receive(:find).with(any_args).and_return(company)
    allow(CompanyService).to receive(:create).with(any_args).and_return(company)
    allow(CompanyService).to receive(:update).with(any_args).and_return(company)
    allow(CompanyService).to receive(:delete).with(any_args).and_return(true)
    
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
    
    # Mock controller-level methods
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

# Don't auto-include - let individual specs include as needed
# RSpec.configure do |config|
#   config.include RequestHelper, type: :request
# end