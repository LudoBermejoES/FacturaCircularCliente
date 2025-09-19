class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_invoice, except: [:bulk_transition]
  before_action :load_history, only: [:show]
  
  def show
    begin
      response = WorkflowService.available_transitions(
        @invoice[:id],
        token: current_user_token
      )

      # Transform the API response into the format expected by the view
      if response && response[:available_transitions]
        @available_transitions = response[:available_transitions].map do |transition_data|
          {
            to_status: transition_data.dig(:to_state, :code) || transition_data.dig('to_state', 'code'),
            to_status_name: transition_data.dig(:to_state, :name) || transition_data.dig('to_state', 'name'),
            description: transition_data.dig(:transition, :description) || transition_data.dig('transition', 'description'),
            requires_comment: transition_data.dig(:transition, :requires_comment) || transition_data.dig('transition', 'requires_comment') || false
          }
        end
      elsif response.is_a?(Array)
        @available_transitions = response
      else
        @available_transitions = []
      end
    rescue ApiService::ApiError => e
      @available_transitions = []
      flash[:alert] = "Failed to load workflow transitions: #{e.message}"
      redirect_to invoice_path(@invoice[:id]) and return
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
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

        # Ensure current workflow state is included in @invoice data
        if @invoice[:has_workflow] && !@invoice[:current_state]
          # If the API didn't return current workflow state, we need to get it
          # For now, we'll use a fallback approach by checking available transitions
          current_response = WorkflowService.available_transitions(@invoice[:id], token: current_user_token)
          if current_response && current_response[:current_state]
            @invoice[:current_state] = current_response[:current_state][:code]
            @invoice[:current_state_name] = current_response[:current_state][:name]
          end
        end

        # Get available transitions and transform them
        response = WorkflowService.available_transitions(
          @invoice[:id],
          token: current_user_token
        )

        # Transform the API response into the format expected by the view
        if response && response[:available_transitions]
          @available_transitions = response[:available_transitions].map do |transition_data|
            {
              to_status: transition_data.dig(:to_state, :code) || transition_data.dig('to_state', 'code'),
              to_status_name: transition_data.dig(:to_state, :name) || transition_data.dig('to_state', 'name'),
              description: transition_data.dig(:transition, :description) || transition_data.dig('transition', 'description'),
              requires_comment: transition_data.dig(:transition, :requires_comment) || transition_data.dig('transition', 'requires_comment') || false
            }
          end
        elsif response.is_a?(Array)
          @available_transitions = response
        else
          @available_transitions = []
        end
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
    respond_to do |format|
      format.html do
        redirect_to invoice_path(@invoice[:id]), alert: "Failed to update invoice status: #{e.message}"
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "workflow_errors",
          partial: "shared/errors",
          locals: { errors: [e.message] }
        )
      end
    end
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
      redirect_to invoices_path, alert: "Failed to load invoice: #{e.message}"
    end
  end
  
  def load_history
    response = WorkflowService.history(token: current_user_token, params: { invoice_id: @invoice[:id] })

    # Handle different response formats
    if response.is_a?(Array)
      @history = response
    elsif response && response[:data]
      @history = response[:data]
    elsif response && response[:history]
      @history = response[:history]
    else
      @history = []
    end
  rescue ApiService::ApiError => e
    @history = []
    Rails.logger.error "Failed to load workflow history: #{e.message}"
  end
end