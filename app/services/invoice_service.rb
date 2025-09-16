class InvoiceService < ApiService
  class << self
    def all(token:, filters: {})
      response = get('/invoices', token: token, params: filters)
      Rails.logger.info "DEBUG: InvoiceService.all - Raw API response: #{response.inspect}"
      
      # Transform JSON API format to expected format
      if response[:data] && response[:data].is_a?(Array)
        invoices = response[:data].map do |invoice_data|
          attributes = invoice_data[:attributes] || {}
          {
            id: invoice_data[:id],
            invoice_number: attributes[:invoice_number],
            proforma_number: attributes[:proforma_number],
            document_type: attributes[:document_type],
            invoice_type: attributes[:document_type], # alias for compatibility
            status: attributes[:status],
            date: attributes[:issue_date],
            issue_date: attributes[:issue_date], # alias for compatibility  
            due_date: attributes[:due_date],
            seller_party_id: attributes[:seller_party_id],
            buyer_party_id: attributes[:buyer_party_id],
            total_invoice: attributes[:total_invoice],
            total: attributes[:total_invoice]&.to_f, # Field used by views for display
            subtotal: attributes[:total_gross_amount_before_taxes]&.to_f, # Subtotal calculation
            total_tax: attributes[:total_tax_outputs]&.to_f, # Tax amount
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
            can_be_converted: attributes[:can_be_converted],
            # Additional fields from API that might be used by views
            total_gross_amount: attributes[:total_gross_amount],
            total_gross_amount_before_taxes: attributes[:total_gross_amount_before_taxes],
            total_tax_outputs: attributes[:total_tax_outputs],
            total_tax_withheld: attributes[:total_tax_withheld],
            total_outstanding_amount: attributes[:total_outstanding_amount],
            exchange_rate: attributes[:exchange_rate],
            # Additional fields that might be missing
            payment_terms: attributes[:payment_terms],
            payment_method: attributes[:payment_method],
            # Company name from API response 
            company_name: attributes[:buyer_name]
          }
        end
        
        result = {
          invoices: invoices,
          meta: response[:meta] || {},
          total: response[:meta] ? response[:meta][:total] : invoices.length
        }
        Rails.logger.info "DEBUG: InvoiceService.all - Transformed response: #{result.inspect}"
        result
      else
        Rails.logger.info "DEBUG: InvoiceService.all - No data field or not an array, returning raw response"
        response
      end
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
          invoice_type: attributes[:document_type], # alias for compatibility
          status: attributes[:status],
          date: attributes[:issue_date],
          issue_date: attributes[:issue_date], # alias for compatibility  
          due_date: attributes[:due_date],
          seller_party_id: attributes[:seller_party_id],
          buyer_party_id: attributes[:buyer_party_id],
          total_invoice: attributes[:total_invoice],
          total: attributes[:total_invoice]&.to_f, # Field used by views for display
          subtotal: attributes[:total_gross_amount_before_taxes]&.to_f, # Subtotal calculation
          total_tax: attributes[:total_tax_outputs]&.to_f, # Tax amount
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
          can_be_converted: attributes[:can_be_converted],
          # Additional fields from API that might be used by views
          total_gross_amount: attributes[:total_gross_amount],
          total_gross_amount_before_taxes: attributes[:total_gross_amount_before_taxes],
          total_tax_outputs: attributes[:total_tax_outputs],
          total_tax_withheld: attributes[:total_tax_withheld],
          total_outstanding_amount: attributes[:total_outstanding_amount],
          exchange_rate: attributes[:exchange_rate],
          # Additional fields that might be missing
          payment_terms: attributes[:payment_terms],
          payment_method: attributes[:payment_method],
          invoice_lines: response[:included]&.select { |item| item[:type] == 'invoice_lines' }&.map do |line|
            line_attrs = line[:attributes] || {}
            {
              id: line[:id],
              description: line_attrs[:description],
              quantity: line_attrs[:quantity],
              unit_price: line_attrs[:unit_price],
              tax_rate: line_attrs[:tax_rate],
              discount_percentage: line_attrs[:discount_percentage],
              total: line_attrs[:total] || (line_attrs[:quantity].to_f * line_attrs[:unit_price].to_f)
            }
          end || []
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
      # Extract line items before creating invoice
      line_items = params.delete(:invoice_lines_attributes) || []
      
      # Convert to JSON API format
      json_api_params = format_for_api(params)
      response = post('/invoices', token: token, body: json_api_params)
      
      # Add line items to the created invoice if any exist
      if response[:data] && response[:data][:id] && line_items.any?
        invoice_id = response[:data][:id]
        line_items.each do |line_item|
          begin
            # Remove nil values and ensure proper format
            clean_line_item = line_item.compact
            
            # Map client field names to API field names
            api_line_item = {
              item_description: clean_line_item[:description] || clean_line_item['description'],
              unit_price_without_tax: clean_line_item[:unit_price] || clean_line_item['unit_price'],
              quantity: clean_line_item[:quantity] || clean_line_item['quantity'],
              tax_rate: clean_line_item[:tax_rate] || clean_line_item['tax_rate'],
              discount_percentage: clean_line_item[:discount_percentage] || clean_line_item['discount_percentage']
            }
            
            # Calculate gross_amount (unit_price * quantity)
            unit_price = api_line_item[:unit_price_without_tax].to_f
            quantity = api_line_item[:quantity].to_f
            api_line_item[:gross_amount] = (unit_price * quantity).round(2)
            
            Rails.logger.info "DEBUG: Adding line item to invoice #{invoice_id}: #{api_line_item.inspect}"
            add_line_item(invoice_id, api_line_item, token: token)
            Rails.logger.info "DEBUG: Line item added successfully"
          rescue => e
            Rails.logger.error "DEBUG: Error adding line item: #{e.class} - #{e.message}"
            # Continue with other line items, don't fail the entire invoice creation
          end
        end
        
        # Recalculate taxes after all line items have been added
        Rails.logger.info "DEBUG: Recalculating taxes for invoice #{invoice_id}"
        recalculate_taxes(invoice_id, token: token)
        Rails.logger.info "DEBUG: Tax recalculation completed"
      end
      
      response
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
      json_api_body = {
        data: {
          type: 'invoice_lines',
          attributes: params
        }
      }
      post("/invoices/#{invoice_id}/lines", token: token, body: json_api_body)
    end
    
    def update_line_item(invoice_id, line_id, params, token:)
      put("/invoices/#{invoice_id}/lines/#{line_id}", token: token, body: { invoice_line: params })
    end
    
    def remove_line_item(invoice_id, line_id, token:)
      # Call ApiService.delete directly to avoid InvoiceService.delete override
      ApiService.delete("/invoices/#{invoice_id}/lines/#{line_id}", token: token)
    end
    
    # Tax calculation methods
    def recalculate_taxes(invoice_id, token:)
      post("/invoices/#{invoice_id}/taxes/recalculate", token: token)
    rescue => e
      Rails.logger.error "DEBUG: Error recalculating taxes for invoice #{invoice_id}: #{e.class} - #{e.message}"
      # Don't fail if tax calculation fails
      nil
    end
    
    # Note: workflow_history, statistics, and stats methods removed - not supported by API
    
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