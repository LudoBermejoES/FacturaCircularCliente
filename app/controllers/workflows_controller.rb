class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_invoice
  before_action :load_history, only: [:show]
  
  def show
    @available_transitions = WorkflowService.available_transitions(
      @invoice[:id], 
      token: current_user_token
    )
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: invoice_path(@invoice[:id]))
  end
  
  def transition
    result = WorkflowService.transition(
      @invoice[:id],
      status: params[:status],
      comment: params[:comment],
      token: current_user_token
    )
    
    respond_to do |format|
      format.html do
        redirect_to invoice_path(@invoice[:id]), 
                    notice: "Invoice status updated to #{params[:status]}"
      end
      format.turbo_stream do
        @invoice = InvoiceService.find(@invoice[:id], token: current_user_token)
        @history = WorkflowService.history(token: current_user_token, params: { invoice_id: @invoice[:id] })
        @available_transitions = WorkflowService.available_transitions(
          @invoice[:id], 
          token: current_user_token
        )
      end
    end
  rescue ApiService::ValidationError => e
    respond_to do |format|
      format.html do
        redirect_to invoice_path(@invoice[:id]), 
                    alert: e.errors.join(', ')
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "workflow_errors",
          partial: "shared/errors",
          locals: { errors: e.errors }
        )
      end
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: invoice_path(@invoice[:id]))
  end
  
  def bulk_transition
    redirect_to invoices_path, alert: "Bulk operations are not supported by the API"
  end
  
  private
  
  def load_invoice
    @invoice = InvoiceService.find(params[:invoice_id], token: current_user_token)
  rescue ApiService::NotFoundError
    redirect_to invoices_path, alert: "Invoice not found"
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: invoices_path)
  end
  
  def load_history
    @history = WorkflowService.history(token: current_user_token, params: { invoice_id: @invoice[:id] })
  rescue ApiService::ApiError => e
    @history = []
    Rails.logger.error "Failed to load workflow history: #{e.message}"
  end
end