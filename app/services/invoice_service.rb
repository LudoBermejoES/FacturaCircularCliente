class InvoiceService < ApiService
  class << self
    def all(token:, filters: {})
      get('/invoices', token: token, params: filters)
    end
    
    def find(id, token:)
      response = get("/invoices/#{id}", token: token)
      Rails.logger.info "DEBUG: InvoiceService.find - Raw API response: #{response.inspect}"
      
      # Transform JSON API format to expected format
      if response[:data]
        attributes = response[:data][:attributes] || {}
        transformed = {
          id: response[:data][:id],
          invoice_number: attributes[:invoice_number],
          proforma_number: attributes[:proforma_number],
          document_type: attributes[:document_type],
          status: attributes[:status],
          date: attributes[:issue_date],
          due_date: attributes[:due_date],
          seller_party_id: attributes[:seller_party_id],
          buyer_party_id: attributes[:buyer_party_id],
          total_invoice: attributes[:total_invoice],
          currency_code: attributes[:currency_code],
          language_code: attributes[:language_code],
          notes: attributes[:notes],
          internal_notes: attributes[:internal_notes],
          is_frozen: attributes[:is_frozen],
          frozen_at: attributes[:frozen_at],
          display_number: attributes[:display_number],
          is_proforma: attributes[:is_proforma],
          created_at: attributes[:created_at],
          updated_at: attributes[:updated_at],
          can_be_modified: attributes[:can_be_modified],
          can_be_converted: attributes[:can_be_converted]
        }
        Rails.logger.info "DEBUG: InvoiceService.find - Transformed invoice: #{transformed.inspect}"
        Rails.logger.info "DEBUG: InvoiceService.find - Transformed invoice[:id]: #{transformed[:id].inspect} (#{transformed[:id].class})"
        transformed
      else
        Rails.logger.info "DEBUG: InvoiceService.find - No data field in response, returning raw response"
        response
      end
    end
    
    def create(params, token:)
      # Convert to JSON API format
      json_api_params = format_for_api(params)
      post('/invoices', token: token, body: json_api_params)
    end
    
    def update(id, params, token:)
      # Convert to JSON API format
      json_api_params = format_for_api(params)
      put("/invoices/#{id}", token: token, body: json_api_params)
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
      body = {
        data: {
          type: 'invoices',
          attributes: {
            status: status
          }
        }
      }
      
      body[:data][:attributes][:comment] = comment if comment.present?
      
      patch("/invoices/#{id}/status", token: token, body: body)
    end
    
    def download_pdf(id, token:)
      download_file("/invoices/#{id}/pdf", token: token)
    end
    
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
    
    # Convert flat hash to JSON API format
    def format_for_api(params)
      # Don't modify original params, work with a copy
      params_copy = params.dup
      
      # Extract relationships
      seller_party_id = params_copy.delete(:seller_party_id)
      buyer_party_id = params_copy.delete(:buyer_party_id)
      
      # Build JSON API structure
      json_api_params = {
        data: {
          type: 'invoices',
          attributes: params_copy
        }
      }
      
      # Add relationships if present
      if seller_party_id || buyer_party_id
        json_api_params[:data][:relationships] = {}
        
        if seller_party_id
          json_api_params[:data][:relationships][:seller_party] = {
            data: { type: 'companies', id: seller_party_id.to_s }
          }
        end
        
        if buyer_party_id
          json_api_params[:data][:relationships][:buyer_party] = {
            data: { type: 'companies', id: buyer_party_id.to_s }
          }
        end
      end
      
      json_api_params
    end
  end
end