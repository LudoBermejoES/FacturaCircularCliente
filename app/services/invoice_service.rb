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
    
    def unfreeze(id, token:)
      post("/invoices/#{id}/unfreeze", token: token)
    end
    
    def send_email(id, recipient_email, token:)
      post("/invoices/#{id}/send_email", token: token, body: { 
        recipient_email: recipient_email 
      })
    end
    
    # Status transitions
    def update_status(id, status, comment: nil, token:)
      patch("/invoices/#{id}/status", token: token, body: { 
        status: status,
        comment: comment 
      }.compact)
    end
    
    # Export functions - these return raw content, not JSON
    def download_pdf(id, token:)
      download_file("/invoices/#{id}/pdf", token: token)
    end
    
    def download_facturae(id, token:)
      download_file("/invoices/#{id}/facturae", token: token)
    end
    
    # Line items management
    def add_line_item(invoice_id, params, token:)
      post("/invoices/#{invoice_id}/invoice_lines", token: token, body: { invoice_line: params })
    end
    
    def update_line_item(invoice_id, line_id, params, token:)
      put("/invoices/#{invoice_id}/invoice_lines/#{line_id}", token: token, body: { invoice_line: params })
    end
    
    def remove_line_item(invoice_id, line_id, token:)
      delete("/invoices/#{invoice_id}/invoice_lines/#{line_id}", token: token)
    end
    
    # Tax calculations
    def calculate_taxes(params, token:)
      post('/invoices/calculate_taxes', token: token, body: params)
    end
    
    # Workflow history
    def workflow_history(id, token:)
      get("/invoices/#{id}/workflow_history", token: token)
    end
    
    # Statistics
    def statistics(token:, params: {})
      get('/invoices/statistics', token: token, params: params)
    end
    
    # Dashboard stats
    def stats(token:)
      get('/invoices/stats', token: token)
    end
    
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
        raise ApiService::NotFoundError, 'Resource not found'
      else
        raise ApiService::ApiError, "Request failed with status: #{response.code}"
      end
    rescue HTTParty::Error => e
      raise ApiService::ApiError, "Network error: #{e.message}"
    end
  end
end