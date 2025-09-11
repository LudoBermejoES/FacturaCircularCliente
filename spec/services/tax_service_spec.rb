require 'rails_helper'

RSpec.describe TaxService, type: :service do
  let(:token) { 'test_access_token' }
  let(:rate_id) { 123 }
  let(:invoice_id) { 456 }
  let(:exemption_id) { 789 }
  let(:base_url) { 'http://localhost:3001/api/v1' }

  describe 'Tax Rates Management' do
    describe '.rates' do
      context 'when successful' do
        let(:rates_response) do
          {
            rates: [
              { id: 1, name: 'IVA General', percentage: 21.0, type: 'IVA', country: 'ES' },
              { id: 2, name: 'IVA Reducido', percentage: 10.0, type: 'IVA', country: 'ES' },
              { id: 3, name: 'IGIC General', percentage: 7.0, type: 'IGIC', country: 'ES', region: 'Canarias' }
            ]
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_rates")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: rates_response.to_json)
        end

        it 'returns available tax rates' do
          result = TaxService.rates(token: token)
          
          expect(result[:rates].size).to eq(3)
          expect(result[:rates].first[:name]).to eq('IVA General')
          expect(result[:rates].first[:percentage]).to eq(21.0)
          expect(result[:rates].last[:type]).to eq('IGIC')
        end
      end
    end

    describe '.rate' do
      context 'when successful' do
        let(:rate_response) do
          {
            id: rate_id,
            name: 'IVA General',
            percentage: 21.0,
            type: 'IVA',
            country: 'ES',
            description: 'General VAT rate for Spain'
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_rates/#{rate_id}")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: rate_response.to_json)
        end

        it 'returns specific tax rate details' do
          result = TaxService.rate(rate_id, token: token)
          
          expect(result[:id]).to eq(rate_id)
          expect(result[:name]).to eq('IVA General')
          expect(result[:percentage]).to eq(21.0)
          expect(result[:type]).to eq('IVA')
        end
      end
    end

    describe '.create_rate' do
      let(:rate_params) do
        {
          name: 'New Tax Rate',
          percentage: 15.0,
          type: 'IVA',
          country: 'ES'
        }
      end

      context 'when successful' do
        let(:created_rate) do
          rate_params.merge(id: 999, created_at: Time.current.iso8601)
        end

        before do
          stub_request(:post, "#{base_url}/tax_rates")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              body: rate_params.to_json
            )
            .to_return(status: 201, body: created_rate.to_json)
        end

        it 'creates tax rate and returns data' do
          result = TaxService.create_rate(rate_params, token: token)
          
          expect(result[:id]).to eq(999)
          expect(result[:name]).to eq('New Tax Rate')
          expect(result[:percentage]).to eq(15.0)
        end
      end
    end
  end

  describe 'Tax Calculations' do
    describe '.calculate' do
      let(:calculation_params) do
        {
          subtotal: 1000.0,
          tax_rate: 21.0,
          region: 'Madrid'
        }
      end

      context 'when successful' do
        let(:calculation_response) do
          {
            subtotal: 1000.0,
            tax_rate: 21.0,
            tax_amount: 210.0,
            total: 1210.0,
            breakdown: {
              iva: { rate: 21.0, amount: 210.0 }
            }
          }
        end

        before do
          stub_request(:post, "#{base_url}/tax_calculations")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              body: calculation_params.to_json
            )
            .to_return(status: 200, body: calculation_response.to_json)
        end

        it 'calculates tax and returns breakdown' do
          result = TaxService.calculate(calculation_params, token: token)
          
          expect(result[:subtotal]).to eq(1000.0)
          expect(result[:tax_amount]).to eq(210.0)
          expect(result[:total]).to eq(1210.0)
          expect(result[:breakdown][:iva][:rate]).to eq(21.0)
        end
      end
    end

    describe '.calculate_invoice' do
      context 'when successful' do
        let(:invoice_calculation_response) do
          {
            invoice_id: invoice_id,
            subtotal: 1500.0,
            total_tax: 315.0,
            total: 1815.0,
            line_items: [
              { description: 'Service 1', subtotal: 1000.0, tax: 210.0, total: 1210.0 },
              { description: 'Service 2', subtotal: 500.0, tax: 105.0, total: 605.0 }
            ]
          }
        end

        before do
          stub_request(:post, "#{base_url}/invoices/#{invoice_id}/calculate_tax")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: invoice_calculation_response.to_json)
        end

        it 'calculates tax for entire invoice' do
          result = TaxService.calculate_invoice(invoice_id, token: token)
          
          expect(result[:invoice_id]).to eq(invoice_id)
          expect(result[:subtotal]).to eq(1500.0)
          expect(result[:total_tax]).to eq(315.0)
          expect(result[:line_items].size).to eq(2)
        end
      end
    end
  end

  describe 'Tax Validation' do
    describe '.validate_tax_id' do
      let(:tax_id) { 'B12345678' }

      context 'when valid Spanish tax ID' do
        let(:validation_response) do
          {
            tax_id: tax_id,
            country: 'ES',
            valid: true,
            type: 'CIF',
            company_name: 'ACME CORP SL'
          }
        end

        before do
          stub_request(:post, "#{base_url}/tax_validations/tax_id")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              body: { tax_id: tax_id, country: 'ES' }.to_json
            )
            .to_return(status: 200, body: validation_response.to_json)
        end

        it 'validates tax ID and returns details' do
          result = TaxService.validate_tax_id(tax_id, country: 'ES', token: token)
          
          expect(result[:tax_id]).to eq(tax_id)
          expect(result[:valid]).to be true
          expect(result[:type]).to eq('CIF')
          expect(result[:company_name]).to eq('ACME CORP SL')
        end
      end

      context 'when invalid tax ID' do
        let(:invalid_response) do
          {
            tax_id: tax_id,
            country: 'ES',
            valid: false,
            errors: ['Invalid format', 'Check digit mismatch']
          }
        end

        before do
          stub_request(:post, "#{base_url}/tax_validations/tax_id")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: invalid_response.to_json)
        end

        it 'returns validation errors' do
          result = TaxService.validate_tax_id(tax_id, token: token)
          
          expect(result[:valid]).to be false
          expect(result[:errors]).to include('Invalid format')
        end
      end
    end

    describe '.validate_invoice_tax' do
      context 'when invoice tax is valid' do
        let(:validation_response) do
          {
            invoice_id: invoice_id,
            valid: true,
            total_tax_calculated: 315.0,
            total_tax_declared: 315.0,
            discrepancies: []
          }
        end

        before do
          stub_request(:post, "#{base_url}/invoices/#{invoice_id}/validate_tax")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: validation_response.to_json)
        end

        it 'validates invoice tax calculations' do
          result = TaxService.validate_invoice_tax(invoice_id, token: token)
          
          expect(result[:invoice_id]).to eq(invoice_id)
          expect(result[:valid]).to be true
          expect(result[:total_tax_calculated]).to eq(315.0)
          expect(result[:discrepancies]).to be_empty
        end
      end
    end
  end

  describe 'Tax Exemptions' do
    describe '.exemptions' do
      context 'when successful' do
        let(:exemptions_response) do
          {
            exemptions: [
              { id: 1, name: 'Export exemption', code: 'E1', description: 'Goods exported outside EU' },
              { id: 2, name: 'Intra-EU supply', code: 'E2', description: 'Supply to EU registered company' }
            ]
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_exemptions")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: exemptions_response.to_json)
        end

        it 'returns available tax exemptions' do
          result = TaxService.exemptions(token: token)
          
          expect(result[:exemptions].size).to eq(2)
          expect(result[:exemptions].first[:name]).to eq('Export exemption')
          expect(result[:exemptions].first[:code]).to eq('E1')
        end
      end
    end

    describe '.apply_exemption' do
      context 'when successful' do
        let(:apply_response) do
          {
            invoice_id: invoice_id,
            exemption_id: exemption_id,
            exemption_name: 'Export exemption',
            recalculated_tax: 0.0,
            message: 'Exemption applied successfully'
          }
        end

        before do
          stub_request(:post, "#{base_url}/invoices/#{invoice_id}/apply_exemption")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              body: { exemption_id: exemption_id }.to_json
            )
            .to_return(status: 200, body: apply_response.to_json)
        end

        it 'applies tax exemption to invoice' do
          result = TaxService.apply_exemption(invoice_id, exemption_id, token: token)
          
          expect(result[:invoice_id]).to eq(invoice_id)
          expect(result[:exemption_id]).to eq(exemption_id)
          expect(result[:recalculated_tax]).to eq(0.0)
        end
      end
    end
  end

  describe 'Regional Tax Variations' do
    describe '.regional_rates' do
      context 'when successful without region filter' do
        let(:regional_response) do
          {
            regions: {
              'Madrid' => { iva_general: 21.0, iva_reducido: 10.0 },
              'Canarias' => { igic_general: 7.0, igic_reducido: 3.0 }
            }
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_rates/regional")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: regional_response.to_json)
        end

        it 'returns regional tax rates' do
          result = TaxService.regional_rates(token: token)
          
          expect(result[:regions]).to have_key(:Madrid)
          expect(result[:regions]).to have_key(:Canarias)
          expect(result[:regions][:Madrid][:iva_general]).to eq(21.0)
          expect(result[:regions][:Canarias][:igic_general]).to eq(7.0)
        end
      end

      context 'when filtering by specific region' do
        let(:canarias_response) do
          {
            region: 'Canarias',
            rates: {
              igic_general: 7.0,
              igic_reducido: 3.0,
              igic_superreducido: 0.0
            }
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_rates/regional")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              query: { region: 'Canarias' }
            )
            .to_return(status: 200, body: canarias_response.to_json)
        end

        it 'returns rates for specific region' do
          result = TaxService.regional_rates(region: 'Canarias', token: token)
          
          expect(result[:region]).to eq('Canarias')
          expect(result[:rates][:igic_general]).to eq(7.0)
          expect(result[:rates][:igic_reducido]).to eq(3.0)
        end
      end
    end
  end

  describe 'Tax Reports' do
    describe '.tax_summary' do
      let(:start_date) { '2024-01-01' }
      let(:end_date) { '2024-03-31' }

      context 'when successful' do
        let(:summary_response) do
          {
            period: { start: start_date, end: end_date },
            summary: {
              total_invoiced: 50000.0,
              total_tax_collected: 10500.0,
              iva_21: 8400.0,
              iva_10: 1500.0,
              igic_7: 600.0
            },
            by_month: [
              { month: '2024-01', total: 15000.0, tax: 3150.0 },
              { month: '2024-02', total: 18000.0, tax: 3780.0 },
              { month: '2024-03', total: 17000.0, tax: 3570.0 }
            ]
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_reports/summary")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              query: { start_date: start_date, end_date: end_date }
            )
            .to_return(status: 200, body: summary_response.to_json)
        end

        it 'returns tax summary for period' do
          result = TaxService.tax_summary(start_date: start_date, end_date: end_date, token: token)
          
          expect(result[:period][:start]).to eq(start_date)
          expect(result[:summary][:total_invoiced]).to eq(50000.0)
          expect(result[:summary][:total_tax_collected]).to eq(10500.0)
          expect(result[:by_month].size).to eq(3)
        end
      end
    end

    describe '.vat_report' do
      let(:period) { 'Q1' }
      let(:year) { 2024 }

      context 'when successful' do
        let(:vat_response) do
          {
            period: period,
            year: year,
            vat_summary: {
              total_output_vat: 10500.0,
              total_input_vat: 2100.0,
              vat_payable: 8400.0
            },
            breakdown: {
              '21%' => { output: 8400.0, input: 1680.0 },
              '10%' => { output: 1500.0, input: 300.0 }
            }
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_reports/vat")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              query: { period: period, year: year }
            )
            .to_return(status: 200, body: vat_response.to_json)
        end

        it 'returns VAT report for period' do
          result = TaxService.vat_report(period: period, year: year, token: token)
          
          expect(result[:period]).to eq(period)
          expect(result[:year]).to eq(year)
          expect(result[:vat_summary][:vat_payable]).to eq(8400.0)
          expect(result[:breakdown][:'21%'][:output]).to eq(8400.0)
        end
      end
    end
  end

  describe 'Spanish Tax Specifics' do
    describe '.irpf_rates' do
      context 'when successful' do
        let(:irpf_response) do
          {
            rates: [
              { type: 'professional', percentage: 15.0, description: 'Professional services' },
              { type: 'rental', percentage: 19.0, description: 'Property rental income' },
              { type: 'artistic', percentage: 7.0, description: 'Artistic and literary works' }
            ]
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_rates/irpf")
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(status: 200, body: irpf_response.to_json)
        end

        it 'returns IRPF tax rates' do
          result = TaxService.irpf_rates(token: token)
          
          expect(result[:rates].size).to eq(3)
          expect(result[:rates].first[:type]).to eq('professional')
          expect(result[:rates].first[:percentage]).to eq(15.0)
        end
      end
    end

    describe '.modelo_303' do
      let(:quarter) { 1 }
      let(:year) { 2024 }

      context 'when successful' do
        let(:modelo_303_response) do
          {
            quarter: quarter,
            year: year,
            data: {
              total_output_vat: 10500.0,
              total_input_vat: 2100.0,
              vat_to_pay: 8400.0,
              previous_payments: 0.0,
              amount_due: 8400.0
            },
            boxes: {
              '01' => 50000.0,  # Total operations subject to VAT
              '03' => 10500.0,  # Total output VAT
              '08' => 10000.0,  # Total input operations
              '09' => 2100.0    # Total input VAT
            }
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_reports/modelo_303")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              query: { quarter: quarter, year: year }
            )
            .to_return(status: 200, body: modelo_303_response.to_json)
        end

        it 'returns Modelo 303 data' do
          result = TaxService.modelo_303(quarter: quarter, year: year, token: token)
          
          expect(result[:quarter]).to eq(quarter)
          expect(result[:year]).to eq(year)
          expect(result[:data][:vat_to_pay]).to eq(8400.0)
          expect(result[:boxes][:'01']).to eq(50000.0)
        end
      end
    end

    describe '.modelo_347' do
      let(:year) { 2024 }

      context 'when successful' do
        let(:modelo_347_response) do
          {
            year: year,
            summary: {
              total_operations: 75000.0,
              total_companies: 15,
              threshold_exceeded: 8
            },
            companies: [
              { tax_id: 'B12345678', name: 'ACME Corp', total: 15000.0 },
              { tax_id: 'B87654321', name: 'Test Inc', total: 12000.0 }
            ]
          }
        end

        before do
          stub_request(:get, "#{base_url}/tax_reports/modelo_347")
            .with(
              headers: { 'Authorization' => "Bearer #{token}" },
              query: { year: year }
            )
            .to_return(status: 200, body: modelo_347_response.to_json)
        end

        it 'returns Modelo 347 data' do
          result = TaxService.modelo_347(year: year, token: token)
          
          expect(result[:year]).to eq(year)
          expect(result[:summary][:total_operations]).to eq(75000.0)
          expect(result[:companies].size).to eq(2)
          expect(result[:companies].first[:tax_id]).to eq('B12345678')
        end
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'when token is nil' do
      it 'raises ArgumentError for all methods' do
        expect { TaxService.rates(token: nil) }
          .to raise_error
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "#{base_url}/tax_rates")
          .to_raise(Net::ReadTimeout)
      end

      it 'raises NetworkError' do
        expect { TaxService.rates(token: token) }
          .to raise_error
      end
    end

    context 'when validation fails' do
      before do
        stub_request(:post, "#{base_url}/tax_rates")
          .to_return(
            status: 422,
            body: {
              error: 'Validation failed',
              errors: { percentage: ['must be between 0 and 100'] }
            }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { TaxService.create_rate({}, token: token) }
          .to raise_error(ApiService::ValidationError) do |error|
            expect(error.errors[:percentage]).to include('must be between 0 and 100')
          end
      end
    end

    context 'when unauthorized access' do
      before do
        stub_request(:get, "#{base_url}/tax_rates")
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises ApiError' do
        expect { TaxService.rates(token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end
end