require "test_helper"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @multi_company_user = {
      access_token: "test_token",
      user_id: 1,
      user_email: "manager@example.com",
      user_name: "Manager User",
      companies: [
        { "id" => 1, "name" => "Company A", "role" => "manager" },
        { "id" => 2, "name" => "Company B", "role" => "owner" }
      ]
    }
    
    @single_company_user = {
      access_token: "test_token",
      user_id: 2,
      user_email: "user@example.com",
      user_name: "Regular User",
      company_id: 1,
      companies: [
        { "id" => 1, "name" => "Company A", "role" => "viewer" }
      ]
    }
  end

  test "should show company selector for multi-company user" do
    setup_authenticated_session(
      role: "manager",
      company_id: nil,
      companies: @multi_company_user[:companies]
    )
    
    get select_company_url
    assert_response :success
    assert_select "h2", text: /Select a Company/
    assert_select "button[type=submit]", count: 2, text: /Company/
  end

  test "should auto-select if user has only one company" do
    setup_authenticated_session(
      role: "viewer",
      company_id: 1,
      companies: @single_company_user[:companies]
    )
    
    AuthService.stubs(:switch_company).returns(mock_switch_response(1))
    
    get select_company_url
    assert_redirected_to dashboard_path
  end

  test "should switch company successfully" do
    setup_authenticated_session(
      role: "manager",
      company_id: 1,
      companies: @multi_company_user[:companies]
    )
    
    AuthService.stubs(:switch_company).returns(mock_switch_response(2))
    
    post switch_company_url, params: { company_id: 2 }
    
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_equal 2, session[:company_id]
    assert_equal "Successfully switched to Company B", flash[:notice]
  end

  test "should handle missing company_id in switch" do
    setup_authenticated_session(
      role: "manager",
      company_id: 1,
      companies: @multi_company_user[:companies]
    )
    
    post switch_company_url, params: { company_id: "" }
    
    assert_redirected_to select_company_path
    follow_redirect!
    assert_equal "Please select a company", flash[:alert]
  end

  test "should handle company switch failure" do
    setup_authenticated_session(
      role: "manager",
      company_id: 1,
      companies: @multi_company_user[:companies]
    )
    
    AuthService.stubs(:switch_company).returns(nil)
    
    post switch_company_url, params: { company_id: 2 }
    
    assert_redirected_to select_company_path
    follow_redirect!
    assert_equal "Failed to switch company", flash[:alert]
  end

  test "should redirect to login if not authenticated for select" do
    get select_company_url
    assert_redirected_to login_path
  end

  test "should show company management page" do
    setup_authenticated_session(role: "viewer", company_id: 1)
    
    CompanyService.stubs(:all).returns(mock_companies_response)
    
    get companies_url
    assert_response :success
    assert_select "h1", text: /Companies/
  end

  test "should create new company" do
    setup_authenticated_session(role: "manager", company_id: 1)
    
    company_params = {
      name: "New Company",
      tax_id: "B12345678",
      email: "info@newcompany.com"
    }
    
    CompanyService.stubs(:create).returns({ data: { id: 3 }, id: 3 })
    
    post companies_url, params: { company: company_params }
    
    assert_redirected_to company_path(3)
    follow_redirect!
    assert_equal "Company was successfully created.", flash[:notice]
  end

  private

  def mock_switch_response(company_id)
    {
      access_token: "new_token_#{company_id}",
      refresh_token: "new_refresh_#{company_id}",
      company_id: company_id,
      user: {
        id: 1,
        email: "manager@example.com",
        name: "Manager User",
        company_name: company_id == 1 ? "Company A" : "Company B"
      },
      companies: @multi_company_user[:companies]
    }
  end

  def mock_companies_response
    {
      companies: [
        { id: 1, name: "Company A", tax_id: "A12345678" },
        { id: 2, name: "Company B", tax_id: "B87654321" }
      ],
      meta: { total: 2, page: 1, pages: 1 }
    }
  end
end