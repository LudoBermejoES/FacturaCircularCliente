class CompanyContactsService < ApiService
  class << self
    def all(company_id:, token:, params: {})
      response = get("/companies/#{company_id}/company_contacts", token: token, params: params)
      
      # Transform JSON API format to expected format
      contacts = []
      if response[:data].is_a?(Array)
        contacts = response[:data].map do |contact_data|
          attributes = contact_data[:attributes] || {}
          {
            id: contact_data[:id],
            name: attributes[:person_name],
            email: attributes[:email],
            telephone: attributes[:telephone],
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
      response = get("/companies/#{company_id}/company_contacts/#{id}", token: token)
      
      # Transform JSON API format to expected format
      if response[:data]
        attributes = response[:data][:attributes] || {}
        {
          id: response[:data][:id],
          name: attributes[:person_name],
          email: attributes[:email],
          telephone: attributes[:telephone],
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
        person_name: params[:name],
        email: params[:email],
        telephone: params[:telephone],
        first_surname: params[:first_surname],
        second_surname: params[:second_surname],
        contact_details: params[:contact_details]
      }.compact
      
      post("/companies/#{company_id}/company_contacts", token: token, body: {
        data: {
          type: 'company_contacts',
          attributes: api_params
        }
      })
    end
    
    def update(company_id:, id:, params:, token:)
      # Map client field names to API field names
      api_params = {
        person_name: params[:name],
        email: params[:email],
        telephone: params[:telephone],
        first_surname: params[:first_surname],
        second_surname: params[:second_surname],
        contact_details: params[:contact_details]
      }.compact
      
      put("/companies/#{company_id}/company_contacts/#{id}", token: token, body: {
        data: {
          type: 'company_contacts',
          attributes: api_params
        }
      })
    end
    
    def destroy(company_id:, id:, token:)
      delete("/companies/#{company_id}/company_contacts/#{id}", token: token)
    end
    
    def activate(company_id:, id:, token:)
      post("/companies/#{company_id}/company_contacts/#{id}/activate", token: token, body: {})
    end
    
    def deactivate(company_id:, id:, token:)
      post("/companies/#{company_id}/company_contacts/#{id}/deactivate", token: token, body: {})
    end
    
    # Get active contacts for a company (useful for invoice creation)
    def active_contacts(company_id:, token:)
      response = get("/companies/#{company_id}/company_contacts", token: token, params: { filter: { is_active: true } })
      
      # Transform JSON API format to expected format
      contacts = []
      if response[:data].is_a?(Array)
        contacts = response[:data].map do |contact_data|
          attributes = contact_data[:attributes] || {}
          {
            id: contact_data[:id],
            name: attributes[:person_name],
            email: attributes[:email],
            telephone: attributes[:telephone],
            full_name: "#{attributes[:person_name]} #{attributes[:first_surname]} #{attributes[:second_surname]}".strip
          }
        end
      end
      
      contacts
    end
  end
end