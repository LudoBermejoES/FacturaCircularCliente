module ApiStubs
  # Base URL for API requests
  API_BASE_URL = "http://albaranes-api:3000/api/v1".freeze

  # Authentication stubs - core authentication endpoints
  def stub_authentication(token: "test_token", valid: true)
    # Stub token validation endpoint
    stub_request(:get, "#{API_BASE_URL}/auth/validate_token")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200, 
        body: { valid: valid }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Stub login endpoint
    stub_request(:post, "#{API_BASE_URL}/auth/login")
      .to_return(
        status: 200, 
        body: { 
          access_token: token,
          refresh_token: "refresh_token",
          user: {
            id: 1,
            email: "test@example.com",
            name: "Test User"
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Company-related API stubs
  def stub_companies_api(token: "test_token")
    mock_companies_response = {
      companies: [
        { id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." },
        { id: 2000, name: "TestCorp", legal_name: "TestCorp Industries Ltd." }
      ]
    }
    
    # Stub companies listing
    stub_request(:get, %r{#{API_BASE_URL}/companies})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200, 
        body: mock_companies_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Stub individual company lookup
    stub_request(:get, %r{#{API_BASE_URL}/companies/\d+})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: { id: 1999, name: "TechSol", legal_name: "TechSol Solutions S.L." }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Company contacts API stubs
  def stub_company_contacts_api(token: "test_token")
    mock_contacts_response = {
      contacts: [
        {
          id: 1,
          name: "John Smith",
          email: "john@techsol.com",
          phone: "+34 123 456 789",
          is_active: true
        }
      ]
    }
    
    stub_request(:get, %r{#{API_BASE_URL}/companies/.*/contacts})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_contacts_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Invoice-related API stubs
  def stub_invoices_api(token: "test_token")
    mock_invoices_response = {
      invoices: [
        {
          id: 1,
          invoice_number: "FC-2025-0001",
          status: "draft",
          total_invoice: "1210.00",
          currency_code: "EUR",
          issue_date: "2025-01-15"
        }
      ],
      meta: { total: 1, page: 1, pages: 1 }
    }
    
    # Stub invoices listing
    stub_request(:get, %r{#{API_BASE_URL}/invoices})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_invoices_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Stub invoice creation
    stub_request(:post, "#{API_BASE_URL}/invoices")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 201,
        body: { 
          data: { 
            id: 123, 
            type: "invoice",
            attributes: {
              invoice_number: "FC-2025-0002",
              status: "draft"
            }
          } 
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Stub individual invoice lookup
    stub_request(:get, %r{#{API_BASE_URL}/invoices/\d+})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          data: {
            id: "123",
            type: "invoice",
            attributes: {
              invoice_number: "FC-2025-0001",
              status: "draft",
              issue_date: "2025-01-15",
              due_date: "2025-02-15"
            }
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Invoice series API stubs
  def stub_invoice_series_api(token: "test_token")
    mock_series_response = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      },
      {
        id: 875,
        series_code: "PF", 
        series_name: "Proformas",
        year: 2025,
        is_active: true
      }
    ]
    
    stub_request(:get, %r{#{API_BASE_URL}/invoice_series})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_series_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Invoice numbering API stubs
  def stub_invoice_numbering_api(token: "test_token")
    mock_numbering_response = {
      data: {
        type: "next_available_numbers",
        attributes: {
          year: 2025,
          available_numbers: {
            "FC" => [{ series_code: "FC", sequence_number: 2, full_number: "FC-2025-0002" }]
          }
        }
      }
    }
    
    stub_request(:get, "#{API_BASE_URL}/invoice_numbering/next_available")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_numbering_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Tax-related API stubs
  def stub_tax_api(token: "test_token")
    mock_tax_rates = [
      { id: 1, name: "IVA General", rate: 21.0, country: "ESP" },
      { id: 2, name: "IVA Reducido", rate: 10.0, country: "ESP" }
    ]
    
    stub_request(:get, %r{#{API_BASE_URL}/tax_rates})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_tax_rates.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # User company relationships
  def stub_user_company_api(token: "test_token")
    mock_user_companies = [
      { id: 1999, name: "TechSol", role: "admin" }
    ]
    
    stub_request(:get, %r{#{API_BASE_URL}/user_companies})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_user_companies.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Workflow-related API stubs
  def stub_workflow_api(token: "test_token")
    mock_transitions = [
      { from: "draft", to: "pending_review", label: "Submit for Review" },
      { from: "pending_review", to: "approved", label: "Approve" }
    ]
    
    stub_request(:get, %r{#{API_BASE_URL}/invoices/\d+/available_transitions})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: mock_transitions.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Stub workflow history
    stub_request(:get, %r{#{API_BASE_URL}/invoices/\d+/workflow_history})
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Comprehensive stub setup - use this for full API coverage
  def stub_all_apis(token: "test_token")
    stub_authentication(token: token)
    stub_companies_api(token: token)
    stub_company_contacts_api(token: token)
    stub_invoices_api(token: token)
    stub_invoice_series_api(token: token)
    stub_invoice_numbering_api(token: token)
    stub_tax_api(token: token)
    stub_user_company_api(token: token)
    stub_workflow_api(token: token)
  end

  # Stub API error responses
  def stub_api_error(endpoint, status: 422, error_message: "API Error")
    stub_request(:any, %r{#{API_BASE_URL}#{endpoint}})
      .to_return(
        status: status,
        body: {
          errors: [{
            status: status.to_s,
            title: error_message,
            detail: "Error details"
          }]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub authentication failure
  def stub_authentication_failure
    stub_request(:get, "#{API_BASE_URL}/auth/validate_token")
      .to_return(
        status: 401,
        body: { error: "Authentication failed" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end

# Include the module in RSpec
RSpec.configure do |config|
  config.include ApiStubs
end