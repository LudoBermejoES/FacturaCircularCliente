require 'rails_helper'

RSpec.describe 'TaxCalculations', type: :request do
  let(:token) { 'mock-token' }
  
  before do
    # Mock current_user_token method
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return(token)
  end

  describe 'Manual calculations (unsupported)' do
    it 'redirects new with error message' do
      get new_tax_calculation_path
      
      expect(response).to redirect_to(invoices_path)
      expect(flash[:alert]).to include('Manual tax calculations are not supported')
    end

    it 'redirects create with error message' do
      post tax_calculations_path, params: { calculation: { base_amount: 1000 } }
      
      expect(response).to redirect_to(invoices_path)
      expect(flash[:alert]).to include('Manual tax calculations are not supported')
    end
  end

  describe 'Tax validation endpoint' do
    it 'validates invoice tax with invoice_id parameter' do
      allow(TaxService).to receive(:validate).and_return({ valid: true, issues: [] })
      
      post validate_tax_calculations_path, 
           params: { invoice_id: 1 },
           headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ 'valid' => true, 'issues' => [] })
      
      expect(TaxService).to have_received(:validate).with("1", token: token)
    end

    it 'returns validation error with no parameters' do
      post validate_tax_calculations_path, headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      result = JSON.parse(response.body)
      expect(result['valid']).to be_falsey
      expect(result['errors']).to include('Invoice ID is required for tax validation')
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:validate).and_raise(ApiService::ApiError.new('Validation service error'))
      
      post validate_tax_calculations_path, 
           params: { invoice_id: 1 },
           headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:unprocessable_entity)
      result = JSON.parse(response.body)
      expect(result['valid']).to be_falsey
      expect(result['errors']).to include('Validation service error')
    end
  end
end