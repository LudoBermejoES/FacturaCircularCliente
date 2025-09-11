require 'rails_helper'

RSpec.describe WorkflowService, type: :service do
  let(:token) { 'test_access_token' }
  let(:invoice_id) { 123 }
  let(:template_id) { 456 }
  let(:rule_id) { 789 }
  let(:base_url) { 'http://localhost:3001/api/v1' }

  describe '.history' do
    context 'when successful' do
      let(:history_response) do
        {
          history: [
            {
              id: 1,
              invoice_id: invoice_id,
              from_status: 'draft',
              to_status: 'pending',
              user_name: 'John Doe',
              comment: 'Ready for review',
              created_at: '2024-01-15T10:00:00Z'
            },
            {
              id: 2,
              invoice_id: invoice_id,
              from_status: 'pending',
              to_status: 'sent',
              user_name: 'Jane Smith',
              comment: 'Sent to customer',
              created_at: '2024-01-16T14:30:00Z'
            }
          ],
          meta: { total: 2 }
        }
      end

      before do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}/workflow_history")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: history_response.to_json)
      end

      it 'returns workflow history' do
        result = WorkflowService.history(invoice_id, token: token)
        
        expect(result[:history].size).to eq(2)
        expect(result[:history].first[:from_status]).to eq('draft')
        expect(result[:history].first[:to_status]).to eq('pending')
        expect(result[:history].last[:from_status]).to eq('pending')
        expect(result[:history].last[:to_status]).to eq('sent')
      end
    end

    context 'when invoice not found' do
      before do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}/workflow_history")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Invoice not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { WorkflowService.history(invoice_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.available_transitions' do
    context 'when successful' do
      let(:transitions_response) do
        {
          transitions: [
            {
              to_status: 'sent',
              label: 'Send to Customer',
              requires_comment: false,
              conditions: ['has_customer_email']
            },
            {
              to_status: 'cancelled',
              label: 'Cancel Invoice',
              requires_comment: true,
              conditions: []
            }
          ],
          current_status: 'pending'
        }
      end

      before do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}/available_transitions")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: transitions_response.to_json)
      end

      it 'returns available transitions' do
        result = WorkflowService.available_transitions(invoice_id, token: token)
        
        expect(result[:transitions].size).to eq(2)
        expect(result[:current_status]).to eq('pending')
        expect(result[:transitions].first[:to_status]).to eq('sent')
        expect(result[:transitions].last[:requires_comment]).to be true
      end
    end

    context 'when no transitions available' do
      before do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}/available_transitions")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 200,
            body: { transitions: [], current_status: 'paid' }.to_json
          )
      end

      it 'returns empty transitions' do
        result = WorkflowService.available_transitions(invoice_id, token: token)
        
        expect(result[:transitions]).to be_empty
        expect(result[:current_status]).to eq('paid')
      end
    end
  end

  describe '.transition' do
    let(:status) { 'sent' }
    let(:comment) { 'Invoice sent to customer via email' }

    context 'when successful transition' do
      let(:transition_response) do
        {
          invoice: {
            id: invoice_id,
            status: status,
            updated_at: '2024-01-16T15:00:00Z'
          },
          workflow_entry: {
            id: 3,
            from_status: 'pending',
            to_status: status,
            comment: comment,
            user_name: 'Current User'
          }
        }
      end

      before do
        stub_request(:patch, "#{base_url}/invoices/#{invoice_id}/status")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { status: status, comment: comment }.to_json
          )
          .to_return(status: 200, body: transition_response.to_json)
      end

      it 'transitions status and returns result' do
        result = WorkflowService.transition(invoice_id, status: status, comment: comment, token: token)
        
        expect(result[:invoice][:status]).to eq(status)
        expect(result[:workflow_entry][:to_status]).to eq(status)
        expect(result[:workflow_entry][:comment]).to eq(comment)
      end
    end

    context 'when transition without comment' do
      before do
        stub_request(:patch, "#{base_url}/invoices/#{invoice_id}/status")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { status: status }.to_json
          )
          .to_return(status: 200, body: { invoice: { status: status } }.to_json)
      end

      it 'transitions without comment' do
        WorkflowService.transition(invoice_id, status: status, token: token)
        
        expect(WebMock).to have_requested(:patch, "#{base_url}/invoices/#{invoice_id}/status")
          .with(body: { status: status }.to_json)
      end
    end

    context 'when invalid transition' do
      before do
        stub_request(:patch, "#{base_url}/invoices/#{invoice_id}/status")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: {
              error: 'Invalid transition',
              errors: { status: ['cannot transition from paid to draft'] }
            }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { WorkflowService.transition(invoice_id, status: 'draft', token: token) }
          .to raise_error(ApiService::ValidationError) do |error|
            expect(error.errors[:status]).to include('cannot transition from paid to draft')
          end
      end
    end
  end

  describe '.bulk_transition' do
    let(:invoice_ids) { [123, 456, 789] }
    let(:status) { 'sent' }
    let(:comment) { 'Bulk sending invoices' }

    context 'when successful bulk transition' do
      let(:bulk_response) do
        {
          results: [
            { invoice_id: 123, status: status, success: true },
            { invoice_id: 456, status: status, success: true },
            { invoice_id: 789, status: status, success: true }
          ],
          summary: { total: 3, successful: 3, failed: 0 }
        }
      end

      before do
        stub_request(:post, "#{base_url}/invoices/bulk_status")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { invoice_ids: invoice_ids, status: status, comment: comment }.to_json
          )
          .to_return(status: 200, body: bulk_response.to_json)
      end

      it 'bulk transitions invoices and returns results' do
        result = WorkflowService.bulk_transition(
          invoice_ids: invoice_ids,
          status: status,
          comment: comment,
          token: token
        )
        
        expect(result[:results].size).to eq(3)
        expect(result[:summary][:successful]).to eq(3)
        expect(result[:summary][:failed]).to eq(0)
        expect(result[:results].all? { |r| r[:success] }).to be true
      end
    end

    context 'when partial failures' do
      let(:partial_response) do
        {
          results: [
            { invoice_id: 123, status: status, success: true },
            { invoice_id: 456, error: 'Invalid transition', success: false },
            { invoice_id: 789, status: status, success: true }
          ],
          summary: { total: 3, successful: 2, failed: 1 }
        }
      end

      before do
        stub_request(:post, "#{base_url}/invoices/bulk_status")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: partial_response.to_json)
      end

      it 'returns results with failures' do
        result = WorkflowService.bulk_transition(
          invoice_ids: invoice_ids,
          status: status,
          token: token
        )
        
        expect(result[:summary][:successful]).to eq(2)
        expect(result[:summary][:failed]).to eq(1)
        failed_result = result[:results].find { |r| !r[:success] }
        expect(failed_result[:error]).to eq('Invalid transition')
      end
    end
  end

  describe '.rules' do
    context 'when successful' do
      let(:rules_response) do
        {
          rules: [
            {
              id: 1,
              name: 'Auto-send on approval',
              from_status: 'pending',
              to_status: 'sent',
              conditions: ['amount < 1000'],
              enabled: true
            },
            {
              id: 2,
              name: 'Require approval for large amounts',
              from_status: 'draft',
              to_status: 'pending',
              conditions: ['amount >= 5000'],
              enabled: true
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/workflow_rules")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: rules_response.to_json)
      end

      it 'returns workflow rules' do
        result = WorkflowService.rules(token: token)
        
        expect(result[:rules].size).to eq(2)
        expect(result[:rules].first[:name]).to eq('Auto-send on approval')
        expect(result[:rules].first[:enabled]).to be true
      end
    end
  end

  describe '.create_rule' do
    let(:rule_params) do
      {
        name: 'New workflow rule',
        from_status: 'draft',
        to_status: 'pending',
        conditions: ['has_line_items'],
        enabled: true
      }
    end

    context 'when successful' do
      let(:created_rule) do
        rule_params.merge(id: rule_id, created_at: '2024-01-16T10:00:00Z')
      end

      before do
        stub_request(:post, "#{base_url}/workflow_rules")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: rule_params.to_json
          )
          .to_return(status: 201, body: created_rule.to_json)
      end

      it 'creates workflow rule and returns data' do
        result = WorkflowService.create_rule(rule_params, token: token)
        
        expect(result[:id]).to eq(rule_id)
        expect(result[:name]).to eq('New workflow rule')
        expect(result[:enabled]).to be true
      end
    end
  end

  describe '.update_rule' do
    let(:update_params) { { name: 'Updated rule name', enabled: false } }

    context 'when successful' do
      let(:updated_rule) do
        {
          id: rule_id,
          name: 'Updated rule name',
          from_status: 'draft',
          to_status: 'pending',
          enabled: false
        }
      end

      before do
        stub_request(:put, "#{base_url}/workflow_rules/#{rule_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: update_params.to_json
          )
          .to_return(status: 200, body: updated_rule.to_json)
      end

      it 'updates workflow rule and returns data' do
        result = WorkflowService.update_rule(rule_id, update_params, token: token)
        
        expect(result[:id]).to eq(rule_id)
        expect(result[:name]).to eq('Updated rule name')
        expect(result[:enabled]).to be false
      end
    end
  end

  describe '.delete_rule' do
    context 'when successful' do
      before do
        stub_request(:delete, "#{base_url}/workflow_rules/#{rule_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'deletes workflow rule successfully' do
        result = WorkflowService.delete_rule(rule_id, token: token)
        
        expect(result).to be_nil
        expect(WebMock).to have_requested(:delete, "#{base_url}/workflow_rules/#{rule_id}")
      end
    end
  end

  describe '.templates' do
    context 'when successful' do
      let(:templates_response) do
        {
          templates: [
            {
              id: 1,
              name: 'Standard Invoice Flow',
              steps: [
                { from: 'draft', to: 'pending' },
                { from: 'pending', to: 'sent' },
                { from: 'sent', to: 'paid' }
              ]
            },
            {
              id: 2,
              name: 'Quick Send Flow',
              steps: [
                { from: 'draft', to: 'sent' }
              ]
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{base_url}/workflow_templates")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: templates_response.to_json)
      end

      it 'returns workflow templates' do
        result = WorkflowService.templates(token: token)
        
        expect(result[:templates].size).to eq(2)
        expect(result[:templates].first[:name]).to eq('Standard Invoice Flow')
        expect(result[:templates].first[:steps].size).to eq(3)
      end
    end
  end

  describe '.create_template' do
    let(:template_params) do
      {
        name: 'Custom Flow',
        steps: [
          { from: 'draft', to: 'review' },
          { from: 'review', to: 'sent' }
        ]
      }
    end

    context 'when successful' do
      let(:created_template) do
        template_params.merge(id: template_id, created_at: '2024-01-16T10:00:00Z')
      end

      before do
        stub_request(:post, "#{base_url}/workflow_templates")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: template_params.to_json
          )
          .to_return(status: 201, body: created_template.to_json)
      end

      it 'creates workflow template and returns data' do
        result = WorkflowService.create_template(template_params, token: token)
        
        expect(result[:id]).to eq(template_id)
        expect(result[:name]).to eq('Custom Flow')
        expect(result[:steps].size).to eq(2)
      end
    end
  end

  describe '.apply_template' do
    context 'when successful' do
      let(:apply_response) do
        {
          invoice: {
            id: invoice_id,
            workflow_template_id: template_id,
            workflow_template_name: 'Standard Invoice Flow'
          },
          message: 'Template applied successfully'
        }
      end

      before do
        stub_request(:post, "#{base_url}/invoices/#{invoice_id}/apply_workflow_template")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { template_id: template_id }.to_json
          )
          .to_return(status: 200, body: apply_response.to_json)
      end

      it 'applies workflow template to invoice' do
        result = WorkflowService.apply_template(invoice_id, template_id, token: token)
        
        expect(result[:invoice][:workflow_template_id]).to eq(template_id)
        expect(result[:message]).to eq('Template applied successfully')
      end
    end

    context 'when template not compatible' do
      before do
        stub_request(:post, "#{base_url}/invoices/#{invoice_id}/apply_workflow_template")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: {
              error: 'Template not compatible',
              errors: { template: ['cannot apply to current invoice status'] }
            }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { WorkflowService.apply_template(invoice_id, template_id, token: token) }
          .to raise_error(ApiService::ValidationError) do |error|
            expect(error.errors[:template]).to include('cannot apply to current invoice status')
          end
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'when token is nil' do
      it 'raises ArgumentError for all methods' do
        expect { WorkflowService.history(invoice_id, token: nil) }
          .to raise_error
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "#{base_url}/invoices/#{invoice_id}/workflow_history")
          .to_raise(Net::ReadTimeout)
      end

      it 'raises NetworkError' do
        expect { WorkflowService.history(invoice_id, token: token) }
          .to raise_error
      end
    end

    context 'when unauthorized' do
      before do
        stub_request(:patch, "#{base_url}/invoices/#{invoice_id}/status")
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises ApiError' do
        expect { WorkflowService.transition(invoice_id, status: 'sent', token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end
end