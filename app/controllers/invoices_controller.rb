class InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :freeze, :send_email, :download_pdf, :download_facturae]
  before_action :load_companies, only: [:new, :create, :edit, :update]
  
  def index
    @page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @filters = {
      search: params[:search],
      status: params[:status],
      company_id: params[:company_id],
      invoice_type: params[:invoice_type],
      date_from: params[:date_from],
      date_to: params[:date_to]
    }.compact
    
    begin
      response = InvoiceService.all(
        token: current_token,
        params: {
          page: @page,
          per_page: @per_page,
          **@filters
        }
      )
      
      @invoices = response[:invoices] || []
      @total_count = response[:meta][:total] if response[:meta]
      @current_page = response[:meta][:page] if response[:meta]
      @total_pages = response[:meta][:pages] if response[:meta]
      
      # Load statistics
      @statistics = InvoiceService.statistics(token: current_token)
    rescue ApiService::ApiError => e
      @invoices = []
      @statistics = {}
      flash.now[:alert] = "Error loading invoices: #{e.message}"
    end
  end
  
  def show
    begin
      @workflow_history = InvoiceService.workflow_history(@invoice[:id], token: current_token)
      @company = CompanyService.find(@invoice[:company_id], token: current_token) if @invoice[:company_id]
    rescue ApiService::ApiError => e
      @workflow_history = []
      flash.now[:alert] = "Error loading invoice details: #{e.message}"
    end
  end
  
  def new
    @invoice = {
      invoice_number: '',
      invoice_type: 'invoice',
      date: Date.today.to_s,
      due_date: (Date.today + 30).to_s,
      status: 'draft',
      company_id: params[:company_id],
      invoice_lines: [build_empty_line_item],
      notes: '',
      internal_notes: ''
    }
  end
  
  def create
    begin
      # Process invoice lines
      invoice_params_with_lines = process_invoice_params(invoice_params)
      
      response = InvoiceService.create(invoice_params_with_lines, token: current_token)
      redirect_to invoice_path(response[:id]), notice: 'Invoice was successfully created.'
    rescue ApiService::ValidationError => e
      @invoice = invoice_params
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || [build_empty_line_item]
      @errors = e.errors
      load_companies
      flash.now[:alert] = 'There were errors creating the invoice.'
      render :new, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      @invoice = invoice_params
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || [build_empty_line_item]
      load_companies
      flash.now[:alert] = "Error creating invoice: #{e.message}"
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @invoice[:invoice_lines] ||= [build_empty_line_item]
  end
  
  def update
    begin
      invoice_params_with_lines = process_invoice_params(invoice_params)
      
      InvoiceService.update(@invoice[:id], invoice_params_with_lines, token: current_token)
      redirect_to invoice_path(@invoice[:id]), notice: 'Invoice was successfully updated.'
    rescue ApiService::ValidationError => e
      @errors = e.errors
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || @invoice[:invoice_lines]
      load_companies
      flash.now[:alert] = 'There were errors updating the invoice.'
      render :edit, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || @invoice[:invoice_lines]
      load_companies
      flash.now[:alert] = "Error updating invoice: #{e.message}"
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    begin
      InvoiceService.destroy(@invoice[:id], token: current_token)
      redirect_to invoices_path, notice: 'Invoice was successfully deleted.'
    rescue ApiService::ApiError => e
      redirect_to invoices_path, alert: "Error deleting invoice: #{e.message}"
    end
  end
  
  def freeze
    begin
      InvoiceService.freeze(@invoice[:id], token: current_token)
      redirect_to invoice_path(@invoice[:id]), notice: 'Invoice was successfully frozen.'
    rescue ApiService::ApiError => e
      redirect_to invoice_path(@invoice[:id]), alert: "Error freezing invoice: #{e.message}"
    end
  end
  
  def send_email
    begin
      InvoiceService.send_email(@invoice[:id], params[:recipient_email], token: current_token)
      redirect_to invoice_path(@invoice[:id]), notice: 'Invoice was successfully sent by email.'
    rescue ApiService::ApiError => e
      redirect_to invoice_path(@invoice[:id]), alert: "Error sending invoice: #{e.message}"
    end
  end
  
  def download_pdf
    begin
      pdf_data = InvoiceService.download_pdf(@invoice[:id], token: current_token)
      send_data pdf_data, 
                filename: "invoice_#{@invoice[:invoice_number]}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    rescue ApiService::ApiError => e
      redirect_to invoice_path(@invoice[:id]), alert: "Error downloading PDF: #{e.message}"
    end
  end
  
  def download_facturae
    begin
      xml_data = InvoiceService.download_facturae(@invoice[:id], token: current_token)
      send_data xml_data,
                filename: "facturae_#{@invoice[:invoice_number]}.xml",
                type: 'application/xml',
                disposition: 'attachment'
    rescue ApiService::ApiError => e
      redirect_to invoice_path(@invoice[:id]), alert: "Error downloading Facturae XML: #{e.message}"
    end
  end
  
  private
  
  def set_invoice
    begin
      @invoice = InvoiceService.find(params[:id], token: current_token)
    rescue ApiService::ApiError => e
      redirect_to invoices_path, alert: "Invoice not found: #{e.message}"
    end
  end
  
  def load_companies
    begin
      response = CompanyService.all(token: current_token, params: { per_page: 100 })
      @companies = response[:companies] || []
    rescue ApiService::ApiError => e
      @companies = []
      flash.now[:alert] = "Error loading companies: #{e.message}"
    end
  end
  
  def invoice_params
    params.require(:invoice).permit(
      :invoice_number, :invoice_type, :date, :due_date, :status,
      :company_id, :notes, :internal_notes, :payment_method,
      :payment_terms, :currency, :exchange_rate,
      :discount_percentage, :discount_amount
    )
  end
  
  def process_invoice_params(base_params)
    processed_params = base_params.dup
    
    # Process invoice lines
    if params[:invoice][:invoice_lines].present?
      lines = params[:invoice][:invoice_lines].values.map do |line|
        next if line[:description].blank? && line[:quantity].blank?
        
        {
          description: line[:description],
          quantity: line[:quantity].to_f,
          unit_price: line[:unit_price].to_f,
          tax_rate: line[:tax_rate].to_f,
          discount_percentage: line[:discount_percentage].to_f,
          product_code: line[:product_code]
        }
      end.compact
      
      processed_params[:invoice_lines_attributes] = lines
    end
    
    processed_params
  end
  
  def build_empty_line_item
    {
      description: '',
      quantity: 1,
      unit_price: 0.0,
      tax_rate: 21.0,
      discount_percentage: 0.0,
      product_code: ''
    }
  end
end