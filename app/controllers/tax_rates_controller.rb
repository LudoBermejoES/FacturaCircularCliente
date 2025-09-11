class TaxRatesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_tax_rate, only: [:show, :edit, :update, :destroy]
  
  def index
    @tax_rates = TaxService.rates(token: current_user_token)
    @regional_rates = TaxService.regional_rates(token: current_user_token)
    @irpf_rates = TaxService.irpf_rates(token: current_user_token)
    
    respond_to do |format|
      format.html
      format.json { render json: @tax_rates }
    end
  rescue ApiService::ApiError => e
    handle_api_error(e)
  end
  
  def show
    respond_to do |format|
      format.html
      format.json { render json: @tax_rate }
    end
  end
  
  def new
    @tax_rate = { 
      name: '', 
      rate: 21.0, 
      type: 'standard',
      region: 'mainland',
      active: true 
    }
  end
  
  def create
    @tax_rate = TaxService.create_rate(tax_rate_params, token: current_user_token)
    
    respond_to do |format|
      format.html { redirect_to tax_rates_path, notice: 'Tax rate was successfully created.' }
      format.json { render json: @tax_rate, status: :created }
    end
  rescue ApiService::ValidationError => e
    @tax_rate = tax_rate_params
    respond_to do |format|
      format.html do
        flash.now[:alert] = e.errors.join(', ')
        render :new
      end
      format.json { render json: { errors: e.errors }, status: :unprocessable_entity }
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: tax_rates_path)
  end
  
  def edit
  end
  
  def update
    @tax_rate = TaxService.update_rate(
      params[:id], 
      tax_rate_params, 
      token: current_user_token
    )
    
    respond_to do |format|
      format.html { redirect_to tax_rates_path, notice: 'Tax rate was successfully updated.' }
      format.json { render json: @tax_rate }
    end
  rescue ApiService::ValidationError => e
    respond_to do |format|
      format.html do
        flash.now[:alert] = e.errors.join(', ')
        render :edit
      end
      format.json { render json: { errors: e.errors }, status: :unprocessable_entity }
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: tax_rates_path)
  end
  
  def destroy
    TaxService.delete_rate(params[:id], token: current_user_token)
    
    respond_to do |format|
      format.html { redirect_to tax_rates_path, notice: 'Tax rate was successfully deleted.' }
      format.json { head :no_content }
    end
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: tax_rates_path)
  end
  
  private
  
  def load_tax_rate
    @tax_rate = TaxService.rate(params[:id], token: current_user_token)
  rescue ApiService::NotFoundError
    redirect_to tax_rates_path, alert: "Tax rate not found"
  rescue ApiService::ApiError => e
    handle_api_error(e, redirect_path: tax_rates_path)
  end
  
  def tax_rate_params
    params.require(:tax_rate).permit(:name, :rate, :type, :region, :active, :description)
  end
end