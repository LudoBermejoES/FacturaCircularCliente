class InvoiceService < ApiService
  class << self
    def all(token:, filters: {})
      get('/invoices', token: token, params: filters)
    end
    
    def find(id, token:)
      get("/invoices/#{id}", token: token)
    end
    
    def create(params, token:)
      post('/invoices', token: token, body: params)
    end
    
    def update(id, params, token:)
      put("/invoices/#{id}", token: token, body: params)
    end
    
    def delete(id, token:)
      super("/invoices/#{id}", token: token)
    end
    
    # Invoice actions
    def freeze(id, token:)
      post("/invoices/#{id}/freeze", token: token)
    end
    
    # Note: unfreeze and send_email methods removed - not supported by API
    
    # Status transitions
    def update_status(id, status, comment: nil, token:)
      patch("/invoices/#{id}/status", token: token, body: { 
        status: status,
        comment: comment 
      }.compact)
    end
    
    # Note: download_pdf method removed - not supported by API
    
    def download_facturae(id, token:)
      download_file("/invoices/#{id}/facturae", token: token)
    end
    
    # Line items management - updated to use /lines endpoint
    def add_line_item(invoice_id, params, token:)
      post("/invoices/#{invoice_id}/lines", token: token, body: { invoice_line: params })
    end
    
    def update_line_item(invoice_id, line_id, params, token:)
      put("/invoices/#{invoice_id}/lines/#{line_id}", token: token, body: { invoice_line: params })
    end
    
    def remove_line_item(invoice_id, line_id, token:)
      # Call ApiService.delete directly to avoid InvoiceService.delete override
      ApiService.delete("/invoices/#{invoice_id}/lines/#{line_id}", token: token)
    end
    
    # Note: calculate_taxes, workflow_history, statistics, and stats methods removed - not supported by API
    
    # Recent invoices
    def recent(token:, limit: 5)
      response = get('/invoices', token: token, params: { limit: limit, status: 'recent' })
      response&.[](:invoices) || []
    end
    
    private
    
    # Special method for downloading files (PDF, XML) that are not JSON
    def download_file(endpoint, token:)
      options = {
        headers: {
          'Authorization' => "Bearer #{token}",
          'Accept' => '*/*'
        }
      }
      
      url = "#{ApiService::BASE_URL}#{endpoint}"
      response = HTTParty.get(url, options)
      
      case response.code
      when 200
        response.body
      when 401
        raise ApiService::AuthenticationError, 'Authentication failed'
      when 404
        raise ApiService::ApiError, 'Resource not found'
      else
        raise ApiService::ApiError, "Request failed with status: #{response.code}"
      end
    rescue HTTParty::Error => e
      raise ApiService::ApiError, "Network error: #{e.message}"
    end
  end
end