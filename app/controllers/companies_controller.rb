class CompaniesController < ApplicationController
  before_action :set_company, only: [:show, :edit, :update, :destroy]
  skip_before_action :authenticate_user!, only: [:select, :switch]
  before_action :ensure_logged_in, only: [:select, :switch]
  
  def select
    Rails.logger.info "DEBUG: CompaniesController#select called"
    @companies = user_companies
    
    if @companies.empty?
      Rails.logger.error "DEBUG: User has no companies!"
      redirect_to login_path, alert: 'No companies found for your account'
    elsif @companies.size == 1
      # Auto-select if only one company
      switch_to_company(@companies.first['id'] || @companies.first[:id])
    end
  end
  
  def switch
    Rails.logger.info "DEBUG: CompaniesController#switch called with params: #{params.inspect}"
    company_id = params[:company_id]
    
    if company_id.blank?
      redirect_to select_company_path, alert: 'Please select a company'
      return
    end
    
    switch_to_company(company_id.to_i)
  end
  
  def index
    @page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @search = params[:search]
    
    begin
      response = CompanyService.all(
        token: current_token,
        params: {
          page: @page,
          per_page: @per_page,
          search: @search
        }.compact
      )
      
      @companies = response[:companies] || []
      @total_count = response[:meta] ? response[:meta][:total] : response[:total]
      @current_page = response[:meta][:page] if response[:meta]
      @total_pages = response[:meta][:pages] if response[:meta]
      
      # Debug: log the company data to see what's being loaded
      Rails.logger.info "DEBUG: Loaded companies: #{@companies.inspect}"
    rescue ApiService::AuthenticationError => e
      clear_session
      redirect_to login_path, alert: 'Please sign in to continue'
    rescue ApiService::ApiError => e
      @companies = []
      flash.now[:alert] = "Error loading companies: #{e.message}"
    end
  end
  
  def show
    begin
      @invoices = [] # Will be loaded from Invoice API later
      @addresses = CompanyService.addresses(@company[:id], token: current_token)
    rescue ApiService::ApiError => e
      @addresses = []
      flash.now[:alert] = "Error loading company details: #{e.message}"
    end
  end
  
  def new
    @company = {
      name: '',
      tax_id: '',
      legal_name: '',
      email: '',
      phone: '',
      website: ''
    }
  end
  
  def create
    begin
      Rails.logger.info "DEBUG: CompaniesController#create starting"
      response = CompanyService.create(company_params, token: current_token)
      Rails.logger.info "DEBUG: CompanyService.create returned: #{response.inspect}"
      
      # Extract ID from JSON API format response
      company_id = response.dig(:data, :id) || response[:id]
      Rails.logger.info "DEBUG: Extracted company_id: #{company_id}"
      
      redirect_to company_path(company_id), notice: 'Company was successfully created.'
      Rails.logger.info "DEBUG: Redirect to company_path(#{company_id}) initiated"
    rescue ApiService::ValidationError => e
      Rails.logger.info "DEBUG: ValidationError caught: #{e.message}, errors: #{e.errors}"
      @company = company_params
      @errors = e.errors
      flash.now[:alert] = 'There were errors creating the company.'
      render :new, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      Rails.logger.info "DEBUG: ApiError caught: #{e.message}"
      @company = company_params
      flash.now[:alert] = "Error creating company: #{e.message}"
      render :new, status: :unprocessable_entity
    rescue => e
      Rails.logger.info "DEBUG: Unexpected error: #{e.class}: #{e.message}"
      Rails.logger.info "DEBUG: Backtrace: #{e.backtrace[0..5].join('\n')}"
      @company = company_params
      flash.now[:alert] = "Unexpected error: #{e.message}"
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    begin
      CompanyService.update(@company[:id], company_params, token: current_token)
      redirect_to company_path(@company[:id]), notice: 'Company was successfully updated.'
    rescue ApiService::ValidationError => e
      @errors = e.errors
      flash.now[:alert] = 'There were errors updating the company.'
      render :edit, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Error updating company: #{e.message}"
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    begin
      CompanyService.destroy(@company[:id], token: current_token)
      redirect_to companies_path, notice: 'Company was successfully deleted.'
    rescue ApiService::ApiError => e
      redirect_to companies_path, alert: "Error deleting company: #{e.message}"
    end
  end
  
  private
  
  def set_company
    begin
      @company = CompanyService.find(params[:id], token: current_token)
      Rails.logger.info "DEBUG: set_company - @company = #{@company.inspect}"
      Rails.logger.info "DEBUG: set_company - @company[:id] = #{@company[:id].inspect} (#{@company[:id].class})"
    rescue ApiService::ApiError => e
      redirect_to companies_path, alert: "Company not found: #{e.message}"
    end
  end
  
  def company_params
    params.require(:company).permit(
      :name, :legal_name, :tax_id, :email, :phone, :website,
      :description, :notes,
      :default_payment_terms, :default_payment_method,
      :bank_account, :swift_bic
    )
  end
  
  def ensure_logged_in
    unless current_token.present?
      redirect_to login_path, alert: 'Please sign in to continue'
    end
  end
  
  def switch_to_company(company_id)
    begin
      Rails.logger.info "DEBUG: switch_to_company called with company_id=#{company_id} (#{company_id.class})"
      auth_response = AuthService.switch_company(current_token, company_id)
      
      if auth_response
        # Update session with new token and company info
        session[:access_token] = auth_response[:access_token]
        session[:refresh_token] = auth_response[:refresh_token] if auth_response[:refresh_token]
        session[:company_id] = auth_response[:company_id]
        session[:companies] = auth_response[:companies] if auth_response[:companies]
        
        # Get the company name by making a fresh API call to get the correct name
        company_name = 'the selected company' # default fallback
        
        begin
          company_details = CompanyService.find(company_id, token: auth_response[:access_token])
          company_name = company_details[:name] || company_details['name'] || company_name
          Rails.logger.info "DEBUG: Fetched company details: #{company_details.inspect}"
        rescue => e
          Rails.logger.info "DEBUG: Failed to fetch company details: #{e.message}"
          # Fallback to auth response or session data
          company_name = auth_response[:user]&.[](:company_name) || 
                         user_companies.find { |c| (c['id'] || c[:id]).to_s == company_id.to_s }&.[]('name') ||
                         user_companies.find { |c| (c['id'] || c[:id]).to_s == company_id.to_s }&.[](:name) ||
                         company_name
        end
        
        Rails.logger.info "DEBUG: Final company_name = #{company_name}"
        redirect_to dashboard_path, notice: "Successfully switched to #{company_name}"
      else
        redirect_to select_company_path, alert: 'Failed to switch company'
      end
    rescue => e
      Rails.logger.error "Company switch error: #{e.message}"
      redirect_to select_company_path, alert: 'An error occurred while switching companies'
    end
  end
end