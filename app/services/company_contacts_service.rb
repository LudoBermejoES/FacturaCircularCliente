class CompanyContactsService < ApiService
  class << self
    def all(company_id:, token:, params: {})
      search_query = params[:search]

      # Get all contacts from API (without search params since backend doesn't implement search)
      api_params = params.except(:search)
      response = get("/companies/#{company_id}/contacts", token: token, params: api_params)

      # Transform JSON API format to expected format
      contacts = []
      if response[:data].is_a?(Array)
        contacts = response[:data].map do |contact_data|
          attributes = contact_data[:attributes] || {}
          {
            id: contact_data[:id].to_i,
            name: attributes[:person_name] || attributes[:name],
            legal_name: attributes[:legal_name],
            tax_id: attributes[:tax_id],
            email: attributes[:email],
            phone: attributes[:telephone] || attributes[:phone],
            website: attributes[:website],
            first_surname: attributes[:first_surname],
            second_surname: attributes[:second_surname],
            contact_details: attributes[:contact_details],
            is_active: attributes[:is_active]
          }
        end
      end

      # Client-side search filtering (workaround for backend not implementing search)
      if search_query.present?
        search_term = search_query.downcase.strip
        contacts = contacts.select do |contact|
          # Search in name, legal_name, email, and tax_id
          searchable_fields = [
            contact[:name],
            contact[:legal_name],
            contact[:email],
            contact[:tax_id]
          ].compact.map(&:downcase)

          searchable_fields.any? { |field| field.include?(search_term) }
        end
      end

      # Update meta with filtered count
      filtered_meta = response[:meta] ? response[:meta].dup : {}
      filtered_meta[:total] = contacts.size if search_query.present?

      {
        contacts: contacts,
        meta: filtered_meta
      }
    end
    
    def find(company_id:, id:, token:)
      response = get("/companies/#{company_id}/contacts/#{id}", token: token)

      # Transform JSON API format to expected format
      if response[:data]
        attributes = response[:data][:attributes] || {}
        contact_data = {
          id: response[:data][:id].to_i,
          name: attributes[:person_name] || attributes[:name],
          legal_name: attributes[:legal_name],
          tax_id: attributes[:tax_id],
          email: attributes[:email],
          phone: attributes[:telephone] || attributes[:phone],
          website: attributes[:website],
          first_surname: attributes[:first_surname],
          second_surname: attributes[:second_surname],
          contact_details: attributes[:contact_details],
          is_active: attributes[:is_active]
        }

        # Also fetch the contact's addresses
        begin
          addresses_response = CompanyContactAddressService.all(
            company_id: company_id,
            contact_id: id,
            token: token
          )
          contact_data[:addresses] = addresses_response[:addresses] || []
        rescue => e
          Rails.logger.error "DEBUG: CompanyContactsService.find - Failed to load addresses: #{e.message}"
          contact_data[:addresses] = []
        end

        contact_data
      else
        response
      end
    end
    
    def create(company_id:, params:, token:)
      Rails.logger.info "DEBUG: CompanyContactsService.create - Received params: #{params.inspect}"
      Rails.logger.info "DEBUG: CompanyContactsService.create - Addresses present?: #{params[:addresses].present?}"
      Rails.logger.info "DEBUG: CompanyContactsService.create - Addresses value: #{params[:addresses].inspect}"

      # Map client field names to API field names (no addresses in contact creation)
      api_params = {
        name: params[:name],
        legal_name: params[:legal_name],
        tax_id: params[:tax_id],
        email: params[:email],
        phone: params[:phone],
        website: params[:website],
        is_active: true
      }.compact

      Rails.logger.info "DEBUG: CompanyContactsService.create - api_params: #{api_params.inspect}"

      request_body = {
        data: {
          type: 'company_contacts',
          attributes: api_params
        }
      }

      Rails.logger.info "DEBUG: CompanyContactsService.create - request_body: #{request_body.inspect}"

      # Create the contact first
      contact_response = post("/companies/#{company_id}/contacts", token: token, body: request_body)

      # If contact creation was successful and addresses are provided, create the address
      if contact_response[:data] && contact_response[:data][:id] && params[:addresses].present?
        contact_id = contact_response[:data][:id]
        Rails.logger.info "DEBUG: CompanyContactsService.create - Contact created with ID: #{contact_id}"

        # Process addresses - create each one
        params[:addresses].each do |address_params|
          next if address_params[:street_address].blank?

          # Prepare address params for the address service
          address_data = {
            address_type: address_params[:address_type] || 'billing',
            street_address: address_params[:street_address],
            city: address_params[:city],
            postal_code: address_params[:postal_code],
            state_province: address_params[:state_province],
            country_code: address_params[:country_code] || 'ESP',
            is_default: address_params[:is_default] == 'true' || address_params[:is_default] == true
          }.compact

          Rails.logger.info "DEBUG: CompanyContactsService.create - Creating address: #{address_data.inspect}"

          begin
            # Create the address using the dedicated address service
            CompanyContactAddressService.create(
              company_id: company_id,
              contact_id: contact_id,
              params: address_data,
              token: token
            )
            Rails.logger.info "DEBUG: CompanyContactsService.create - Address created successfully"
          rescue => e
            Rails.logger.error "DEBUG: CompanyContactsService.create - Address creation failed: #{e.message}"
            # Don't fail the whole contact creation if address creation fails
          end
        end
      end

      contact_response
    end
    
    def update(company_id:, id:, params:, token:)
      # Map client field names to API field names
      api_params = {
        name: params[:name],
        legal_name: params[:legal_name],
        tax_id: params[:tax_id],
        email: params[:email],
        phone: params[:phone],
        website: params[:website],
        is_active: true
      }.compact
      
      put("/companies/#{company_id}/contacts/#{id}", token: token, body: {
        data: {
          type: 'company_contacts',
          attributes: api_params
        }
      })
    end
    
    def destroy(company_id:, id:, token:)
      delete("/companies/#{company_id}/contacts/#{id}", token: token)
    end
    
    def activate(company_id:, id:, token:)
      post("/companies/#{company_id}/contacts/#{id}/activate", token: token, body: {})
    end
    
    def deactivate(company_id:, id:, token:)
      post("/companies/#{company_id}/contacts/#{id}/deactivate", token: token, body: {})
    end
    
    # Get active contacts for a company (useful for invoice creation)
    def active_contacts(company_id:, token:)
      response = get("/companies/#{company_id}/contacts", token: token, params: { filter: { is_active: true } })

      # Transform JSON API format to expected format
      contacts = []
      if response[:data].is_a?(Array)
        contacts = response[:data].map do |contact_data|
          attributes = contact_data[:attributes] || {}

          # Use person_name if available, fallback to name
          name = attributes[:person_name] || attributes[:name]

          # Construct full name from name parts
          name_parts = [
            attributes[:person_name] || attributes[:name],
            attributes[:first_surname],
            attributes[:second_surname]
          ].compact.reject(&:empty?)
          full_name = name_parts.join(' ')

          {
            id: contact_data[:id].to_i,
            name: name,
            email: attributes[:email],
            phone: attributes[:telephone] || attributes[:phone],
            full_name: full_name
          }
        end
      end

      contacts
    end
  end
end