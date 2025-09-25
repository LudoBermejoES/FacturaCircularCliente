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
            invoice_series_id: attributes[:invoice_series_id],
            proforma_number: attributes[:proforma_number],
            document_type: attributes[:document_type],
            invoice_type: attributes[:document_type], # alias for compatibility
            status: attributes[:status],
            date: attributes[:issue_date],
            issue_date: attributes[:issue_date], # alias for compatibility  
            due_date: attributes[:due_date],
            seller_party_id: attributes[:seller_party_id],
            buyer_party_id: attributes[:buyer_party_id],
            buyer_company_contact_id: attributes[:buyer_company_contact_id],
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
            company_name: attributes[:buyer_name],
            # Workflow functionality
            workflow_definition_id: attributes[:workflow_definition_id]
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
      response = get("/invoices/#{id}?include=invoice_lines,invoice_taxes", token: token)
      Rails.logger.info "DEBUG: InvoiceService.find - Raw API response: #{response.inspect}"
      
      # Transform JSON API format to expected format
      if response[:data]
        attributes = response[:data][:attributes] || {}
        # Workaround: If invoice_series_id is nil, try to infer it from invoice number prefix
        invoice_series_id = attributes[:invoice_series_id]
        if invoice_series_id.nil? && attributes[:invoice_number].present?
          case attributes[:invoice_number]
          when /^FC-/
            invoice_series_id = "72" # FC - Facturas Comerciales 2025
          when /^PF-/
            invoice_series_id = "74" # PF - Proforma 2025
          end
        end

        transformed = {
          id: response[:data][:id],
          invoice_number: attributes[:invoice_number],
          invoice_series_id: invoice_series_id,
          proforma_number: attributes[:proforma_number],
          document_type: attributes[:document_type],
          invoice_type: attributes[:document_type], # alias for compatibility
          status: attributes[:status],
          date: attributes[:issue_date],
          issue_date: attributes[:issue_date], # alias for compatibility
          due_date: attributes[:due_date],
          seller_party_id: attributes[:seller_party_id],
          buyer_party_id: attributes[:buyer_party_id],
          buyer_company_contact_id: attributes[:buyer_company_contact_id],
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
          workflow_definition_id: attributes[:workflow_definition_id],
          # Global financial fields
          total_general_discounts: attributes[:total_general_discounts],
          total_general_surcharges: attributes[:total_general_surcharges],
          total_financial_expenses: attributes[:total_financial_expenses],
          total_reimbursable_expenses: attributes[:total_reimbursable_expenses],
          withholding_amount: attributes[:withholding_amount],
          payment_in_kind_amount: attributes[:payment_in_kind_amount],
          invoice_lines: response[:included]&.select { |item| item[:type] == 'invoice_lines' }&.map do |line|
            line_attrs = line[:attributes] || {}
            quantity = line_attrs[:quantity].to_f
            unit_price = line_attrs[:unit_price_without_tax].to_f
            {
              id: line[:id],
              line_number: line_attrs[:line_number],
              description: line_attrs[:item_description],
              item_description: line_attrs[:item_description], # For view compatibility
              quantity: quantity,
              unit_price: unit_price,
              unit_price_without_tax: unit_price, # For view compatibility
              tax_rate: 21.0, # Default tax rate (could be computed from invoice_taxes)
              discount_percentage: line_attrs[:discount_rate] || 0,
              discount_rate: line_attrs[:discount_rate], # For view compatibility
              gross_amount: line_attrs[:gross_amount],
              total: line_attrs[:gross_amount] || (quantity * unit_price),
              product_code: line_attrs[:article_code] # Map article_code to product_code for client compatibility
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
      # Convert to JSON API format (line items are now handled by the backend automatically)
      json_api_params = format_for_api(params)
      response = post('/invoices', token: token, body: json_api_params)

      response
    end
    
    def update(id, params, token:)
      # Convert to JSON API format
      json_api_params = format_for_api(params)
      response = put("/invoices/#{id}", token: token, body: json_api_params)

      # Apply same transformation as find method
      if response[:data]
        attributes = response[:data][:attributes] || {}
        invoice_series_id = attributes[:invoice_series_id]
        if invoice_series_id.nil? && attributes[:invoice_number].present?
          case attributes[:invoice_number]
          when /^FC-/
            invoice_series_id = "72" # FC - Facturas Comerciales 2025
          when /^PF-/
            invoice_series_id = "74" # PF - Proforma 2025
          end
        end

        transformed = {
          id: response[:data][:id],
          invoice_number: attributes[:invoice_number],
          invoice_series_id: invoice_series_id,
          proforma_number: attributes[:proforma_number],
          document_type: attributes[:document_type],
          invoice_type: attributes[:document_type], # alias for compatibility
          status: attributes[:status],
          date: attributes[:issue_date],
          issue_date: attributes[:issue_date], # alias for compatibility
          due_date: attributes[:due_date],
          seller_party_id: attributes[:seller_party_id],
          buyer_party_id: attributes[:buyer_party_id],
          buyer_company_contact_id: attributes[:buyer_company_contact_id],
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
          workflow_definition_id: attributes[:workflow_definition_id],
          # Global financial fields
          total_general_discounts: attributes[:total_general_discounts],
          total_general_surcharges: attributes[:total_general_surcharges],
          total_financial_expenses: attributes[:total_financial_expenses],
          total_reimbursable_expenses: attributes[:total_reimbursable_expenses],
          withholding_amount: attributes[:withholding_amount],
          payment_in_kind_amount: attributes[:payment_in_kind_amount]
        }

        Rails.logger.info "DEBUG: InvoiceService.update - Transformed invoice: #{transformed.inspect}"
        Rails.logger.info "DEBUG: InvoiceService.update - Transformed invoice[:id]: #{transformed[:id].inspect} (#{transformed[:id].class})"

        return transformed
      else
        response
      end
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

    # Tax context integration methods

    # Calculate taxes for invoice with establishment context
    def calculate_taxes_with_context(id, establishment_id: nil, token:)
      # Get invoice tax calculation from API
      tax_calculation = TaxService.calculate_invoice_tax(id, token: token)

      # If establishment provided, enrich with tax context
      if establishment_id
        establishment_context = CompanyEstablishmentService.find_with_context(establishment_id, token: token)
        tax_calculation[:establishment_context] = establishment_context
      end

      tax_calculation
    rescue => e
      Rails.logger.error "Error calculating taxes with context for invoice #{id}: #{e.message}"
      { error: e.message }
    end

    # Create invoice with automatic tax context resolution
    def create_with_tax_context(params, token:)
      # Extract tax context parameters
      establishment_id = params.delete(:establishment_id)
      buyer_country_override = params.delete(:buyer_country_override)
      buyer_city_override = params.delete(:buyer_city_override)
      auto_calculate_tax_context = params.delete(:auto_calculate_tax_context)

      # Create the invoice first
      result = create(params, token: token)

      # If auto-calculation is enabled and establishment is provided, calculate tax context
      if auto_calculate_tax_context && establishment_id && result[:data]
        invoice_id = result[:data][:id]

        begin
          # Resolve tax context
          buyer_location = nil
          if buyer_country_override.present? || buyer_city_override.present?
            buyer_location = {
              country: buyer_country_override,
              city: buyer_city_override
            }.compact
          end

          tax_context = TaxService.resolve_tax_context(
            establishment_id: establishment_id,
            buyer_location: buyer_location,
            product_types: ['goods'], # Default for now
            token: token
          )

          # Store tax context in the result for client use
          result[:tax_context] = tax_context

          # Optionally update the invoice with tax context data
          if tax_context[:cross_border] || tax_context[:reverse_charge]
            update_params = {
              tax_context_establishment_id: establishment_id,
              tax_context_cross_border: tax_context[:cross_border],
              tax_context_reverse_charge: tax_context[:reverse_charge]
            }

            # Update the invoice with context (non-critical, don't fail if this fails)
            begin
              update(invoice_id, update_params, token: token)
            rescue => update_error
              Rails.logger.warn "Failed to update invoice #{invoice_id} with tax context: #{update_error.message}"
            end
          end

        rescue => tax_error
          Rails.logger.error "Error resolving tax context for invoice #{invoice_id}: #{tax_error.message}"
          result[:tax_context_error] = tax_error.message
        end
      end

      result
    end

    # Update invoice with automatic tax context resolution
    def update_with_tax_context(id, params, token:)
      # Extract tax context parameters
      establishment_id = params.delete(:establishment_id)
      buyer_country_override = params.delete(:buyer_country_override)
      buyer_city_override = params.delete(:buyer_city_override)
      auto_calculate_tax_context = params.delete(:auto_calculate_tax_context)

      # Update the invoice first
      result = update(id, params, token: token)

      # If auto-calculation is enabled and establishment is provided, calculate tax context
      if auto_calculate_tax_context && establishment_id
        begin
          # Get the current invoice buyer information for context
          buyer_location = nil
          if buyer_country_override.present? || buyer_city_override.present?
            buyer_location = {
              country: buyer_country_override,
              city: buyer_city_override
            }.compact
          end

          tax_context = TaxService.resolve_tax_context(
            establishment_id: establishment_id,
            buyer_location: buyer_location,
            product_types: ['goods'], # Default for now
            token: token
          )

          # Store tax context in the result for client use
          result[:tax_context] = tax_context

          # Update the invoice with tax context data if needed
          if tax_context[:cross_border] || tax_context[:reverse_charge]
            context_update_params = {
              tax_context_establishment_id: establishment_id,
              tax_context_cross_border: tax_context[:cross_border],
              tax_context_reverse_charge: tax_context[:reverse_charge]
            }

            # Perform secondary update with context (non-critical)
            begin
              update(id, context_update_params, token: token)
            rescue => update_error
              Rails.logger.warn "Failed to update invoice #{id} with tax context: #{update_error.message}"
            end
          end

        rescue => tax_error
          Rails.logger.error "Error resolving tax context for invoice #{id}: #{tax_error.message}"
          result[:tax_context_error] = tax_error.message
        end
      end

      result
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
      buyer_company_contact_id = params_copy.delete(:buyer_company_contact_id)

      # Build JSON API structure
      json_api_params = {
        data: {
          type: 'invoices',
          attributes: params_copy
        }
      }

      # Add relationships if present
      if seller_party_id || buyer_party_id || buyer_company_contact_id
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

        if buyer_company_contact_id
          json_api_params[:data][:relationships][:buyer_company_contact] = {
            data: { type: 'company_contacts', id: buyer_company_contact_id.to_s }
          }
        end
      end

      json_api_params
    end

    # Tax context integration methods

    # Calculate taxes for invoice with establishment context
    def calculate_taxes_with_context(id, establishment_id: nil, token:)
      # Get invoice tax calculation from API
      tax_calculation = TaxService.calculate_invoice_tax(id, token: token)

      # If establishment provided, enrich with tax context
      if establishment_id
        establishment_context = CompanyEstablishmentService.find_with_context(establishment_id, token: token)
        tax_calculation[:establishment_context] = establishment_context
      end

      tax_calculation
    rescue => e
      Rails.logger.error "Error calculating taxes with context for invoice #{id}: #{e.message}"
      { error: e.message }
    end

    # Validate cross-border transaction for invoice
    def validate_cross_border_transaction(id, token:)
      invoice = find(id, token: token)

      # Get establishment and buyer information
      establishment_id = invoice[:establishment_id] || invoice[:tax_context_establishment_id]

      if establishment_id
        establishment = CompanyEstablishmentService.find(establishment_id, token: token)
        seller_jurisdiction = establishment[:tax_jurisdiction][:code] if establishment[:tax_jurisdiction]

        # Determine buyer jurisdiction (simplified logic)
        buyer_jurisdiction = 'ESP' # Default

        # Use TaxService for cross-border validation
        TaxService.validate_cross_border_transaction(
          seller_jurisdiction: seller_jurisdiction,
          buyer_jurisdiction: buyer_jurisdiction,
          product_types: ['goods'],
          token: token
        )
      else
        { error: 'No establishment information available for cross-border validation' }
      end
    rescue => e
      Rails.logger.error "Error validating cross-border transaction for invoice #{id}: #{e.message}"
      { error: e.message }
    end
  end
end