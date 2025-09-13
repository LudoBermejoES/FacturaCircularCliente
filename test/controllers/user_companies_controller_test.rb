require "test_helper"

class UserCompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner_session = {
      access_token: "owner_token",
      user_id: 1,
      user_email: "owner@example.com",
      user_name: "Owner User",
      company_id: 1,
      companies: [
        { "id" => 1, "name" => "Test Company", "role" => "owner" }
      ]
    }
    
    @manager_session = {
      access_token: "manager_token",
      user_id: 2,
      user_email: "manager@example.com",
      user_name: "Manager User",
      company_id: 1,
      companies: [
        { "id" => 1, "name" => "Test Company", "role" => "manager" }
      ]
    }
    
    @viewer_session = {
      access_token: "viewer_token",
      user_id: 3,
      user_email: "viewer@example.com",
      user_name: "Viewer User",
      company_id: 1,
      companies: [
        { "id" => 1, "name" => "Test Company", "role" => "viewer" }
      ]
    }
  end

  test "owner should access user management" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    UserCompanyService.stubs(:list_users).returns(mock_users_list)
    
    get company_users_url(1)
    assert_response :success
    assert_select "h1", text: /Company Users/
    assert_select "a", text: /Invite User/
  end

  test "manager should access user management" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    UserCompanyService.stubs(:list_users).returns(mock_users_list)
    
    get company_users_url(1)
    assert_response :success
    assert_select "h1", text: /Company Users/
  end

  test "viewer should not access user management" do
    setup_authenticated_session(role: "viewer", company_id: 1)
    
    get company_users_url(1)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_equal "You do not have permission to manage users.", flash[:alert]
  end

  test "should show user invitation form for authorized users" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    get new_company_user_url(1)
    assert_response :success
    assert_select "h2", text: /Invite User to Test Company/
    assert_select "input[type=email]"
    assert_select "select#role"
  end

  test "should invite new user to company" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    UserCompanyService.stubs(:invite_user).returns({ success: true })
    
    post company_users_url(1), params: {
      email: "newuser@example.com",
      role: "viewer"
    }
    
    assert_redirected_to company_users_path(1)
    follow_redirect!
    assert_equal "User newuser@example.com has been invited to Test Company.", flash[:notice]
  end

  test "should handle invitation errors" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    error = ApiService::ValidationError.new("Validation failed", { email: ["already exists"] })
    UserCompanyService.stubs(:invite_user).raises(error)
    
    post company_users_url(1), params: {
      email: "existing@example.com",
      role: "viewer"
    }
    
    assert_response :unprocessable_entity
    assert_equal "There were errors inviting the user.", flash.now[:alert]
  end

  test "should show edit role form" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    UserCompanyService.stubs(:list_users).returns(mock_users_list)
    
    get edit_company_user_url(1, 2)
    assert_response :success
    assert_select "h2", text: /Edit User Role/
    assert_select "select#role"
  end

  test "should update user role" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    UserCompanyService.stubs(:list_users).returns(mock_users_list)
    UserCompanyService.stubs(:update_user_role).returns({ success: true })
    
    patch company_user_url(1, 2), params: { role: "manager" }
    
    assert_redirected_to company_users_path(1)
    follow_redirect!
    assert_equal "User role has been updated.", flash[:notice]
  end

  test "should remove user from company" do
    setup_authenticated_session(role: "owner", company_id: 1)
    
    UserCompanyService.stubs(:list_users).returns(mock_users_list)
    UserCompanyService.stubs(:remove_user).returns({ success: true })
    
    delete company_user_url(1, 2)
    
    assert_redirected_to company_users_path(1)
    follow_redirect!
    assert_equal "User has been removed from Test Company.", flash[:notice]
  end

  test "should redirect if no company selected" do
    # Setup authenticated session without company_id
    AuthService.stubs(:login).returns({
      access_token: "test_token",
      refresh_token: "refresh_token",
      user: { id: 1, email: "test@example.com", name: "Test User" },
      company_id: nil,
      companies: []
    })
    AuthService.stubs(:validate_token).returns({ valid: true })
    
    post login_url, params: { email: "test@example.com", password: "password" }
    
    get company_users_url(1)
    assert_redirected_to select_company_path
    follow_redirect!
    assert_equal "No companies found for your account", flash[:alert]
  end

  test "manager cannot assign owner role" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    get new_company_user_url(1)
    assert_response :success
    # Check that owner role is not in the available roles
    assert_select "select#role option[value=owner]", count: 0
  end

  test "admin cannot remove owner" do
    setup_authenticated_session(role: "admin", company_id: 1)
    
    UserCompanyService.stubs(:list_users).returns(mock_users_list)
    
    get company_users_url(1)
    assert_response :success
    # Should not show remove button for owner (user id 1)
    assert_select "form[action='/companies/1/users/1'][method=post]", count: 0
  end

  private

  def mock_users_list
    [
      { id: 1, name: "Owner User", email: "owner@example.com", role: "owner", is_active: true, created_at: 1.month.ago },
      { id: 2, name: "Manager User", email: "manager@example.com", role: "manager", is_active: true, created_at: 2.months.ago },
      { id: 3, name: "Viewer User", email: "viewer@example.com", role: "viewer", is_active: true, created_at: 3.months.ago }
    ]
  end
end