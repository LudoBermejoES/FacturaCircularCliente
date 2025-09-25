class TaxService < ApiService
  # Enhanced tax service with multi-jurisdiction support

  # Legacy methods for backward compatibility
  def self.rates(token:)
    response = get('/tax/rates', token: token)
    response[:rates] || []
  end

  def self.exemptions(token:)
    response = get('/tax/exemptions', token: token)
    response[:exemptions] || []
  end

  def self.calculate(invoice_id, token:)
    response = post("/tax/calculate/#{invoice_id}", token: token)
    response
  end

  def self.validate(invoice_id, token:)
    response = post("/tax/validate/#{invoice_id}", token: token)
    response
  end

  def self.recalculate(invoice_id, token:)
    response = post("/tax/recalculate/#{invoice_id}", token: token)
    response
  end

  # Enhanced methods for multi-jurisdiction tax support
  def self.calculate_invoice_tax(invoice_id, token:)
    response = post("/tax/calculate_invoice/#{invoice_id}", token: token)
    response[:data] || {}
  end

  def self.validate_cross_border_transaction(seller_jurisdiction:, buyer_jurisdiction:, product_types:, token:)
    response = post('/tax/validate_cross_border',
      body: {
        seller_jurisdiction: seller_jurisdiction,
        buyer_jurisdiction: buyer_jurisdiction,
        product_types: product_types
      },
      token: token)
    response[:data] || {}
  end

  def self.get_jurisdiction_requirements(jurisdiction_code, token:)
    response = get("/tax/jurisdictions/#{jurisdiction_code}/requirements", token: token)
    response[:data] || {}
  end

  # Tax context resolution for multi-jurisdiction support
  def self.resolve_tax_context(establishment_id: nil, buyer_location: nil, product_types: [], token:)
    response = post('/tax/resolve_context',
      body: {
        establishment_id: establishment_id,
        buyer_location: buyer_location,
        product_types: product_types
      },
      token: token)

    response[:data] || {
      establishment: nil,
      tax_jurisdiction: nil,
      applicable_rates: [],
      cross_border: false,
      reverse_charge: false
    }
  end
end