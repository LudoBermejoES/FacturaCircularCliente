class InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :freeze, :send_email, :download_pdf, :download_facturae]
  before_action :load_companies, only: [:new, :create, :edit, :update]
  before_action :load_invoice_series, only: [:new, :create, :edit, :update]
  before_action :load_workflows, only: [:new, :create, :edit, :update]
  before_action :check_permission_to_create, only: [:new, :create]
  before_action :check_permission_to_edit, only: [:edit, :update, :destroy]
  
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
        filters: {
          page: @page,
          per_page: @per_page,
          **@filters
        }
      )
      
      @invoices = response[:invoices] || []
      @total_count = response[:meta] ? response[:meta][:total] : response[:total]
      @current_page = response[:meta][:page] if response[:meta]
      @total_pages = response[:meta][:pages] if response[:meta]
      
      # Statistics endpoint doesn't exist in API, use empty hash
      @statistics = {}
    rescue ApiService::ApiError => e
      @invoices = []
      @statistics = {}
      flash.now[:alert] = "Error loading invoices: #{e.message}"
    end
  end
  
  def show
    begin
      # Load seller company information
      @seller_company = nil
      if @invoice[:seller_party_id] || @invoice[:seller_company_id]
        seller_id = @invoice[:seller_party_id] || @invoice[:seller_company_id]
        @seller_company = CompanyService.find(seller_id, token: current_token)
      end

      # Load buyer company or contact information
      @buyer_company = nil
      @buyer_contact = nil

      if @invoice[:buyer_party_id] || @invoice[:buyer_company_id]
        buyer_id = @invoice[:buyer_party_id] || @invoice[:buyer_company_id]
        @buyer_company = CompanyService.find(buyer_id, token: current_token)
      elsif @invoice[:buyer_company_contact_id]
        Rails.logger.info "DEBUG: Found buyer_company_contact_id: #{@invoice[:buyer_company_contact_id]}"

        # Try to load the company contact
        # Since the API requires a company_id, we'll try the seller's company first (current user's company)
        seller_company_id = @invoice[:seller_party_id]

        if seller_company_id
          @buyer_contact = CompanyContactService.find(
            @invoice[:buyer_company_contact_id],
            company_id: seller_company_id,
            token: current_token
          )
          Rails.logger.info "DEBUG: Loaded buyer contact: #{@buyer_contact.inspect}"
        end

        # Fall back to placeholder if loading failed
        if @buyer_contact.nil?
          Rails.logger.info "DEBUG: Could not load contact, using placeholder"
          @buyer_contact = {
            id: @invoice[:buyer_company_contact_id],
            company_name: @invoice[:buyer_name] || "External Contact",
            email: nil,
            phone: nil,
            tax_id: nil
          }
        end
      end

      # Workflow history endpoint doesn't exist in API, use empty array
      @workflow_history = []

      # Legacy company field for backward compatibility
      @company = @buyer_company || @buyer_contact
    rescue ApiService::ApiError => e
      @workflow_history = []
      @seller_company = nil
      @buyer_company = nil
      @buyer_contact = nil
      flash.now[:alert] = "Error loading invoice details: #{e.message}"
    end
  end
  
  def new
    @invoice = {
      invoice_number: '',
      invoice_type: 'invoice',
      issue_date: Date.today.to_s,
      due_date: (Date.today + 30).to_s,
      status: 'draft',
      seller_party_id: params[:seller_party_id],
      buyer_party_id: params[:buyer_party_id],
      buyer_company_contact_id: params[:buyer_company_contact_id],
      invoice_lines: [build_empty_line_item],
      notes: '',
      internal_notes: ''
    }
    
    load_companies
    load_invoice_series
    load_all_company_contacts
  end
  
  def create
    begin
      Rails.logger.info "DEBUG: InvoicesController#create - Starting"
      Rails.logger.info "DEBUG: Raw params: #{params.inspect}"
      Rails.logger.info "DEBUG: Invoice params: #{invoice_params.inspect}"
      
      # Process invoice lines
      invoice_params_with_lines = process_invoice_params(invoice_params)
      Rails.logger.info "DEBUG: Processed params: #{invoice_params_with_lines.inspect}"
      
      Rails.logger.info "DEBUG: Calling InvoiceService.create"
      response = InvoiceService.create(invoice_params_with_lines, token: current_token)
      Rails.logger.info "DEBUG: InvoiceService.create returned: #{response.inspect}"
      redirect_to invoice_path(response[:data][:id]), notice: 'Invoice created successfully'
    rescue ApiService::ValidationError => e
      Rails.logger.info "DEBUG: ValidationError caught: #{e.message}"
      Rails.logger.info "DEBUG: ValidationError errors: #{e.errors.inspect}"
      @invoice = invoice_params
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || [build_empty_line_item]

      # Preserve buyer selection from original form submission
      if params[:buyer_selection].present?
        type, id = params[:buyer_selection].split(':')
        if type == 'company'
          @invoice[:buyer_party_id] = id
          @invoice[:buyer_company_contact_id] = nil
        elsif type == 'contact'
          @invoice[:buyer_party_id] = nil
          @invoice[:buyer_company_contact_id] = id
        end
      end

      # Parse API errors into a format the view can understand
      @errors = parse_validation_errors(e.errors)
      Rails.logger.info "DEBUG: Parsed errors: #{@errors.inspect}"

      load_companies
      load_invoice_series
      load_all_company_contacts
      flash.now[:alert] = 'Please fix the errors below.'
      render :new, status: :unprocessable_content
    rescue ApiService::ApiError => e
      Rails.logger.info "DEBUG: ApiError caught: #{e.message}"
      @invoice = invoice_params
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || [build_empty_line_item]

      # Preserve buyer selection from original form submission
      if params[:buyer_selection].present?
        type, id = params[:buyer_selection].split(':')
        if type == 'company'
          @invoice[:buyer_party_id] = id
          @invoice[:buyer_company_contact_id] = nil
        elsif type == 'contact'
          @invoice[:buyer_party_id] = nil
          @invoice[:buyer_company_contact_id] = id
        end
      end

      load_companies
      load_invoice_series
      load_all_company_contacts
      flash.now[:alert] = "Error creating invoice: #{e.message}"
      render :new, status: :unprocessable_content
    rescue => e
      Rails.logger.error "DEBUG: Unexpected error in create: #{e.class} - #{e.message}"
      Rails.logger.error "DEBUG: Backtrace: #{e.backtrace.first(5).join("\n")}"
      @invoice = invoice_params
      flash.now[:alert] = "Unexpected error: #{e.message}"
      render :new, status: :unprocessable_content
    end
  end
  
  def edit
    @invoice[:invoice_lines] ||= [build_empty_line_item]
    
    load_companies
    load_invoice_series
    load_all_company_contacts
  end
  
  def update
    begin
      invoice_params_with_lines = process_invoice_params(invoice_params)
      
      InvoiceService.update(@invoice[:id], invoice_params_with_lines, token: current_token)
      redirect_to invoice_path(@invoice[:id]), notice: 'Invoice updated successfully'
    rescue ApiService::ValidationError => e
      # Parse API errors into a format the view can understand
      @errors = parse_validation_errors(e.errors)
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || @invoice[:invoice_lines]
      load_companies
      load_invoice_series
      load_all_company_contacts
      flash.now[:alert] = 'Please fix the errors below.'
      render :edit, status: :unprocessable_content
    rescue ApiService::ApiError => e
      @invoice[:invoice_lines] = params[:invoice][:invoice_lines]&.values || @invoice[:invoice_lines]
      load_companies
      load_invoice_series
      load_all_company_contacts
      flash.now[:alert] = "Error updating invoice: #{e.message}"
      render :edit, status: :unprocessable_content
    end
  end
  
  def destroy
    begin
      InvoiceService.delete(@invoice[:id], token: current_token)
      redirect_to invoices_path, notice: 'Invoice deleted successfully'
    rescue ApiService::ApiError => e
      redirect_to invoices_path, alert: "Error deleting invoice: #{e.message}"
    end
  end
  
  def freeze
    begin
      InvoiceService.freeze(@invoice[:id], token: current_token)
      redirect_to invoice_path(@invoice[:id]), notice: 'Invoice frozen'
    rescue ApiService::ApiError => e
      redirect_to invoice_path(@invoice[:id]), alert: "Error freezing invoice: #{e.message}"
    end
  end
  
  def send_email
    begin
      InvoiceService.send_email(@invoice[:id], params[:recipient_email], token: current_token)
      redirect_to invoice_path(@invoice[:id]), notice: 'Email sent'
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
      Rails.logger.info "DEBUG: set_invoice - @invoice = #{@invoice.inspect}"
      Rails.logger.info "DEBUG: set_invoice - @invoice[:id] = #{@invoice[:id].inspect} (#{@invoice[:id].class})"
    rescue ApiService::ApiError => e
      redirect_to invoices_path, alert: "Invoice not found: #{e.message}"
    end
  end
  
  def load_companies
    begin
      response = CompanyService.all(token: current_token, params: { per_page: 100 })
      all_companies = response[:companies] || []

      # Seller companies: All companies (user can select which company is selling)
      @seller_companies = all_companies

      # For customers, load both companies and contacts separately
      @customer_companies = all_companies # Real companies

      # Load company contacts
      if current_company_id
        begin
          contacts_response = CompanyContactsService.all(
            company_id: current_company_id,
            token: current_token,
            params: { per_page: 100 }
          )
          @customer_contacts = contacts_response[:contacts] || []
        rescue ApiService::ApiError => e
          @customer_contacts = []
          Rails.logger.warn "Error loading company contacts: #{e.message}"
        end
      else
        @customer_contacts = []
      end

      # Create combined buyer options with type identification
      @buyer_options = []

      # Add companies with 'company' type
      all_companies.each do |company|
        @buyer_options << {
          id: company[:id],
          name: company[:corporate_name] || company[:trade_name] || company[:name] || "Company ##{company[:id]}",
          type: 'company'
        }
      end

      # Add contacts with 'contact' type
      @customer_contacts.each do |contact|
        @buyer_options << {
          id: contact[:id],
          name: contact[:name] || contact[:legal_name] || "Contact ##{contact[:id]}",
          type: 'contact'
        }
      end

      # Keep @companies for backward compatibility
      @companies = all_companies
    rescue ApiService::ApiError => e
      @companies = []
      @seller_companies = []
      @customer_companies = []
      @customer_contacts = []
      @buyer_options = []
      flash.now[:alert] = "Error loading companies: #{e.message}"
    end
  end
  
  def load_company_contacts(company_id = nil)
    @company_contacts = {}
    return unless company_id.present?
    
    begin
      contacts = CompanyContactsService.active_contacts(company_id: company_id, token: current_token)
      @company_contacts[company_id.to_s] = contacts
    rescue ApiService::ApiError => e
      @company_contacts[company_id.to_s] = []
      Rails.logger.warn "Error loading company contacts for company #{company_id}: #{e.message}"
    end
  end
  
  def load_all_company_contacts
    @company_contacts = {}
    return unless @companies.present?
    
    @companies.each do |company|
      begin
        contacts = CompanyContactsService.active_contacts(company_id: company[:id], token: current_token)
        @company_contacts[company[:id].to_s] = contacts
      rescue ApiService::ApiError => e
        @company_contacts[company[:id].to_s] = []
        Rails.logger.warn "Error loading contacts for company #{company[:id]}: #{e.message}"
      end
    end
  end

  def load_invoice_series
    begin
      # Load active invoice series for current year
      @invoice_series = InvoiceSeriesService.all(
        token: current_token,
        filters: {
          year: Date.current.year,
          active_only: true
        }
      )
    rescue ApiService::ApiError => e
      @invoice_series = []
      Rails.logger.warn "Error loading invoice series: #{e.message}"
      # Don't show error to user as this might be called during error states
    end
  end

  def load_workflows
    begin
      # Load workflow definitions - API doesn't support filtering yet
      response = WorkflowService.definitions(token: current_token)
      @workflows = response[:data] || response[:workflow_definitions] || []
    rescue ApiService::ApiError => e
      @workflows = []
      Rails.logger.warn "Error loading workflows: #{e.message}"
      # Don't show error to user as this might be called during error states
    end
  end
  
  def invoice_params
    # WORKAROUND: Rails 8 seems to have a bug with :issue_date parameter filtering
    # Allow it explicitly in addition to the permit list
    base_params = params.require(:invoice).permit(
      :invoice_number, :invoice_series_id, :invoice_type, :issue_date, :due_date, :status,
      :seller_party_id, :buyer_party_id, :buyer_company_contact_id, :notes, :internal_notes, :payment_method,
      :payment_terms, :currency, :exchange_rate, :workflow_definition_id,
      :discount_percentage, :discount_amount,
      invoice_lines: {},  # Allow nested hash structure
      invoice_lines_attributes: [:description, :quantity, :unit_price, :tax_rate, :discount_percentage, :product_code]
    )
    
    # Manual workaround for issue_date parameter filtering bug
    if params[:invoice][:issue_date].present? && !base_params.key?(:issue_date)
      base_params[:issue_date] = params[:invoice][:issue_date]
    end
    
    base_params
  end
  
  def process_invoice_params(base_params)
    processed_params = base_params.dup

    # Process buyer selection - override the empty buyer fields with the selected values
    if params[:buyer_selection].present?
      type, id = params[:buyer_selection].split(':')
      if type == 'company'
        processed_params[:buyer_party_id] = id
        processed_params[:buyer_company_contact_id] = nil
      elsif type == 'contact'
        processed_params[:buyer_party_id] = nil
        processed_params[:buyer_company_contact_id] = id
      end
    end

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
  
  def check_permission_to_create
    unless can?(:create, :invoices)
      redirect_to dashboard_path, alert: "You don't have permission to create invoices."
    end
  end
  
  def check_permission_to_edit
    unless can?(:edit, :invoices)
      redirect_to dashboard_path, alert: "You don't have permission to edit invoices."
    end
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
  
  # Parse API validation errors into a format the view can understand
  # API errors come in format: [{status: "422", source: {pointer: "/data/attributes/invoice_number"}, title: "Validation Error", detail: "Invoice number can't be blank", code: "VALIDATION_ERROR"}]
  # We need to convert to: {"invoice_number" => ["can't be blank"]}
  def parse_validation_errors(api_errors)
    errors = {}
    
    return errors unless api_errors.is_a?(Array)
    
    api_errors.each do |error|
      next unless error.is_a?(Hash) && error[:source] && error[:source][:pointer] && error[:detail]
      
      # Extract field name from pointer like "/data/attributes/invoice_number"
      pointer = error[:source][:pointer]
      if pointer.match(%r{/data/attributes/(.+)})
        field_name = $1
        message = error[:detail]
        
        # Remove field name from the beginning of the message if it's there
        # "Invoice number can't be blank" -> "can't be blank"
        field_label = field_name.humanize.downcase
        message = message.gsub(/^#{Regexp.escape(field_label)}\s+/i, '')
        
        errors[field_name] ||= []
        errors[field_name] << message
      end
    end
    
    errors
  end
  
end