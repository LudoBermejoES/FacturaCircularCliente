class CompanyContactService < ApiService
  class << self
    # Get all company contacts for a specific company
    def all(company_id:, token:, filters: {})
      response = get("/companies/#{company_id}/contacts", token: token, params: filters)

      if response[:data]
        contacts = response[:data].map do |contact_data|
          transform_contact_response(contact_data)
        end

        {
          contacts: contacts,
          meta: response[:meta] || {},
          total: response[:meta] ? response[:meta][:total] : contacts.length
        }
      else
        response
      end
    end

    # Find a specific company contact
    # Since the API requires a company_id, we'll need to try the current user's company
    def find(contact_id, company_id:, token:)
      response = get("/companies/#{company_id}/contacts/#{contact_id}", token: token)

      if response[:data]
        transform_contact_response(response[:data])
      else
        response
      end
    rescue ApiService::ApiError => e
      Rails.logger.error "DEBUG: CompanyContactService.find error: #{e.message}"
      nil
    end

    # Create a new company contact
    def create(company_id:, params:, token:)
      json_api_params = format_for_api(params)
      post("/companies/#{company_id}/contacts", token: token, body: json_api_params)
    end

    # Update a company contact
    def update(company_id:, contact_id:, params:, token:)
      json_api_params = format_for_api(params)
      put("/companies/#{company_id}/contacts/#{contact_id}", token: token, body: json_api_params)
    end

    # Delete a company contact
    def delete(company_id:, contact_id:, token:)
      super("/companies/#{company_id}/contacts/#{contact_id}", token: token)
    end

    # Search company contacts across all companies the user has access to
    def search(query:, token:)
      # This would need a global search endpoint that doesn't exist yet
      # For now, return empty results
      { contacts: [], total: 0 }
    end

    private

    # Transform API response to expected format
    def transform_contact_response(contact_data)
      attributes = contact_data[:attributes] || {}

      {
        id: contact_data[:id],
        company_name: attributes[:company_name] || attributes[:legal_name],
        legal_name: attributes[:legal_name],
        tax_id: attributes[:tax_id],
        email: attributes[:email],
        phone: attributes[:phone],
        contact_person: attributes[:contact_person],
        is_active: attributes[:is_active],
        owner_company_id: attributes[:owner_company_id],
        # Address info if available
        street_address: attributes[:street_address],
        city: attributes[:city],
        postal_code: attributes[:postal_code],
        state_province: attributes[:state_province],
        country_code: attributes[:country_code],
        created_at: attributes[:created_at],
        updated_at: attributes[:updated_at]
      }
    end

    # Convert flat hash to JSON API format
    def format_for_api(params)
      {
        data: {
          type: 'company_contacts',
          attributes: params
        }
      }
    end
  end
end