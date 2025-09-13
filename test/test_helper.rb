ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...
  end
end

# Helper methods for authentication in integration tests
class ActionDispatch::IntegrationTest
  def sign_in_as(user_data)
    # Mock the AuthService login to return success
    mock_response = {
      access_token: user_data[:access_token] || "test_token",
      refresh_token: user_data[:refresh_token] || "refresh_token",
      user: {
        id: user_data[:user_id] || 1,
        email: user_data[:user_email] || "test@example.com",
        name: user_data[:user_name] || "Test User",
        company_id: user_data[:company_id]
      },
      company_id: user_data[:company_id],
      companies: user_data[:companies] || []
    }
    
    # Stub the login method using mocha
    AuthService.stubs(:login).returns(mock_response)
    
    # Also stub validate_token to return valid
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    post login_url, params: { email: "test@example.com", password: "password" }
    
    # Follow redirect if needed (for single company users)
    if user_data[:company_id]
      follow_redirect! if response.redirect?
    end
  end
  
  def current_session
    # Access the session in integration tests
    session
  end
  
  def setup_authenticated_session(role: "viewer", company_id: 1, companies: nil)
    companies ||= [
      { "id" => company_id, "name" => "Test Company", "role" => role }
    ]
    
    user_data = {
      access_token: "test_#{role}_token",
      user_id: 1,
      user_email: "#{role}@example.com",
      user_name: "#{role.capitalize} User",
      company_id: company_id,
      companies: companies
    }
    
    # Stub validate_token before signing in
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    # Also stub InvoiceService.recent for dashboard access
    InvoiceService.stubs(:recent).returns([])
    
    sign_in_as(user_data)
    user_data
  end
end
