require 'test_helper'

class InvoiceWorkflowSimplifiedTest < ActionDispatch::IntegrationTest
  setup do
    # Use the same authentication approach as working system tests
    AuthService.stubs(:login).returns({
      access_token: "test_admin_token",
      refresh_token: "test_refresh_token",
      user: {
        id: 1,
        email: "admin@example.com",
        name: "Admin User",
        company_id: 1859
      },
      company_id: 1859,
      companies: [{ id: 1859, name: "Test Company", role: "admin" }]
    })

    AuthService.stubs(:validate_token).returns({ valid: true })

    # Mock basic API services with simplified responses
    InvoiceService.stubs(:all).returns({ invoices: [], meta: { total: 0 } })
    InvoiceService.stubs(:statistics).returns({ total_count: 0 })
    InvoiceService.stubs(:recent).returns([])
    InvoiceService.stubs(:create).returns({ data: { id: "737" } })
    InvoiceService.stubs(:find).returns({
      id: 737,
      invoice_number: "FC-0002",
      status: "draft",
      has_workflow: true
    })

    CompanyService.stubs(:all).returns({ companies: [] })
    InvoiceSeriesService.stubs(:all).returns([])
    CompanyContactsService.stubs(:all).returns({ contacts: [] })
    WorkflowService.stubs(:definitions).returns({ data: [] })
    WorkflowService.stubs(:available_transitions).returns({ available_transitions: [] })
    WorkflowService.stubs(:transition).returns({ success: true })
    WorkflowService.stubs(:history).returns([])

    # Perform login to establish session (same as system tests)
    post login_path, params: {
      email: "admin@example.com",
      password: "password123"
    }
  end

  test "can access invoices page for workflow management" do
    get invoices_path
    assert_response :success
    assert_select "h1", /Invoices/
  end

  test "can access new invoice page" do
    get new_invoice_path
    assert_response :success
    assert_select "h1", /New Invoice/
  end

  test "can access invoice show page" do
    get invoice_path(737)
    assert_response :success
  end

  test "invoice workflow navigation is accessible" do
    # Mock specific invoice for workflow testing
    InvoiceService.stubs(:find).returns({
      id: 737,
      invoice_number: "FC-0002",
      status: "draft",
      has_workflow: true,
      workflow_definition_id: 373
    })

    get invoice_workflow_path(737)
    assert_response :success
  end

  test "authenticated user can navigate invoice workflow sections" do
    # Test main invoice navigation is accessible
    get invoices_path
    assert_response :success

    get new_invoice_path
    assert_response :success

    # Test specific invoice workflow access
    get invoice_workflow_path(737)
    assert_response :success
  end
end