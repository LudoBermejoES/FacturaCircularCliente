require 'rails_helper'

RSpec.describe 'TaxRates', type: :request do
  let(:tax_rate) { build(:tax_rate_response) }
  let(:tax_rates) { [tax_rate] }
  let(:regional_rates) { [tax_rate] }
  let(:irpf_rates) { [tax_rate] }
  let(:token) { 'mock-token' }
  
  before do
    # Mock TaxService calls
    allow(TaxService).to receive(:rates).and_return(tax_rates)
    allow(TaxService).to receive(:regional_rates).and_return(regional_rates)
    allow(TaxService).to receive(:irpf_rates).and_return(irpf_rates)
    allow(TaxService).to receive(:rate).and_return(tax_rate)
    allow(TaxService).to receive(:create_rate).and_return(tax_rate)
    allow(TaxService).to receive(:update_rate).and_return(tax_rate)
    allow(TaxService).to receive(:delete_rate).and_return(true)
    
    # Mock current_user_token method
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return(token)
  end

  describe 'GET /tax_rates' do
    it 'lists tax rates' do
      get tax_rates_path
      
      expect(response).to have_http_status(:ok)
      expect(assigns(:tax_rates)).to eq(tax_rates)
      expect(assigns(:regional_rates)).to eq(regional_rates)
      expect(assigns(:irpf_rates)).to eq(irpf_rates)
      
      # Verify service calls
      expect(TaxService).to have_received(:rates).with(token: token)
      expect(TaxService).to have_received(:regional_rates).with(token: token)
      expect(TaxService).to have_received(:irpf_rates).with(token: token)
    end

    it 'supports JSON format' do
      get tax_rates_path, headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(JSON.parse(response.body)).to be_present
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:rates).and_raise(ApiService::ApiError.new('API Error'))
      
      get tax_rates_path
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'GET /tax_rates/:id' do
    let(:tax_rate_id) { tax_rate[:id] }

    it 'shows specific tax rate' do
      get tax_rate_path(tax_rate_id)
      
      expect(response).to have_http_status(:ok)
      expect(assigns(:tax_rate)).to eq(tax_rate)
      
      expect(TaxService).to have_received(:rate).with(tax_rate_id.to_s, token: token)
    end

    it 'supports JSON format' do
      get tax_rate_path(tax_rate_id), headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(JSON.parse(response.body)).to eq(tax_rate.stringify_keys)
    end

    it 'handles tax rate not found' do
      allow(TaxService).to receive(:rate).and_raise(ApiService::ApiError.new('Tax rate not found'))
      
      get tax_rate_path(tax_rate_id)
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'GET /tax_rates/new' do
    it 'shows new tax rate form' do
      get new_tax_rate_path
      
      expect(response).to have_http_status(:ok)
      expect(assigns(:tax_rate)).to be_a(Hash)
      expect(assigns(:tax_rate)[:name]).to eq('')
      expect(assigns(:tax_rate)[:rate]).to eq(21.0)
    end
  end

  describe 'POST /tax_rates' do
    let(:tax_rate_params) do
      {
        name: 'New VAT Rate',
        rate: 15.0,
        type: 'reduced',
        region: 'canary_islands',
        active: true,
        description: 'Canary Islands reduced rate'
      }
    end

    it 'creates tax rate successfully' do
      post tax_rates_path, params: { tax_rate: tax_rate_params }
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:notice]).to eq('Tax rate was successfully created.')
      
      expect(TaxService).to have_received(:create_rate).with(
        tax_rate_params.stringify_keys,
        token: token
      )
    end

    it 'supports JSON format for creation' do
      post tax_rates_path, 
           params: { tax_rate: tax_rate_params },
           headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    context 'with validation errors' do
      before do
        allow(TaxService).to receive(:create_rate).and_raise(
          ApiService::ValidationError.new('Validation failed', ['Rate must be positive'])
        )
      end

      it 'renders form with errors for HTML format' do
        post tax_rates_path, params: { tax_rate: tax_rate_params }
        
        expect(response).to have_http_status(:ok) # renders :new
        expect(flash.now[:alert]).to eq('Rate must be positive')
      end

      it 'returns JSON errors for JSON format' do
        post tax_rates_path, 
             params: { tax_rate: tax_rate_params },
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Rate must be positive')
      end
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:create_rate).and_raise(ApiService::ApiError.new('Server error'))
      
      post tax_rates_path, params: { tax_rate: tax_rate_params }
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'GET /tax_rates/:id/edit' do
    let(:tax_rate_id) { tax_rate[:id] }

    it 'shows edit tax rate form' do
      get edit_tax_rate_path(tax_rate_id)
      
      expect(response).to have_http_status(:ok)
      expect(assigns(:tax_rate)).to eq(tax_rate)
      
      expect(TaxService).to have_received(:rate).with(tax_rate_id.to_s, token: token)
    end
  end

  describe 'PUT /tax_rates/:id' do
    let(:tax_rate_id) { tax_rate[:id] }
    let(:update_params) do
      {
        name: 'Updated VAT Rate',
        rate: 18.0,
        type: 'standard'
      }
    end

    it 'updates tax rate successfully' do
      put tax_rate_path(tax_rate_id), params: { tax_rate: update_params }
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:notice]).to eq('Tax rate was successfully updated.')
      
      expect(TaxService).to have_received(:update_rate).with(
        tax_rate_id.to_s,
        update_params.stringify_keys,
        token: token
      )
    end

    it 'supports JSON format for updates' do
      put tax_rate_path(tax_rate_id), 
          params: { tax_rate: update_params },
          headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end

    context 'with validation errors' do
      before do
        allow(TaxService).to receive(:update_rate).and_raise(
          ApiService::ValidationError.new('Validation failed', ['Name cannot be blank'])
        )
      end

      it 'renders edit form with errors for HTML format' do
        put tax_rate_path(tax_rate_id), params: { tax_rate: update_params }
        
        expect(response).to have_http_status(:ok) # renders :edit
        expect(flash.now[:alert]).to eq('Name cannot be blank')
      end

      it 'returns JSON errors for JSON format' do
        put tax_rate_path(tax_rate_id), 
            params: { tax_rate: update_params },
            headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Name cannot be blank')
      end
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:update_rate).and_raise(ApiService::ApiError.new('Server error'))
      
      put tax_rate_path(tax_rate_id), params: { tax_rate: update_params }
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'DELETE /tax_rates/:id' do
    let(:tax_rate_id) { tax_rate[:id] }

    it 'deletes tax rate successfully' do
      delete tax_rate_path(tax_rate_id)
      
      expect(response).to redirect_to(tax_rates_path)
      expect(flash[:notice]).to eq('Tax rate was successfully deleted.')
      
      expect(TaxService).to have_received(:delete_rate).with(tax_rate_id.to_s, token: token)
    end

    it 'supports JSON format for deletion' do
      delete tax_rate_path(tax_rate_id), headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:no_content)
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:delete_rate).and_raise(ApiService::ApiError.new('Cannot delete'))
      
      delete tax_rate_path(tax_rate_id)
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end
end