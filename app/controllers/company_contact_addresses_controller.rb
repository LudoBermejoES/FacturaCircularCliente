class CompanyContactAddressesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company
  before_action :set_contact
  before_action :set_address, only: [:show, :edit, :update, :destroy, :set_default]

  def index
    begin
      response = CompanyContactAddressService.all(
        company_id: @company[:id],
        contact_id: @contact[:id],
        token: current_token
      )

      @addresses = response[:addresses] || []
      @total_count = response[:meta] ? response[:meta][:total] : @addresses.size
    rescue ApiService::AuthenticationError => e
      clear_session
      redirect_to login_path, alert: 'Please sign in to continue'
    rescue ApiService::ApiError => e
      @addresses = []
      flash.now[:alert] = "Error loading addresses: #{e.message}"
    end
  end

  def show
    # @address is set by before_action
  end

  def new
    @address = {
      street_address: '',
      city: '',
      postal_code: '',
      state_province: '',
      country_code: 'ESP',
      address_type: 'billing',
      is_default: @contact[:addresses].blank? # First address should be default
    }
  end

  def create
    begin
      response = CompanyContactAddressService.create(
        company_id: @company[:id],
        contact_id: @contact[:id],
        params: address_params,
        token: current_token
      )

      redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                  notice: 'Address was successfully created.'
    rescue ApiService::ValidationError => e
      @address = address_params
      @errors = e.errors
      flash.now[:alert] = 'There were errors creating the address.'
      render :new, status: :unprocessable_content
    rescue ApiService::ApiError => e
      @address = address_params
      flash.now[:alert] = "Error creating address: #{e.message}"
      render :new, status: :unprocessable_content
    end
  end

  def edit
    # @address is set by before_action
  end

  def update
    begin
      CompanyContactAddressService.update(
        company_id: @company[:id],
        contact_id: @contact[:id],
        address_id: @address[:id],
        params: address_params,
        token: current_token
      )

      redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                  notice: 'Address was successfully updated.'
    rescue ApiService::ValidationError => e
      @errors = e.errors
      flash.now[:alert] = 'There were errors updating the address.'
      render :edit, status: :unprocessable_content
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Error updating address: #{e.message}"
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    begin
      CompanyContactAddressService.delete(
        company_id: @company[:id],
        contact_id: @contact[:id],
        address_id: @address[:id],
        token: current_token
      )

      redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                  notice: 'Address was successfully deleted.'
    rescue ApiService::ApiError => e
      redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                  alert: "Error deleting address: #{e.message}"
    end
  end

  def set_default
    begin
      CompanyContactAddressService.set_default(
        company_id: @company[:id],
        contact_id: @contact[:id],
        address_id: @address[:id],
        token: current_token
      )

      respond_to do |format|
        format.html do
          redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                      notice: 'Address was successfully set as default.'
        end
        format.json { render json: { success: true, message: 'Address was successfully set as default.' } }
      end
    rescue ApiService::ApiError => e
      respond_to do |format|
        format.html do
          redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                      alert: "Error setting default address: #{e.message}"
        end
        format.json { render json: { success: false, message: e.message }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_company
    begin
      @company = CompanyService.find(params[:company_id], token: current_token)
    rescue ApiService::ApiError => e
      redirect_to companies_path, alert: "Company not found: #{e.message}"
    end
  end

  def set_contact
    begin
      @contact = CompanyContactService.find(
        params[:company_contact_id],
        company_id: @company[:id],
        token: current_token
      )

      if @contact.nil?
        redirect_to company_company_contacts_path(@company[:id]),
                    alert: "Contact not found"
        return
      end
    rescue ApiService::ApiError => e
      redirect_to company_company_contacts_path(@company[:id]),
                  alert: "Contact not found: #{e.message}"
    end
  end

  def set_address
    begin
      @address = CompanyContactAddressService.find(
        company_id: @company[:id],
        contact_id: @contact[:id],
        address_id: params[:id],
        token: current_token
      )

      if @address.nil?
        redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                    alert: "Address not found"
        return
      end
    rescue ApiService::ApiError => e
      redirect_to company_company_contact_addresses_path(@company[:id], @contact[:id]),
                  alert: "Address not found: #{e.message}"
    end
  end

  def address_params
    params.require(:address).permit(
      :street_address, :city, :postal_code, :state_province,
      :country_code, :address_type, :is_default
    )
  end
end