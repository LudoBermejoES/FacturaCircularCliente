require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_authenticated_session(role: "admin", company_id: 1999)
  end

  test "new action loads invoice series data" do
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      }
    ]

    mock_companies = [
      {
        id: 1999,
        name: "Test Company"
      }
    ]

    mock_workflows = [
      {
        id: 1,
        name: "Test Workflow",
        is_active: true
      }
    ]

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    # Mock CompanyContactsService.active_contacts call for load_all_company_contacts
    CompanyContactsService.stubs(:active_contacts)
      .with(company_id: 1999, token: "test_admin_token")
      .returns([])

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: mock_workflows })

    get new_invoice_path

    assert_response :success
    assert assigns(:invoice_series)
    assert_equal mock_invoice_series, assigns(:invoice_series)
    assert assigns(:workflows)
    assert_equal mock_workflows, assigns(:workflows)
  end

  test "new action handles API service errors when loading series" do
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .raises(ApiService::ApiError, "Failed to load series")

    get new_invoice_path

    assert_response :success
    assert_equal [], assigns(:invoice_series)
  end

  test "new action renders form with correct structure" do
    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales",
        year: 2025,
        is_active: true
      }
    ]

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    get new_invoice_path

    assert_response :success
    
    # Check that the form contains the series dropdown
    assert_select 'select[name="invoice[invoice_series_id]"]'
    assert_select 'option', text: /FC - Facturas Comerciales/

    # Check that the workflow dropdown exists
    assert_select 'select[name="invoice[workflow_definition_id]"]'

    # Check that the invoice number field is read-only
    assert_select 'input[name="invoice[invoice_number]"][readonly]'

    # Check for Stimulus controller data attributes
    assert_select '[data-controller*="invoice-form"]'
    assert_select '[data-invoice-form-target="seriesSelect"]'
    assert_select '[data-invoice-form-target="invoiceNumber"]'
    assert_select '[data-action*="invoice-form#onSeriesChange"]'
  end

  test "create action includes invoice_series_id in permitted parameters" do
    mock_invoice_series = [{ id: 874, series_code: "FC", series_name: "Facturas Comerciales" }]

    mock_companies = [
      {
        id: 1999,
        name: "Test Company"
      }
    ]

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    # Comprehensive stubbing to prevent WebMock errors
    CompanyContactsService.stubs(:active_contacts).returns([])

    mock_create_response = {
      data: { id: 123 },
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874,
      status: "draft"
    }

    InvoiceService.stubs(:create)
      .returns(mock_create_response)

    invoice_params = {
      invoice_series_id: 874,
      invoice_number: "FC-2025-0001",
      invoice_type: "invoice",
      status: "draft",
      seller_party_id: 1999,
      buyer_party_id: 1999,
      issue_date: "2025-01-15",
      due_date: "2025-02-15"
    }

    post invoices_path, params: { invoice: invoice_params }

    assert_redirected_to invoice_path(123)
  end

  test "create action validates required invoice_series_id" do
    mock_invoice_series = [{ id: 874, series_code: "FC", series_name: "Facturas Comerciales" }]

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])
    
    # Stub InvoiceService.create to raise a validation error
    validation_errors = [
      {
        status: "422",
        source: { pointer: "/data/attributes/invoice_series_id" },
        title: "Validation Error",
        detail: "Invoice series can't be blank",
        code: "VALIDATION_ERROR"
      }
    ]
    InvoiceService.stubs(:create).raises(ApiService::ValidationError.new("Validation failed", validation_errors))

    invoice_params = {
      # Missing invoice_series_id
      invoice_number: "FC-2025-0001",
      invoice_type: "invoice",
      status: "draft"
    }

    post invoices_path, params: { invoice: invoice_params }

    assert_response :unprocessable_content # Re-renders form with errors
  end

  test "edit action loads invoice series for form" do
    mock_invoice = {
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874
    }

    mock_invoice_series = [
      {
        id: 874,
        series_code: "FC",
        series_name: "Facturas Comerciales"
      }
    ]

    InvoiceService.stubs(:find)
      .returns(mock_invoice)

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])

    get edit_invoice_path(123)

    assert_response :success
    assert assigns(:invoice_series)
    assert_equal mock_invoice_series, assigns(:invoice_series)
  end

  test "update action handles invoice_series_id changes" do
    mock_invoice = {
      id: 123,
      invoice_number: "FC-2025-0001",
      invoice_series_id: 874
    }

    mock_invoice_series = [{ id: 875, series_code: "PF", series_name: "Proformas" }]

    InvoiceService.stubs(:find).returns(mock_invoice)

    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    # Mock CompanyContactsService.all call that was added recently
    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])

    updated_invoice = mock_invoice.merge(
      invoice_series_id: 875,
      invoice_number: "PF-2025-0001"
    )

    InvoiceService.stubs(:update)
      .returns(updated_invoice)

    patch invoice_path(123), params: {
      invoice: {
        invoice_series_id: 875,
        invoice_number: "PF-2025-0001"
      }
    }

    assert_redirected_to invoice_path(123)
  end

  test "new action loads workflow definitions" do
    mock_workflows = [
      {
        id: 1,
        name: "Test Workflow",
        is_active: true
      },
      {
        id: 2,
        name: "Approval Workflow",
        is_active: true
      }
    ]

    # Mock all required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns([])

    CompanyContactsService.stubs(:active_contacts).returns([])

    # Mock WorkflowService.definitions call
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: mock_workflows })

    get new_invoice_path

    assert_response :success
    assert assigns(:workflows)
    assert_equal mock_workflows, assigns(:workflows)
  end

  test "new action handles workflow service errors gracefully" do
    # Mock other required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns([])

    CompanyContactsService.stubs(:active_contacts).returns([])

    # Mock WorkflowService.definitions to raise an error
    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .raises(ApiService::ApiError, "Failed to load workflows")

    get new_invoice_path

    assert_response :success
    assert_equal [], assigns(:workflows)
  end

  test "create action includes workflow_definition_id in permitted parameters" do
    mock_companies = [{ id: 1999, name: "Test Company" }]

    # Mock all required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: mock_companies })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns([])

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])

    mock_create_response = {
      data: { id: 123 },
      id: 123,
      invoice_number: "FC-2025-0001",
      workflow_definition_id: 1,
      status: "draft"
    }

    InvoiceService.stubs(:create)
      .returns(mock_create_response)

    invoice_params = {
      invoice_series_id: 874,
      invoice_type: "invoice",
      status: "draft",
      workflow_definition_id: 1,
      seller_party_id: 1999,
      buyer_party_id: 1999,
      issue_date: "2025-01-15",
      due_date: "2025-02-15"
    }

    post invoices_path, params: { invoice: invoice_params }

    assert_redirected_to invoice_path(123)
  end

  test "form contains workflow selection dropdown" do
    mock_workflows = [
      { id: 1, name: "Test Workflow" },
      { id: 2, name: "Approval Workflow" }
    ]

    # Mock all required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns([])

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: mock_workflows })

    CompanyContactsService.stubs(:active_contacts).returns([])

    get new_invoice_path

    assert_response :success

    # Check that the workflow dropdown exists
    assert_select 'select[name="invoice[workflow_definition_id]"]'
    assert_select 'option', text: "Select workflow (optional)"
    assert_select 'option', text: "Test Workflow"
    assert_select 'option', text: "Approval Workflow"
  end

  test "form contains invoice type dropdown with correct data attributes" do
    mock_invoice_series = [
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
        series_name: "Proforma",
        year: 2025,
        is_active: true
      }
    ]

    # Mock all required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])

    get new_invoice_path

    assert_response :success

    # Check that the invoice type dropdown exists with proper data attributes
    assert_select 'select[name="invoice[invoice_type]"]'
    assert_select 'select[data-action*="change->invoice-form#onInvoiceTypeChange"]'
    assert_select 'select[data-invoice-form-target="invoiceTypeSelect"]'

    # Check that all invoice type options are present
    assert_select 'option[value="invoice"]', text: 'Invoice'
    assert_select 'option[value="credit_note"]', text: 'Credit Note'
    assert_select 'option[value="debit_note"]', text: 'Debit Note'
    assert_select 'option[value="proforma"]', text: 'Proforma'
  end

  test "form includes Stimulus controller data attributes for series filtering" do
    mock_invoice_series = [
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
        series_name: "Proforma",
        year: 2025,
        is_active: true
      }
    ]

    # Mock all required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])

    get new_invoice_path

    assert_response :success

    # Verify form has invoice-form Stimulus controller
    assert_select '[data-controller*="invoice-form"]'

    # Verify series select has correct targets and actions
    assert_select 'select[data-invoice-form-target="seriesSelect"]'
    assert_select 'select[data-action*="invoice-form#onSeriesChange"]'

    # Verify invoice type select has correct targets and actions
    assert_select 'select[data-invoice-form-target="invoiceTypeSelect"]'
    assert_select 'select[data-action*="invoice-form#onInvoiceTypeChange"]'

    # Verify invoice number field has target
    assert_select 'input[data-invoice-form-target="invoiceNumber"]'
  end

  test "new action populates multiple invoice series for filtering" do
    mock_invoice_series = [
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
        series_name: "Proforma",
        year: 2025,
        is_active: true
      },
      {
        id: 876,
        series_code: "CR",
        series_name: "Credit Note",
        year: 2025,
        is_active: true
      },
      {
        id: 877,
        series_code: "DB",
        series_name: "Debit Note",
        year: 2025,
        is_active: true
      }
    ]

    # Mock all required services
    CompanyService.stubs(:all)
      .with(token: "test_admin_token", params: { per_page: 100 })
      .returns({ companies: [] })

    CompanyContactsService.stubs(:all)
      .with(company_id: 1999, token: "test_admin_token", params: { per_page: 100 })
      .returns({ contacts: [] })

    InvoiceSeriesService.stubs(:all)
      .with(token: "test_admin_token", filters: { year: Date.current.year, active_only: true })
      .returns(mock_invoice_series)

    WorkflowService.stubs(:definitions)
      .with(token: "test_admin_token")
      .returns({ data: [] })

    CompanyContactsService.stubs(:active_contacts).returns([])

    get new_invoice_path

    assert_response :success
    assert assigns(:invoice_series)
    assert_equal mock_invoice_series, assigns(:invoice_series)

    # Verify all series types are available in the dropdown
    assert_select 'option', text: /FC - Facturas Comerciales/
    assert_select 'option', text: /PF - Proforma/
    assert_select 'option', text: /CR - Credit Note/
    assert_select 'option', text: /DB - Debit Note/
  end

  # Test for show action with company contact loading
  test "show action loads seller company information" do
    invoice_data = {
      id: "729",
      invoice_number: "PF-0001",
      seller_party_id: 1859,
      buyer_party_id: nil,
      buyer_company_contact_id: nil,
      status: "draft",
      total: 0.0
    }

    seller_company = {
      id: 1859,
      name: "TechSol",
      tax_id: "B12345678",
      email: "info@techsol.com",
      phone: "+34912345678"
    }

    InvoiceService.stubs(:find)
      .with("729", token: "test_admin_token")
      .returns(invoice_data)

    CompanyService.stubs(:find)
      .with(1859, token: "test_admin_token")
      .returns(seller_company)

    get invoice_path(729)

    assert_response :success
    assert_equal invoice_data, assigns(:invoice)
    assert_equal seller_company, assigns(:seller_company)
    assert_nil assigns(:buyer_company)
    assert_nil assigns(:buyer_contact)
  end

  test "show action loads buyer company information when buyer_party_id is present" do
    invoice_data = {
      id: "727",
      invoice_number: "FC-2025-0001",
      seller_party_id: 1859,
      buyer_party_id: 1860,
      buyer_company_contact_id: nil,
      status: "draft",
      total: 1210.0
    }

    seller_company = {
      id: 1859,
      name: "TechSol",
      tax_id: "B12345678"
    }

    buyer_company = {
      id: 1860,
      name: "GreenWaste",
      tax_id: "B23456789"
    }

    InvoiceService.stubs(:find)
      .with("727", token: "test_admin_token")
      .returns(invoice_data)

    CompanyService.stubs(:find)
      .with(1859, token: "test_admin_token")
      .returns(seller_company)

    CompanyService.stubs(:find)
      .with(1860, token: "test_admin_token")
      .returns(buyer_company)

    get invoice_path(727)

    assert_response :success
    assert_equal invoice_data, assigns(:invoice)
    assert_equal seller_company, assigns(:seller_company)
    assert_equal buyer_company, assigns(:buyer_company)
    assert_nil assigns(:buyer_contact)
  end

  test "show action loads buyer contact information when buyer_company_contact_id is present" do
    invoice_data = {
      id: "729",
      invoice_number: "PF-0001",
      seller_party_id: 1859,
      buyer_party_id: nil,
      buyer_company_contact_id: 112,
      buyer_name: "DataCenter Barcelona (Contact)",
      status: "draft",
      total: 0.0
    }

    seller_company = {
      id: 1859,
      name: "TechSol",
      tax_id: "B12345678"
    }

    buyer_contact = {
      id: "112",
      company_name: "DataCenter Barcelona S.A.",
      legal_name: "DataCenter Barcelona S.A.",
      tax_id: "A22222222",
      email: "services@datacenterbarcelona.com",
      phone: "+34 933 789 012"
    }

    InvoiceService.stubs(:find)
      .with("729", token: "test_admin_token")
      .returns(invoice_data)

    CompanyService.stubs(:find)
      .with(1859, token: "test_admin_token")
      .returns(seller_company)

    CompanyContactService.stubs(:find)
      .with(112, company_id: 1859, token: "test_admin_token")
      .returns(buyer_contact)

    get invoice_path(729)

    assert_response :success
    assert_equal invoice_data, assigns(:invoice)
    assert_equal seller_company, assigns(:seller_company)
    assert_nil assigns(:buyer_company)
    assert_equal buyer_contact, assigns(:buyer_contact)
  end

  test "show action falls back to placeholder when company contact loading fails" do
    invoice_data = {
      id: "729",
      invoice_number: "PF-0001",
      seller_party_id: 1859,
      buyer_party_id: nil,
      buyer_company_contact_id: 112,
      buyer_name: "DataCenter Barcelona (Contact)",
      status: "draft",
      total: 0.0
    }

    seller_company = {
      id: 1859,
      name: "TechSol",
      tax_id: "B12345678"
    }

    InvoiceService.stubs(:find)
      .with("729", token: "test_admin_token")
      .returns(invoice_data)

    CompanyService.stubs(:find)
      .with(1859, token: "test_admin_token")
      .returns(seller_company)

    # Mock CompanyContactService to return nil (simulating failure)
    CompanyContactService.stubs(:find)
      .with(112, company_id: 1859, token: "test_admin_token")
      .returns(nil)

    get invoice_path(729)

    assert_response :success
    assert_equal invoice_data, assigns(:invoice)
    assert_equal seller_company, assigns(:seller_company)
    assert_nil assigns(:buyer_company)

    # Should fall back to placeholder contact
    expected_placeholder = {
      id: 112,
      company_name: "DataCenter Barcelona (Contact)",
      email: nil,
      phone: nil,
      tax_id: nil
    }
    assert_equal expected_placeholder, assigns(:buyer_contact)
  end

  test "show action handles missing seller_party_id gracefully" do
    invoice_data = {
      id: "729",
      invoice_number: "PF-0001",
      seller_party_id: nil,
      buyer_party_id: nil,
      buyer_company_contact_id: 112,
      buyer_name: "DataCenter Barcelona (Contact)",
      status: "draft",
      total: 0.0
    }

    InvoiceService.stubs(:find)
      .with("729", token: "test_admin_token")
      .returns(invoice_data)

    get invoice_path(729)

    assert_response :success
    assert_equal invoice_data, assigns(:invoice)
    assert_nil assigns(:seller_company)
    assert_nil assigns(:buyer_company)

    # Should still create placeholder contact
    expected_placeholder = {
      id: 112,
      company_name: "DataCenter Barcelona (Contact)",
      email: nil,
      phone: nil,
      tax_id: nil
    }
    assert_equal expected_placeholder, assigns(:buyer_contact)
  end

  private

  def mock_required_services
    # Mock all required services to prevent API calls during testing
    InvoiceService.stubs(:recent).returns([])
    CompanyService.stubs(:all).returns([])
  end
end