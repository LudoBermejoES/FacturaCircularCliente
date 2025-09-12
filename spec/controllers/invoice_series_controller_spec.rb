require 'rails_helper'

RSpec.describe InvoiceSeriesController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company_id) { '123' }
  let(:series_id) { '456' }
  let(:company) { build(:company_response, id: company_id.to_i, name: 'Test Company') }
  
  let(:series_data) do
    {
      id: series_id.to_i,
      series_code: 'FC',
      series_name: 'Facturas Comerciales',
      year: 2025,
      current_number: 10,
      is_active: true,
      is_default: false,
      series_type: 'standard',
      activation_date: '2025-01-01',
      legal_justification: 'Required for commercial invoices'
    }
  end

  let(:series_list) do
    {
      invoice_series: [series_data],
      meta: { total: 1, page: 1, pages: 1 }
    }
  end

  before do
    # Mock authentication
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_token).and_return(token)
    
    # Mock CompanyService.find for all tests - use string ID
    allow(CompanyService).to receive(:find).with(company_id, token: token).and_return(company)
  end

  describe 'GET #index' do
    before do
      allow(InvoiceSeriesService).to receive(:all).with(company_id, token: token, filters: {})
        .and_return(series_list)
    end

    it 'renders index template with invoice series' do
      get :index, params: { company_id: company_id }
      
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
      expect(assigns(:invoice_series)).to eq(series_list[:invoice_series])
      expect(assigns(:company)).to eq(company)
    end

    context 'with filters' do
      let(:filters) { { 'year' => '2025', 'is_active' => 'true' } }

      before do
        allow(InvoiceSeriesService).to receive(:all).with(company_id, token: token, filters: filters)
          .and_return(series_list)
      end

      it 'passes filters to the service' do
        get :index, params: { company_id: company_id, year: '2025', is_active: 'true' }
        
        expect(InvoiceSeriesService).to have_received(:all).with(company_id, token: token, filters: filters)
      end
    end

    context 'when API error occurs' do
      before do
        allow(InvoiceSeriesService).to receive(:all)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'sets error flash and redirects to company page' do
        get :index, params: { company_id: company_id }
        
        expect(response).to redirect_to(company_path(company_id))
        expect(flash[:error]).to eq('Server error')
      end
    end
  end

  describe 'GET #show' do
    let(:statistics) do
      { total_invoices: 100, numbers_used: 100, gaps_count: 0 }
    end

    before do
      allow(InvoiceSeriesService).to receive(:find).with(company_id, series_id, token: token)
        .and_return(series_data)
      allow(InvoiceSeriesService).to receive(:statistics).with(company_id, series_id, token: token)
        .and_return(statistics)
    end

    it 'renders show template with series details' do
      get :show, params: { company_id: company_id, id: series_id }
      
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
      expect(assigns(:invoice_series)).to eq(series_data)
      expect(assigns(:statistics)).to eq(statistics)
    end
  end

  describe 'GET #new' do
    before do
      allow(InvoiceSeriesService).to receive(:all).with(company_id, token: token, filters: {})
        .and_return(series_list)
    end

    it 'renders new template with form data' do
      get :new, params: { company_id: company_id }
      
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
      expect(assigns(:invoice_series)).to include(
        year: Date.current.year,
        is_active: true,
        is_default: false
      )
      expect(assigns(:series_codes)).to eq(['FC', 'PF', 'CR', 'AB', 'RE'])
      expect(assigns(:series_types)).to eq(['standard', 'proforma', 'credit_note', 'debit_note', 'receipt'])
    end
  end

  describe 'GET #edit' do
    before do
      allow(InvoiceSeriesService).to receive(:find).with(company_id, series_id, token: token)
        .and_return(series_data)
    end

    it 'renders edit template with series data' do
      get :edit, params: { company_id: company_id, id: series_id }
      
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
      expect(assigns(:invoice_series)).to eq(series_data)
    end
  end

  describe 'POST #create' do
    let(:series_params) do
      {
        series_code: 'FC',
        series_name: 'New Series',
        year: '2025',
        series_type: 'standard',
        is_active: 'true',
        is_default: 'false',
        legal_justification: 'New series for testing'
      }
    end

    let(:formatted_params) do
      {
        series_code: 'FC',
        series_name: 'New Series',
        year: 2025,
        series_type: 'standard',
        is_active: true,
        is_default: false,
        legal_justification: 'New series for testing'
      }
    end

    context 'when successful' do
      before do
        allow(InvoiceSeriesService).to receive(:create)
          .with(company_id, formatted_params, token: token)
          .and_return(series_data.merge(id: 789))
      end

      it 'creates series and redirects to show page' do
        post :create, params: { company_id: company_id, invoice_series: series_params }
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, 789))
        expect(flash[:notice]).to eq('Invoice series created successfully')
      end
    end

    context 'when validation fails' do
      let(:error_response) do
        { errors: { series_code: ['is already taken'] } }
      end

      before do
        allow(InvoiceSeriesService).to receive(:create)
          .with(company_id, formatted_params, token: token)
          .and_return(error_response)
      end

      it 'renders new template with errors' do
        post :create, params: { company_id: company_id, invoice_series: series_params }
        
        expect(response).to render_template(:new)
        expect(assigns(:invoice_series)[:errors]).to include('Series code is already taken')
      end
    end

    context 'when API error occurs' do
      before do
        allow(InvoiceSeriesService).to receive(:create)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'renders new template with error' do
        post :create, params: { company_id: company_id, invoice_series: series_params }
        
        expect(response).to render_template(:new)
        expect(assigns(:invoice_series)[:errors]).to include('Server error')
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        series_name: 'Updated Name',
        is_active: 'false',
        legal_justification: 'Updating for test'
      }
    end

    let(:formatted_params) do
      {
        series_name: 'Updated Name',
        is_active: false,
        legal_justification: 'Updating for test'
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:find).with(company_id, series_id, token: token)
        .and_return(series_data)
    end

    context 'when successful' do
      before do
        allow(InvoiceSeriesService).to receive(:update)
          .with(company_id, series_id, formatted_params, token: token)
          .and_return(series_data.merge(series_name: 'Updated Name'))
      end

      it 'updates series and redirects to show page' do
        patch :update, params: { company_id: company_id, id: series_id, invoice_series: update_params }
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
        expect(flash[:notice]).to eq('Invoice series updated successfully')
      end
    end

    context 'when validation fails' do
      let(:error_response) do
        { errors: { series_name: ['is too long'] } }
      end

      before do
        allow(InvoiceSeriesService).to receive(:update)
          .with(company_id, series_id, formatted_params, token: token)
          .and_return(error_response)
      end

      it 'renders edit template with errors' do
        patch :update, params: { company_id: company_id, id: series_id, invoice_series: update_params }
        
        expect(response).to render_template(:edit)
        expect(assigns(:invoice_series)[:errors]).to include('Series name is too long')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when successful' do
      before do
        allow(InvoiceSeriesService).to receive(:delete)
          .with(company_id, series_id, token: token)
          .and_return({ success: true })
      end

      it 'deletes series and redirects to index' do
        delete :destroy, params: { company_id: company_id, id: series_id }
        
        expect(response).to redirect_to(company_invoice_series_index_path(company_id))
        expect(flash[:notice]).to eq('Invoice series deleted successfully')
      end
    end

    context 'when deletion fails' do
      before do
        allow(InvoiceSeriesService).to receive(:delete)
          .and_raise(ApiService::ApiError.new('Cannot delete active series'))
      end

      it 'redirects with error message' do
        delete :destroy, params: { company_id: company_id, id: series_id }
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
        expect(flash[:error]).to eq('Cannot delete active series')
      end
    end
  end

  describe 'POST #activate' do
    before do
      allow(InvoiceSeriesService).to receive(:activate)
        .with(company_id, series_id, token: token)
        .and_return({ id: series_id, is_active: true })
    end

    it 'activates series and redirects back' do
      post :activate, params: { company_id: company_id, id: series_id }
      
      expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
      expect(flash[:notice]).to eq('Series activated successfully')
    end
  end

  describe 'POST #deactivate' do
    let(:reason) { 'End of year' }

    before do
      allow(InvoiceSeriesService).to receive(:deactivate)
        .with(company_id, series_id, reason: reason, token: token)
        .and_return({ id: series_id, is_active: false })
    end

    it 'deactivates series with reason and redirects back' do
      post :deactivate, params: { company_id: company_id, id: series_id, reason: reason }
      
      expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
      expect(flash[:notice]).to eq('Series deactivated successfully')
    end
  end

  describe 'GET #statistics' do
    let(:stats) do
      {
        total_invoices: 150,
        numbers_used: 150,
        gaps_count: 0,
        usage_by_month: { '2025-01' => 150 }
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:find).with(company_id, series_id, token: token)
        .and_return(series_data)
      allow(InvoiceSeriesService).to receive(:statistics)
        .with(company_id, series_id, token: token)
        .and_return(stats)
    end

    it 'renders statistics partial' do
      get :statistics, params: { company_id: company_id, id: series_id }
      
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(partial: '_statistics')
      expect(assigns(:statistics)).to eq(stats)
    end
  end

  describe 'GET #compliance' do
    let(:compliance_data) do
      {
        is_compliant: true,
        has_gaps: false,
        has_duplicates: false,
        validation_errors: []
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:find).with(company_id, series_id, token: token)
        .and_return(series_data)
      allow(InvoiceSeriesService).to receive(:compliance)
        .with(company_id, series_id, token: token)
        .and_return(compliance_data)
    end

    it 'renders compliance partial' do
      get :compliance, params: { company_id: company_id, id: series_id }
      
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(partial: '_compliance')
      expect(assigns(:compliance)).to eq(compliance_data)
    end
  end

  describe 'POST #rollover' do
    let(:new_year) { '2026' }
    let(:rollover_response) do
      {
        old_series: { id: series_id, year: 2025 },
        new_series: { id: 999, year: 2026 },
        message: 'Series rolled over successfully'
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:rollover)
        .with(company_id, series_id, new_year: 2026, token: token)
        .and_return(rollover_response)
    end

    it 'rolls over series and redirects to new series' do
      post :rollover, params: { company_id: company_id, id: series_id, new_year: new_year }
      
      expect(response).to redirect_to(company_invoice_series_path(company_id, 999))
      expect(flash[:notice]).to eq('Series rolled over successfully to year 2026')
    end

    context 'when rollover fails' do
      before do
        allow(InvoiceSeriesService).to receive(:rollover)
          .and_raise(ApiService::ApiError.new('Series already exists for 2026'))
      end

      it 'redirects with error message' do
        post :rollover, params: { company_id: company_id, id: series_id, new_year: new_year }
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
        expect(flash[:error]).to eq('Series already exists for 2026')
      end
    end
  end

  describe 'private methods' do
    describe '#set_company' do
      context 'when company not found' do
        before do
          allow(CompanyService).to receive(:find).with(company_id, token: token)
            .and_raise(ApiService::ApiError.new('Company not found'))
        end

        it 'redirects to companies index' do
          get :index, params: { company_id: company_id }
          
          expect(response).to redirect_to(companies_path)
          expect(flash[:error]).to eq('Company not found')
        end
      end
    end
  end
end