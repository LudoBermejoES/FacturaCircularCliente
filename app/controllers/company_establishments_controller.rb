require 'ostruct'

class CompanyEstablishmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_establishment, only: [:show, :edit, :update, :destroy]

  def index
    begin
      @establishments = CompanyEstablishmentService.all(
        token: current_token
      )
    rescue ApiService::AuthenticationError
      redirect_to new_session_path, alert: 'Please sign in to continue.'
    rescue ApiService::ApiError => e
      flash[:alert] = "Failed to load establishments: #{e.message}"
      @establishments = []
    end
  end

  def show
    begin
      # @establishment already set by before_action
    rescue ApiService::NotFoundError
      redirect_to company_establishments_path, alert: 'Establishment not found.'
    end
  end

  def new
    @establishment = {}
    load_jurisdictions_for_form
  end

  def create
    begin
      @establishment = CompanyEstablishmentService.create(
        establishment_params,
        token: current_token
      )

      redirect_to company_establishment_path(@establishment[:id]),
                  notice: 'Establishment created successfully.'
    rescue ApiService::ValidationError => e
      flash.now[:alert] = "Failed to create establishment: #{e.message}"
      @establishment = establishment_params
      load_jurisdictions_for_form
      render :new, status: :unprocessable_entity
    rescue ApiService::AuthenticationError
      redirect_to new_session_path, alert: 'Please sign in to continue.'
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Failed to create establishment: #{e.message}"
      @establishment = establishment_params
      load_jurisdictions_for_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_jurisdictions_for_form
  end

  def update
    begin
      @establishment = CompanyEstablishmentService.update(
        params[:id],
        establishment_params,
        token: current_token
      )

      redirect_to company_establishment_path(@establishment[:id]),
                  notice: 'Establishment updated successfully.'
    rescue ApiService::ValidationError => e
      flash.now[:alert] = "Failed to update establishment: #{e.message}"
      load_jurisdictions_for_form
      render :edit, status: :unprocessable_entity
    rescue ApiService::NotFoundError
      redirect_to company_establishments_path, alert: 'Establishment not found.'
    rescue ApiService::AuthenticationError
      redirect_to new_session_path, alert: 'Please sign in to continue.'
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Failed to update establishment: #{e.message}"
      load_jurisdictions_for_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      CompanyEstablishmentService.destroy(
        params[:id],
        token: current_token
      )

      redirect_to company_establishments_path,
                  notice: 'Establishment deleted successfully.'
    rescue ApiService::ForbiddenError
      redirect_to company_establishments_path,
                  alert: 'Cannot delete the default establishment.'
    rescue ApiService::NotFoundError
      redirect_to company_establishments_path, alert: 'Establishment not found.'
    rescue ApiService::AuthenticationError
      redirect_to new_session_path, alert: 'Please sign in to continue.'
    rescue ApiService::ApiError => e
      redirect_to company_establishments_path,
                  alert: "Failed to delete establishment: #{e.message}"
    end
  end

  # AJAX endpoint for tax context resolution
  def resolve_tax_context
    begin
      establishment_id = params[:establishment_id]
      buyer_location = params[:buyer_location] || {}
      product_types = params[:product_types] || []

      tax_context = TaxService.resolve_tax_context(
        establishment_id: establishment_id,
        buyer_location: buyer_location,
        product_types: product_types,
        token: current_token
      )

      render json: {
        success: true,
        tax_context: tax_context
      }
    rescue ApiService::AuthenticationError
      render json: {
        success: false,
        error: 'Authentication required'
      }, status: :unauthorized
    rescue ApiService::ApiError => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  private

  def set_establishment
    @establishment = CompanyEstablishmentService.find(
      params[:id],
      token: current_token
    )
  rescue ApiService::NotFoundError
    redirect_to company_establishments_path, alert: 'Establishment not found.'
  rescue ApiService::AuthenticationError
    redirect_to new_session_path, alert: 'Please sign in to continue.'
  end

  def establishment_params
    params.require(:establishment).permit(
      :name, :address_line_1, :address_line_2, :city, :postal_code,
      :currency_code, :is_default, :tax_jurisdiction_id
    )
  end

  def load_jurisdictions_for_form
    begin
      @jurisdictions = TaxJurisdictionService.all(
        token: current_token
      )
    rescue ApiService::ApiError => e
      flash.now[:alert] = "Failed to load tax jurisdictions: #{e.message}"
      @jurisdictions = []
    end
  end
end