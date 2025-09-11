class TaxService < ApiService
  # Tax Rates Management
  def self.rates(token:)
    get("/tax_rates", token: token)
  end
  
  def self.rate(id, token:)
    get("/tax_rates/#{id}", token: token)
  end
  
  def self.create_rate(params, token:)
    post("/tax_rates", body: params, token: token)
  end
  
  def self.update_rate(id, params, token:)
    put("/tax_rates/#{id}", body: params, token: token)
  end
  
  def self.delete_rate(id, token:)
    delete("/tax_rates/#{id}", token: token)
  end
  
  # Tax Calculations
  def self.calculate(params, token:)
    post("/tax_calculations", body: params, token: token)
  end
  
  def self.calculate_invoice(invoice_id, token:)
    post("/invoices/#{invoice_id}/calculate_tax", token: token)
  end
  
  def self.recalculate_invoice(invoice_id, token:)
    post("/invoices/#{invoice_id}/recalculate_tax", token: token)
  end
  
  # Tax Validation
  def self.validate_tax_id(tax_id, country: 'ES', token:)
    post("/tax_validations/tax_id", body: { 
      tax_id: tax_id, 
      country: country 
    }, token: token)
  end
  
  def self.validate_invoice_tax(invoice_id, token:)
    post("/invoices/#{invoice_id}/validate_tax", token: token)
  end
  
  # Tax Exemptions
  def self.exemptions(token:)
    get("/tax_exemptions", token: token)
  end
  
  def self.create_exemption(params, token:)
    post("/tax_exemptions", body: params, token: token)
  end
  
  def self.apply_exemption(invoice_id, exemption_id, token:)
    post("/invoices/#{invoice_id}/apply_exemption", 
         body: { exemption_id: exemption_id }, 
         token: token)
  end
  
  # Regional Tax Variations
  def self.regional_rates(region: nil, token:)
    params = region ? { region: region } : {}
    get("/tax_rates/regional", params: params, token: token)
  end
  
  # Tax Reports
  def self.tax_summary(start_date:, end_date:, token:)
    get("/tax_reports/summary", 
        params: { 
          start_date: start_date, 
          end_date: end_date 
        }, 
        token: token)
  end
  
  def self.vat_report(period:, year:, token:)
    get("/tax_reports/vat", 
        params: { 
          period: period, 
          year: year 
        }, 
        token: token)
  end
  
  # Spanish Tax Specifics
  def self.irpf_rates(token:)
    get("/tax_rates/irpf", token: token)
  end
  
  def self.modelo_303(quarter:, year:, token:)
    get("/tax_reports/modelo_303", 
        params: { 
          quarter: quarter, 
          year: year 
        }, 
        token: token)
  end
  
  def self.modelo_347(year:, token:)
    get("/tax_reports/modelo_347", 
        params: { year: year }, 
        token: token)
  end
end