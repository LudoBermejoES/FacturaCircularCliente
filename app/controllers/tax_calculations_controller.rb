class TaxCalculationsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Tax Calculator interface for manual calculations
    @jurisdictions = []
    @establishments = []

    begin
      # Load jurisdictions for dropdown
      @jurisdictions = TaxJurisdictionService.all(token: current_token)

      # Load company establishments for context
      @establishments = CompanyEstablishmentService.all(token: current_token)
    rescue ApiService::ApiError => e
      Rails.logger.error "Failed to load tax calculation data: #{e.message}"
    end

    respond_to do |format|
      format.html
      format.json { render json: { jurisdictions: @jurisdictions, establishments: @establishments } }
    end
  end

  def new
    redirect_to invoices_path, alert: "Manual tax calculations are not supported by the API. Use invoice-specific calculations instead."
  end
  
  def create
    redirect_to invoices_path, alert: "Manual tax calculations are not supported by the API. Use invoice-specific calculations instead."
  end
  
  def invoice
    invoice_id = params[:invoice_id]

    @result = TaxService.calculate(invoice_id, token: current_token)
    @invoice = InvoiceService.find(invoice_id, token: current_token)

    respond_to do |format|
      format.html { render plain: "Success: #{@result.inspect}" }
      format.json { render json: @result }
      format.turbo_stream
    end
  end
  
  def recalculate
    invoice_id = params[:invoice_id]

    @result = TaxService.recalculate(invoice_id, token: current_token)
    @invoice = InvoiceService.find(invoice_id, token: current_token)

    respond_to do |format|
      format.html { redirect_to invoice_path(invoice_id), notice: 'Tax recalculated successfully' }
      format.json { render json: @result }
      format.turbo_stream
    end
  end
  
  def validate
    if params[:invoice_id].present?
      @validation = TaxService.validate(params[:invoice_id], token: current_user_token)
    else
      @validation = { valid: false, errors: ['Invoice ID is required for tax validation'] }
    end
    
    respond_to do |format|
      format.json { render json: @validation }
      format.turbo_stream
    end
  rescue ApiService::ApiError => e
    respond_to do |format|
      format.json { render json: { valid: false, errors: [e.message] }, status: :unprocessable_content }
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