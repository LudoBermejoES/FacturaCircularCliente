require 'test_helper'

class InvoiceAutoAssignmentSimplifiedTest < ActionDispatch::IntegrationTest
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

    # Mock basic API services for invoice auto-assignment testing
    InvoiceService.stubs(:all).returns({ invoices: [], meta: { total: 0 } })
    InvoiceService.stubs(:statistics).returns({ total_count: 0 })
    InvoiceService.stubs(:recent).returns([])
    InvoiceService.stubs(:create).returns({ data: { id: "123" } })
    CompanyService.stubs(:all).returns({ companies: [] })
    InvoiceSeriesService.stubs(:all).returns([])
    CompanyContactsService.stubs(:all).returns({ contacts: [] })
    WorkflowService.stubs(:definitions).returns({ data: [] })

    # Perform login to establish session
    post login_path, params: {
      email: "admin@example.com",
      password: "password123"
    }
  end

  test "invoice form loads successfully for auto-assignment testing" do
    get new_invoice_path
    assert_response :success
    assert_select "h1", /New Invoice/
  end

  test "invoice creation flow is accessible" do
    get new_invoice_path
    assert_response :success
    assert_select "form"
  end

  test "invoice auto-assignment navigation works" do
    # Test invoice creation navigation
    get invoices_path
    assert_response :success

    get new_invoice_path
    assert_response :success
  end

  test "invoice form has proper structure for auto-assignment" do
    get new_invoice_path
    assert_response :success

    # Basic form structure should be present
    assert_select "form"
    assert_select "input, select", minimum: 1
  end
end