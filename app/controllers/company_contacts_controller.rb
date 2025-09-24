class CompanyContactsController < ApplicationController
  before_action :set_company
  before_action :set_company_contact, only: [:edit, :update, :destroy, :activate, :deactivate]
  
  def index
    @page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @search = params[:search]
    
    begin
      response = CompanyContactsService.all(
        company_id: @company[:id],
        token: current_token,
        params: {
          page: @page,
          per_page: @per_page,
          search: @search
        }.compact
      )
      
      @contacts = response[:contacts] || []
      @total_count = response[:meta] ? response[:meta][:total] : 0
      @current_page = response[:meta][:page] if response[:meta]
      @total_pages = response[:meta][:pages] if response[:meta]
    rescue ApiService::AuthenticationError => e
      clear_session
      redirect_to login_path, alert: 'Please sign in to continue'
    rescue ApiService::ApiError => e
      @contacts = []
      flash.now[:alert] = "Error loading contacts: #{e.message}"
    end
  end
  
  def new
    @contact = {
      name: '',
      legal_name: '',
      tax_id: '',
      email: '',
      phone: '',
      website: ''
    }
  end
  
  def create
    begin
      response = CompanyContactsService.create(
        company_id: @company[:id],
        params: contact_params,
        token: current_token
      )
      
      redirect_to company_company_contacts_path(@company[:id]), 
                  notice: 'Contact was successfully created.'
    rescue ApiService::ValidationError => e
      @contact = contact_params
      @errors = e.errors
      flash.now[:alert] = 'There were errors creating the contact.'
      render :new, status: :unprocessable_content
    rescue ApiService::ApiError => e
      @contact = contact_params
      flash.now[:alert] = "Error creating contact: #{e.message}"
      render :new, status: :unprocessable_content
    end
  end
  
  def edit
  end
  
  def update
    begin
      CompanyContactsService.update(
        company_id: @company[:id],
        id: @contact[:id],
        params: contact_params,
        token: current_token
      )
      redirect_to company_company_contacts_path(@company[:id]), 
                  notice: 'Contact was successfully updated.'
    rescue ApiService::ValidationError => e
      @errors = e.errors
      flash.now[:alert] = 'There were errors updating the contact.'
      render :edit, status: :unprocessable_content
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Error updating contact: #{e.message}"
      render :edit, status: :unprocessable_content
    end
  end
  
  def destroy
    begin
      CompanyContactsService.destroy(
        company_id: @company[:id],
        id: @contact[:id],
        token: current_token
      )
      redirect_to company_company_contacts_path(@company[:id]), 
                  notice: 'Contact was successfully deleted.'
    rescue ApiService::ApiError => e
      redirect_to company_company_contacts_path(@company[:id]), 
                  alert: "Error deleting contact: #{e.message}"
    end
  end
  
  def activate
    begin
      CompanyContactsService.activate(
        company_id: @company[:id],
        id: @contact[:id],
        token: current_token
      )
      redirect_to company_company_contacts_path(@company[:id]), 
                  notice: 'Contact was successfully activated.'
    rescue ApiService::ApiError => e
      redirect_to company_company_contacts_path(@company[:id]), 
                  alert: "Error activating contact: #{e.message}"
    end
  end
  
  def deactivate
    begin
      CompanyContactsService.deactivate(
        company_id: @company[:id],
        id: @contact[:id],
        token: current_token
      )
      redirect_to company_company_contacts_path(@company[:id]), 
                  notice: 'Contact was successfully deactivated.'
    rescue ApiService::ApiError => e
      redirect_to company_company_contacts_path(@company[:id]), 
                  alert: "Error deactivating contact: #{e.message}"
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
  
  def set_company_contact
    begin
      @contact = CompanyContactsService.find(
        company_id: @company[:id],
        id: params[:id],
        token: current_token
      )
    rescue ApiService::ApiError => e
      redirect_to company_company_contacts_path(@company[:id]), 
                  alert: "Contact not found: #{e.message}"
    end
  end
  
  def contact_params
    Rails.logger.info "DEBUG: Raw params before permit: #{params.inspect}"

    # First, fix the malformed addresses parameter before permit
    company_contact_params = params[:company_contact].to_unsafe_h
    Rails.logger.info "DEBUG: Before fixing addresses: #{company_contact_params.inspect}"

    # Look for malformed address keys like "addresses[0"
    addresses_data = {}
    company_contact_params.each do |key, value|
      if key.match?(/^addresses\[\d+/)
        # Extract the index from malformed key like "addresses[0"
        index_match = key.match(/^addresses\[(\d+)/)
        if index_match
          index = index_match[1]
          addresses_data[index] = value
        end
      end
    end

    # Remove malformed address keys and add properly structured addresses
    company_contact_params.reject! { |key, _| key.match?(/^addresses\[\d+/) }
    company_contact_params['addresses'] = addresses_data if addresses_data.present?

    Rails.logger.info "DEBUG: After fixing addresses: #{company_contact_params.inspect}"

    # Now permit with the fixed structure
    permitted_params = ActionController::Parameters.new(company_contact_params).permit(
      :name, :legal_name, :tax_id, :email, :phone, :website,
      addresses: {}
    )

    Rails.logger.info "DEBUG: Permitted params after permit: #{permitted_params.inspect}"

    # Convert the hash-based addresses to array format
    if permitted_params[:addresses].present?
      Rails.logger.info "DEBUG: Found addresses in permitted params: #{permitted_params[:addresses].inspect}"
      addresses_array = []
      permitted_params[:addresses].each do |key, address_data|
        Rails.logger.info "DEBUG: Processing address key: #{key}, data: #{address_data.inspect}"
        Rails.logger.info "DEBUG: Key match check: #{key.match?(/^\d+$/)}, Data class: #{address_data.class}"

        if key.match?(/^\d+$/) && (address_data.is_a?(Hash) || address_data.is_a?(ActionController::Parameters))
          # Extract nested data and convert to proper format
          address_hash = {}
          address_data.each do |field, value_hash|
            Rails.logger.info "DEBUG: Processing field #{field}: #{value_hash.inspect} (#{value_hash.class})"
            if (value_hash.is_a?(Hash) || value_hash.is_a?(ActionController::Parameters)) && value_hash.key?(']')
              address_hash[field.to_sym] = value_hash[']']
              Rails.logger.info "DEBUG: Extracted value for #{field}: #{value_hash[']']}"
            else
              address_hash[field.to_sym] = value_hash
              Rails.logger.info "DEBUG: Direct value for #{field}: #{value_hash}"
            end
          end
          Rails.logger.info "DEBUG: Processed address hash: #{address_hash.inspect}"

          # Only add non-empty addresses (addresses with at least a street_address)
          if address_hash[:street_address].present?
            addresses_array << address_hash
            Rails.logger.info "DEBUG: Added address to array (street_address present)"
          else
            Rails.logger.info "DEBUG: Skipped address - no street_address"
          end
        else
          Rails.logger.info "DEBUG: Skipped address key #{key} - doesn't match conditions"
        end
      end
      permitted_params[:addresses] = addresses_array
      Rails.logger.info "DEBUG: Final addresses array: #{addresses_array.inspect}"
    else
      Rails.logger.info "DEBUG: No addresses found in permitted params"
    end

    Rails.logger.info "DEBUG: Final permitted params being passed to service: #{permitted_params.inspect}"
    permitted_params
  end
end