require 'test_helper'

class SimplifiedIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    # Use the same authentication approach as working system tests
    AuthService.stubs(:login).returns({
      access_token: "test_admin_token",
      refresh_token: "test_refresh_token",
      user: {
        id: 1,
        email: "admin@example.com",
        name: "Admin User",
        company_id: 1
      },
      company_id: 1,
      companies: [{ id: 1, name: "Test Company", role: "admin" }]
    })

    AuthService.stubs(:validate_token).returns({ valid: true })

    # Mock basic API services with the same pattern as system tests
    InvoiceService.stubs(:all).returns({ invoices: [], meta: { total: 0 } })
    InvoiceService.stubs(:statistics).returns({ total_count: 0 })
    InvoiceService.stubs(:recent).returns([])
    CompanyService.stubs(:all).returns({ companies: [] })
    InvoiceSeriesService.stubs(:all).returns([])
    CompanyContactsService.stubs(:all).returns({ contacts: [] })
    WorkflowService.stubs(:definitions).returns({ data: [] })

    # Perform login to establish session (same as system tests)
    post login_path, params: {
      email: "admin@example.com",
      password: "password123"
    }
  end

  test "can access dashboard page" do
    get root_path
    assert_response :success
    assert_select "title", /FacturaCircular/
  end

  test "can access invoices index page" do
    get invoices_path
    assert_response :success
    assert_select "h1", /Invoices/
  end

  test "can access new invoice page" do
    get new_invoice_path
    assert_response :success
    assert_select "h1", /New Invoice/
  end

  test "can access companies page" do
    get companies_path
    assert_response :success
    assert_select "h1", /Companies/
  end

  test "authenticated user can navigate main sections" do
    # Test main navigation is accessible
    get root_path
    assert_response :success

    get invoices_path
    assert_response :success

    get companies_path
    assert_response :success
  end
end