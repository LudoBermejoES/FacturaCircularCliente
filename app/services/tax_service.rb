class TaxService < ApiService
  # Basic tax endpoints that actually exist in the API
  
  def self.rates(token:)
    get('/tax/rates', token: token)
  end
  
  def self.exemptions(token:)
    get('/tax/exemptions', token: token)
  end
  
  def self.calculate(invoice_id, token:)
    post("/tax/calculate/#{invoice_id}", token: token)
  end
  
  def self.validate(invoice_id, token:)
    post("/tax/validate/#{invoice_id}", token: token)
  end
  
  def self.recalculate(invoice_id, token:)
    post("/tax/recalculate/#{invoice_id}", token: token)
  end
  
  # Note: The following methods were removed as they don't exist in the API:
  # - CRUD operations for tax rates (create_rate, update_rate, delete_rate)
  # - Regional tax variations (regional_rates, irpf_rates)
  # - Tax calculations endpoint (calculate with params)
  # - Tax validation with tax_id (validate_tax_id)
  # - Tax exemption creation (create_exemption, apply_exemption)
  # - Tax reports (tax_summary, vat_report, modelo_303, modelo_347)
  # 
  # These features would need to be implemented in the API if required,
  # or handled client-side with static data/calculations.
end