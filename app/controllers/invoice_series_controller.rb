class InvoiceSeriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company
  before_action :set_invoice_series, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :statistics, :compliance]
  
  def index
    filters = {
      year: params[:year],
      series_type: params[:series_type],
      active_only: params[:active_only]
    }
    
    result = InvoiceSeriesService.all(token: current_token, filters: filters)
    @invoice_series = result || []
    @years = (2020..Date.current.year + 1).to_a.reverse
    @series_types = InvoiceSeriesService.series_types
  rescue ApiService::ApiError => e
    Rails.logger.error "Failed to load invoice series: #{e.message}"
    flash[:alert] = "Failed to load invoice series: #{e.message}"
    @invoice_series = []
    @years = (2020..Date.current.year + 1).to_a.reverse
    @series_types = InvoiceSeriesService.series_types
  end
  
  def show
    @statistics = InvoiceSeriesService.statistics(@invoice_series[:id], token: current_token)
  rescue ApiService::ApiError => e
    Rails.logger.error "Failed to load series statistics: #{e.message}"
    @statistics = nil
  end
  
  def new
    @invoice_series = {
      company_id: @company[:id],
      year: Date.current.year,
      is_active: true,
      is_default: false
    }
    @series_codes = InvoiceSeriesService.series_codes
    @series_types = InvoiceSeriesService.series_types
  end
  
  def create
    series_data = {
      series_code: params[:invoice_series][:series_code],
      year: params[:invoice_series][:year],
      series_type: params[:invoice_series][:series_type],
      series_name: params[:invoice_series][:series_name],
      is_default: params[:invoice_series][:is_default] == '1',
      is_active: params[:invoice_series][:is_active] == '1',
      legal_justification: params[:invoice_series][:legal_justification]
    }
    
    result = InvoiceSeriesService.create(series_data, token: current_token)
    
    if result[:errors]
      @invoice_series = params[:invoice_series]
      @series_codes = InvoiceSeriesService.series_codes
      @series_types = InvoiceSeriesService.series_types
      @errors = result[:errors]
      render :new, status: :ok
    else
      flash[:notice] = "Invoice series created successfully"
      redirect_to company_invoice_series_path(@company[:id], result[:id])
    end
  rescue ApiService::ValidationError => e
    flash[:alert] = "Validation error: #{e.message}"
    @invoice_series = params[:invoice_series]
    @series_codes = InvoiceSeriesService.series_codes
    @series_types = InvoiceSeriesService.series_types
    render :new, status: :ok
  rescue ApiService::ApiError => e
    flash[:alert] = "Failed to create invoice series: #{e.message}"
    @invoice_series = params[:invoice_series]
    @series_codes = InvoiceSeriesService.series_codes
    @series_types = InvoiceSeriesService.series_types
    render :new, status: :ok
  end
  
  def edit
    @series_codes = InvoiceSeriesService.series_codes
    @series_types = InvoiceSeriesService.series_types
  end
  
  def update
    series_data = {
      series_name: params[:invoice_series][:series_name],
      is_default: params[:invoice_series][:is_default] == '1',
      is_active: params[:invoice_series][:is_active] != '0',
      legal_justification: params[:invoice_series][:legal_justification]
    }
    
    result = InvoiceSeriesService.update(@invoice_series[:id], series_data, token: current_token)
    
    if result[:errors]
      @series_codes = InvoiceSeriesService.series_codes
      @series_types = InvoiceSeriesService.series_types
      @errors = result[:errors]
      render :edit, status: :ok
    else
      flash[:notice] = "Invoice series updated successfully"
      redirect_to company_invoice_series_path(@company[:id], @invoice_series[:id])
    end
  rescue ApiService::ValidationError => e
    flash[:alert] = "Validation error: #{e.message}"
    render :edit, status: :ok
  rescue ApiService::ApiError => e
    flash[:alert] = "Failed to update invoice series: #{e.message}"
    render :edit, status: :ok
  end
  
  def destroy
    InvoiceSeriesService.delete(@invoice_series[:id], token: current_token)
    flash[:notice] = "Invoice series deleted successfully"
    redirect_to company_invoice_series_index_path(@company[:id])
  rescue ApiService::ApiError => e
    flash[:error] = e.message
    redirect_to company_invoice_series_path(@company[:id], @invoice_series[:id])
  end
  
  def activate
    InvoiceSeriesService.activate(
      @invoice_series[:id], 
      token: current_token,
      effective_date: params[:effective_date]
    )
    
    flash[:notice] = "Invoice series activated successfully"
    redirect_to company_invoice_series_path(@company[:id], @invoice_series[:id])
  rescue ApiService::ApiError => e
    flash[:alert] = "Failed to activate invoice series: #{e.message}"
    redirect_to company_invoice_series_path(@company[:id], @invoice_series[:id])
  end
  
  def deactivate
    InvoiceSeriesService.deactivate(
      @invoice_series[:id], 
      token: current_token,
      reason: params[:reason],
      effective_date: params[:effective_date]
    )
    
    flash[:notice] = "Invoice series deactivated successfully"
    redirect_to company_invoice_series_path(@company[:id], @invoice_series[:id])
  rescue ApiService::ApiError => e
    flash[:alert] = "Failed to deactivate invoice series: #{e.message}"
    redirect_to company_invoice_series_path(@company[:id], @invoice_series[:id])
  end
  
  def statistics
    @statistics = InvoiceSeriesService.statistics(@invoice_series[:id], token: current_token)
    render partial: 'statistics', locals: { statistics: @statistics }
  rescue ApiService::ApiError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
  
  def compliance
    @compliance = InvoiceSeriesService.compliance(@invoice_series[:id], token: current_token)
    render partial: 'compliance', locals: { compliance: @compliance }
  rescue ApiService::ApiError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
  
  def rollover
    result = InvoiceSeriesService.rollover(
      params[:id],
      token: current_token,
      new_year: params[:new_year]
    )
    
    if result[:new_series]
      flash[:notice] = "Series rolled over successfully to year #{params[:new_year]}"
      redirect_to company_invoice_series_path(@company[:id], result[:new_series][:id])
    else
      flash[:notice] = "Series rolled over successfully to year #{params[:new_year]}"
      redirect_to company_invoice_series_index_path(@company[:id], year: params[:new_year])
    end
  rescue ApiService::ApiError => e
    flash[:alert] = "Failed to rollover series: #{e.message}"
    redirect_to company_invoice_series_index_path(@company[:id])
  end
  
  private
  
  def set_company
    @company = CompanyService.find(params[:company_id], token: current_token)
  rescue ApiService::ApiError => e
    flash[:error] = "Company not found"
    redirect_to companies_path
  end
  
  def set_invoice_series
    @invoice_series = InvoiceSeriesService.find(params[:id], token: current_token)
  rescue ApiService::ApiError => e
    flash[:alert] = "Invoice series not found"
    redirect_to company_invoice_series_index_path(@company[:id])
  end
end