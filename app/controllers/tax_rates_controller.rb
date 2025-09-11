class TaxRatesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @tax_rates = TaxService.rates(token: current_user_token)
    @exemptions = TaxService.exemptions(token: current_user_token)
    
    respond_to do |format|
      format.html
      format.json { render json: @tax_rates }
    end
  rescue ApiService::ApiError => e
    redirect_to root_path, alert: "Unable to load tax rates: #{e.message}"
  end
  
  def show
    redirect_to tax_rates_path, alert: "Tax rate details are not supported by the API"
  end
  
  def new
    redirect_to tax_rates_path, alert: "Creating tax rates is not supported by the API"
  end
  
  def create
    redirect_to tax_rates_path, alert: "Creating tax rates is not supported by the API"
  end
  
  def edit
    redirect_to tax_rates_path, alert: "Editing tax rates is not supported by the API"
  end
  
  def update
    redirect_to tax_rates_path, alert: "Updating tax rates is not supported by the API"
  end
  
  def destroy
    redirect_to tax_rates_path, alert: "Deleting tax rates is not supported by the API"
  end
end