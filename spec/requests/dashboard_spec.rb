require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }

  before do
    # Include ApiStubs for this spec
    extend ApiStubs
    
    # Stub authentication API calls to prevent WebMock errors
    stub_authentication(token: token)
    
    # Mock AuthService methods like in Minitest tests
    allow(AuthService).to receive(:validate_token).and_return({ valid: true })
    
    # Set up session data to simulate logged in state
    allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return({
      'access_token' => token,
      'user_id' => 1,
      'user_email' => 'test@example.com'
    })
  end

  describe 'GET /dashboard' do
    let(:invoice_stats) do
      {
        total_invoices: 45,
        draft_count: 12,
        sent_count: 18,
        paid_count: 15,
        total_amount: 125000.50,
        pending_amount: 45000.25
      }
    end

    before do
      # Mock the authenticate_user! method to bypass authentication completely
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      
      # Mock InvoiceService methods to avoid HTTP calls (using same pattern as other specs)
      # Note: stats method removed from InvoiceService
      allow(InvoiceService).to receive(:recent).with(any_args).and_return([
        build(:invoice_response), build(:invoice_response)
      ])
    end


    it 'shows recent invoices' do
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Recent Invoices')
    end
  end

  describe 'without authentication' do
    before do
      # Override all RequestHelper authentication mocks to simulate no authentication
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(false)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false) 
      allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_call_original
    end

    it 'redirects to login' do
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end
  end
end