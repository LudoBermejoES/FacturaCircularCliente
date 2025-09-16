class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_invoice, except: [:bulk_transition]
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
    unless params[:invoice_ids].present? && params[:status].present?
      redirect_to invoices_path, alert: "Please select invoices and specify a status"
      return
    end

    invoice_ids = params[:invoice_ids].reject(&:blank?).map(&:to_i)

    if invoice_ids.empty?
      redirect_to invoices_path, alert: "Please select at least one invoice"
      return
    end

    begin
      result = WorkflowService.bulk_transition(
        invoice_ids,
        status: params[:status],
        comment: params[:comment],
        token: current_user_token
      )

      success_count = result['success_count'] || invoice_ids.size
      flash[:success] = "Successfully updated #{success_count} invoice(s) to #{params[:status]}"

      if result['errors'] && result['errors'].any?
        flash[:warning] = "Some invoices could not be updated: #{result['errors'].join(', ')}"
      end

    rescue ApiService::ValidationError => e
      error_message = case e.errors
                      when Array
                        e.errors.join(', ')
                      when Hash
                        e.errors.values.flatten.join(', ')
                      else
                        e.message
                      end
      flash[:error] = "Validation error: #{error_message}"
    rescue ApiService::ApiError => e
      flash[:error] = "Failed to update invoices: #{e.message}"
    end

    redirect_to invoices_path
  end
  
  private
  
  def load_invoice
    @invoice = InvoiceService.find(params[:invoice_id], token: current_user_token)
  rescue ApiService::ApiError => e
    if e.message.include?("not found") || e.message.include?("Not found")
      redirect_to invoices_path, alert: "Invoice not found"
    else
      handle_api_error(e, redirect_path: invoices_path)
    end
  end
  
  def load_history
    @history = WorkflowService.history(token: current_user_token, params: { invoice_id: @invoice[:id] })
  rescue ApiService::ApiError => e
    @history = []
    Rails.logger.error "Failed to load workflow history: #{e.message}"
  end
end