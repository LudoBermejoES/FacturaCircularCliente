require "test_helper"

class Api::V1::InvoiceNumberingControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
    
    # Stub required services to prevent actual API calls
    CompanyService.stubs(:all).returns([])
    InvoiceService.stubs(:recent).returns([])
  end

  test "next_available returns success with valid parameters" do
    mock_api_response = {
      data: {
        type: "next_available_numbers",
        attributes: {
          company_id: 1999,
          year: 2025,
          series_type: "commercial",
          available_numbers: {
            "FC" => [
              {
                series_id: 874,
                series_code: "FC",
                sequence_number: 2,
                full_number: "FC-2025-0002",
                preview: true
              }
            ]
          }
        }
      }
    }

    # Stub the HTTP request to the backend API
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
      .with(
        query: { series_type: "commercial", year: 2025 },
        headers: {
          'Authorization' => 'Bearer test_admin_token',
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: mock_api_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get "/api/v1/invoice_numbering/next_available", 
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :success
    
    response_data = JSON.parse(response.body)
    
    assert_equal "next_available_numbers", response_data["data"]["type"]
    # Compare with string keys since JSON parsing returns strings
    expected_attributes = mock_api_response[:data][:attributes].deep_stringify_keys
    assert_equal expected_attributes, response_data["data"]["attributes"]
  end

  test "next_available uses default parameters when not provided" do
    current_year = Date.current.year
    
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
      .with(
        query: { series_type: "commercial", year: current_year },
        headers: { 'Authorization' => 'Bearer test_admin_token' }
      )
      .to_return(
        status: 200,
        body: { data: { attributes: {} } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get "/api/v1/invoice_numbering/next_available",
        headers: { "Accept" => "application/json" }

    assert_response :success
  end

  test "next_available handles API service errors" do
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
      .with(
        query: { series_type: "commercial", year: 2025 },
        headers: { 'Authorization' => 'Bearer test_admin_token' }
      )
      .to_return(status: 422, body: "Backend API error")

    get "/api/v1/invoice_numbering/next_available",
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :unprocessable_content
    
    response_data = JSON.parse(response.body)
    
    assert_equal "API Error", response_data["errors"][0]["title"]
    assert_equal "422", response_data["errors"][0]["status"]
  end

  test "next_available handles unexpected errors" do
    # Stub the InvoiceNumberingService to raise an exception instead of HTTP stubbing
    InvoiceNumberingService.stubs(:next_available)
      .raises(StandardError.new("Network error"))

    get "/api/v1/invoice_numbering/next_available",
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :internal_server_error
    
    response_data = JSON.parse(response.body)
    
    assert_equal "Internal Server Error", response_data["errors"][0]["title"]
    assert_equal "Unable to fetch next available numbers", response_data["errors"][0]["detail"]
    assert_equal "500", response_data["errors"][0]["status"]
  end

  test "next_available requires authentication" do
    # Stub the authenticate_api_user! method to simulate unauthenticated request
    Api::V1::InvoiceNumberingController.any_instance.stubs(:logged_in?).returns(false)
    
    get "/api/v1/invoice_numbering/next_available",
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    
    response_data = JSON.parse(response.body)
    assert_equal "Authentication Required", response_data["errors"][0]["title"]
    assert_equal "401", response_data["errors"][0]["status"]
  end

  test "next_available handles different series types" do
    %w[commercial proforma credit_note].each do |series_type|
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
        .with(
          query: { series_type: series_type, year: 2025 },
          headers: { 'Authorization' => 'Bearer test_admin_token' }
        )
        .to_return(
          status: 200,
          body: {
            data: {
              attributes: {
                series_type: series_type,
                available_numbers: {}
              }
            }
          }.to_json
        )

      get "/api/v1/invoice_numbering/next_available",
          params: { year: 2025, series_type: series_type },
          headers: { "Accept" => "application/json" }

      assert_response :success
      
      response_data = JSON.parse(response.body)
      assert_equal series_type, response_data["data"]["attributes"]["series_type"]
    end
  end

  test "next_available handles different years" do
    [2024, 2025, 2026].each do |year|
      stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
        .with(
          query: { series_type: "commercial", year: year },
          headers: { 'Authorization' => 'Bearer test_admin_token' }
        )
        .to_return(
          status: 200,
          body: {
            data: {
              attributes: {
                year: year,
                available_numbers: {}
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

  test "next_available returns empty response when no numbers available" do
    stub_request(:get, "http://albaranes-api:3000/api/v1/invoice_numbering/next_available")
      .with(
        query: { series_type: "commercial", year: 2025 },
        headers: { 'Authorization' => 'Bearer test_admin_token' }
      )
      .to_return(
        status: 200,
        body: { data: { attributes: {} } }.to_json
      )

    get "/api/v1/invoice_numbering/next_available",
        params: { year: 2025, series_type: "commercial" },
        headers: { "Accept" => "application/json" }

    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal({}, response_data["data"]["attributes"])
  end
end