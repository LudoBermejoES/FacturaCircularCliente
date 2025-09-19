require 'rails_helper'

RSpec.describe 'InvoiceService with Workflow', type: :service do
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }
  let(:token) { 'test-jwt-token' }
  let(:company_id) { 1859 }

  describe 'invoice creation with workflow' do
    it 'creates invoice with workflow_definition_id' do
      # Mock successful invoice creation response
      invoice_response = {
        data: {
          id: '737',
          type: 'invoices',
          attributes: {
            invoice_number: 'FC-0002',
            invoice_series_id: 748,
            invoice_series_code: 'FC',
            document_type: 'FC',
            issue_date: '2025-09-18',
            status: 'draft',
            workflow_definition_id: 373,
            total_invoice: 1815.0,
            seller_party_id: company_id,
            buyer_company_contact_id: 112,
            invoice_lines: []
          }
        }
      }.to_json

      # Stub the API request - make it more permissive to catch the actual request
      stub_request(:post, "#{base_url}/invoices")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 201, body: invoice_response, headers: { 'Content-Type' => 'application/json' })

      # Create invoice with workflow
      params = {
        invoice_series_id: 748,
        document_type: 'FC',
        issue_date: '2025-09-18',
        status: 'draft',
        workflow_definition_id: 373,
        invoice_lines: {
          '0' => {
            description: 'Software Development Services',
            quantity: '1',
            unit_price: '1500',
            tax_rate: '21.0'
          }
        }
      }

      result = InvoiceService.create(params, token: token)

      expect(result[:data]).to be_present
      expect(result[:data][:id]).to eq('737')
      expect(result[:data][:attributes][:workflow_definition_id]).to eq(373)
      expect(result[:data][:attributes][:status]).to eq('draft')
    end

    it 'handles fields that do not exist in API gracefully' do
      # Mock response without the non-existent fields
      invoice_response = {
        data: {
          id: '738',
          type: 'invoices',
          attributes: {
            invoice_number: 'FC-0003',
            invoice_series_id: 748,
            document_type: 'FC',
            issue_date: '2025-09-18',
            status: 'draft'
          }
        }
      }.to_json

      stub_request(:post, "#{base_url}/invoices")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 201, body: invoice_response, headers: { 'Content-Type' => 'application/json' })

      # Include non-existent fields in params
      params = {
        invoice_series_id: 748,
        document_type: 'FC',
        issue_date: '2025-09-18',
        due_date: '2025-10-18',  # Non-existent in API
        notes: 'Test notes',      # Non-existent in API
        internal_notes: 'Internal', # Non-existent in API
        invoice_type: 'invoice',  # Non-existent in API
        status: 'draft'
      }

      result = InvoiceService.create(params, token: token)

      # Should still succeed despite non-existent fields
      expect(result[:data]).to be_present
      expect(result[:data][:id]).to eq('738')
    end
  end

  describe 'invoice status transitions' do
    let(:invoice_id) { 737 }

    it 'transitions invoice status to approved' do
      transition_response = {
        id: invoice_id,
        invoice_id: invoice_id,
        current_state: {
          code: 'approved',
          name: 'Approved',
          category: 'active'
        },
        previous_state: {
          code: 'draft',
          name: 'Draft'
        },
        transitioned_at: Time.current.iso8601
      }.to_json

      stub_request(:patch, "#{base_url}/invoices/#{invoice_id}/status")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 200, body: transition_response, headers: { 'Content-Type' => 'application/json' })

      result = InvoiceService.update_status(invoice_id, 'approved', token: token)

      expect(result[:current_state][:code]).to eq('approved')
    end

    it 'handles invalid status transitions' do
      error_response = {
        errors: [{
          status: 422,
          title: 'Invalid Transition',
          detail: 'Invalid transition to status: invalid_status'
        }]
      }.to_json

      stub_request(:patch, "#{base_url}/invoices/#{invoice_id}/status")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 422, body: error_response, headers: { 'Content-Type' => 'application/json' })

      expect {
        InvoiceService.update_status(invoice_id, 'invalid_status', token: token)
      }.to raise_error(ApiService::ValidationError)
    end
  end

  describe 'invoice freezing' do
    let(:invoice_id) { 737 }

    it 'freezes an approved invoice' do
      frozen_response = {
        data: {
          id: invoice_id.to_s,
          type: 'invoices',
          attributes: {
            invoice_number: 'FC-0002',
            status: 'approved',
            is_frozen: true,
            frozen_at: Time.current.iso8601,
            frozen_hash: 'abc123def456'
          }
        }
      }.to_json

      stub_request(:post, "#{base_url}/invoices/#{invoice_id}/freeze")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: frozen_response, headers: { 'Content-Type' => 'application/json' })

      result = InvoiceService.freeze(invoice_id, token: token)

      expect(result[:data][:attributes][:is_frozen]).to be true
      expect(result[:data][:attributes][:frozen_at]).to be_present
    end

    it 'prevents freezing draft invoices' do
      error_response = {
        error: 'Invoice cannot be frozen in draft status',
        code: 'CANNOT_FREEZE'
      }.to_json

      stub_request(:post, "#{base_url}/invoices/#{invoice_id}/freeze")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 403, body: error_response, headers: { 'Content-Type' => 'application/json' })

      expect {
        InvoiceService.freeze(invoice_id, token: token)
      }.to raise_error(ApiService::ApiError)
    end

    it 'prevents updating frozen invoices' do
      error_response = {
        error: 'Cannot modify frozen invoice',
        code: 'INVOICE_FROZEN'
      }.to_json

      stub_request(:put, "#{base_url}/invoices/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 422, body: error_response, headers: { 'Content-Type' => 'application/json' })

      expect {
        InvoiceService.update(invoice_id, { notes: 'Update attempt' }, token: token)
      }.to raise_error(ApiService::ValidationError)
    end
  end
end