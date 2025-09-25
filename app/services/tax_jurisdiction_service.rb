# frozen_string_literal: true

class TaxJurisdictionService < ApiService
  BASE_ENDPOINT = '/tax_jurisdictions'

  # Get all tax jurisdictions
  def self.all(token:, filters: {})
    response = get(BASE_ENDPOINT, token: token, params: filters)
    jurisdictions = response[:data] || []
    jurisdictions.map { |jurisdiction| transform_api_response(jurisdiction) }
  end

  # Get specific tax jurisdiction
  def self.find(id, token:)
    response = get("#{BASE_ENDPOINT}/#{id}", token: token)
    transform_api_response(response[:data])
  end

  # Get tax rates for a jurisdiction
  def self.tax_rates(jurisdiction_id, token:, effective_date: nil)
    params = effective_date ? { effective_date: effective_date } : {}
    response = get("#{BASE_ENDPOINT}/#{jurisdiction_id}/tax_rates", token: token, params: params)
    tax_rates = response[:data] || []
    tax_rates.map { |rate| transform_tax_rate_response(rate) }
  end

  # Get jurisdictions by country
  def self.by_country(country_code, token:)
    all(token: token, filters: { country: country_code })
  end

  # Get EU member jurisdictions
  def self.eu_members(token:)
    all(token: token).select { |jurisdiction| jurisdiction[:eu_member] }
  end

  # Get jurisdictions by tax regime
  def self.by_tax_regime(regime, token:)
    all(token: token, filters: { tax_regime: regime })
  end

  # Transform API response to client format
  def self.transform_api_response(api_response)
    return {} unless api_response

    attributes = api_response[:attributes] || {}

    {
      id: api_response[:id],
      code: attributes[:code],
      country_name: attributes[:country_name],
      country_code: attributes[:country_code],
      region_code: attributes[:region_code],
      currency: attributes[:currency],
      tax_regime: attributes[:tax_regime],
      default_tax_regime: attributes[:default_tax_regime],
      eu_member: attributes[:eu_member],
      default_vat_rate: attributes[:default_vat_rate],
      reduced_vat_rates: attributes[:reduced_vat_rates],
      requirements: attributes[:requirements] || {},
      exemptions: attributes[:exemptions] || [],
      compliance_notes: attributes[:compliance_notes],
      # Derived display properties
      name: attributes[:name],
      display_name: attributes[:name] || "#{attributes[:country_name]} (#{attributes[:code]})",
      full_code: "#{attributes[:country_code]}-#{attributes[:code]}",
      currency_symbol: currency_symbol_for(attributes[:currency]),
      # Tax context properties
      requires_vat_id: attributes[:eu_member],
      euro_currency: attributes[:currency] == 'EUR',
      spanish_territory: attributes[:country_code] == 'ES',
      requires_einvoice: attributes[:requires_einvoice]
    }
  end

  # Transform tax rate API response
  def self.transform_tax_rate_response(api_response)
    return {} unless api_response

    attributes = api_response[:attributes] || {}

    {
      id: api_response[:id],
      name: attributes[:name],
      code: attributes[:code],
      rate: attributes[:rate],
      category: attributes[:category],
      rate_type: attributes[:rate_type],
      group_code: attributes[:group_code],
      tax_scope: attributes[:tax_scope],
      effective_from: attributes[:effective_from],
      effective_to: attributes[:effective_to],
      applies_to: attributes[:applies_to] || [],
      valid_from: attributes[:effective_from], # for compatibility
      valid_until: attributes[:effective_to], # for compatibility
      is_active: attributes[:effective_to].nil?,
      # Display properties
      display_rate: "#{attributes[:rate]}%",
      full_description: "#{attributes[:name]} (#{attributes[:rate]}%)"
    }
  end

  # Get currency symbol for display
  def self.currency_symbol_for(currency)
    case currency&.upcase
    when 'EUR' then '€'
    when 'USD' then '$'
    when 'GBP' then '£'
    when 'MXN' then '$'
    when 'PLN' then 'zł'
    else currency
    end
  end

  private_class_method :transform_api_response, :transform_tax_rate_response,
                       :currency_symbol_for
end