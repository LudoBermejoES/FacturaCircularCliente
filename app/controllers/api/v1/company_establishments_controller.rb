class Api::V1::CompanyEstablishmentsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Delegate to the service to get company establishments
    @company_establishments = CompanyEstablishmentService.all(token: current_token)

    render json: {
      establishments: @company_establishments
    }
  rescue ApiService::ApiError => e
    render json: {
      error: "Failed to load company establishments: #{e.message}",
      establishments: []
    }, status: :unprocessable_entity
  end
end