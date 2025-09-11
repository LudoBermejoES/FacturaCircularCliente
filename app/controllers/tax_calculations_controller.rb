class TaxCalculationsController < ApplicationController
  before_action :authenticate_user!
  
  def new
    @calculation = {
      base_amount: 0,
      tax_rate: 21,
      discount_percentage: 0,
      retention_percentage: 0
    }
  end
  
  def create
    @result = TaxService.calculate(calculation_params, token: current_user_token)
    
    respond_to do |format|
      format.html { render :show }
      format.json { render json: @result }
      format.turbo_stream
    end
  rescue ApiService::ValidationError => e
    @calculation = calculation_params
    respond_to do |format|
      format.html do
        flash.now[:alert] = e.errors.join(', ')
        render :new
      end
      format.json { render json: { errors: e.errors }, status: :unprocessable_entity }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "calculation_errors",
          partial: "shared/errors",
          locals: { errors: e.errors }
        )
      end
    end
  rescue ApiService::ApiError => e
    handle_api_error(e)
  end
  
  def invoice
    invoice_id = params[:invoice_id]
    
    @result = TaxService.calculate_invoice(invoice_id, token: current_user_token)
    @invoice = InvoiceService.find(invoice_id, token: current_user_token)
    
    respond_to do |format|
      format.html { render :invoice_calculation }
      format.json { render json: @result }
      format.turbo_stream
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: invoice_path(invoice_id))
  end
  
  def recalculate
    invoice_id = params[:invoice_id]
    
    @result = TaxService.recalculate_invoice(invoice_id, token: current_user_token)
    @invoice = InvoiceService.find(invoice_id, token: current_user_token)
    
    respond_to do |format|
      format.html { redirect_to invoice_path(invoice_id), notice: 'Tax recalculated successfully' }
      format.json { render json: @result }
      format.turbo_stream
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: invoice_path(invoice_id))
  end
  
  def validate
    if params[:tax_id].present?
      @validation = TaxService.validate_tax_id(
        params[:tax_id], 
        country: params[:country] || 'ES',
        token: current_user_token
      )
    elsif params[:invoice_id].present?
      @validation = TaxService.validate_invoice_tax(
        params[:invoice_id],
        token: current_user_token
      )
    else
      @validation = { valid: false, errors: ['No tax ID or invoice ID provided'] }
    end
    
    respond_to do |format|
      format.json { render json: @validation }
      format.turbo_stream
    end
  rescue ApiService::ApiError => e
    respond_to do |format|
      format.json { render json: { valid: false, errors: [e.message] }, status: :unprocessable_entity }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "validation_result",
          partial: "tax_calculations/validation_result",
          locals: { validation: { valid: false, errors: [e.message] } }
        )
      end
    end
  end
  
  private
  
  def calculation_params
    params.require(:calculation).permit(
      :base_amount,
      :tax_rate,
      :tax_type,
      :discount_percentage,
      :discount_amount,
      :retention_percentage,
      :retention_amount,
      :surcharge_percentage,
      :region,
      line_items: [
        :description,
        :quantity,
        :unit_price,
        :tax_rate,
        :discount_percentage
      ]
    )
  end
end