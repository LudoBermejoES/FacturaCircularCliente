class CompanyContactAddressService < ApiService
  class << self
    # Get all addresses for a company contact
    def all(company_id:, contact_id:, token:)
      response = get("/companies/#{company_id}/contacts/#{contact_id}/addresses", token: token)

      if response[:data] && response[:data].is_a?(Array)
        addresses = response[:data].map do |address_data|
          transform_address_response(address_data)
        end

        {
          addresses: addresses,
          meta: response[:meta] || {},
          total: response[:meta] ? response[:meta][:total] : addresses.length
        }
      else
        { addresses: [], meta: { total: 0 }, total: 0 }
      end
    rescue ApiService::ApiError => e
      Rails.logger.error "DEBUG: CompanyContactAddressService.all error: #{e.message}"
      { addresses: [], meta: { total: 0 }, total: 0 }
    end

    # Find a specific address
    def find(company_id:, contact_id:, address_id:, token:)
      response = get("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}", token: token)

      if response[:data]
        transform_address_response(response[:data])
      else
        nil
      end
    rescue ApiService::ApiError => e
      Rails.logger.error "DEBUG: CompanyContactAddressService.find error: #{e.message}"
      nil
    end

    # Create a new address
    def create(company_id:, contact_id:, params:, token:)
      json_api_params = format_address_for_api(params)
      post("/companies/#{company_id}/contacts/#{contact_id}/addresses", token: token, body: json_api_params)
    end

    # Update an address
    def update(company_id:, contact_id:, address_id:, params:, token:)
      json_api_params = format_address_for_api(params)
      patch("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}", token: token, body: json_api_params)
    end

    # Delete an address
    def delete(company_id:, contact_id:, address_id:, token:)
      super("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}", token: token)
    end

    # Set an address as default
    def set_default(company_id:, contact_id:, address_id:, token:)
      post("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{address_id}/set_default", token: token)
    end

    private

    # Transform API response to expected format
    def transform_address_response(address_data)
      attributes = address_data[:attributes] || {}

      {
        id: address_data[:id],
        street_address: attributes[:street_address],
        city: attributes[:city],
        postal_code: attributes[:postal_code],
        state_province: attributes[:state_province],
        country_code: attributes[:country_code],
        country_name: attributes[:country_name],
        address_type: attributes[:address_type],
        is_default: attributes[:is_default],
        full_address: attributes[:full_address],
        full_address_with_country: attributes[:full_address_with_country],
        created_at: attributes[:created_at],
        updated_at: attributes[:updated_at],
        # Add computed display_type
        display_type: transform_address_type_display(attributes[:address_type])
      }
    end

    # Transform address type to display format
    def transform_address_type_display(address_type)
      case address_type
      when 'billing'
        'Billing'
      when 'shipping'
        'Shipping'
      else
        address_type&.capitalize || 'Unknown'
      end
    end

    # Helper method for testing
    def transform_address(address_hash)
      # Add display_type to a simple hash for testing
      address_hash.merge(
        display_type: transform_address_type_display(address_hash[:address_type])
      )
    end

    # Convert address params to JSON API format
    def format_address_for_api(params)
      {
        data: {
          type: 'addresses',
          attributes: {
            street_address: params[:street_address],
            city: params[:city],
            postal_code: params[:postal_code],
            state_province: params[:state_province],
            country_code: params[:country_code],
            address_type: params[:address_type],
            is_default: params[:is_default]
          }.compact
        }
      }
    end
  end
end