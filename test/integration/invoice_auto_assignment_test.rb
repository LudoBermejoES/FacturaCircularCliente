require "test_helper"

class InvoiceAutoAssignmentTest < ActionDispatch::IntegrationTest
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
    setup_mocked_services
  end

  test "API endpoint responds correctly for AJAX requests" do
    # Stub the backend API call
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
      .with(query: { series_type: "commercial", year: 2025 })
      .to_return(
        status: 200,
        body: {
          data: {
            type: "next_available_numbers",
            attributes: {
              available_numbers: {
                "FC" => [{ series_code: "FC", sequence_number: 2, full_number: "FC-2025-0002" }]
              }
            }
          }
        }.to_json
      )

    get "/api/v1/invoice_numbering/next_available", 
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :success
    
    response_data = JSON.parse(response.body)
    
    assert_equal "next_available_numbers", response_data["data"]["type"]
    assert response_data["data"]["attributes"]["available_numbers"]
    assert response_data["data"]["attributes"]["available_numbers"]["FC"]
    
    fc_series = response_data["data"]["attributes"]["available_numbers"]["FC"]
    assert fc_series.is_a?(Array)
    assert_equal 2, fc_series.first["sequence_number"]
    assert_equal "FC-2025-0002", fc_series.first["full_number"]
  end

  test "complete invoice creation flow with auto-assignment" do
    # Visit new invoice page
    get new_invoice_path
    assert_response :success

    # Verify form structure exists
    assert_select 'select[name="invoice[invoice_series_id]"]'
    assert_select 'input[name="invoice[invoice_number]"][readonly]'

    # Mock successful invoice creation
    mock_created_invoice = {
      id: 123,
      invoice_number: "FC-2025-0002",
      invoice_series_id: 874,
      status: "draft",
      invoice_type: "invoice"
    }

    InvoiceService.stubs(:create)
      .returns(mock_created_invoice)

    # Submit form with series selected
    post invoices_path, params: {
      invoice: {
        invoice_series_id: 874,
        invoice_number: "FC-2025-0002",
        invoice_type: "invoice",
        status: "draft",
        seller_party_id: 1999,
        buyer_party_id: 1999,
        issue_date: "2025-01-15",
        due_date: "2025-02-15"
      }
    }

    assert_redirected_to invoice_path(123)
  end

  test "series selection triggers correct API call parameters" do
    # Test different series types
    series_mappings = {
      "FC" => "commercial",
      "PF" => "proforma", 
      "CR" => "credit_note"
    }

    series_mappings.each do |series_code, expected_type|
      # Stub the backend API for each series type
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
        .with(query: { series_type: expected_type, year: 2025 })
        .to_return(
          status: 200,
          body: {
            data: {
              attributes: {
                available_numbers: {
                  series_code => [{ series_code: series_code, sequence_number: 1 }]
                }
              }
            }
          }.to_json
        )

      get "/api/v1/invoice_numbering/next_available",
          params: { year: 2025, series_type: expected_type },
          headers: { "Accept" => "application/json" }

      assert_response :success
    end
  end

  test "handles API errors gracefully" do
    # Clear existing stubs and set up specific error scenario
    WebMock.reset!
    
    # Mock API error - more specific with headers
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
      .with(
        query: { series_type: "commercial", year: 2025 },
        headers: { 'Authorization' => 'Bearer test_admin_token' }
      )
      .to_return(status: 422, body: { errors: [{ title: "API Error" }] }.to_json)

    get "/api/v1/invoice_numbering/next_available",
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :unprocessable_content
    
    response_data = JSON.parse(response.body)
    assert response_data["errors"]
    assert_equal "API Error", response_data["errors"][0]["title"]
  end

  test "invoice form loads with correct structure" do
    get new_invoice_path

    assert_response :success
    
    # Check that the form contains the series dropdown
    assert_select 'select[name="invoice[invoice_series_id]"]'
    assert_select 'option', text: /FC - Facturas Comerciales/
    
    # Check that the invoice number field is read-only
    assert_select 'input[name="invoice[invoice_number]"][readonly]'
    
    # Check for Stimulus controller data attributes
    assert_select '[data-controller*="invoice-form"]'
    assert_select '[data-invoice-form-target="seriesSelect"]'
    assert_select '[data-invoice-form-target="invoiceNumber"]'
    assert_select '[data-action*="invoice-form#onSeriesChange"]'
  end

  test "different years generate different numbers" do
    [2024, 2025, 2026].each do |year|
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
        .with(query: { series_type: "commercial", year: year })
        .to_return(
          status: 200,
          body: {
            data: {
              attributes: {
                year: year,
                available_numbers: { "FC" => [{ sequence_number: 1, full_number: "FC-#{year}-0001" }] }
              }
            }
          }.to_json
        )

      get "/api/v1/invoice_numbering/next_available",
          params: { year: year, series_type: "commercial" },
          headers: { "Accept" => "application/json" }

      assert_response :success
      
      response_data = JSON.parse(response.body)
      assert_equal year, response_data["data"]["attributes"]["year"]
    end
  end

  private

  def setup_mocked_services
    # Mock InvoiceSeriesService for form dropdown - exact parameters from controller
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      }
    ]
    
    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    # Mock CompanyService - exact parameters from controller
    mock_companies_response = {
      companies: [{ id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." }]
    }
    
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns(mock_companies_response)
    
    CompanyService.stubs(:find).returns({
      id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L."
    })
    
    InvoiceService.stubs(:find).returns({})
    InvoiceService.stubs(:recent).returns([])
    
    # Mock TaxService to prevent tax-related API calls
    TaxService.stubs(:all).returns([])
    TaxService.stubs(:calculate).returns([])
    
    # Mock UserCompanyService to prevent user-related API calls  
    UserCompanyService.stubs(:companies_for_user).returns([])
    
    # Mock WorkflowService to prevent workflow-related API calls
    WorkflowService.stubs(:available_transitions).returns([])
    
    # Stub common authentication and service requests to prevent VCR errors
    stub_request(:get, /albaranes-api.*\/companies/).to_return(status: 200, body: '{"companies": []}')
    stub_request(:get, /albaranes-api.*\/invoice_series/).to_return(status: 200, body: '[]')
    stub_request(:get, /albaranes-api.*\/auth/).to_return(status: 200, body: '{"valid": true}')
    stub_request(:post, /albaranes-api.*\/auth/).to_return(status: 200, body: '{"token": "test_token"}')
  end
end