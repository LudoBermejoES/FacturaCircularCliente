module ApiHelper
  def stub_api_request(method, endpoint, response_body, status = 200)
    stub_request(method, "#{ENV.fetch('API_BASE_URL', 'http://localhost:3001/api/v1')}#{endpoint}")
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_api_request_with_query(method, endpoint, query, response_body, status = 200)
    stub_request(method, "#{ENV.fetch('API_BASE_URL', 'http://localhost:3001/api/v1')}#{endpoint}")
      .with(query: query)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_authenticated_request(method, endpoint, token, response_body, status = 200)
    stub_request(method, "#{ENV.fetch('API_BASE_URL', 'http://localhost:3001/api/v1')}#{endpoint}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_successful_login
    stub_api_request(:post, '/auth/login', {
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      user: { 
        id: 1, 
        email: 'test@example.com', 
        name: 'Test User' 
      }
    })
  end
  
  def stub_failed_login
    stub_api_request(:post, '/auth/login', 
      { error: 'Invalid credentials' }, 
      401
    )
  end
  
  def stub_token_refresh
    stub_api_request(:post, '/auth/refresh', {
      access_token: 'new_access_token',
      refresh_token: 'new_refresh_token'
    })
  end
  
  def stub_companies_list(companies = nil)
    companies ||= [
      { id: 1, name: 'Company A', tax_id: 'A12345678', email: 'a@company.com' },
      { id: 2, name: 'Company B', tax_id: 'B87654321', email: 'b@company.com' }
    ]
    
    stub_api_request(:get, '/companies', {
      companies: companies,
      total: companies.length,
      page: 1,
      per_page: 10
    })
  end
  
  def stub_invoices_list(invoices = nil)
    invoices ||= [
      { 
        id: 1, 
        invoice_number: 'INV-001', 
        status: 'draft',
        total: 1210.00,
        date: Date.current.to_s,
        company: { id: 1, name: 'Company A' }
      }
    ]
    
    stub_api_request(:get, '/invoices', {
      invoices: invoices,
      statistics: {
        total_count: invoices.length,
        total_amount: invoices.sum { |i| i[:total] },
        status_counts: invoices.group_by { |i| i[:status] }.transform_values(&:count)
      },
      total: invoices.length,
      page: 1
    })
  end
end

RSpec.configure do |config|
  config.include ApiHelper
end