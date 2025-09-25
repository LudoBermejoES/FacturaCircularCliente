class TaxJurisdictionsController < ApplicationController
  before_action :authenticate_user!

  def index
    begin
      filters = {}
      filters[:country] = params[:country] if params[:country].present?

      @jurisdictions = TaxJurisdictionService.all(
        token: current_token,
        filters: filters
      )

      # Apply additional filters client-side for better UX
      if params[:tax_regime].present?
        @jurisdictions = @jurisdictions.select { |j| j[:tax_regime] == params[:tax_regime] }
      end

      if params[:eu_member].present?
        is_eu = params[:eu_member] == 'true'
        @jurisdictions = @jurisdictions.select { |j| j[:eu_member] == is_eu }
      end

    rescue ApiService::AuthenticationError
      redirect_to new_session_path, alert: 'Please sign in to continue.'
    rescue ApiService::ApiError => e
      flash[:alert] = "Failed to load tax jurisdictions: #{e.message}"
      @jurisdictions = []
    end
  end

  def show
    begin
      @jurisdiction = TaxJurisdictionService.find(
        params[:id],
        token: current_token
      )

      @tax_rates = TaxJurisdictionService.tax_rates(
        params[:id],
        token: current_token
      )

    rescue ApiService::NotFoundError
      redirect_to tax_jurisdictions_path, alert: 'Tax jurisdiction not found.'
    rescue ApiService::AuthenticationError
      redirect_to new_session_path, alert: 'Please sign in to continue.'
    rescue ApiService::ApiError => e
      redirect_to tax_jurisdictions_path, alert: "Failed to load tax jurisdiction: #{e.message}"
    end
  end
end