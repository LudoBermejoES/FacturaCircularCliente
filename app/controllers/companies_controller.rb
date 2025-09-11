class CompaniesController < ApplicationController
  before_action :set_company, only: [:show, :edit, :update, :destroy]
  
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
      website: '',
      company_type: 'customer'
    }
  end
  
  def create
    begin
      response = CompanyService.create(company_params, token: current_token)
      redirect_to company_path(response[:id]), notice: 'Company was successfully created.'
    rescue ApiService::ValidationError => e
      @company = company_params
      @errors = e.errors
      flash.now[:alert] = 'There were errors creating the company.'
      render :new, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      @company = company_params
      flash.now[:alert] = "Error creating company: #{e.message}"
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
    rescue ApiService::ApiError => e
      redirect_to companies_path, alert: "Company not found: #{e.message}"
    end
  end
  
  def company_params
    params.require(:company).permit(
      :name, :legal_name, :tax_id, :email, :phone, :website,
      :company_type, :description, :notes,
      :default_payment_terms, :default_payment_method,
      :bank_account, :swift_bic
    )
  end
end