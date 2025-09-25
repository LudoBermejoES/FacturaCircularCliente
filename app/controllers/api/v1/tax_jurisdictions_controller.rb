# frozen_string_literal: true

class Api::V1::TaxJurisdictionsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/tax_jurisdictions/:id/tax_rates
  def tax_rates
    jurisdiction_id = params[:id]

    begin
      # Fetch tax rates from the main API
      tax_rates = TaxJurisdictionService.tax_rates(jurisdiction_id, token: current_token)

      render json: {
        data: tax_rates
      }
    rescue ApiService::ApiError => e
      render json: {
        error: "Failed to load tax rates: #{e.message}",
        data: []
      }, status: :unprocessable_entity
    end
  end
end