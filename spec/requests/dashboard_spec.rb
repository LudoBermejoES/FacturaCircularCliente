require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
    allow(user).to receive(:access_token).and_return(token)
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
      stub_request(:get, 'http://localhost:3001/api/v1/invoices/stats')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: invoice_stats.to_json)
      
      stub_request(:get, 'http://localhost:3001/api/v1/invoices')
        .with(
          query: { limit: 5, status: 'recent' },
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(
          status: 200, 
          body: { 
            invoices: [build(:invoice_response), build(:invoice_response)],
            total: 2 
          }.to_json
        )
    end

    it 'renders dashboard with statistics' do
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Dashboard')
      expect(response.body).to include('125,000.50')
      expect(response.body).to include('45 invoices')
    end

    it 'shows recent invoices' do
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Recent Invoices')
    end
  end

  describe 'without authentication' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(false)
    end

    it 'redirects to login' do
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end
  end
end