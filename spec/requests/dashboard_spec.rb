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
    
    # Set up session data properly for request specs
    # Using the session method from ActionDispatch::IntegrationTest
    # This will be set before each request is made
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
      # Skip all authentication completely for dashboard tests
      allow_any_instance_of(DashboardController).to receive(:authenticate_user!).and_return(nil)
      
      # Mock all ApplicationController methods that dashboard uses
      allow_any_instance_of(DashboardController).to receive(:current_user).and_return(user)
      allow_any_instance_of(DashboardController).to receive(:user_companies).and_return([
        { id: 1, name: 'Test Company' }
      ])
      allow_any_instance_of(DashboardController).to receive(:current_token).and_return(token)
      allow_any_instance_of(DashboardController).to receive(:logged_in?).and_return(true)
      allow_any_instance_of(DashboardController).to receive(:user_signed_in?).and_return(true)
      
      # Mock InvoiceService.recent to return static data with keyword arguments
      allow(InvoiceService).to receive(:recent).with(token: token, limit: 5).and_return([
        build(:invoice_response), build(:invoice_response)
      ])
    end


    it 'shows recent invoices' do
      # Override authentication methods to avoid session issues
      allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
      allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
        { id: 1, email: 'test@example.com', name: 'Test User' }
      )
      allow_any_instance_of(ApplicationController).to receive(:user_companies).and_return([
        { 'id' => 1, 'name' => 'Test Company' }
      ])

      get dashboard_path
      if response.status == 500
        puts "Response body: #{response.body}"
        puts "Response status: #{response.status}"
      end
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