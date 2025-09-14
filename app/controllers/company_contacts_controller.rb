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
      email: '',
      telephone: '',
      first_surname: '',
      second_surname: '',
      contact_details: ''
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
      render :new, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      @contact = contact_params
      flash.now[:alert] = "Error creating contact: #{e.message}"
      render :new, status: :unprocessable_entity
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
      render :edit, status: :unprocessable_entity
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Error updating contact: #{e.message}"
      render :edit, status: :unprocessable_entity
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
    params.require(:company_contact).permit(
      :name, :email, :telephone, :first_surname, :second_surname, :contact_details
    )
  end
end