require 'rails_helper'

RSpec.describe WorkflowService do
  let(:token) { 'test_access_token' }
  
  describe '.history' do
    let(:history_response) do
      {
        history: [
          {
            id: 1,
            invoice_id: 1,
            from_status: 'draft',
            to_status: 'sent',
            user_id: 1,
            comment: 'Approved for sending',
            created_at: '2024-01-01T12:00:00Z'
          }
        ],
        meta: { total: 1, page: 1 }
      }
    end
    
    before do
      stub_request(:get, 'http://albaranes-api:3000/api/v1/workflow_history')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: history_response.to_json)
    end
    
    it 'returns workflow history' do
      result = described_class.history(token: token)
      expect(result).to eq(history_response.deep_symbolize_keys)
    end
    
    context 'with parameters' do
      let(:params) { { invoice_id: 1, limit: 10 } }
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/workflow_history')
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: params
          )
          .to_return(status: 200, body: history_response.to_json)
      end
      
      it 'passes parameters in query string' do
        described_class.history(token: token, params: params)
        expect(WebMock).to have_requested(:get, 'http://albaranes-api:3000/api/v1/workflow_history')
          .with(query: params)
      end
    end
  end
  
  describe '.available_transitions' do
    let(:invoice_id) { 1 }
    let(:transitions_response) do
      {
        available_transitions: [
          { from: 'draft', to: 'sent', label: 'Send to Client' },
          { from: 'draft', to: 'cancelled', label: 'Cancel Invoice' }
        ]
      }
    end
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/workflow/available_transitions")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: transitions_response.to_json)
    end
    
    it 'returns available transitions for invoice' do
      result = described_class.available_transitions(invoice_id, token: token)
      expect(result).to eq(transitions_response.deep_symbolize_keys)
    end
  end
  
  describe '.transition' do
    let(:invoice_id) { 1 }
    let(:status) { 'sent' }
    let(:comment) { 'Ready for client review' }
    let(:transition_response) do
      {
        id: invoice_id,
        status: status,
        updated_at: '2024-01-01T12:00:00Z'
      }
    end
    
    before do
      stub_request(:patch, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/status")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: { status: status, comment: comment }.to_json
        )
        .to_return(status: 200, body: transition_response.to_json)
    end
    
    it 'transitions invoice status with comment' do
      result = described_class.transition(invoice_id, status: status, comment: comment, token: token)
      expect(result).to eq(transition_response.deep_symbolize_keys)
    end
    
    context 'without comment' do
      before do
        stub_request(:patch, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/status")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { status: status }.to_json
          )
          .to_return(status: 200, body: transition_response.to_json)
      end
      
      it 'transitions invoice status without comment' do
        result = described_class.transition(invoice_id, status: status, token: token)
        expect(result).to eq(transition_response.deep_symbolize_keys)
      end
    end
  end
  
  describe '.definitions' do
    let(:definitions_response) do
      {
        definitions: [
          {
            id: 1,
            name: 'Standard Invoice Workflow',
            description: 'Standard workflow for invoice processing'
          }
        ]
      }
    end
    
    before do
      stub_request(:get, 'http://albaranes-api:3000/api/v1/workflow_definitions')
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: definitions_response.to_json)
    end
    
    it 'returns workflow definitions' do
      result = described_class.definitions(token: token)
      expect(result).to eq(definitions_response.deep_symbolize_keys)
    end
  end
  
  describe '.definition_states' do
    let(:definition_id) { 1 }
    let(:states_response) do
      {
        states: [
          { id: 1, name: 'draft', label: 'Draft' },
          { id: 2, name: 'sent', label: 'Sent' },
          { id: 3, name: 'paid', label: 'Paid' }
        ]
      }
    end
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}/states")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: states_response.to_json)
    end
    
    it 'returns states for workflow definition' do
      result = described_class.definition_states(definition_id, token: token)
      expect(result).to eq(states_response.deep_symbolize_keys)
    end
  end
  
  describe '.definition_transitions' do
    let(:definition_id) { 1 }
    let(:transitions_response) do
      {
        transitions: [
          { from: 'draft', to: 'sent', label: 'Send Invoice' },
          { from: 'sent', to: 'paid', label: 'Mark as Paid' }
        ]
      }
    end
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}/transitions")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: transitions_response.to_json)
    end
    
    it 'returns transitions for workflow definition' do
      result = described_class.definition_transitions(definition_id, token: token)
      expect(result).to eq(transitions_response.deep_symbolize_keys)
    end
  end
end