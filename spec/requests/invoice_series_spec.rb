require 'rails_helper'

RSpec.describe 'InvoiceSeries', type: :request do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company_id) { 123 }
  let(:series_id) { 456 }
  let(:company) { build(:company_response, id: company_id, name: 'Test Company') }
  
  let(:series_data) do
    {
      id: series_id,
      series_code: 'FC',
      series_name: 'Facturas Comerciales',
      year: 2025,
      current_number: 10,
      is_active: true,
      is_default: false,
      series_type: 'standard'
    }
  end

  let(:series_list) do
    [series_data]
  end

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    
    # Mock API calls
    allow(CompanyService).to receive(:find).with(company_id.to_s, token: token).and_return(company)
    allow(InvoiceSeriesService).to receive(:all).and_return(series_list)
    allow(InvoiceSeriesService).to receive(:find).and_return(series_data)
  end

  describe 'GET /companies/:company_id/invoice_series' do
    it 'displays invoice series list' do
      get company_invoice_series_index_path(company_id)
      
      if response.status != 200
        puts "Response status: #{response.status}"
        # Extract actual error from HTML error page
        if response.body.include?('<h2 id="container">')
          error_match = response.body.match(/<h2 id="container">(.*?)<\/h2>/m)
          puts "Error: #{error_match[1]}" if error_match
        end
        if response.body.include?('<div id="message">')
          message_match = response.body.match(/<div id="message">(.*?)<\/div>/m)
          puts "Message: #{message_match[1]}" if message_match
        end
        if response.body.include?('ActionView::Template::Error')
          puts "Template error detected"
          error_section = response.body.match(/<pre[^>]*>(.*?)<\/pre>/m)
          puts "Error details: #{error_section[1][0..500]}" if error_section
        end
      end
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Invoice Series')
      expect(response.body).to include('Facturas Comerciales')
      expect(response.body).to include('FC')
    end

    it 'includes action buttons' do
      get company_invoice_series_index_path(company_id)
      
      expect(response.body).to include('New Series')
    end

    it 'shows active/inactive status' do
      get company_invoice_series_index_path(company_id)
      
      expect(response.body).to include('Active')
    end
  end

  describe 'GET /companies/:company_id/invoice_series/:id' do
    let(:statistics) do
      { total_invoices: 100, numbers_used: 100, gaps_count: 0 }
    end

    before do
      allow(InvoiceSeriesService).to receive(:statistics).and_return(statistics)
    end

    it 'displays series details' do
      get company_invoice_series_path(company_id, series_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Facturas Comerciales')
      expect(response.body).to include('FC')
      expect(response.body).to include('2025')
      expect(response.body).to include('Current Number')
    end

    it 'shows series statistics' do
      get company_invoice_series_path(company_id, series_id)
      
      expect(response.body).to include('Usage Statistics')
      expect(response.body).to include('Total Invoices')
    end

    it 'includes action buttons' do
      get company_invoice_series_path(company_id, series_id)
      
      expect(response.body).to include('Edit')
      expect(response.body).to include('Deactivate')
      expect(response.body).to include('Check Compliance')
      expect(response.body).to include('View Statistics')
    end
  end

  describe 'GET /companies/:company_id/invoice_series/new' do
    before do
      allow(InvoiceSeriesService).to receive(:series_codes).and_return([['FC - Factura', 'FC']])
      allow(InvoiceSeriesService).to receive(:series_types).and_return([['Commercial', 'commercial']])
    end
    
    it 'displays new invoice series form' do
      get new_company_invoice_series_path(company_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New')
      expect(response.body).to include('Series')
    end

    it 'includes form controls' do
      get new_company_invoice_series_path(company_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('invoice_series')
    end
  end

  describe 'GET /companies/:company_id/invoice_series/:id/edit' do
    before do
      allow(InvoiceSeriesService).to receive(:series_codes).and_return([['FC - Factura', 'FC']])
      allow(InvoiceSeriesService).to receive(:series_types).and_return([['Commercial', 'commercial']])
    end
    
    it 'displays edit invoice series form' do
      get edit_company_invoice_series_path(company_id, series_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit')
    end

    it 'shows non-editable fields as text' do
      get edit_company_invoice_series_path(company_id, series_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('cannot be changed')
    end

    it 'includes update button' do
      get edit_company_invoice_series_path(company_id, series_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Update')
    end
  end

  describe 'POST /companies/:company_id/invoice_series' do
    let(:create_params) do
      {
        invoice_series: {
          series_code: 'PF',
          series_name: 'Proformas',
          year: '2025',
          series_type: 'proforma',
          is_active: 'true',
          legal_justification: 'New proforma series'
        }
      }
    end

    context 'when successful' do
      before do
        allow(InvoiceSeriesService).to receive(:create)
          .and_return(series_data.merge(id: 789))
      end

      it 'creates new series and redirects' do
        post company_invoice_series_index_path(company_id), params: create_params
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, 789))
        expect(flash[:notice]).to eq('Invoice series created successfully')
      end
    end

    context 'when validation fails' do
      before do
        allow(InvoiceSeriesService).to receive(:create)
          .and_raise(ApiService::ValidationError.new('series_code is already taken'))
      end

      it 'renders new template with errors' do
        post company_invoice_series_index_path(company_id), params: create_params
        
        expect(response).to have_http_status(:ok)
        expect(flash[:alert]).to include('series_code is already taken')
      end
    end
  end

  describe 'PATCH /companies/:company_id/invoice_series/:id' do
    let(:update_params) do
      {
        invoice_series: {
          series_name: 'Updated Name',
          is_active: 'false'
        }
      }
    end

    context 'when successful' do
      before do
        allow(InvoiceSeriesService).to receive(:update)
          .and_return(series_data.merge(series_name: 'Updated Name'))
      end

      it 'updates series and redirects' do
        patch company_invoice_series_path(company_id, series_id), params: update_params
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
        expect(flash[:notice]).to eq('Invoice series updated successfully')
      end
    end
  end

  describe 'DELETE /companies/:company_id/invoice_series/:id' do
    context 'when successful' do
      before do
        allow(InvoiceSeriesService).to receive(:delete)
          .and_return({ success: true })
      end

      it 'deletes series and redirects to index' do
        delete company_invoice_series_path(company_id, series_id)
        
        expect(response).to redirect_to(company_invoice_series_index_path(company_id))
        expect(flash[:notice]).to eq('Invoice series deleted successfully')
      end
    end

    context 'when deletion fails' do
      before do
        allow(InvoiceSeriesService).to receive(:delete)
          .and_raise(ApiService::ApiError.new('Cannot delete series with invoices'))
      end

      it 'redirects with error' do
        delete company_invoice_series_path(company_id, series_id)
        
        expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
        expect(flash[:error]).to eq('Cannot delete series with invoices')
      end
    end
  end

  describe 'POST /companies/:company_id/invoice_series/:id/activate' do
    before do
      allow(InvoiceSeriesService).to receive(:activate)
        .and_return({ id: series_id, is_active: true })
    end

    it 'activates series and redirects' do
      post activate_company_invoice_series_path(company_id, series_id)
      
      expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
      expect(flash[:notice]).to eq('Invoice series activated successfully')
    end
  end

  describe 'POST /companies/:company_id/invoice_series/:id/deactivate' do
    before do
      allow(InvoiceSeriesService).to receive(:deactivate)
        .and_return({ id: series_id, is_active: false })
    end

    it 'deactivates series and redirects' do
      post deactivate_company_invoice_series_path(company_id, series_id), 
           params: { reason: 'End of year' }
      
      expect(response).to redirect_to(company_invoice_series_path(company_id, series_id))
      expect(flash[:notice]).to eq('Invoice series deactivated successfully')
    end
  end

  describe 'GET /companies/:company_id/invoice_series/:id/statistics' do
    let(:stats) do
      {
        total_invoices: 150,
        numbers_used: 150,
        gaps_count: 2,
        gaps: [5, 27]
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:statistics).and_return(stats)
    end

    it 'returns statistics partial' do
      get statistics_company_invoice_series_path(company_id, series_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('150')
      expect(response.body).to include('Gaps Detected')
    end
  end

  describe 'GET /companies/:company_id/invoice_series/:id/compliance' do
    let(:compliance_data) do
      {
        is_compliant: true,
        has_gaps: false,
        has_duplicates: false,
        validation_errors: [],
        recommendations: ['Consider enabling automatic backup']
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:compliance).and_return(compliance_data)
    end

    it 'returns compliance partial' do
      get compliance_company_invoice_series_path(company_id, series_id)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Compliant')
      expect(response.body).to include('Consider enabling automatic backup')
    end
  end

  describe 'POST /companies/:company_id/invoice_series/:id/rollover' do
    let(:rollover_response) do
      {
        old_series: { id: series_id, year: 2025 },
        new_series: { id: 999, year: 2026 }
      }
    end

    before do
      allow(InvoiceSeriesService).to receive(:rollover).and_return(rollover_response)
    end

    it 'rolls over series to new year' do
      post rollover_company_invoice_series_path(company_id, series_id),
           params: { new_year: '2026' }
      
      expect(response).to redirect_to(company_invoice_series_path(company_id, 999))
      expect(flash[:notice]).to include('2026')
    end
  end

  describe 'error handling' do
    context 'when company not found' do
      before do
        allow(CompanyService).to receive(:find)
          .and_raise(ApiService::ApiError.new('Company not found'))
      end

      it 'redirects to companies index' do
        get company_invoice_series_index_path(company_id)
        
        expect(response).to redirect_to(companies_path)
        expect(flash[:error]).to eq('Company not found')
      end
    end

    context 'when authentication fails' do
      before do
        # Override the global mock to not stub authenticate_user!
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_call_original
        # Make logged_in? return false so authenticate_user! will redirect
        allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)
      end

      it 'redirects to login' do
        get company_invoice_series_index_path(company_id)
        expect(response).to redirect_to(login_path)
      end
    end
  end
end