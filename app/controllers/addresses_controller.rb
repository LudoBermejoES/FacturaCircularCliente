class AddressesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company

  # POST /companies/:company_id/addresses
  def create
    # Validate postal code before sending to API
    validation_result = AddressValidator.validate_params(address_params)
    
    unless validation_result[:valid]
      flash[:error] = "Validation failed: #{validation_result[:errors].join(', ')}"
      redirect_to company_path(@company[:id])
      return
    end

    result = CompanyService.create_address(@company[:id].to_s, address_params.to_h, token: current_token)
    
    if result[:errors]
      flash[:error] = "Failed to create address: #{result[:errors]}"
    else
      flash[:notice] = "Address created successfully"
    end
    
    redirect_to company_path(@company[:id])
  rescue ApiService::ValidationError => e
    flash[:error] = "Validation failed: #{e.errors}"
    redirect_to company_path(@company[:id])
  rescue ApiService::ApiError => e
    flash[:error] = e.message
    redirect_to company_path(@company[:id])
  rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
    flash[:error] = "Network timeout - please try again"
    redirect_to company_path(@company[:id])
  end

  # PATCH/PUT /companies/:company_id/addresses/:id
  def update
    # Validate postal code before sending to API
    validation_result = AddressValidator.validate_params(address_params)
    
    unless validation_result[:valid]
      flash[:error] = "Validation failed: #{validation_result[:errors].join(', ')}"
      redirect_to company_path(@company[:id])
      return
    end

    result = CompanyService.update_address(@company[:id].to_s, params[:id], address_params.to_h, token: current_token)
    
    if result[:errors]
      flash[:error] = "Failed to update address: #{result[:errors]}"
    else
      flash[:notice] = "Address updated successfully"
    end
    
    redirect_to company_path(@company[:id])
  rescue ApiService::ValidationError => e
    flash[:error] = "Validation failed: #{e.errors}"
    redirect_to company_path(@company[:id])
  rescue ApiService::ApiError => e
    flash[:error] = e.message
    redirect_to company_path(@company[:id])
  rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
    flash[:error] = "Network timeout - please try again"
    redirect_to company_path(@company[:id])
  end

  # DELETE /companies/:company_id/addresses/:id
  def destroy
    result = CompanyService.destroy_address(@company[:id].to_s, params[:id], token: current_token)
    
    if result[:errors]
      flash[:error] = "Failed to delete address: #{result[:errors]}"
    else
      flash[:notice] = "Address deleted successfully"
    end
    
    redirect_to company_path(@company[:id])
  rescue ApiService::ApiError => e
    flash[:error] = e.message
    redirect_to company_path(@company[:id])
  rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
    flash[:error] = "Network timeout - please try again"
    redirect_to company_path(@company[:id])
  end

  private

  def set_company
    @company = CompanyService.find(params[:company_id], token: current_token)
  rescue ApiService::ApiError => e
    flash[:error] = e.message
    redirect_to companies_path
  end

  def address_params
    params.require(:address).permit(
      :address,
      :post_code,
      :town,
      :province,
      :country_code,
      :address_type,
      :is_default
    )
  end
end