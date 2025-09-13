class Api::V1::InvoiceNumberingController < ApplicationController
  before_action :authenticate_user!

  def next_available
    begin
      year = params[:year] || Date.current.year
      series_type = params[:series_type] || 'commercial'
      
      response = InvoiceNumberingService.next_available(
        token: current_token,
        year: year,
        series_type: series_type
      )
      
      render json: {
        data: {
          type: 'next_available_numbers',
          attributes: response
        }
      }, status: :ok
      
    rescue ApiService::ApiError => e
      render json: {
        errors: [{
          status: '422',
          title: 'API Error',
          detail: e.message
        }]
      }, status: :unprocessable_entity
      
    rescue => e
      Rails.logger.error "Error fetching next available numbers: #{e.message}"
      render json: {
        errors: [{
          status: '500',
          title: 'Internal Server Error',
          detail: 'Unable to fetch next available numbers'
        }]
      }, status: :internal_server_error
    end
  end
end