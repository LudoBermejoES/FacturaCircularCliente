require 'rails_helper'

RSpec.describe 'Workflows', type: :request do
  let(:invoice_id) { 'invoice-123' }
  let(:invoice) { build(:invoice_response, id: invoice_id) }
  let(:history) { build(:workflow_history_response) }
  let(:available_transitions) { build(:workflow_transitions_response) }
  let(:token) { 'mock-token' }
  
  before do
    # Mock WorkflowService and InvoiceService calls
    allow(InvoiceService).to receive(:find).and_return(invoice)
    allow(WorkflowService).to receive(:history).and_return(history)
    allow(WorkflowService).to receive(:available_transitions).and_return(available_transitions)
    allow(WorkflowService).to receive(:transition).and_return({ success: true })
    allow(WorkflowService).to receive(:bulk_transition).and_return({ updated_count: 2 })
    
    # Mock current_user_token method (alias to current_token)
    allow_any_instance_of(ApplicationController).to receive(:current_user_token).and_return(token)
  end

  describe 'GET /invoices/:invoice_id/workflow' do
    it 'shows workflow history and available transitions' do
      get invoice_workflow_path(invoice_id)
      
      expect(response).to have_http_status(:ok)
      expect(assigns(:invoice)).to eq(invoice)
      expect(assigns(:history)).to eq(history)
      expect(assigns(:available_transitions)).to eq(available_transitions)
      
      # Verify service calls
      expect(InvoiceService).to have_received(:find).with(invoice_id, token: token)
      expect(WorkflowService).to have_received(:history).with(invoice_id, token: token)
      expect(WorkflowService).to have_received(:available_transitions).with(invoice_id, token: token)
    end

    it 'renders workflow page content' do
      get invoice_workflow_path(invoice_id)
      
      expect(response.body).to include('Workflow History')
      expect(response.body).to include('Available Transitions')
    end

    it 'supports turbo stream format' do
      get invoice_workflow_path(invoice_id), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
    end

    context 'when invoice not found' do
      before do
        allow(InvoiceService).to receive(:find).and_raise(ApiService::ApiError.new('Invoice not found'))
      end

      it 'handles API error gracefully' do
        get invoice_workflow_path(invoice_id)
        
        expect(response).to have_http_status(:found) # redirect due to error handling
      end
    end

    context 'when API error occurs' do
      before do
        allow(InvoiceService).to receive(:find).and_raise(ApiService::ApiError.new('API Error'))
      end

      it 'handles API error gracefully' do
        get invoice_workflow_path(invoice_id)
        
        expect(response).to have_http_status(:found) # redirect
      end
    end

    context 'when workflow history fails to load' do
      before do
        allow(WorkflowService).to receive(:history).and_raise(ApiService::ApiError.new('History error'))
      end

      it 'continues with empty history and logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to load workflow history/)
        
        get invoice_workflow_path(invoice_id)
        
        expect(response).to have_http_status(:ok)
        expect(assigns(:history)).to eq([])
      end
    end

  end

  describe 'POST /invoices/:invoice_id/workflow/transition' do
    let(:status) { 'approved' }
    let(:comment) { 'Looks good to proceed' }

    it 'executes status transition successfully' do
      post transition_invoice_workflow_path(invoice_id), params: {
        status: status,
        comment: comment
      }
      
      expect(response).to redirect_to(invoice_path(invoice_id))
      expect(flash[:notice]).to eq("Invoice status updated to #{status}")
      
      expect(WorkflowService).to have_received(:transition).with(
        invoice_id,
        status: status,
        comment: comment,
        token: 'mock-token'
      )
    end

    it 'supports turbo stream format' do
      post transition_invoice_workflow_path(invoice_id), 
           params: { status: status, comment: comment },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
      
      # Should refresh data for turbo stream response
      expect(InvoiceService).to have_received(:find).with(invoice_id, token: 'mock-token')
      expect(WorkflowService).to have_received(:history).with(invoice_id, token: 'mock-token')
      expect(WorkflowService).to have_received(:available_transitions).with(invoice_id, token: 'mock-token')
    end

    context 'with validation errors' do
      before do
        allow(WorkflowService).to receive(:transition).and_raise(
          ApiService::ValidationError.new(['Invalid status transition', 'Comment required'])
        )
      end

      it 'redirects with error messages for HTML format' do
        post transition_invoice_workflow_path(invoice_id), params: {
          status: status,
          comment: comment
        }
        
        expect(response).to redirect_to(invoice_path(invoice_id))
        expect(flash[:alert]).to eq('Invalid status transition, Comment required')
      end

      it 'renders error partial for turbo stream format' do
        post transition_invoice_workflow_path(invoice_id), 
             params: { status: status, comment: comment },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('workflow_errors')
      end
    end

    context 'with API error' do
      before do
        allow(WorkflowService).to receive(:transition).and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'handles API error gracefully' do
        post transition_invoice_workflow_path(invoice_id), params: {
          status: status,
          comment: comment
        }
        
        expect(response).to have_http_status(:found) # redirect due to error handling
      end
    end

  end

  describe 'POST /invoices/bulk_transition' do
    let(:invoice_ids) { ['invoice-1', 'invoice-2'] }
    let(:status) { 'approved' }
    let(:comment) { 'Bulk approval' }

    it 'executes bulk status transition successfully' do
      post bulk_invoice_transition_path, params: {
        invoice_ids: invoice_ids,
        status: status,
        comment: comment
      }
      
      expect(response).to redirect_to(invoices_path)
      expect(flash[:notice]).to eq("2 invoices updated to #{status}")
      
      expect(WorkflowService).to have_received(:bulk_transition).with(
        invoice_ids: invoice_ids,
        status: status,
        comment: comment,
        token: 'mock-token'
      )
    end

    it 'handles empty invoice selection' do
      post bulk_invoice_transition_path, params: {
        invoice_ids: [],
        status: status,
        comment: comment
      }
      
      expect(response).to redirect_to(invoices_path)
      expect(flash[:alert]).to eq('No invoices selected')
      expect(WorkflowService).not_to have_received(:bulk_transition)
    end

    it 'handles missing invoice_ids parameter' do
      post bulk_invoice_transition_path, params: {
        status: status,
        comment: comment
      }
      
      expect(response).to redirect_to(invoices_path)
      expect(flash[:alert]).to eq('No invoices selected')
      expect(WorkflowService).not_to have_received(:bulk_transition)
    end

    context 'with validation errors' do
      before do
        allow(WorkflowService).to receive(:bulk_transition).and_raise(
          ApiService::ValidationError.new(['Some invoices already have this status'])
        )
      end

      it 'redirects with error messages' do
        post bulk_invoice_transition_path, params: {
          invoice_ids: invoice_ids,
          status: status,
          comment: comment
        }
        
        expect(response).to redirect_to(invoices_path)
        expect(flash[:alert]).to eq('Some invoices already have this status')
      end
    end

    context 'with API error' do
      before do
        allow(WorkflowService).to receive(:bulk_transition).and_raise(ApiService::ApiError.new('Server error'))
      end

      it 'handles API error gracefully' do
        post bulk_invoice_transition_path, params: {
          invoice_ids: invoice_ids,
          status: status,
          comment: comment
        }
        
        expect(response).to have_http_status(:found) # redirect due to error handling
      end
    end

  end
end