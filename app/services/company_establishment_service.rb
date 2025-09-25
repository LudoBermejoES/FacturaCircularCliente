# frozen_string_literal: true

class CompanyEstablishmentService < ApiService
  BASE_ENDPOINT = '/company_establishments'

  # Get all establishments for current company
  def self.all(token:)
    response = get(BASE_ENDPOINT, token: token)
    establishments = response[:establishments] || []
    establishments.map { |establishment| transform_api_response_index(establishment) }
  end

  # Get specific establishment
  def self.find(id, token:)
    response = get("#{BASE_ENDPOINT}/#{id}", token: token)
    transform_api_response(response[:data])
  end

  # Create new establishment
  def self.create(establishment_params, token:)
    api_params = format_for_api(establishment_params)
    response = post(BASE_ENDPOINT, body: api_params, token: token)
    transform_api_response(response[:data])
  end

  # Update establishment
  def self.update(id, establishment_params, token:)
    api_params = format_for_api(establishment_params)
    response = patch("#{BASE_ENDPOINT}/#{id}", body: api_params, token: token)
    transform_api_response(response[:data])
  end

  # Delete establishment
  def self.destroy(id, token:)
    delete("#{BASE_ENDPOINT}/#{id}", token: token)
    true
  end

  # Get default establishment
  def self.default(token:)
    establishments = all(token: token)
    establishments.find { |est| est[:is_default] } || establishments.first
  end

  # Get establishments by tax jurisdiction
  def self.by_tax_jurisdiction(jurisdiction_id, token:)
    establishments = all(token: token)
    establishments.select { |est| est[:tax_jurisdiction_id] == jurisdiction_id.to_i }
  end

  # Resolve tax context for establishment
  def self.resolve_tax_context(establishment_id, buyer_location: {}, product_types: [], token:)
    request_body = {
      buyer_location: buyer_location,
      product_types: product_types
    }

    response = post("#{BASE_ENDPOINT}/#{establishment_id}/resolve_tax_context", body: request_body, token: token)
    response[:data] || {}
  end

  # Format establishment data for API
  def self.format_for_api(params)
    {
      data: {
        type: 'company_establishments',
        attributes: {
          name: params[:name],
          address_line_1: params[:address_line_1],
          address_line_2: params[:address_line_2],
          city: params[:city],
          state_province: params[:state_province],
          postal_code: params[:postal_code],
          currency_code: params[:currency_code],
          is_default: params[:is_default] || false,
          tax_jurisdiction_id: params[:tax_jurisdiction_id]
        }
      }
    }
  end

  # Transform API response to client format (for individual items - JSON API format)
  def self.transform_api_response(api_response)
    return {} unless api_response

    attributes = api_response[:attributes] || {}
    relationships = api_response[:relationships] || {}
    tax_jurisdiction = relationships.dig(:tax_jurisdiction, :data)

    {
      id: api_response[:id]&.to_i,
      name: attributes[:name],
      address_line_1: attributes[:address_line_1],
      address_line_2: attributes[:address_line_2],
      city: attributes[:city],
      state_province: attributes[:state_province],
      postal_code: attributes[:postal_code],
      currency_code: attributes[:currency_code],
      is_default: attributes[:is_default],
      tax_jurisdiction_id: attributes[:tax_jurisdiction_id] || tax_jurisdiction&.dig(:id)&.to_i,
      created_at: attributes[:created_at],
      updated_at: attributes[:updated_at],
      # Derived properties
      full_address: build_full_address(attributes),
      display_name: build_display_name(attributes),
      default_indicator: attributes[:is_default] ? ' (Default)' : ''
    }
  end

  # Transform API response for index (flattened format)
  def self.transform_api_response_index(api_response)
    return {} unless api_response

    {
      id: api_response[:id]&.to_i,
      name: api_response[:name],
      address_line_1: api_response[:address_line_1],
      address_line_2: api_response[:address_line_2],
      city: api_response[:city],
      state_province: api_response[:state_province],
      postal_code: api_response[:postal_code],
      currency_code: api_response[:currency_code],
      is_default: api_response[:is_default],
      tax_jurisdiction_id: api_response.dig(:tax_jurisdiction, :id)&.to_i,
      tax_jurisdiction: api_response[:tax_jurisdiction],
      created_at: api_response[:created_at],
      updated_at: api_response[:updated_at],
      # Derived properties
      full_address: build_full_address(api_response),
      display_name: build_display_name(api_response),
      default_indicator: api_response[:is_default] ? ' (Default)' : ''
    }
  end

  # Build full address for display
  def self.build_full_address(attributes)
    parts = []
    parts << attributes[:address_line_1] if attributes[:address_line_1].present?
    parts << attributes[:address_line_2] if attributes[:address_line_2].present?

    location_parts = []
    location_parts << attributes[:city] if attributes[:city].present?
    location_parts << attributes[:state_province] if attributes[:state_province].present?
    location_parts << attributes[:postal_code] if attributes[:postal_code].present?

    parts << location_parts.join(', ') if location_parts.any?
    parts.empty? ? nil : parts.join("\n")
  end

  # Build display name with default indicator
  def self.build_display_name(attributes)
    name = attributes[:name] || 'Unnamed Establishment'
    default_text = attributes[:is_default] ? ' (Default)' : ''
    "#{name}#{default_text}"
  end

  private_class_method :format_for_api, :transform_api_response, :transform_api_response_index,
                       :build_full_address, :build_display_name
end