require 'rails_helper'

RSpec.describe InvoiceService do
  let(:token) { 'test_access_token' }
  
  describe '.all' do
    context 'with JSON API format response' do
      let(:json_api_response) do
        {
          data: [
            {
              id: "1",
              type: "invoices",
              attributes: {
                invoice_number: "FC-2025-0001",
                invoice_series_code: "FC",
                status: "draft",
                issue_date: "2025-09-15",
                due_date: "2025-10-15",
                total_invoice: "1210.00",
                currency_code: "EUR",
                language_code: "es",
                is_frozen: false,
                display_number: "FC-FC-2025-0001",
                is_proforma: false,
                can_be_modified: true,
                can_be_converted: false,
                created_at: "2025-09-15T10:00:00.000Z",
                updated_at: "2025-09-15T10:00:00.000Z"
              }
            },
            {
              id: "2", 
              type: "invoices",
              attributes: {
                invoice_number: "FC-2025-0002",
                invoice_series_code: "FC", 
                status: "sent",
                issue_date: "2025-09-15",
                due_date: "2025-10-15",
                total_invoice: "550.00",
                currency_code: "EUR",
                language_code: "es",
                is_frozen: false,
                display_number: "FC-FC-2025-0002",
                is_proforma: false,
                can_be_modified: true,
                can_be_converted: false,
                created_at: "2025-09-15T10:00:00.000Z",
                updated_at: "2025-09-15T10:00:00.000Z"
              }
            }
          ],
          meta: {
            total: 2,
            page: 1,
            pages: 1,
            per_page: 25
          }
        }
      end
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: json_api_response.to_json)
      end
      
      it 'transforms JSON API format to expected client format' do
        result = described_class.all(token: token)
        
        expect(result[:invoices]).to be_an(Array)
        expect(result[:invoices].length).to eq(2)
        expect(result[:meta]).to eq(json_api_response[:meta])
        expect(result[:total]).to eq(2)
        
        # Check transformation of first invoice
        first_invoice = result[:invoices].first
        expect(first_invoice[:id]).to eq("1")
        expect(first_invoice[:invoice_number]).to eq("FC-2025-0001")
        expect(first_invoice[:status]).to eq("draft")
        expect(first_invoice[:date]).to eq("2025-09-15") # mapped from issue_date
        expect(first_invoice[:due_date]).to eq("2025-10-15")
        expect(first_invoice[:total_invoice]).to eq("1210.00")
        expect(first_invoice[:is_frozen]).to eq(false)
        expect(first_invoice[:display_number]).to eq("FC-FC-2025-0001")
      end
    end

    context 'without filters' do
      let(:response_body) do
        {
          invoices: [
            { id: 1, invoice_number: 'INV-001', status: 'draft', total: 1210.00 },
            { id: 2, invoice_number: 'INV-002', status: 'sent', total: 550.00 }
          ],
          statistics: {
            total_count: 2,
            total_amount: 1760.00,
            status_counts: { draft: 1, sent: 1 }
          },
          total: 2,
          page: 1
        }
      end
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: response_body.to_json)
      end
      
      it 'returns response as-is when not in JSON API format' do
        result = described_class.all(token: token)
        expect(result).to eq(response_body.deep_symbolize_keys)
      end
    end
    
    context 'with filters' do
      let(:filters) { { status: 'draft', company_id: 1, page: 2 } }
      
      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(
            query: filters,
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: { invoices: [], total: 0 }.to_json)
      end
      
      it 'passes filters as query parameters' do
        described_class.all(token: token, filters: filters)
        expect(WebMock).to have_requested(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(query: filters)
      end
    end
  end
  
  describe '.find' do
    let(:invoice_id) { 1 }
    let(:response_body) do
      {
        id: 1,
        invoice_number: 'INV-001',
        status: 'draft',
        total: 1210.00,
        company: { id: 1, name: 'Test Company' },
        invoice_lines: [
          { description: 'Service', quantity: 10, unit_price: 100, tax_rate: 21 }
        ]
      }
    end
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}?include=invoice_lines,invoice_taxes")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: response_body.to_json)
    end
    
    it 'returns invoice details' do
      result = described_class.find(invoice_id, token: token)
      expect(result).to eq(response_body.deep_symbolize_keys)
    end
  end
  
  describe '.create' do
    let(:invoice_params) do
      {
        seller_party_id: 1,
        buyer_party_id: 2,
        invoice_type: 'standard',
        date: Date.current.to_s,
        due_date: 30.days.from_now.to_s,
        invoice_lines_attributes: [
          { description: 'Service', quantity: 10, unit_price: 100, tax_rate: 21 }
        ]
      }
    end
    
    let(:response_body) do
      {
        id: 1,
        invoice_number: 'FC-2025-0001',
        status: 'draft',
        total: 1210.00
      }
    end
    
    before do
      # Expected JSON API format - invoice_lines_attributes are now extracted and sent separately
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            invoice_type: 'standard',
            date: Date.current.to_s,
            due_date: 30.days.from_now.to_s
          },
          relationships: {
            seller_party: {
              data: { type: 'companies', id: '1' }
            },
            buyer_party: {
              data: { type: 'companies', id: '2' }
            }
          }
        }
      }
      
      # Mock the invoice creation (backend handles line items automatically)
      stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
        .to_return(status: 201, body: { data: { id: '1' } }.to_json)
    end
    
    it 'creates invoice with line items' do
      result = described_class.create(invoice_params, token: token)
      expect(result[:data][:id]).to eq('1')
    end

    context 'with company contact as buyer' do
      let(:contact_invoice_params) do
        {
          seller_party_id: 1,
          buyer_company_contact_id: 8,
          invoice_type: 'proforma',
          date: Date.current.to_s,
          due_date: 30.days.from_now.to_s,
          invoice_lines_attributes: [
            { description: 'Service', quantity: 1, unit_price: 100, tax_rate: 21 }
          ]
        }
      end

      before do
        # Expected JSON API format with buyer_company_contact relationship
        expected_body = {
          data: {
            type: 'invoices',
            attributes: {
              invoice_type: 'proforma',
              date: Date.current.to_s,
              due_date: 30.days.from_now.to_s
            },
            relationships: {
              seller_party: {
                data: { type: 'companies', id: '1' }
              },
              buyer_company_contact: {
                data: { type: 'company_contacts', id: '8' }
              }
            }
          }
        }

        # Mock the initial invoice creation (without line items)
        stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
          .to_return(status: 201, body: { data: { id: '2' } }.to_json)

      end

      it 'creates invoice with company contact relationship' do
        result = described_class.create(contact_invoice_params, token: token)
        expect(result[:data][:id]).to eq('2')

        # Verify the correct API call was made with buyer_company_contact relationship
        expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/invoices')
          .with { |req|
            body = JSON.parse(req.body)
            expect(body['data']['relationships']['buyer_company_contact']['data']['type']).to eq('company_contacts')
            expect(body['data']['relationships']['buyer_company_contact']['data']['id']).to eq('8')
            expect(body['data']['relationships']).not_to have_key('buyer_party')
          }
      end
    end
  end
  
  describe '.update' do
    let(:invoice_id) { 1 }
    let(:update_params) { { status: 'sent' } }
    
    before do
      # Expected JSON API format
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            status: 'sent'
          }
        }
      }
      
      stub_request(:put, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}")
        .with(
          body: expected_body.to_json,
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 200, body: { id: invoice_id, status: 'sent' }.to_json)
    end
    
    it 'updates invoice' do
      result = described_class.update(invoice_id, update_params, token: token)
      expect(result).to eq({ id: invoice_id, status: 'sent' })
    end
  end
  
  describe '.delete' do
    let(:invoice_id) { 1 }
    
    before do
      stub_request(:delete, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 204, body: '')
    end
    
    it 'deletes invoice' do
      result = described_class.delete(invoice_id, token: token)
      expect(result).to be_nil
    end
  end
  
  describe '.freeze' do
    let(:invoice_id) { 1 }
    
    before do
      stub_request(:post, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/freeze")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: { frozen: true, message: 'Invoice frozen' }.to_json)
    end
    
    it 'freezes the invoice' do
      result = described_class.freeze(invoice_id, token: token)
      expect(result).to eq({ frozen: true, message: 'Invoice frozen' })
    end
  end
  
  describe '.update_status' do
    let(:invoice_id) { 1 }
    let(:status) { 'approved' }
    let(:comment) { 'Looks good' }
    
    before do
      # Expected JSON API format
      expected_body = {
        data: {
          type: 'invoices',
          attributes: {
            status: status,
            comment: comment
          }
        }
      }
      
      stub_request(:patch, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/status")
        .with(
          headers: { 'Authorization' => "Bearer #{token}" },
          body: expected_body.to_json
        )
        .to_return(status: 200, body: { id: invoice_id, status: status }.to_json)
    end
    
    it 'updates invoice status with comment' do
      result = described_class.update_status(invoice_id, status, comment: comment, token: token)
      expect(result[:status]).to eq(status)
    end
  end
  
  describe '.download_facturae' do
    let(:invoice_id) { 1 }
    let(:xml_content) { '<?xml version="1.0"?><Facturae></Facturae>' }
    
    before do
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/facturae")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(status: 200, body: xml_content, headers: { 'Content-Type' => 'application/xml' })
    end
    
    it 'returns Facturae XML content' do
      result = described_class.download_facturae(invoice_id, token: token)
      expect(result).to eq(xml_content)
    end
  end

  describe 'line items management' do
    let(:invoice_id) { 1 }

    describe '.add_line_item' do
      let(:line_params) do
        {
          description: 'New Service',
          quantity: 5,
          unit_price: 100.0,
          tax_rate: 21
        }
      end

      before do
        # Updated to use JSON API format
        expected_body = {
          data: {
            type: 'invoice_lines',
            attributes: line_params
          }
        }
        
        stub_request(:post, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/lines")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: expected_body.to_json
          )
          .to_return(status: 201, body: { id: 10 }.to_json)
      end

      it 'creates new line item' do
        result = described_class.add_line_item(invoice_id, line_params, token: token)
        expect(result[:id]).to eq(10)
      end
    end

    describe '.update_line_item' do
      let(:line_id) { 5 }
      let(:update_params) { { quantity: 10 } }

      before do
        stub_request(:put, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/lines/#{line_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: { invoice_line: update_params }.to_json
          )
          .to_return(status: 200, body: { id: line_id, quantity: 10 }.to_json)
      end

      it 'updates line item' do
        result = described_class.update_line_item(invoice_id, line_id, update_params, token: token)
        expect(result[:quantity]).to eq(10)
      end
    end

    describe '.remove_line_item' do
      let(:line_id) { 5 }

      before do
        stub_request(:delete, "http://albaranes-api:3000/api/v1/invoices/#{invoice_id}/lines/#{line_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '')
      end

      it 'removes line item' do
        result = described_class.remove_line_item(invoice_id, line_id, token: token)
        expect(result).to be_nil
      end
    end
  end

  describe '.recent' do
    let(:recent_response) do
      {
        invoices: [
          { id: 1, invoice_number: 'INV-001', status: 'sent' },
          { id: 2, invoice_number: 'INV-002', status: 'draft' }
        ]
      }
    end

    context 'when successful' do
      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices")
          .with(query: { limit: 5, status: 'recent' })
          .to_return(status: 200, body: recent_response.to_json)
      end

      it 'returns recent invoices array' do
        result = described_class.recent(token: token)
        expect(result).to eq(recent_response[:invoices])
      end
    end

    context 'when response is nil' do
      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices")
          .with(
            query: { limit: 5, status: 'recent' },
            headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' }
          )
          .to_return(status: 204, body: '')
      end

      it 'returns empty array' do
        result = described_class.recent(token: token)
        expect(result).to eq([])
      end
    end
  end

  describe 'workflow functionality' do
    let(:token) { 'test_access_token' }

    describe '.find with workflow_definition_id' do
      let(:invoice_with_workflow_response) do
        {
          data: {
            id: "123",
            type: "invoices",
            attributes: {
              invoice_number: "FC-2025-0001",
              invoice_series_id: 72,
              status: "draft",
              issue_date: "2025-09-15",
              workflow_definition_id: 2,
              total_invoice: "1210.00",
              currency_code: "EUR",
              created_at: "2025-09-15T10:00:00.000Z",
              updated_at: "2025-09-15T10:00:00.000Z"
            }
          },
          included: [
            {
              id: "1",
              type: "invoice_lines",
              attributes: {
                line_number: 1,
                item_description: "Test Service",
                quantity: 1.0,
                unit_price_without_tax: 100.0,
                gross_amount: 100.0,
                article_code: "SRV001"
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/123?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: invoice_with_workflow_response.to_json)
      end

      it 'transforms response including workflow_definition_id' do
        result = described_class.find(123, token: token)

        expect(result[:id]).to eq("123")
        expect(result[:workflow_definition_id]).to eq(2)
        expect(result[:invoice_series_id]).to eq(72)
        expect(result[:status]).to eq("draft")
        expect(result[:invoice_lines]).to be_an(Array)
        expect(result[:invoice_lines].first[:product_code]).to eq("SRV001")
      end
    end

    describe '.find with workflow fallback' do
      let(:invoice_without_workflow_response) do
        {
          data: {
            id: "124",
            type: "invoices",
            attributes: {
              invoice_number: "PF-2025-0001",
              invoice_series_id: nil,
              status: "draft",
              issue_date: "2025-09-15",
              workflow_definition_id: nil,
              total_invoice: "550.00",
              currency_code: "EUR"
            }
          }
        }
      end

      before do
        stub_request(:get, "http://albaranes-api:3000/api/v1/invoices/124?include=invoice_lines,invoice_taxes")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: invoice_without_workflow_response.to_json)
      end

      it 'handles nil workflow_definition_id gracefully' do
        result = described_class.find(124, token: token)

        expect(result[:id]).to eq("124")
        expect(result[:workflow_definition_id]).to be_nil
        # Note: invoice_series_id will be inferred from the invoice number
      end

      it 'infers series from invoice number when invoice_series_id is nil' do
        result = described_class.find(124, token: token)

        # The service should infer series ID based on invoice number prefix
        expect(result[:invoice_series_id]).to eq("74") # PF series
      end
    end

    describe '.create with workflow_definition_id' do
      let(:create_params_with_workflow) do
        {
          issue_date: '2025-09-15',
          workflow_definition_id: 2,
          currency_code: 'EUR',
          seller_party_id: 1,
          buyer_party_id: 2,
          invoice_lines_attributes: [
            {
              item_description: 'Test Service',
              quantity: 1.0,
              unit_price_without_tax: 100.0
            }
          ]
        }
      end

      let(:expected_api_params) do
        {
          data: {
            type: 'invoices',
            attributes: {
              issue_date: '2025-09-15',
              workflow_definition_id: 2,
              currency_code: 'EUR',
              invoice_lines_attributes: [
                {
                  item_description: 'Test Service',
                  quantity: 1.0,
                  unit_price_without_tax: 100.0
                }
              ]
            },
            relationships: {
              seller_party: {
                data: { type: 'companies', id: '1' }
              },
              buyer_party: {
                data: { type: 'companies', id: '2' }
              }
            }
          }
        }
      end

      before do
        stub_request(:post, 'http://albaranes-api:3000/api/v1/invoices')
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: expected_api_params.to_json
          )
          .to_return(status: 201, body: { success: true }.to_json)
      end

      it 'includes workflow_definition_id in API request' do
        result = described_class.create(create_params_with_workflow, token: token)
        expect(result[:success]).to eq(true)

        # Verify the request was made with correct parameters
        expect(WebMock).to have_requested(:post, 'http://albaranes-api:3000/api/v1/invoices')
          .with(body: expected_api_params.to_json)
      end
    end

    describe '.update with workflow_definition_id' do
      let(:update_params_with_workflow) do
        {
          workflow_definition_id: 3,
          notes: 'Updated with new workflow'
        }
      end

      let(:expected_update_params) do
        {
          data: {
            type: 'invoices',
            attributes: {
              workflow_definition_id: 3,
              notes: 'Updated with new workflow'
            }
          }
        }
      end

      before do
        stub_request(:put, 'http://albaranes-api:3000/api/v1/invoices/123')
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            body: expected_update_params.to_json
          )
          .to_return(status: 200, body: { success: true }.to_json)
      end

      it 'includes workflow_definition_id in update request' do
        result = described_class.update(123, update_params_with_workflow, token: token)
        expect(result[:success]).to eq(true)

        # Verify the request was made with correct parameters
        expect(WebMock).to have_requested(:put, 'http://albaranes-api:3000/api/v1/invoices/123')
          .with(body: expected_update_params.to_json)
      end
    end

    describe 'workflow data transformation' do
      let(:complex_workflow_response) do
        {
          data: [
            {
              id: "1",
              type: "invoices",
              attributes: {
                invoice_number: "FC-2025-0001",
                invoice_series_id: 72,
                status: "draft",
                workflow_definition_id: 1,
                total_invoice: "1210.00"
              }
            },
            {
              id: "2",
              type: "invoices",
              attributes: {
                invoice_number: "FC-2025-0002",
                invoice_series_id: 72,
                status: "approved",
                workflow_definition_id: 2,
                total_invoice: "550.00"
              }
            }
          ],
          meta: {
            total: 2,
            page: 1,
            per_page: 25
          }
        }
      end

      before do
        stub_request(:get, 'http://albaranes-api:3000/api/v1/invoices')
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: complex_workflow_response.to_json)
      end

      it 'correctly transforms workflow_definition_id for all invoices' do
        result = described_class.all(token: token)

        expect(result[:invoices]).to be_an(Array)
        expect(result[:invoices].length).to eq(2)

        first_invoice = result[:invoices].first
        expect(first_invoice[:workflow_definition_id]).to eq(1)
        expect(first_invoice[:status]).to eq("draft")

        second_invoice = result[:invoices].second
        expect(second_invoice[:workflow_definition_id]).to eq(2)
        expect(second_invoice[:status]).to eq("approved")
      end

      it 'maintains other transformed fields alongside workflow data' do
        result = described_class.all(token: token)

        first_invoice = result[:invoices].first
        expect(first_invoice[:id]).to eq("1")
        expect(first_invoice[:invoice_series_id]).to eq(72)
        expect(first_invoice[:total]).to eq(1210.0) # Converted to float
        expect(first_invoice[:workflow_definition_id]).to eq(1)
      end
    end

    describe 'error handling for workflow operations' do
      context 'when API returns workflow validation error' do
        before do
          stub_request(:put, 'http://albaranes-api:3000/api/v1/invoices/123')
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(
              status: 422,
              body: {
                errors: [
                  {
                    status: "422",
                    title: "Validation Error",
                    detail: "Workflow definition not found or not accessible"
                  }
                ]
              }.to_json
            )
        end

        it 'handles workflow validation errors gracefully' do
          expect {
            described_class.update(123, { workflow_definition_id: 999 }, token: token)
          }.to raise_error(ApiService::ValidationError)
        end
      end

      context 'when API returns frozen invoice error for workflow change' do
        before do
          stub_request(:put, 'http://albaranes-api:3000/api/v1/invoices/123')
            .with(headers: { 'Authorization' => "Bearer #{token}" })
            .to_return(
              status: 403,
              body: {
                errors: [
                  {
                    status: "403",
                    title: "Forbidden",
                    detail: "Cannot modify workflow of frozen invoice"
                  }
                ]
              }.to_json
            )
        end

        it 'handles frozen invoice errors for workflow changes' do
          expect {
            described_class.update(123, { workflow_definition_id: 2 }, token: token)
          }.to raise_error(ApiService::ApiError)
        end
      end
    end
  end
end