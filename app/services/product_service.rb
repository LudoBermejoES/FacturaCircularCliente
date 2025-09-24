class ProductService < ApiService
  class << self
    def all(token:, params: {})
      response = get('/products', token: token, params: params)

      # Transform JSON API format to expected format
      products = []
      if response[:data].is_a?(Array)
        products = response[:data].map do |product_data|
          transform_api_response({ data: product_data })
        end
      end

      {
        products: products,
        meta: response[:meta]
      }
    end

    def find(id, token:)
      response = get("/products/#{id}", token: token)

      # Transform JSON API format to expected format
      if response[:data]
        transform_api_response(response)
      else
        response
      end
    end

    def create(params, token:)
      # Map client field names to API field names
      api_params = {
        sku: params[:sku],
        name: params[:name],
        description: params[:description],
        is_active: params[:is_active].nil? ? true : params[:is_active],
        base_price: params[:base_price],
        currency_code: params[:currency_code] || 'EUR',
        tax_rate: params[:tax_rate] || 21.0
      }.compact

      response = post('/products', token: token, body: {
        data: {
          type: 'products',
          attributes: api_params
        }
      })

      # Transform the response
      if response[:data]
        transform_api_response(response)
      else
        response
      end
    end

    def update(id, params, token:)
      # Map client field names to API field names
      api_params = {
        sku: params[:sku],
        name: params[:name],
        description: params[:description],
        is_active: params[:is_active],
        base_price: params[:base_price],
        currency_code: params[:currency_code],
        tax_rate: params[:tax_rate]
      }.compact

      response = put("/products/#{id}", token: token, body: {
        data: {
          type: 'products',
          attributes: api_params
        }
      })

      # Transform the response
      if response[:data]
        transform_api_response(response)
      else
        response
      end
    end

    def destroy(id, token:)
      delete("/products/#{id}", token: token)
    end

    def search(query, token:, params: {})
      search_params = params.merge(q: query)
      response = get('/products/search', token: token, params: search_params)

      # Transform JSON API format to expected format
      products = []
      if response[:data].is_a?(Array)
        products = response[:data].map do |product_data|
          transform_api_response({ data: product_data })
        end
      end

      {
        products: products,
        meta: response[:meta]
      }
    end

    def invoice_line_attributes(id, token:)
      response = get("/products/#{id}/invoice_line_attributes", token: token)

      if response[:data]
        response[:data][:attributes] || {}
      else
        response
      end
    end

    # Tax filter helpers - matches the API filtering capabilities
    def by_tax_rate(tax_rate, token:, params: {})
      filter_params = params.merge(filter: { tax_rate: tax_rate })
      all(token: token, params: filter_params)
    end

    def active_only(token:, params: {})
      filter_params = params.merge(filter: { is_active: true })
      all(token: token, params: filter_params)
    end

    def standard_tax_products(token:, params: {})
      by_tax_rate(21, token: token, params: params)
    end

    def reduced_tax_products(token:, params: {})
      by_tax_rate(10, token: token, params: params)
    end

    def super_reduced_tax_products(token:, params: {})
      by_tax_rate(4, token: token, params: params)
    end

    def tax_exempt_products(token:, params: {})
      by_tax_rate(0, token: token, params: params)
    end

    private

    def transform_api_response(api_response)
      attributes = api_response.dig(:data, :attributes) || {}

      {
        id: api_response.dig(:data, :id),
        sku: attributes[:sku],
        name: attributes[:name],
        description: attributes[:description],
        is_active: attributes[:is_active],
        base_price: attributes[:base_price],
        currency_code: attributes[:currency_code],
        tax_rate: attributes[:tax_rate],
        created_at: attributes[:created_at],
        updated_at: attributes[:updated_at],

        # Computed attributes from API
        price_with_tax: attributes[:price_with_tax],
        display_name: attributes[:display_name],
        formatted_price: attributes[:formatted_price],
        tax_description: attributes[:tax_description],
        standard_tax: attributes[:standard_tax],
        reduced_tax: attributes[:reduced_tax],
        super_reduced_tax: attributes[:super_reduced_tax],
        tax_exempt: attributes[:tax_exempt]
      }
    end
  end
end