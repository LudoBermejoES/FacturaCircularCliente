require 'rails_helper'

RSpec.describe ProductService, type: :service do
  let(:token) { 'test_access_token' }
  let(:product_id) { 123 }
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }

  describe '.all' do
    context 'when successful' do
      let(:products_response) do
        {
          data: [
            {
              id: 1,
              type: 'products',
              attributes: {
                sku: 'PRD-001',
                name: 'Test Product 1',
                description: 'A sample product for testing',
                is_active: true,
                base_price: '100.0',
                currency_code: 'EUR',
                tax_rate: '21.0',
                created_at: '2025-01-18T12:00:00Z',
                updated_at: '2025-01-18T12:00:00Z',
                price_with_tax: '121.0',
                display_name: 'PRD-001 - Test Product 1',
                formatted_price: 'EUR 100.0',
                tax_description: 'Standard (21%)',
                standard_tax: true,
                reduced_tax: false,
                super_reduced_tax: false,
                tax_exempt: false
              }
            },
            {
              id: 2,
              type: 'products',
              attributes: {
                sku: 'PRD-002',
                name: 'Test Product 2',
                description: 'Another test product',
                is_active: false,
                base_price: '50.0',
                currency_code: 'EUR',
                tax_rate: '10.0',
                created_at: '2025-01-18T12:00:00Z',
                updated_at: '2025-01-18T12:00:00Z',
                price_with_tax: '55.0',
                display_name: 'PRD-002 - Test Product 2',
                formatted_price: 'EUR 50.0',
                tax_description: 'Reduced (10%)',
                standard_tax: false,
                reduced_tax: true,
                super_reduced_tax: false,
                tax_exempt: false
              }
            }
          ],
          meta: { total_count: 2, page_count: 1, current_page: 1, per_page: 20 }
        }
      end

      before do
        stub_request(:get, "#{base_url}/products")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: products_response.to_json)
      end

      it 'returns products list' do
        result = ProductService.all(token: token)

        expect(result[:products].size).to eq(2)
        expect(result[:products].first[:name]).to eq('Test Product 1')
        expect(result[:products].first[:sku]).to eq('PRD-001')
        expect(result[:products].first[:base_price]).to eq('100.0')
        expect(result[:products].first[:tax_rate]).to eq('21.0')
        expect(result[:products].first[:price_with_tax]).to eq('121.0')
        expect(result[:meta][:total_count]).to eq(2)
      end
    end

    context 'with filter parameters' do
      let(:params) { { filter: { is_active: true, tax_rate: 21 } } }

      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: params
          )
          .to_return(status: 200, body: { data: [], meta: {} }.to_json)
      end

      it 'passes filter parameters' do
        ProductService.all(token: token, params: params)

        expect(WebMock).to have_requested(:get, "#{base_url}/products")
          .with(query: params)
      end
    end

    context 'with pagination parameters' do
      let(:params) { { page: { number: 2, size: 10 } } }

      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: params
          )
          .to_return(status: 200, body: { data: [], meta: {} }.to_json)
      end

      it 'passes pagination parameters' do
        ProductService.all(token: token, params: params)

        expect(WebMock).to have_requested(:get, "#{base_url}/products")
          .with(query: params)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
      end

      it 'raises AuthenticationError' do
        expect { ProductService.all(token: token) }
          .to raise_error(ApiService::AuthenticationError)
      end
    end
  end

  describe '.find' do
    context 'when successful' do
      let(:product_response) do
        {
          data: {
            id: product_id,
            type: 'products',
            attributes: {
              sku: 'PRD-123',
              name: 'Specific Product',
              description: 'A specific product for testing',
              is_active: true,
              base_price: '150.0',
              currency_code: 'EUR',
              tax_rate: '21.0',
              created_at: '2025-01-18T12:00:00Z',
              updated_at: '2025-01-18T12:00:00Z',
              price_with_tax: '181.5',
              display_name: 'PRD-123 - Specific Product',
              formatted_price: 'EUR 150.0',
              tax_description: 'Standard (21%)',
              standard_tax: true,
              reduced_tax: false,
              super_reduced_tax: false,
              tax_exempt: false
            }
          }
        }
      end

      before do
        stub_request(:get, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: product_response.to_json)
      end

      it 'returns product details' do
        result = ProductService.find(product_id, token: token)

        expect(result[:id]).to eq(product_id)
        expect(result[:name]).to eq('Specific Product')
        expect(result[:sku]).to eq('PRD-123')
        expect(result[:base_price]).to eq('150.0')
        expect(result[:tax_rate]).to eq('21.0')
        expect(result[:price_with_tax]).to eq('181.5')
        expect(result[:standard_tax]).to be true
      end
    end

    context 'when product not found' do
      before do
        stub_request(:get, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Product not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { ProductService.find(product_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.create' do
    let(:product_params) do
      {
        sku: 'NEW-001',
        name: 'New Product',
        description: 'A new test product',
        base_price: 200.00,
        tax_rate: 21.0,
        currency_code: 'EUR',
        is_active: true
      }
    end

    context 'when successful' do
      let(:created_product) do
        {
          data: {
            id: 789,
            type: 'products',
            attributes: {
              sku: 'NEW-001',
              name: 'New Product',
              description: 'A new test product',
              is_active: true,
              base_price: '200.0',
              currency_code: 'EUR',
              tax_rate: '21.0',
              created_at: Time.current.iso8601,
              updated_at: Time.current.iso8601,
              price_with_tax: '242.0',
              display_name: 'NEW-001 - New Product',
              formatted_price: 'EUR 200.0',
              tax_description: 'Standard (21%)',
              standard_tax: true,
              reduced_tax: false,
              super_reduced_tax: false,
              tax_exempt: false
            }
          }
        }
      end

      before do
        stub_request(:post, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'products',
                attributes: {
                  sku: 'NEW-001',
                  name: 'New Product',
                  description: 'A new test product',
                  is_active: true,
                  base_price: 200.00,
                  currency_code: 'EUR',
                  tax_rate: 21.0
                }
              }
            }.to_json
          )
          .to_return(status: 201, body: created_product.to_json)
      end

      it 'creates product and returns transformed data' do
        result = ProductService.create(product_params, token: token)

        expect(result[:id]).to eq(789)
        expect(result[:name]).to eq('New Product')
        expect(result[:sku]).to eq('NEW-001')
        expect(result[:base_price]).to eq('200.0')
        expect(result[:tax_rate]).to eq('21.0')
        expect(result[:price_with_tax]).to eq('242.0')
      end
    end

    context 'when validation fails' do
      before do
        stub_request(:post, "#{base_url}/products")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 422,
            body: {
              errors: [
                {
                  status: '422',
                  source: { pointer: '/data/attributes/sku' },
                  title: 'Validation Error',
                  detail: "Sku can't be blank"
                },
                {
                  status: '422',
                  source: { pointer: '/data/attributes/base_price' },
                  title: 'Validation Error',
                  detail: 'Base price must be greater than or equal to 0'
                }
              ]
            }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { ProductService.create(product_params, token: token) }
          .to raise_error(ApiService::ValidationError)
      end
    end
  end

  describe '.update' do
    let(:update_params) do
      {
        name: 'Updated Product Name',
        description: 'Updated description',
        base_price: 175.0
      }
    end

    context 'when successful' do
      let(:updated_product) do
        {
          data: {
            id: product_id,
            type: 'products',
            attributes: {
              sku: 'PRD-123',
              name: 'Updated Product Name',
              description: 'Updated description',
              is_active: true,
              base_price: '175.0',
              currency_code: 'EUR',
              tax_rate: '21.0',
              updated_at: Time.current.iso8601,
              price_with_tax: '211.75',
              display_name: 'PRD-123 - Updated Product Name',
              formatted_price: 'EUR 175.0',
              tax_description: 'Standard (21%)',
              standard_tax: true,
              reduced_tax: false,
              super_reduced_tax: false,
              tax_exempt: false
            }
          }
        }
      end

      before do
        stub_request(:put, "#{base_url}/products/#{product_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: {
              data: {
                type: 'products',
                attributes: {
                  name: 'Updated Product Name',
                  description: 'Updated description',
                  base_price: 175.0
                }
              }
            }.to_json
          )
          .to_return(status: 200, body: updated_product.to_json)
      end

      it 'updates product and returns transformed data' do
        result = ProductService.update(product_id, update_params, token: token)

        expect(result[:id]).to eq(product_id)
        expect(result[:name]).to eq('Updated Product Name')
        expect(result[:description]).to eq('Updated description')
        expect(result[:base_price]).to eq('175.0')
        expect(result[:price_with_tax]).to eq('211.75')
      end
    end

    context 'when product not found' do
      before do
        stub_request(:put, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Product not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { ProductService.update(product_id, update_params, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.destroy' do
    context 'when successful' do
      before do
        stub_request(:delete, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'deletes product successfully' do
        result = ProductService.destroy(product_id, token: token)

        expect(result).to be_nil
        expect(WebMock).to have_requested(:delete, "#{base_url}/products/#{product_id}")
      end
    end

    context 'when product is referenced by invoices' do
      before do
        stub_request(:delete, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 409,
            body: { error: 'Cannot delete product referenced by invoices' }.to_json
          )
      end

      it 'raises ApiError' do
        expect { ProductService.destroy(product_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe '.search' do
    let(:query) { 'Test Product' }

    context 'when successful' do
      let(:search_response) do
        {
          data: [
            {
              id: 1,
              type: 'products',
              attributes: {
                sku: 'TST-001',
                name: 'Test Product Alpha',
                description: 'A test product for alpha testing',
                is_active: true,
                base_price: '100.0',
                currency_code: 'EUR',
                tax_rate: '21.0',
                price_with_tax: '121.0',
                display_name: 'TST-001 - Test Product Alpha',
                formatted_price: 'EUR 100.0',
                tax_description: 'Standard (21%)'
              }
            },
            {
              id: 2,
              type: 'products',
              attributes: {
                sku: 'TST-002',
                name: 'Test Product Beta',
                description: 'A test product for beta testing',
                is_active: true,
                base_price: '120.0',
                currency_code: 'EUR',
                tax_rate: '21.0',
                price_with_tax: '145.2',
                display_name: 'TST-002 - Test Product Beta',
                formatted_price: 'EUR 120.0',
                tax_description: 'Standard (21%)'
              }
            }
          ],
          meta: { total_count: 2, query: query }
        }
      end

      before do
        stub_request(:get, "#{base_url}/products/search")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { q: query }
          )
          .to_return(status: 200, body: search_response.to_json)
      end

      it 'returns search results' do
        result = ProductService.search(query, token: token)

        expect(result[:products].size).to eq(2)
        expect(result[:products].all? { |p| p[:name].include?('Test Product') }).to be true
        expect(result[:meta][:query]).to eq(query)
      end
    end

    context 'with additional filter parameters' do
      let(:params) { { filter: { is_active: true } } }

      before do
        stub_request(:get, "#{base_url}/products/search")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { q: query, filter: { is_active: true } }
          )
          .to_return(status: 200, body: { data: [], meta: {} }.to_json)
      end

      it 'passes search query and filter parameters' do
        ProductService.search(query, token: token, params: params)

        expect(WebMock).to have_requested(:get, "#{base_url}/products/search")
          .with(query: { q: query, filter: { is_active: true } })
      end
    end

    context 'when no results found' do
      before do
        stub_request(:get, "#{base_url}/products/search")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { q: query }
          )
          .to_return(status: 200, body: { data: [], meta: { total_count: 0 } }.to_json)
      end

      it 'returns empty results' do
        result = ProductService.search(query, token: token)

        expect(result[:products]).to be_empty
        expect(result[:meta][:total_count]).to eq(0)
      end
    end
  end

  describe '.invoice_line_attributes' do
    context 'when successful' do
      let(:line_attributes_response) do
        {
          data: {
            type: 'invoice_line_attributes',
            attributes: {
              item_description: 'A sample product for testing',
              quantity: 1,
              unit_price_without_tax: '100.0',
              tax_rate: '21.0',
              discount_rate: 0,
              line_extension_amount: '100.0'
            }
          }
        }
      end

      before do
        stub_request(:get, "#{base_url}/products/#{product_id}/invoice_line_attributes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: line_attributes_response.to_json)
      end

      it 'returns invoice line attributes' do
        result = ProductService.invoice_line_attributes(product_id, token: token)

        expect(result[:item_description]).to eq('A sample product for testing')
        expect(result[:quantity]).to eq(1)
        expect(result[:unit_price_without_tax]).to eq('100.0')
        expect(result[:tax_rate]).to eq('21.0')
        expect(result[:discount_rate]).to eq(0)
        expect(result[:line_extension_amount]).to eq('100.0')
      end
    end

    context 'when product not found' do
      before do
        stub_request(:get, "#{base_url}/products/#{product_id}/invoice_line_attributes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 404, body: { error: 'Product not found' }.to_json)
      end

      it 'raises ApiError' do
        expect { ProductService.invoice_line_attributes(product_id, token: token) }
          .to raise_error(ApiService::ApiError)
      end
    end
  end

  describe 'tax filter helpers' do
    let(:filter_response) do
      {
        data: [
          {
            id: 1,
            type: 'products',
            attributes: {
              sku: 'STD-001',
              name: 'Standard Tax Product',
              tax_rate: '21.0',
              standard_tax: true
            }
          }
        ],
        meta: { total_count: 1 }
      }
    end

    describe '.by_tax_rate' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { tax_rate: 21 } }
          )
          .to_return(status: 200, body: filter_response.to_json)
      end

      it 'filters products by tax rate' do
        result = ProductService.by_tax_rate(21, token: token)

        expect(result[:products].size).to eq(1)
        expect(result[:products].first[:tax_rate]).to eq('21.0')
      end
    end

    describe '.active_only' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { is_active: true } }
          )
          .to_return(status: 200, body: filter_response.to_json)
      end

      it 'filters for active products only' do
        result = ProductService.active_only(token: token)

        expect(result[:products].size).to eq(1)
        expect(WebMock).to have_requested(:get, "#{base_url}/products")
          .with(query: { filter: { is_active: true } })
      end
    end

    describe '.standard_tax_products' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { tax_rate: 21 } }
          )
          .to_return(status: 200, body: filter_response.to_json)
      end

      it 'filters for standard tax (21%) products' do
        result = ProductService.standard_tax_products(token: token)

        expect(result[:products].size).to eq(1)
        expect(result[:products].first[:standard_tax]).to be true
      end
    end

    describe '.reduced_tax_products' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { tax_rate: 10 } }
          )
          .to_return(status: 200, body: { data: [], meta: {} }.to_json)
      end

      it 'filters for reduced tax (10%) products' do
        ProductService.reduced_tax_products(token: token)

        expect(WebMock).to have_requested(:get, "#{base_url}/products")
          .with(query: { filter: { tax_rate: 10 } })
      end
    end

    describe '.super_reduced_tax_products' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { tax_rate: 4 } }
          )
          .to_return(status: 200, body: { data: [], meta: {} }.to_json)
      end

      it 'filters for super reduced tax (4%) products' do
        ProductService.super_reduced_tax_products(token: token)

        expect(WebMock).to have_requested(:get, "#{base_url}/products")
          .with(query: { filter: { tax_rate: 4 } })
      end
    end

    describe '.tax_exempt_products' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { filter: { tax_rate: 0 } }
          )
          .to_return(status: 200, body: { data: [], meta: {} }.to_json)
      end

      it 'filters for tax exempt (0%) products' do
        ProductService.tax_exempt_products(token: token)

        expect(WebMock).to have_requested(:get, "#{base_url}/products")
          .with(query: { filter: { tax_rate: 0 } })
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'when token is nil' do
      before do
        stub_request(:get, "#{base_url}/products")
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            }
          )
          .to_return(status: 401, body: { error: 'Authentication failed. Please login again.' }.to_json)
      end

      it 'raises AuthenticationError for all methods' do
        expect { ProductService.all(token: nil) }
          .to raise_error(ApiService::AuthenticationError, 'Authentication failed. Please login again.')
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "#{base_url}/products")
          .to_raise(Net::ReadTimeout)
      end

      it 'raises ApiError with network error message' do
        expect { ProductService.all(token: token) }
          .to raise_error(ApiService::ApiError, 'Unexpected error: Net::ReadTimeout with "Exception from WebMock"')
      end
    end

    context 'when server returns 500' do
      before do
        stub_request(:get, "#{base_url}/products")
          .to_return(status: 500, body: { error: 'Internal server error' }.to_json)
      end

      it 'raises ApiError' do
        expect { ProductService.all(token: token) }
          .to raise_error(ApiService::ApiError, /Server error|Unexpected error/)
      end
    end
  end

  describe 'private methods' do
    describe '.transform_api_response' do
      let(:api_response) do
        {
          data: {
            id: '123',
            type: 'products',
            attributes: {
              sku: 'TEST-001',
              name: 'Test Product',
              description: 'A test product',
              is_active: true,
              base_price: '100.0',
              currency_code: 'EUR',
              tax_rate: '21.0',
              created_at: '2025-01-18T12:00:00Z',
              updated_at: '2025-01-18T12:00:00Z',
              price_with_tax: '121.0',
              display_name: 'TEST-001 - Test Product',
              formatted_price: 'EUR 100.0',
              tax_description: 'Standard (21%)',
              standard_tax: true,
              reduced_tax: false,
              super_reduced_tax: false,
              tax_exempt: false
            }
          }
        }
      end

      it 'correctly transforms API response to client format' do
        transformed = ProductService.send(:transform_api_response, api_response)

        expect(transformed[:id]).to eq('123')
        expect(transformed[:sku]).to eq('TEST-001')
        expect(transformed[:name]).to eq('Test Product')
        expect(transformed[:description]).to eq('A test product')
        expect(transformed[:is_active]).to be true
        expect(transformed[:base_price]).to eq('100.0')
        expect(transformed[:currency_code]).to eq('EUR')
        expect(transformed[:tax_rate]).to eq('21.0')
        expect(transformed[:price_with_tax]).to eq('121.0')
        expect(transformed[:display_name]).to eq('TEST-001 - Test Product')
        expect(transformed[:formatted_price]).to eq('EUR 100.0')
        expect(transformed[:tax_description]).to eq('Standard (21%)')
        expect(transformed[:standard_tax]).to be true
        expect(transformed[:reduced_tax]).to be false
        expect(transformed[:super_reduced_tax]).to be false
        expect(transformed[:tax_exempt]).to be false
      end
    end
  end
end