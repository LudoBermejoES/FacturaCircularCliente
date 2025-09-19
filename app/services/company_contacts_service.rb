class CompanyContactsService < ApiService
  class << self
    def all(company_id:, token:, params: {})
      response = get("/companies/#{company_id}/contacts", token: token, params: params)
      
      # Transform JSON API format to expected format
      contacts = []
      if response[:data].is_a?(Array)
        contacts = response[:data].map do |contact_data|
          attributes = contact_data[:attributes] || {}
          {
            id: contact_data[:id].to_i,
            name: attributes[:person_name] || attributes[:name],
            legal_name: attributes[:legal_name],
            tax_id: attributes[:tax_id],
            email: attributes[:email],
            phone: attributes[:telephone] || attributes[:phone],
            website: attributes[:website],
            first_surname: attributes[:first_surname],
            second_surname: attributes[:second_surname],
            contact_details: attributes[:contact_details],
            is_active: attributes[:is_active]
          }
        end
      end
      
      {
        contacts: contacts,
        meta: response[:meta]
      }
    end
    
    def find(company_id:, id:, token:)
      response = get("/companies/#{company_id}/contacts/#{id}", token: token)
      
      # Transform JSON API format to expected format
      if response[:data]
        attributes = response[:data][:attributes] || {}
        {
          id: response[:data][:id].to_i,
          name: attributes[:person_name] || attributes[:name],
          legal_name: attributes[:legal_name],
          tax_id: attributes[:tax_id],
          email: attributes[:email],
          phone: attributes[:telephone] || attributes[:phone],
          website: attributes[:website],
          first_surname: attributes[:first_surname],
          second_surname: attributes[:second_surname],
          contact_details: attributes[:contact_details],
          is_active: attributes[:is_active]
        }
      else
        response
      end
    end
    
    def create(company_id:, params:, token:)
      # Map client field names to API field names
      api_params = {
        name: params[:name],
        legal_name: params[:legal_name],
        tax_id: params[:tax_id],
        email: params[:email],
        phone: params[:phone],
        website: params[:website],
        is_active: true
      }.compact
      
      # Add addresses if provided
      if params[:addresses].present?
        api_params[:addresses] = params[:addresses].map do |address|
          {
            address_type: address[:address_type],
            street_address: address[:street_address],
            city: address[:city],
            postal_code: address[:postal_code],
            state_province: address[:state_province],
            country_code: address[:country_code] || 'ESP',
            is_default: address[:is_default] == 'true' || address[:is_default] == true
          }.compact
        end.reject { |addr| addr[:street_address].blank? }
      end
      
      Rails.logger.info "DEBUG: CompanyContactsService.create - api_params: #{api_params.inspect}"
      
      request_body = {
        data: {
          type: 'company_contacts',
          attributes: api_params
        }
      }
      
      Rails.logger.info "DEBUG: CompanyContactsService.create - request_body: #{request_body.inspect}"
      
      post("/companies/#{company_id}/contacts", token: token, body: request_body)
    end
    
    def update(company_id:, id:, params:, token:)
      # Map client field names to API field names
      api_params = {
        name: params[:name],
        legal_name: params[:legal_name],
        tax_id: params[:tax_id],
        email: params[:email],
        phone: params[:phone],
        website: params[:website],
        is_active: true
      }.compact
      
      put("/companies/#{company_id}/contacts/#{id}", token: token, body: {
        data: {
          type: 'company_contacts',
          attributes: api_params
        }
      })
    end
    
    def destroy(company_id:, id:, token:)
      delete("/companies/#{company_id}/contacts/#{id}", token: token)
    end
    
    def activate(company_id:, id:, token:)
      post("/companies/#{company_id}/contacts/#{id}/activate", token: token, body: {})
    end
    
    def deactivate(company_id:, id:, token:)
      post("/companies/#{company_id}/contacts/#{id}/deactivate", token: token, body: {})
    end
    
    # Get active contacts for a company (useful for invoice creation)
    def active_contacts(company_id:, token:)
      response = get("/companies/#{company_id}/contacts", token: token, params: { filter: { is_active: true } })
      
      # Transform JSON API format to expected format
      contacts = []
      if response[:data].is_a?(Array)
        contacts = response[:data].map do |contact_data|
          attributes = contact_data[:attributes] || {}
          {
            id: contact_data[:id].to_i,
            name: attributes[:name],
            email: attributes[:email],
            phone: attributes[:telephone] || attributes[:phone],
            full_name: "#{attributes[:name]} #{attributes[:legal_name]}".strip.squeeze(' ')
          }
        end
      end
      
      contacts
    end
  end
end