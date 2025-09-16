class InvoiceSeriesService < ApiService
  class << self
    # Get all invoice series for the current company
    def all(token:, filters: {})
      params = {}
      params[:year] = filters[:year] if filters[:year].present?
      params[:series_type] = filters[:series_type] if filters[:series_type].present?
      params[:active_only] = filters[:active_only] if filters[:active_only].present?
      
      response = get('/invoice_series', token: token, params: params)
      response.dig(:data, :attributes, :series) || []
    end
    
    # Get a specific invoice series
    def find(id, token:)
      response = get("/invoice_series/#{id}", token: token)
      response.dig(:data, :attributes)
    end
    
    # Create a new invoice series
    def create(params, token:)
      response = post('/invoice_series', token: token, body: params)
      response[:data]
    end
    
    # Update an existing invoice series
    def update(id, params, token:)
      response = put("/invoice_series/#{id}", token: token, body: params)
      response[:data]
    end
    
    # Delete an invoice series
    def destroy(id, token:)
      delete("/invoice_series/#{id}", token: token)
      true
    rescue ApiService::ApiError => e
      raise e
    end
    
    # Activate a series
    def activate(id, token:, effective_date: nil)
      body = {}
      body[:effective_date] = effective_date if effective_date.present?
      
      response = post("/invoice_series/#{id}/activate", token: token, body: body)
      response[:data]
    end
    
    # Deactivate a series
    def deactivate(id, token:, reason:, effective_date: nil)
      body = { reason: reason }
      body[:effective_date] = effective_date if effective_date.present?
      
      response = post("/invoice_series/#{id}/deactivate", token: token, body: body)
      response[:data]
    end
    
    # Get series statistics
    def statistics(id, token:)
      response = get("/invoice_series/#{id}/statistics", token: token)
      response.dig(:data, :attributes)
    end
    
    # Get compliance report
    def compliance(id, token:)
      response = get("/invoice_series/#{id}/compliance", token: token)
      response.dig(:data, :attributes)
    end
    
    # Rollover series for new year
    def rollover(id, token:, new_year:)
      body = { new_year: new_year }
      response = post("/invoice_series/#{id}/rollover", token: token, body: body)
      response[:data]
    end
    
    # Get series types for dropdowns
    def series_types
      [
        ['Commercial', 'commercial'],
        ['Proforma', 'proforma'],
        ['Credit Note', 'credit_note'],
        ['Debit Note', 'debit_note'],
        ['Simplified', 'simplified'],
        ['Rectificative', 'rectificative']
      ]
    end
    
    # Get common series codes
    def series_codes
      [
        ['FC - Factura Comercial', 'FC'],
        ['PF - Proforma', 'PF'],
        ['CR - Credit Note', 'CR'],
        ['DB - Debit Note', 'DB'],
        ['SI - Simplified Invoice', 'SI'],
        ['RE - Rectificative', 'RE']
      ]
    end
  end
end