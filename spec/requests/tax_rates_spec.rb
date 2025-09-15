require 'rails_helper'

RSpec.describe 'TaxRates', type: :request do
  let(:tax_rates_response) { 
    { 
      'data' => [
        { 'id' => 1, 'attributes' => { 'name' => 'Standard VAT', 'rate' => 21.0, 'type' => 'vat' } }
      ]
    }
  }
  let(:exemptions_response) { 
    { 
      'data' => [
        { 'id' => 1, 'attributes' => { 'name' => 'Export', 'description' => 'Goods exported outside EU' } }
      ]
    }
  }
  let(:token) { 'mock-token' }
  
  before do
    # Mock authentication methods
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return({ id: 1, email: 'test@example.com' })
    
    # Mock TaxService calls for read-only operations
    allow(TaxService).to receive(:rates).and_return(tax_rates_response)
    allow(TaxService).to receive(:exemptions).and_return(exemptions_response)
  end

  describe 'GET /tax_rates' do
    it 'lists tax rates and exemptions' do
      get tax_rates_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Current Tax Rates')
      expect(response.body).to include('Standard VAT')
      
      # Verify service calls
      expect(TaxService).to have_received(:rates).with(token: token)
      expect(TaxService).to have_received(:exemptions).with(token: token)
    end

    it 'supports JSON format' do
      get tax_rates_path, headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:rates).and_raise(ApiService::ApiError.new('API Error'))
      
      get tax_rates_path
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'Unsupported operations redirect with error messages' do
    let(:tax_rate_id) { 1 }

    it 'redirects show with error message' do
      get tax_rate_path(tax_rate_id)
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:alert]).to include('not supported by the API')
    end

    it 'redirects new with error message' do
      get new_tax_rate_path
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:alert]).to include('not supported by the API')
    end

    it 'redirects create with error message' do
      post tax_rates_path, params: { tax_rate: { name: 'Test' } }
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:alert]).to include('not supported by the API')
    end

    it 'redirects edit with error message' do
      get edit_tax_rate_path(tax_rate_id)
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:alert]).to include('not supported by the API')
    end

    it 'redirects update with error message' do
      put tax_rate_path(tax_rate_id), params: { tax_rate: { name: 'Test' } }
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:alert]).to include('not supported by the API')
    end

    it 'redirects destroy with error message' do
      delete tax_rate_path(tax_rate_id)
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:alert]).to include('not supported by the API')
    end
  end
end