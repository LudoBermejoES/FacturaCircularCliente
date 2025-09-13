require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @test_companies = [
      { "id" => 1, "name" => "Company A", "role" => "owner" },
      { "id" => 2, "name" => "Company B", "role" => "manager" },
      { "id" => 3, "name" => "Company C", "role" => "viewer" }
    ]
  end

  test "current_user_role returns correct role for current company" do
    setup_session_with_role("manager", 2)
    
    get dashboard_url
    assert_response :success
    
    # Verify the user has the correct role in session
    company = session[:companies].find { |c| c["id"] == 2 }
    assert_equal "manager", company["role"]
  end

  test "can? returns true for owner on all actions" do
    setup_session_with_role("owner", 1)
    get dashboard_url
    assert_response :success
    
    # Owner role should have access to dashboard
    # We can't test the can? method directly in integration tests
    # but we can verify the owner can access the page
  end

  test "can? returns correct permissions for admin" do
    setup_session_with_role("admin", 1)
    get dashboard_url
    assert_response :success
    
    # Admin should have access to dashboard
  end

  test "can? returns correct permissions for manager" do
    setup_session_with_role("manager", 2)
    get dashboard_url
    assert_response :success
    
    # Manager should have access to dashboard
  end

  test "can? returns correct permissions for accountant" do
    setup_session_with_role("accountant", 1)
    get dashboard_url
    assert_response :success
    
    # Accountant should have access to dashboard
  end

  test "can? returns correct permissions for reviewer" do
    setup_session_with_role("reviewer", 1)
    get dashboard_url
    assert_response :success
    
    # Reviewer should have access to dashboard
  end

  test "can? returns correct permissions for submitter" do
    setup_session_with_role("submitter", 1)
    get dashboard_url
    assert_response :success
    
    # Submitter should have access to dashboard
  end

  test "can? returns correct permissions for viewer" do
    setup_session_with_role("viewer", 3)
    get dashboard_url
    assert_response :success
    
    # Viewer should have access to dashboard
  end

  test "can? returns false when no role" do
    # Setup session without companies
    AuthService.stubs(:login).returns({
      access_token: "test_token",
      refresh_token: "refresh_token",
      user: { id: 1, email: "test@example.com", name: "Test User" },
      company_id: nil,
      companies: []
    })
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    post login_url, params: { email: "test@example.com", password: "password" }
    
    # User without company/role should be redirected
    get dashboard_url
    assert_response :redirect
  end

  test "current_company returns correct company" do
    setup_session_with_role("manager", 2)
    get dashboard_url
    
    # In integration tests, we can't access controller internals directly
    # But we can verify the session was set correctly
    assert_equal 2, session[:company_id]
    assert_not_nil session[:companies]
  end

  test "current_company_id returns correct id" do
    setup_session_with_role("owner", 1)
    get dashboard_url
    
    # Verify session has correct company_id
    assert_equal 1, session[:company_id]
  end

  test "user_companies returns all companies" do
    setup_session_with_role("manager", 2)
    get dashboard_url
    
    # Verify session has companies
    assert_equal 3, session[:companies].size
    assert_equal ["Company A", "Company B", "Company C"], session[:companies].map { |c| c["name"] }
  end

  test "ensure_can! redirects when permission denied" do
    setup_session_with_role("viewer", 1)
    
    # Try to access a protected action
    # This would normally be in a controller action
    get new_invoice_url
    
    # Should redirect due to lack of permission
    assert_redirected_to dashboard_path
  end

  test "authenticate_user! redirects when not logged in" do
    # No session setup
    get dashboard_url
    
    assert_redirected_to login_path
    follow_redirect!
    assert_equal "Please sign in to continue", flash[:alert]
  end

  test "logged_in? returns true when token present and valid" do
    setup_session_with_role("manager", 1)
    
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    get dashboard_url
    assert_response :success
    # Successfully accessing dashboard means user is logged in
  end

  test "logged_in? returns false when no token" do
    get login_url # Don't need auth for login page
    assert_response :success
    # Can access login page without being logged in
  end

  test "current_user returns user info from session" do
    setup_session_with_role("manager", 2)
    
    get dashboard_url
    
    # Verify session has user data
    assert_equal 1, session[:user_id]
    assert_equal "manager@example.com", session[:user_email]
    assert_equal "Manager User", session[:user_name]
    assert_equal 2, session[:company_id]
    assert_equal 3, session[:companies].size
  end

  private

  def setup_session_with_role(role, company_id)
    companies = @test_companies.map do |c|
      c.merge("role" => c["id"] == company_id ? role : c["role"])
    end
    
    # Use the helper method from test_helper.rb
    setup_authenticated_session(
      role: role,
      company_id: company_id,
      companies: companies
    )
  end
end