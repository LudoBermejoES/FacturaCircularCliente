class CompanyService < ApiService
  class << self
    def all(token:, params: {})
      response = get('/companies', token: token, params: params)
      
      # Transform JSON API format to expected format
      companies = []
      if response[:data].is_a?(Array)
        companies = response[:data].map do |company_data|
          attributes = company_data[:attributes] || {}
          {
            id: company_data[:id],
            name: attributes[:trade_name] || attributes[:corporate_name],
            legal_name: attributes[:corporate_name],
            tax_id: attributes[:tax_identification_number],
            email: attributes[:email],
            phone: attributes[:telephone],
            website: attributes[:web_address]
          }
        end
      end
      
      {
        companies: companies,
        meta: response[:meta]
      }
    end
    
    def find(id, token:)
      response = get("/companies/#{id}", token: token)
      
      # Transform JSON API format to expected format
      if response[:data]
        attributes = response[:data][:attributes] || {}
        {
          id: response[:data][:id],
          name: attributes[:trade_name] || attributes[:corporate_name],
          legal_name: attributes[:corporate_name],
          tax_id: attributes[:tax_identification_number],
          email: attributes[:email],
          phone: attributes[:telephone],
          website: attributes[:web_address]
        }
      else
        response
      end
    end
    
    def create(params, token:)
      # Map client field names to API field names
      api_params = {
        trade_name: params[:name],
        corporate_name: params[:legal_name] || params[:name],
        tax_identification_number: params[:tax_id],
        email: params[:email],
        telephone: params[:phone],
        web_address: params[:website],
        person_type_code: 'J', # Default to legal entity
        residence_type_code: 'R' # Default to resident
      }.compact
      
      post('/companies', token: token, body: {
        data: {
          type: 'companies',
          attributes: api_params
        }
      })
    end
    
    def update(id, params, token:)
      # Map client field names to API field names
      api_params = {
        trade_name: params[:name],
        corporate_name: params[:legal_name] || params[:name],
        tax_identification_number: params[:tax_id],
        email: params[:email],
        telephone: params[:phone],
        web_address: params[:website],
        person_type_code: 'J', # Default to legal entity
        residence_type_code: 'R' # Default to resident
      }.compact
      
      put("/companies/#{id}", token: token, body: {
        data: {
          type: 'companies',
          attributes: api_params
        }
      })
    end
    
    def destroy(id, token:)
      delete("/companies/#{id}", token: token)
    end
    
    # Address management
    def addresses(company_id, token:)
      response = get("/companies/#{company_id}/addresses", token: token)
      
      # Transform JSON API format to expected format
      addresses = []
      if response[:data].is_a?(Array)
        addresses = response[:data].map do |address_data|
          attributes = address_data[:attributes] || {}
          {
            id: address_data[:id],
            address: attributes[:address],
            post_code: attributes[:post_code],
            town: attributes[:town],
            province: attributes[:province],
            country_code: attributes[:country_code],
            address_type: attributes[:address_type] || 'legal',
            is_default: attributes[:is_primary] || false
          }
        end
      end
      
      addresses
    end
    
    def create_address(company_id, params, token:)
      # Transform params to JSON API format
      api_params = {
        address: params[:address],
        post_code: params[:post_code],
        town: params[:town],
        province: params[:province],
        country_code: params[:country_code],
        is_primary: params[:is_default], # Map is_default to is_primary
        address_type: params[:address_type]
      }.compact
      
      post("/companies/#{company_id}/addresses", token: token, body: {
        data: {
          type: 'addresses',
          attributes: api_params
        }
      })
    end
    
    def update_address(company_id, address_id, params, token:)
      # Transform params to JSON API format
      api_params = {
        address: params[:address],
        post_code: params[:post_code],
        town: params[:town],
        province: params[:province],
        country_code: params[:country_code],
        is_primary: params[:is_default], # Map is_default to is_primary
        address_type: params[:address_type]
      }.compact
      
      put("/companies/#{company_id}/addresses/#{address_id}", token: token, body: {
        data: {
          type: 'addresses',
          attributes: api_params
        }
      })
    end
    
    def destroy_address(company_id, address_id, token:)
      delete("/companies/#{company_id}/addresses/#{address_id}", token: token)
    end
    
    # Search companies - uses standard index with query param since /companies/search doesn't exist
    def search(query, token:)
      get('/companies', token: token, params: { q: query })
    end
  end
end