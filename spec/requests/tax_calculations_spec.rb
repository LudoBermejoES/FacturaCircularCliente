require 'rails_helper'

RSpec.describe 'TaxCalculations', type: :request do
  let(:tax_calculation) { build(:tax_calculation_response) }
  let(:invoice) { build(:invoice_response) }
  let(:token) { 'mock-token' }
  
  before do
    # Mock TaxService calls
    allow(TaxService).to receive(:calculate).and_return(tax_calculation)
    allow(TaxService).to receive(:calculate_invoice).and_return(tax_calculation)
    allow(TaxService).to receive(:recalculate_invoice).and_return(tax_calculation)
    allow(TaxService).to receive(:validate_tax_id).and_return({ valid: true })
    allow(TaxService).to receive(:validate_invoice_tax).and_return({ valid: true })
    
    # Mock InvoiceService calls
    allow(InvoiceService).to receive(:find).and_return(invoice)
    
    # Mock current_user_token method
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return(token)
  end

  describe 'GET /tax_calculations/new' do
    it 'shows new tax calculation form' do
      get new_tax_calculation_path
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /tax_calculations' do
    let(:calculation_params) do
      {
        base_amount: 1000.0,
        tax_rate: 21,
        discount_percentage: 10,
        retention_percentage: 15
      }
    end

    it 'performs tax calculation successfully' do
      post tax_calculations_path, params: { calculation: calculation_params }
      
      expect(response).to have_http_status(:ok) # renders :show
      
      expect(TaxService).to have_received(:calculate).with(
        instance_of(ActionController::Parameters),
        token: token
      )
    end

    it 'supports JSON format' do
      post tax_calculations_path, 
           params: { calculation: calculation_params },
           headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(JSON.parse(response.body)).to be_present
    end

    it 'supports turbo stream format' do
      post tax_calculations_path, 
           params: { calculation: calculation_params },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
    end

    context 'with validation errors' do
      before do
        allow(TaxService).to receive(:calculate).and_raise(
          ApiService::ValidationError.new('Validation failed', ['Base amount must be positive'])
        )
      end

      it 'renders form with errors for HTML format' do
        post tax_calculations_path, params: { calculation: calculation_params }
        
        expect(response).to have_http_status(:ok) # renders :new
        expect(flash.now[:alert]).to eq('Base amount must be positive')
      end

      it 'returns JSON errors for JSON format' do
        post tax_calculations_path, 
             params: { calculation: calculation_params },
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Base amount must be positive')
      end

      it 'renders error partial for turbo stream format' do
        post tax_calculations_path, 
             params: { calculation: calculation_params },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('calculation_errors')
      end
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:calculate).and_raise(ApiService::ApiError.new('Server error'))
      
      post tax_calculations_path, params: { calculation: calculation_params }
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'GET /tax_calculations/invoice/:invoice_id' do
    let(:invoice_id) { invoice[:id] }

    it 'calculates taxes for specific invoice' do
      get invoice_tax_calculation_path(invoice_id)
      
      expect(response).to have_http_status(:ok)
      
      expect(TaxService).to have_received(:calculate_invoice).with(
        invoice_id.to_s,
        token: token
      )
      expect(InvoiceService).to have_received(:find).with(
        invoice_id.to_s,
        token: token
      )
    end

    it 'supports JSON format' do
      get invoice_tax_calculation_path(invoice_id), 
          headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(JSON.parse(response.body)).to be_present
    end

    it 'supports turbo stream format' do
      get invoice_tax_calculation_path(invoice_id), 
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:calculate_invoice).and_raise(
        ApiService::ApiError.new('Invoice not found')
      )
      
      get invoice_tax_calculation_path(invoice_id)
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'POST /tax_calculations/recalculate/:invoice_id' do
    let(:invoice_id) { invoice[:id] }

    it 'recalculates taxes for invoice' do
      post recalculate_tax_calculation_path(invoice_id)
      
      expect(response).to redirect_to(invoice_path(invoice_id))
      expect(flash[:notice]).to eq('Tax recalculated successfully')
      
      expect(TaxService).to have_received(:recalculate_invoice).with(
        invoice_id.to_s,
        token: token
      )
      expect(InvoiceService).to have_received(:find).with(
        invoice_id.to_s,
        token: token
      )
    end

    it 'supports JSON format' do
      post recalculate_tax_calculation_path(invoice_id), 
           headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(JSON.parse(response.body)).to be_present
    end

    it 'supports turbo stream format' do
      post recalculate_tax_calculation_path(invoice_id), 
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
    end

    it 'handles API errors gracefully' do
      allow(TaxService).to receive(:recalculate_invoice).and_raise(
        ApiService::ApiError.new('Recalculation failed')
      )
      
      post recalculate_tax_calculation_path(invoice_id)
      
      expect(response).to have_http_status(:found) # redirect due to error handling
    end
  end

  describe 'POST /tax_calculations/validate' do
    context 'with tax ID validation' do
      let(:tax_id) { 'B12345678' }
      let(:country) { 'ES' }

      it 'validates tax ID successfully' do
        post validate_tax_calculations_path, 
             params: { tax_id: tax_id, country: country },
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
        expect(JSON.parse(response.body)['valid']).to be true
        
        expect(TaxService).to have_received(:validate_tax_id).with(
          tax_id,
          country: country,
          token: token
        )
      end

      it 'validates with default country when not specified' do
        post validate_tax_calculations_path, 
             params: { tax_id: tax_id },
             headers: { 'Accept' => 'application/json' }
        
        expect(TaxService).to have_received(:validate_tax_id).with(
          tax_id,
          country: 'ES',
          token: token
        )
      end

      it 'supports turbo stream format' do
        post validate_tax_calculations_path, 
             params: { tax_id: tax_id, country: country },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/vnd.turbo-stream.html')
      end
    end

    context 'with invoice tax validation' do
      let(:invoice_id) { invoice[:id] }

      it 'validates invoice tax successfully' do
        post validate_tax_calculations_path, 
             params: { invoice_id: invoice_id },
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['valid']).to be true
        
        expect(TaxService).to have_received(:validate_invoice_tax).with(
          invoice_id.to_s,
          token: token
        )
      end
    end

    context 'with no parameters' do
      it 'returns validation error' do
        post validate_tax_calculations_path, 
             params: {},
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:ok)
        result = JSON.parse(response.body)
        expect(result['valid']).to be false
        expect(result['errors']).to include('No tax ID or invoice ID provided')
      end
    end

    context 'with API errors' do
      before do
        allow(TaxService).to receive(:validate_tax_id).and_raise(
          ApiService::ApiError.new('Validation service unavailable')
        )
      end

      it 'handles API errors for JSON format' do
        post validate_tax_calculations_path, 
             params: { tax_id: 'B12345678' },
             headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        result = JSON.parse(response.body)
        expect(result['valid']).to be false
        expect(result['errors']).to include('Validation service unavailable')
      end

      it 'handles API errors for turbo stream format' do
        post validate_tax_calculations_path, 
             params: { tax_id: 'B12345678' },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('validation_result')
      end
    end
  end
end