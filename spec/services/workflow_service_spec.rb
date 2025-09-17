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
      stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}/workflow_states")
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
      stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}/workflow_transitions")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: transitions_response.to_json)
    end

    it 'returns transitions for workflow definition' do
      result = described_class.definition_transitions(definition_id, token: token)
      expect(result).to eq(transitions_response.deep_symbolize_keys)
    end
  end

  describe '.create_definition' do
    let(:params) do
      {
        name: 'New Workflow',
        code: 'NEW_WF',
        description: 'Test workflow',
        company_id: 1,
        is_active: true,
        is_default: false
      }
    end

    let(:expected_body) do
      {
        data: {
          attributes: params
        }
      }
    end

    let(:create_response) do
      {
        id: 1,
        name: params[:name],
        code: params[:code],
        description: params[:description],
        company_id: params[:company_id],
        is_active: params[:is_active],
        is_default: params[:is_default],
        created_at: '2024-01-01T12:00:00Z',
        updated_at: '2024-01-01T12:00:00Z'
      }
    end

    before do
      stub_request(:post, 'http://albaranes-api:3000/api/v1/workflow_definitions')
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: expected_body.to_json
        )
        .to_return(status: 201, body: create_response.to_json)
    end

    it 'creates workflow definition with JSON API format' do
      result = described_class.create_definition(params, token: token)
      expect(result).to eq(create_response.deep_symbolize_keys)
    end

    it 'sends data wrapped in JSON API structure' do
      described_class.create_definition(params, token: token)
      expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/workflow_definitions')
        .with(body: expected_body.to_json)
    end

    it 'includes all parameters in attributes' do
      described_class.create_definition(params, token: token)
      expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/workflow_definitions')
        .with { |req|
          body = JSON.parse(req.body)
          body['data']['attributes']['name'] == 'New Workflow' &&
          body['data']['attributes']['code'] == 'NEW_WF' &&
          body['data']['attributes']['description'] == 'Test workflow' &&
          body['data']['attributes']['company_id'] == 1 &&
          body['data']['attributes']['is_active'] == true &&
          body['data']['attributes']['is_default'] == false
        }
    end
  end

  describe '.update_definition' do
    let(:definition_id) { 1 }
    let(:params) do
      {
        name: 'Updated Workflow',
        description: 'Updated description',
        is_active: false
      }
    end

    let(:expected_body) do
      {
        data: {
          attributes: params
        }
      }
    end

    let(:update_response) do
      {
        id: definition_id,
        name: params[:name],
        code: 'EXISTING_CODE',
        description: params[:description],
        company_id: 1,
        is_active: params[:is_active],
        is_default: false,
        updated_at: '2024-01-02T12:00:00Z'
      }
    end

    before do
      stub_request(:put, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: expected_body.to_json
        )
        .to_return(status: 200, body: update_response.to_json)
    end

    it 'updates workflow definition with JSON API format' do
      result = described_class.update_definition(definition_id, params, token: token)
      expect(result).to eq(update_response.deep_symbolize_keys)
    end

    it 'sends data wrapped in JSON API structure' do
      described_class.update_definition(definition_id, params, token: token)
      expect(WebMock).to have_requested(:put, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}")
        .with(body: expected_body.to_json)
    end

    it 'includes only provided parameters in attributes' do
      described_class.update_definition(definition_id, params, token: token)
      expect(WebMock).to have_requested(:put, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}")
        .with { |req|
          body = JSON.parse(req.body)
          body['data']['attributes']['name'] == 'Updated Workflow' &&
          body['data']['attributes']['description'] == 'Updated description' &&
          body['data']['attributes']['is_active'] == false &&
          !body['data']['attributes'].key?('code')
        }
    end
  end

  describe '.delete_definition' do
    let(:definition_id) { 1 }

    before do
      stub_request(:delete, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '')
    end

    it 'deletes workflow definition' do
      result = described_class.delete_definition(definition_id, token: token)
      expect(result).to be_nil
    end
  end

  describe '.definition' do
    let(:definition_id) { 1 }
    let(:definition_response) do
      {
        id: definition_id,
        name: 'Standard Workflow',
        code: 'STANDARD_WF',
        description: 'Standard workflow for invoices',
        company_id: 1,
        is_active: true,
        is_default: false
      }
    end

    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/workflow_definitions/#{definition_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: definition_response.to_json)
    end

    it 'returns workflow definition details' do
      result = described_class.definition(definition_id, token: token)
      expect(result).to eq(definition_response.deep_symbolize_keys)
    end

    it 'returns symbolized keys that work with frontend views' do
      result = described_class.definition(definition_id, token: token)

      # Test that both symbol and string key access patterns work
      expect(result[:id]).to eq(definition_id)
      expect(result[:name]).to eq('Standard Workflow')
      expect(result[:is_active]).to eq(true)

      # Test the specific patterns used in views
      expect(result[:id] || result['id']).to eq(definition_id)
      expect(result[:name] || result['name']).to eq('Standard Workflow')
    end
  end
end