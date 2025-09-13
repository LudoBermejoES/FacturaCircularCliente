require 'rails_helper'

RSpec.describe InvoiceSeriesService, type: :service do
  let(:token) { 'test_access_token' }
  let(:series_id) { '456' }
  
  describe '.all' do
    let(:response_body) do
      {
        data: {
          attributes: {
            series: [
              { id: 1, series_code: 'FC', series_name: 'Facturas', year: 2025, current_number: 10 },
              { id: 2, series_code: 'PF', series_name: 'Proformas', year: 2025, current_number: 5 }
            ]
          }
        }
      }
    end

    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_body.to_json)
    end

    it 'returns all invoice series' do
      result = described_class.all(token: token)
      expect(result).to eq(response_body[:data][:attributes][:series])
    end

    context 'with filters' do
      let(:filters) { { year: 2025, active_only: true } }

      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { year: 2025, active_only: true }
          )
          .to_return(status: 200, body: response_body.to_json)
      end

      it 'passes filters as query parameters' do
        result = described_class.all(token: token, filters: filters)
        expect(result).to eq(response_body[:data][:attributes][:series])
      end
    end
  end

  describe '.find' do
    let(:series_data) do
      {
        data: {
          attributes: {
            id: series_id,
            series_code: 'FC',
            series_name: 'Facturas Comerciales',
            year: 2025,
            current_number: 15,
            is_active: true,
            is_default: false
          }
        }
      }
    end

    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: series_data.to_json)
    end

    it 'returns specific invoice series' do
      result = described_class.find(series_id, token: token)
      expect(result).to eq(series_data[:data][:attributes])
    end
  end

  describe '.create' do
    let(:series_params) do
      {
        series_code: 'FC',
        series_name: 'Facturas Comerciales',
        year: 2025,
        series_type: 'commercial',
        is_active: true,
        is_default: false,
        legal_justification: 'Nueva serie para facturas comerciales'
      }
    end

    let(:response_body) do
      {
        data: series_params.merge(id: 789, current_number: 0)
      }
    end

    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/invoice_series")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: series_params.to_json
        )
        .to_return(status: 201, body: response_body.to_json)
    end

    it 'creates new invoice series' do
      result = described_class.create(series_params, token: token)
      expect(result).to eq(response_body[:data])
    end
  end

  describe '.update' do
    let(:update_params) do
      {
        series_name: 'Updated Series Name',
        is_active: false,
        legal_justification: 'Deactivating series for compliance'
      }
    end

    let(:response_body) do
      {
        data: {
          id: series_id,
          series_code: 'FC',
          series_name: 'Updated Series Name',
          year: 2025,
          is_active: false
        }
      }
    end

    before do
      stub_request(:put, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: update_params.to_json
        )
        .to_return(status: 200, body: response_body.to_json)
    end

    it 'updates invoice series' do
      result = described_class.update(series_id, update_params, token: token)
      expect(result).to eq(response_body[:data])
    end
  end

  describe '.destroy' do
    before do
      stub_request(:delete, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '')
    end

    it 'deletes invoice series' do
      result = described_class.destroy(series_id, token: token)
      expect(result).to be true
    end
  end

  describe '.activate' do
    let(:response_body) do
      {
        data: { 
          id: series_id, 
          is_active: true, 
          activation_date: Date.current.to_s,
          message: 'Series activated successfully' 
        }
      }
    end

    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}/activate")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: {}.to_json
        )
        .to_return(status: 200, body: response_body.to_json)
    end

    it 'activates invoice series' do
      result = described_class.activate(series_id, token: token)
      expect(result).to eq(response_body[:data])
    end

    context 'with effective date' do
      let(:effective_date) { '2025-02-01' }

      before do
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}/activate")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { effective_date: effective_date }.to_json
          )
          .to_return(status: 200, body: response_body.to_json)
      end

      it 'activates with effective date' do
        result = described_class.activate(series_id, token: token, effective_date: effective_date)
        expect(result).to eq(response_body[:data])
      end
    end
  end

  describe '.deactivate' do
    let(:reason) { 'End of fiscal year' }
    let(:response_body) do
      {
        data: { 
          id: series_id, 
          is_active: false, 
          deactivation_date: Date.current.to_s,
          deactivation_reason: reason,
          message: 'Series deactivated successfully' 
        }
      }
    end

    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}/deactivate")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: { reason: reason }.to_json
        )
        .to_return(status: 200, body: response_body.to_json)
    end

    it 'deactivates invoice series with reason' do
      result = described_class.deactivate(series_id, token: token, reason: reason)
      expect(result).to eq(response_body[:data])
    end
  end

  describe '.statistics' do
    let(:stats_data) do
      {
        data: {
          attributes: {
            total_invoices: 150,
            numbers_used: 150,
            gaps_count: 2,
            gaps: [5, 27],
            last_used_date: '2025-01-10',
            usage_by_month: {
              :'2025-01' => 150
            }
          }
        }
      }
    end

    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}/statistics")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: stats_data.to_json)
    end

    it 'returns series statistics' do
      result = described_class.statistics(series_id, token: token)
      expect(result).to eq(stats_data[:data][:attributes])
    end
  end

  describe '.compliance' do
    let(:compliance_data) do
      {
        data: {
          attributes: {
            is_compliant: true,
            has_gaps: false,
            has_duplicates: false,
            validation_errors: [],
            recommendations: ['Consider setting up automatic backup']
          }
        }
      }
    end

    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}/compliance")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: compliance_data.to_json)
    end

    it 'returns compliance check results' do
      result = described_class.compliance(series_id, token: token)
      expect(result).to eq(compliance_data[:data][:attributes])
    end
  end

  describe '.rollover' do
    let(:new_year) { '2026' }
    let(:response_body) do
      {
        data: {
          old_series: { id: series_id, year: 2025, is_active: false },
          new_series: { id: 999, year: 2026, is_active: true, current_number: 0 },
          message: 'Series rolled over successfully'
        }
      }
    end

    before do
      expected_body = {
        new_year: new_year
      }

      stub_request(:post, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}/rollover")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: expected_body.to_json
        )
        .to_return(status: 200, body: response_body.to_json)
    end

    it 'rolls over series to new year' do
      result = described_class.rollover(series_id, token: token, new_year: new_year)
      expect(result).to eq(response_body[:data])
    end
  end

  describe '.series_types' do
    it 'returns array of series types for dropdowns' do
      result = described_class.series_types
      expect(result).to be_an(Array)
      expect(result.first).to eq(['Commercial', 'commercial'])
    end
  end

  describe '.series_codes' do
    it 'returns array of series codes for dropdowns' do
      result = described_class.series_codes
      expect(result).to be_an(Array)
      expect(result.first).to eq(['FC - Factura Comercial', 'FC'])
    end
  end

  describe 'error handling' do
    context 'when API returns 404' do
      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series/#{series_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'raises ApiError' do
        expect {
          described_class.find(series_id, token: token)
        }.to raise_error(ApiService::ApiError)
      end
    end

    context 'when API returns 422' do
      let(:error_response) do
        {
          errors: {
            series_code: ['is already taken'],
            year: ['must be present']
          }
        }
      end

      before do
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoice_series")
          .to_return(status: 422, body: error_response.to_json)
      end

      it 'raises ValidationError' do
        expect {
          described_class.create({}, token: token)
        }.to raise_error(ApiService::ValidationError)
      end
    end

    context 'when authentication fails' do
      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_series")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises AuthenticationError' do
        expect {
          described_class.all(token: token)
        }.to raise_error(ApiService::AuthenticationError)
      end
    end
  end
end