class Api::V1::CompanyContactsController < ApplicationController
  def index
    company_id = params[:company_id]
    
    begin
      contacts = CompanyContactsService.active_contacts(company_id: company_id, token: current_token)
      render json: {
        contacts: contacts.map do |contact|
          {
            id: contact[:id],
            name: contact[:full_name] || contact[:name],
            email: contact[:email],
            telephone: contact[:telephone]
          }
        end
      }
    rescue ApiService::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      render json: { error: "Unexpected error: #{e.message}" }, status: :internal_server_error
    end
  end
end