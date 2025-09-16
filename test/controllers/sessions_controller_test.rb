require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @valid_credentials = {
      email: "manager@example.com",
      password: "password123"
    }
    
    @single_company_credentials = {
      email: "user@example.com", 
      password: "password123"
    }
  end

  test "should get login page" do
    get login_url
    assert_response :success
    assert_select "h2", text: /Sign in to FacturaCircular/i
  end

  test "should redirect to dashboard if already logged in" do
    # Mock the API response for single company user
    mock_response = {
      access_token: "test_token",
      refresh_token: "refresh_token",
      user: {
        id: 1,
        email: "user@example.com",
        name: "Test User",
        company_id: 1
      },
      company_id: 1,
      companies: [{ id: 1, name: "Test Company", role: "viewer" }]
    }
    
    AuthService.stubs(:login).returns(mock_response)
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    # Simulate logged in user
    post login_url, params: @single_company_credentials
    
    get login_url
    assert_redirected_to dashboard_path
  end

  test "should login user with single company" do
    # Mock the API response for single company user
    AuthService.stubs(:login).returns(mock_single_company_response)
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    post login_url, params: @single_company_credentials
    
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_equal "Successfully logged in!", flash[:notice]
  end

  test "should redirect to company selector for multi-company user" do
    # Mock the API response for multi-company user
    AuthService.stubs(:login).returns(mock_multi_company_response)
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    post login_url, params: @valid_credentials
    
    assert_redirected_to select_company_path
    follow_redirect!
    assert_select "h2", text: /Select a Company/
  end

  test "should handle invalid credentials" do
    AuthService.stubs(:login).returns(nil)
    
    post login_url, params: { email: "wrong@example.com", password: "wrong" }
    
    assert_response :unprocessable_content
    assert_select ".text-red-800", text: /Invalid email or password/
  end

  test "should logout user" do
    # Login first
    AuthService.stubs(:login).returns(mock_single_company_response)
    AuthService.stubs(:validate_token).returns({ valid: true })
    post login_url, params: @single_company_credentials
    
    AuthService.stubs(:logout).returns({ message: "Logged out" })
    
    delete logout_url
    
    assert_redirected_to login_path
    follow_redirect!
    assert_equal "Successfully logged out!", flash[:notice]
  end

  test "should clear session on logout even if API fails" do
    # Login first
    AuthService.stubs(:login).returns(mock_single_company_response)
    AuthService.stubs(:validate_token).returns({ valid: true })
    post login_url, params: @single_company_credentials
    
    # Simulate API failure during logout
    AuthService.stubs(:logout).raises(ApiService::ApiError.new("Network error"))
    
    delete logout_url
    
    assert_redirected_to login_path
    assert_nil session[:access_token]
    assert_nil session[:user_id]
    assert_nil session[:company_id]
  end

  private

  def mock_single_company_response
    {
      access_token: "test_token_123",
      refresh_token: "refresh_token_123",
      user: {
        id: 1,
        email: "user@example.com",
        name: "Test User",
        company_id: 1
      },
      company_id: 1,
      companies: [
        { id: 1, name: "Test Company", role: "viewer" }
      ]
    }
  end

  def mock_multi_company_response
    {
      access_token: "test_token_456",
      refresh_token: "refresh_token_456",
      user: {
        id: 2,
        email: "manager@example.com",
        name: "Manager User"
      },
      company_id: nil,
      companies: [
        { id: 1, name: "Company A", role: "manager" },
        { id: 2, name: "Company B", role: "owner" },
        { id: 3, name: "Company C", role: "viewer" }
      ]
    }
  end
end